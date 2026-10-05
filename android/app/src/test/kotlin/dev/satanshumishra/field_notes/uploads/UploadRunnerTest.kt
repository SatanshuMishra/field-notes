package dev.satanshumishra.field_notes.uploads

import org.json.JSONObject
import org.junit.Assert.assertEquals
import org.junit.Assert.assertFalse
import org.junit.Assert.assertTrue
import org.junit.Before
import org.junit.Test
import java.io.File
import java.nio.file.Files
import java.util.Collections
import java.util.concurrent.CountDownLatch
import java.util.concurrent.TimeUnit
import java.util.concurrent.atomic.AtomicInteger

class UploadRunnerTest {
    private lateinit var root: File
    private lateinit var store: UploadStore
    private lateinit var coordinator: UploadCoordinator

    @Before
    fun setUp() {
        root = Files.createTempDirectory("uploads").toFile()
        store = UploadStore(File(root, "store"))
        coordinator = UploadCoordinator()
    }

    private fun item(taskId: String, push: Boolean = false, requiresWiFi: Boolean = false, bytes: Int = 1024): UploadItem {
        val body = File(root, "$taskId.bin")
        body.writeBytes(ByteArray(bytes))
        return UploadItem(
            taskId = taskId,
            group = if (push) UploadItem.PUSH_GROUP else "field_notes_media",
            url = "https://relay.test/$taskId",
            method = if (push) "POST" else "PUT",
            headers = mapOf("Authorization" to "UploadPass token"),
            filePath = body.path,
            mimeType = "application/octet-stream",
            requiresWiFi = requiresWiFi,
            metaData = JSONObject().put("taskId", taskId).toString(),
        )
    }

    private fun runner(transport: UploadTransport, lane: Lane = Lane.ANY) =
        UploadRunner(store, transport, lane, coordinator)

    private fun results(): Map<String, JSONObject> = store.takeResults().associateBy {
        it.getJSONObject("task").getString("taskId")
    }

    private class FakeTransport(
        private val answer: (UploadItem, Int) -> TransportAnswer = { _, _ -> TransportAnswer(200, "{}") },
        private val delayMillis: Long = 0,
    ) : UploadTransport {
        val sent: MutableList<String> = Collections.synchronizedList(mutableListOf())
        private val calls = mutableMapOf<String, Int>()
        private val partsNow = AtomicInteger(0)
        val mostPartsAtOnce = AtomicInteger(0)
        var onSend: (UploadItem) -> Unit = {}

        override fun send(item: UploadItem, onBytes: (Long) -> Unit): TransportAnswer {
            val call = synchronized(calls) {
                val next = (calls[item.taskId] ?: 0) + 1
                calls[item.taskId] = next
                next
            }
            sent.add(item.taskId)
            onSend(item)
            if (!item.isPush) {
                mostPartsAtOnce.accumulateAndGet(partsNow.incrementAndGet(), ::maxOf)
            }
            try {
                Thread.sleep(delayMillis)
                onBytes(File(item.filePath).length())
                return answer(item, call)
            } finally {
                if (!item.isPush) {
                    partsNow.decrementAndGet()
                }
            }
        }

        override fun abortAll() = Unit
    }

    @Test
    fun at_most_two_parts_go_at_once_and_pushes_do_not_wait_for_them() {
        for (index in 0 until 6) {
            store.put(item("part.video.$index"))
        }
        store.put(item("push.notes", push = true))
        val transport = FakeTransport(delayMillis = 60)

        val outcome = runner(transport).run()

        assertEquals(UploadRunner.Outcome.DONE, outcome)
        assertEquals(2, transport.mostPartsAtOnce.get())
        assertTrue(transport.sent.indexOf("push.notes") < 3)
        val finished = results()
        assertEquals(7, finished.size)
        assertTrue(finished.values.all { it.getString("status") == "complete" })
        assertTrue(store.pending().isEmpty())
    }

    @Test
    fun both_lanes_together_still_send_at_most_two_parts() {
        for (index in 0 until 4) {
            store.put(item("part.poster.$index"))
            store.put(item("part.video.$index", requiresWiFi = true))
        }
        val transport = FakeTransport(delayMillis = 60)
        val lanes = listOf(Lane.ANY, Lane.UNMETERED).map { lane -> Thread { runner(transport, lane).run() } }

        lanes.forEach { it.start() }
        lanes.forEach { it.join(10_000) }

        assertEquals(2, transport.mostPartsAtOnce.get())
        assertEquals(8, results().size)
    }

    @Test
    fun items_go_in_the_order_they_were_added() {
        store.put(item("push.zz", push = true))
        store.put(item("push.aa", push = true))
        val transport = FakeTransport()

        runner(transport).run()

        assertEquals(listOf("push.zz", "push.aa"), transport.sent)
    }

