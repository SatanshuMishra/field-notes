package dev.satanshumishra.field_notes.uploads

import org.json.JSONObject
import org.junit.Assert.assertEquals
import org.junit.Assert.assertFalse
import org.junit.Assert.assertTrue
import org.junit.Before
import org.junit.Test
import java.io.File
import java.net.InetAddress
import java.net.ServerSocket
import java.nio.file.Files
import java.util.Collections
import java.util.concurrent.CountDownLatch
import java.util.concurrent.TimeUnit
import java.util.concurrent.atomic.AtomicInteger
import kotlin.concurrent.thread

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

    private val paused: MutableList<Long> = Collections.synchronizedList(mutableListOf())

    private fun runner(
        transport: UploadTransport,
        lane: Lane = Lane.ANY,
        onProgress: (Long, Long) -> Unit = { _, _ -> },
        pause: (Long) -> Unit = { paused.add(it) },
    ) = UploadRunner(store, transport, lane, coordinator, onProgress, pause)

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
    fun a_transient_failure_counts_an_attempt_and_ends_the_run_with_a_retry() {
        store.put(item("part.video.0"))
        store.put(item("part.video.1"))
        val transport = FakeTransport(answer = { item, call ->
            if (item.taskId == "part.video.0" && call == 1) TransportAnswer(503, "") else TransportAnswer(200, "{}")
        })

        assertEquals(UploadRunner.Outcome.RETRY, runner(transport).run())
        val first = results()
        assertEquals(1, store.pending().first { it.taskId == "part.video.0" }.attempts)

        assertEquals(UploadRunner.Outcome.DONE, runner(transport).run())
        val all = first + results()
        assertEquals(setOf("part.video.0", "part.video.1"), all.keys)
        assertTrue(all.values.all { it.getString("status") == "complete" })
    }

    @Test
    fun a_lost_network_charges_only_the_tasks_in_flight() {
        for (index in 0 until 6) {
            store.put(item("part.video.$index"))
        }
        val transport = FakeTransport(
            answer = { _, _ -> throw java.io.IOException("network is unreachable") },
            delayMillis = 30,
        )

        assertEquals(UploadRunner.Outcome.RETRY, runner(transport).run())

        val charged = store.pending().filter { it.attempts > 0 }
        assertEquals(6, store.pending().size)
        assertTrue(charged.size <= UploadCoordinator.PARTS_AT_ONCE)
        assertTrue(charged.all { it.attempts == 1 })
    }

    @Test
    fun work_added_after_a_cancelled_run_is_scheduled() {
        store.put(item("part.video.0"))
        val started = CountDownLatch(1)
        val release = CountDownLatch(1)
        val transport = FakeTransport()
        transport.onSend = {
            started.countDown()
            release.await(5, TimeUnit.SECONDS)
        }
        val running = runner(transport)
        val worker = Thread { running.run() }
        worker.start()
        assertTrue(started.await(5, TimeUnit.SECONDS))
        assertTrue(coordinator.isActive(Lane.ANY))

        running.stop()

        assertFalse(coordinator.isActive(Lane.ANY))
        release.countDown()
        worker.join(5_000)
        assertFalse(coordinator.isActive(Lane.ANY))
    }

    @Test
    fun a_lane_ends_when_its_remaining_work_is_held_by_another_job() {
        store.put(item("part.video.0"))
        assertEquals("part.video.0", coordinator.claimNext { store.pending() }?.taskId)
        val transport = FakeTransport()
        var outcome: UploadRunner.Outcome? = null
        val worker = Thread { outcome = runner(transport).run() }

        worker.start()
        worker.join(2_000)

        assertEquals(UploadRunner.Outcome.DONE, outcome)
        assertTrue(transport.sent.isEmpty())
        assertFalse(coordinator.isActive(Lane.ANY))
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
        val transport = FakeTransport(answer = { _, _ -> TransportAnswer(503, "") })

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
    fun a_slow_down_waits_its_retry_after_and_counts_no_try() {
        store.put(item("part.video.0"))
        val transport = FakeTransport(answer = { _, call ->
            if (call <= 15) TransportAnswer(429, "", retryAfterSeconds = 2) else TransportAnswer(200, "{}")
        })

        assertEquals(UploadRunner.Outcome.DONE, runner(transport).run())

        assertEquals("complete", results().getValue("part.video.0").getString("status"))
        assertEquals(16, transport.sent.size)
        assertEquals(30_000L, paused.sum())
        assertTrue(store.pending().isEmpty())
    }

    @Test
    fun a_slow_down_without_a_wait_waits_thirty_seconds() {
        store.put(item("push.notes", push = true))
        val transport = FakeTransport(answer = { _, call ->
            if (call == 1) TransportAnswer(429, "") else TransportAnswer(200, "{}")
        })

        assertEquals(UploadRunner.Outcome.DONE, runner(transport).run())

        assertEquals(30_000L, paused.sum())
        assertTrue(paused.all { it <= 500L })
        assertEquals("complete", results().getValue("push.notes").getString("status"))
    }

    @Test
    fun a_slow_down_waits_at_most_a_minute() {
        store.put(item("part.video.0"))
        val transport = FakeTransport(answer = { _, call ->
            if (call == 1) TransportAnswer(429, "", retryAfterSeconds = 86_400) else TransportAnswer(200, "{}")
        })

        assertEquals(UploadRunner.Outcome.DONE, runner(transport).run())

        assertEquals(60_000L, paused.sum())
    }

    @Test
    fun a_stopped_lane_stops_waiting_out_a_slow_down() {
        store.put(item("part.video.0"))
        val transport = FakeTransport(answer = { _, _ -> TransportAnswer(429, "", retryAfterSeconds = 60) })
        lateinit var running: UploadRunner
        running = runner(transport, pause = { millis ->
            paused.add(millis)
            running.stop()
        })

        assertEquals(UploadRunner.Outcome.STOPPED, running.run())

        assertEquals(1, paused.size)
        assertEquals(0, store.pending().single().attempts)
        assertTrue(results().isEmpty())
    }

    @Test
    fun a_timeout_or_too_early_answer_counts_a_try() {
        for (code in listOf(408, 425)) {
            store.put(item("part.$code"))
            val transport = FakeTransport(answer = { _, call ->
                if (call == 1) TransportAnswer(code, "") else TransportAnswer(200, "{}")
            })

            assertEquals(UploadRunner.Outcome.RETRY, runner(transport).run())
            assertEquals(1, store.pending().single { it.taskId == "part.$code" }.attempts)
            assertEquals(UploadRunner.Outcome.DONE, runner(transport).run())
        }
        assertTrue(paused.isEmpty())
    }

    @Test
    fun a_slow_down_stops_waiting_when_another_part_fails() {
        store.put(item("part.video.0"))
        store.put(item("part.video.1"))
        val waiting = CountDownLatch(1)
        val transport = FakeTransport(answer = { item, _ ->
            if (item.taskId == "part.video.0") {
                TransportAnswer(429, "", retryAfterSeconds = 60)
            } else {
                waiting.await(5, TimeUnit.SECONDS)
                TransportAnswer(503, "")
            }
        })
        val running = runner(transport, pause = { millis ->
            paused.add(millis)
            waiting.countDown()
            Thread.sleep(5)
        })

        assertEquals(UploadRunner.Outcome.RETRY, running.run())

        assertTrue(paused.size < 60)
        assertEquals(0, store.pending().single { it.taskId == "part.video.0" }.attempts)
        assertEquals(1, store.pending().single { it.taskId == "part.video.1" }.attempts)
    }

    @Test
    fun a_slowed_down_part_is_counted_once_in_the_progress() {
        store.put(item("part.video.0", bytes = 4096))
        val transport = FakeTransport(answer = { _, call ->
            if (call == 1) TransportAnswer(429, "", retryAfterSeconds = 1) else TransportAnswer(200, "{}")
        })
        val reported = Collections.synchronizedList(mutableListOf<Pair<Long, Long>>())

        runner(transport, onProgress = { sent, total -> reported.add(sent to total) }).run()

        assertTrue(reported.all { (sent, total) -> sent <= total })
        assertEquals(4096L to 4096L, reported.last())
    }

    @Test
    fun the_relay_wait_is_read_from_its_answer() {
        ServerSocket(0, 1, InetAddress.getLoopbackAddress()).use { server ->
            val relay = thread {
                server.accept().use { socket ->
                    val input = socket.getInputStream().bufferedReader(Charsets.ISO_8859_1)
                    val headers = generateSequence { input.readLine() }.takeWhile { it.isNotEmpty() }.toList()
                    val length = headers.first { it.startsWith("Content-Length:", ignoreCase = true) }
                        .substringAfter(':').trim().toInt()
                    repeat(length) { input.read() }
                    socket.getOutputStream().write(
                        "HTTP/1.1 429 Too Many Requests\r\nRetry-After: 7\r\nContent-Length: 0\r\nConnection: close\r\n\r\n"
                            .toByteArray(Charsets.ISO_8859_1),
                    )
                }
            }
            val transport = HttpTransport({ null }, root)
            val part = item("part.video.0").copy(url = "http://127.0.0.1:${server.localPort}/part")

            val answer = transport.send(part) { }
            relay.join(5_000)

            assertEquals(429, answer.statusCode)
            assertEquals(7, answer.retryAfterSeconds)
        }
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

    @Test
    fun only_web_addresses_and_upload_methods_are_accepted() {
        val stored = item("part.video.0").storedJson()
        val refused = listOf(
            JSONObject(stored.toString()).put("url", "file:///data/data/app/secret"),
            JSONObject(stored.toString()).put("method", "DELETE"),
        ).count { json ->
            try {
                UploadItem.fromJson(json)
                false
            } catch (error: IllegalArgumentException) {
                true
            }
        }

        assertEquals(2, refused)
    }

    @Test
    fun a_file_outside_the_app_is_never_sent() {
        val outside = Files.createTempFile("outside", ".bin").toFile()
        outside.writeBytes(ByteArray(16))
        val transport = HttpTransport({ null }, File(root, "app"))

        val answer = transport.send(item("part.video.0").copy(filePath = outside.path)) { }

        assertEquals(HttpTransport.MISSING_FILE, answer.statusCode)
    }

    @Test
    fun results_and_queued_tasks_never_carry_the_upload_pass() {
        store.put(item("part.video.0"))

        runner(FakeTransport()).run()

        val task = results().getValue("part.video.0").getJSONObject("task")
        assertFalse(task.has("headers"))
        assertFalse(item("part.video.1").publicJson().has("headers"))
    }

    @Test
    fun an_oversized_answer_is_kept_without_its_body() {
        store.put(item("push.notes", push = true))
        val huge = "x".repeat(HttpTransport.MAX_BODY_BYTES + 1)
        val transport = FakeTransport(answer = { _, _ -> TransportAnswer(200, huge) })

        runner(transport).run()

        val result = results().getValue("push.notes")
        assertEquals("complete", result.getString("status"))
        assertTrue(result.isNull("body"))
    }

    @Test
    fun an_unexpected_error_fails_only_that_task() {
        store.put(item("part.video.0"))
        store.put(item("part.video.1"))
        val transport = FakeTransport(answer = { item, _ ->
            if (item.taskId == "part.video.0") throw IllegalStateException("bad header") else TransportAnswer(200, "{}")
        })

        assertEquals(UploadRunner.Outcome.DONE, runner(transport).run())

        val finished = results()
        assertEquals("failed", finished.getValue("part.video.0").getString("status"))
        assertEquals("complete", finished.getValue("part.video.1").getString("status"))
    }

    @Test
    fun a_failed_store_write_does_not_escape_the_runner() {
        store.put(item("part.video.0"))
        File(root, "store/results").writeText("not a folder")

        val outcome = runner(FakeTransport()).run()

        assertEquals(UploadRunner.Outcome.RETRY, outcome)
        assertEquals(listOf("part.video.0"), store.pending().map { it.taskId })
        assertEquals(0, store.pending().single().attempts)
    }

    @Test
    fun cancelling_everything_keeps_results_already_finished() {
        store.put(item("part.video.0"))
        runner(FakeTransport()).run()
        store.put(item("part.video.1"))

        store.cancelAll()

        assertTrue(store.pending().isEmpty())
        assertEquals(setOf("part.video.0"), results().keys)
    }
}