    @Test
    fun a_transient_failure_counts_an_attempt_and_asks_for_a_retry() {
        store.put(item("part.video.0"))
        store.put(item("part.video.1"))
        val transport = FakeTransport(answer = { item, call ->
            if (item.taskId == "part.video.0" && call == 1) TransportAnswer(503, "") else TransportAnswer(200, "{}")
        })

        assertEquals(UploadRunner.Outcome.RETRY, runner(transport).run())
        assertEquals(setOf("part.video.1"), results().keys)
        assertEquals(1, store.pending().single().attempts)

        assertEquals(UploadRunner.Outcome.DONE, runner(transport).run())
        assertEquals("complete", results().getValue("part.video.0").getString("status"))
    }

    @Test
    fun a_lost_connection_is_retried_like_a_server_error() {
        store.put(item("part.video.0"))
        val transport = FakeTransport(answer = { _, call ->
            if (call == 1) throw java.io.IOException("bad record mac") else TransportAnswer(200, "{}")
        })

        assertEquals(UploadRunner.Outcome.RETRY, runner(transport).run())
        assertEquals(UploadRunner.Outcome.DONE, runner(transport).run())
        assertEquals("complete", results().getValue("part.video.0").getString("status"))
    }

    @Test
    fun the_tenth_failed_attempt_is_reported_as_failed() {
        store.put(item("part.video.0"))
        val transport = FakeTransport(answer = { _, _ -> TransportAnswer(429, "") })

        repeat(UploadItem.MAX_ATTEMPTS - 1) {
            assertEquals(UploadRunner.Outcome.RETRY, runner(transport).run())
        }
        assertEquals(UploadRunner.Outcome.DONE, runner(transport).run())

        val failed = results().getValue("part.video.0")
        assertEquals("failed", failed.getString("status"))
        assertEquals(UploadItem.MAX_ATTEMPTS, transport.sent.size)
        assertTrue(store.pending().isEmpty())
    }

    @Test
    fun a_refusal_is_final_and_keeps_the_answer() {
        store.put(item("push.notes", push = true))
        val transport = FakeTransport(answer = { _, _ -> TransportAnswer(401, "{\"error\":\"unauthorized\"}") })

        assertEquals(UploadRunner.Outcome.DONE, runner(transport).run())

        val failed = results().getValue("push.notes")
        assertEquals("failed", failed.getString("status"))
        assertEquals(401, failed.getInt("statusCode"))
        assertEquals("{\"error\":\"unauthorized\"}", failed.getString("body"))
    }

    @Test
    fun a_cancelled_upload_leaves_no_result() {
        store.put(item("part.video.0"))
        val started = CountDownLatch(1)
        val cancelled = CountDownLatch(1)
        val transport = FakeTransport()
        transport.onSend = {
            started.countDown()
            cancelled.await(5, TimeUnit.SECONDS)
        }
        val worker = Thread { runner(transport).run() }
        worker.start()
        assertTrue(started.await(5, TimeUnit.SECONDS))

        store.cancel(listOf("part.video.0"))
        cancelled.countDown()
        worker.join(5_000)

        assertTrue(results().isEmpty())
        assertTrue(store.pending().isEmpty())
    }

    @Test
    fun each_lane_sends_only_its_own_items() {
        store.put(item("part.poster.0"))
        store.put(item("part.video.0", requiresWiFi = true))
        val transport = FakeTransport()

        runner(transport, Lane.UNMETERED).run()

        assertEquals(listOf("part.video.0"), transport.sent)
        assertEquals(listOf("part.poster.0"), store.pending().map { it.taskId })
    }

    @Test
    fun a_lane_reports_work_added_while_it_runs() {
        store.put(item("part.video.0"))
        val transport = FakeTransport()
        transport.onSend = { sent ->
            if (sent.taskId == "part.video.0") {
                store.put(item("part.video.1"))
            }
        }

        assertEquals(UploadRunner.Outcome.DONE, runner(transport).run())

        assertEquals(listOf("part.video.0", "part.video.1"), transport.sent)
        assertFalse(coordinator.isActive(Lane.ANY))
    }

    @Test
    fun re_adding_an_item_resets_its_attempts_and_drops_a_stale_result() {
        val first = store.put(item("part.video.0"))
        store.recordAttempt(first)
        store.finish(UploadResult(store.pending().single(), true, 200, "{}"))
        store.put(item("part.video.0"))

        assertTrue(store.takeResults().isEmpty())
        assertEquals(0, store.pending().single().attempts)
    }

    @Test(expected = IllegalArgumentException::class)
    fun a_task_id_that_could_leave_the_folder_is_refused() {
        store.put(item("part.video.0").copy(taskId = "../escape"))
    }
}
