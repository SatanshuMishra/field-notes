package dev.satanshumishra.field_notes.uploads

import java.io.File
import java.io.IOException
import java.util.concurrent.Semaphore
import java.util.concurrent.TimeUnit
import java.util.concurrent.atomic.AtomicInteger
import java.util.concurrent.atomic.AtomicLong
import kotlin.concurrent.thread

class UploadCoordinator(partsAtOnce: Int = PARTS_AT_ONCE) {
    private val lock = Any()
    private val claimed = mutableSetOf<String>()
    private val active = mutableMapOf<Lane, MutableSet<Long>>()
    private var lastToken = 0L
    val partSlots = Semaphore(partsAtOnce, true)

    @Volatile
    var onResults: (() -> Unit)? = null

    fun begin(lane: Lane): Long = synchronized(lock) {
        lastToken += 1
        active.getOrPut(lane) { mutableSetOf() }.add(lastToken)
        lastToken
    }

    fun end(lane: Lane, token: Long) = synchronized(lock) { active[lane]?.remove(token) }

    fun isActive(lane: Lane): Boolean = synchronized(lock) { active[lane]?.isNotEmpty() == true }

    fun endIfIdle(lane: Lane, token: Long, candidates: () -> List<UploadItem>): Boolean = synchronized(lock) {
        if (candidates().any { it.taskId !in claimed }) {
            false
        } else {
            active[lane]?.remove(token)
            true
        }
    }

    fun claimNext(candidates: () -> List<UploadItem>): UploadItem? = synchronized(lock) {
        val next = candidates().firstOrNull { it.taskId !in claimed } ?: return null
        claimed.add(next.taskId)
        next
    }

    fun release(taskId: String) = synchronized(lock) { claimed.remove(taskId) }

    fun announceResults() {
        onResults?.invoke()
    }

    companion object {
        const val PARTS_AT_ONCE = 2
        val shared = UploadCoordinator()
    }
}

class UploadRunner(
    private val store: UploadStore,
    private val transport: UploadTransport,
    private val lane: Lane,
    private val coordinator: UploadCoordinator = UploadCoordinator.shared,
    private val onProgress: (sent: Long, total: Long) -> Unit = { _, _ -> },
    private val pause: (millis: Long) -> Unit = { Thread.sleep(it) },
) {
    enum class Outcome { DONE, RETRY, STOPPED }

    @Volatile
    private var stopped = false

    @Volatile
    private var storageFailed = false

    @Volatile
    private var token = NO_TOKEN
    private val skipped = mutableSetOf<String>()
    private val transientFailures = AtomicInteger(0)
    private val counted = mutableSetOf<String>()
    private val sentBytes = AtomicLong(0)
    private val totalBytes = AtomicLong(0)

    fun stop() {
        stopped = true
        coordinator.end(lane, token)
        transport.abortAll()
    }

    fun run(): Outcome {
        token = coordinator.begin(lane)
        try {
            countEligibleParts()
            while (true) {
                runPass()
                if (storageFailed) {
                    return Outcome.RETRY
                }
                if (stopped) {
                    return Outcome.STOPPED
                }
                if (transientFailures.get() > 0) {
                    return Outcome.RETRY
                }
                if (coordinator.endIfIdle(lane, token) { candidates(push = true) + candidates(push = false) }) {
                    return Outcome.DONE
                }
            }
        } finally {
            coordinator.end(lane, token)
        }
    }

    private fun runPass() {
        val workers = listOf(thread(name = "uploads-${lane.name.lowercase()}-pushes") { drain(push = true) }) +
            (1..UploadCoordinator.PARTS_AT_ONCE).map { index ->
                thread(name = "uploads-${lane.name.lowercase()}-parts-$index") { drain(push = false) }
            }
        workers.forEach { it.join() }
    }

    private fun keepGoing(): Boolean = !stopped && transientFailures.get() == 0

    private fun drain(push: Boolean) {
        while (keepGoing()) {
            val item = coordinator.claimNext { candidates(push) } ?: return
            try {
                if (push) {
                    send(item)
                } else if (acquireSlot()) {
                    try {
                        send(item)
                    } finally {
                        coordinator.partSlots.release()
                    }
                }
            } catch (error: IOException) {
                storageFailed = true
                stopped = true
            } catch (error: RuntimeException) {
                failQuietly(item)
            } finally {
                coordinator.release(item.taskId)
            }
        }
    }

    private fun acquireSlot(): Boolean {
        while (!stopped) {
            if (coordinator.partSlots.tryAcquire(SLOT_WAIT_MILLIS, TimeUnit.MILLISECONDS)) {
                return true
            }
        }
        return false
    }

    private fun candidates(push: Boolean): List<UploadItem> {
        val skippedNow = synchronized(skipped) { skipped.toSet() }
        return store.pending().filter { item ->
            item.isPush == push && item.lane == lane && item.taskId !in skippedNow
        }
    }

    private fun countEligibleParts() {
        for (item in candidates(push = false)) {
            count(item)
        }
        report()
    }

    private fun count(item: UploadItem) {
        if (item.isPush) {
            return
        }
        val added = synchronized(counted) { counted.add(item.taskId) }
        if (added) {
            totalBytes.addAndGet(File(item.filePath).length())
        }
    }

    private fun report() {
        onProgress(sentBytes.get(), totalBytes.get())
    }

    private fun send(item: UploadItem) {
        count(item)
        val sentNow = AtomicLong(0)
        val answer = try {
            transport.send(item) { bytes ->
                if (!item.isPush) {
                    sentNow.addAndGet(bytes)
                    sentBytes.addAndGet(bytes)
                    report()
                }
            }
        } catch (error: IOException) {
            if (!stopped) {
                retryLater(item)
            }
            return
        }
        when {
            answer.statusCode in SUCCESS -> finish(item, true, answer)
            answer.statusCode == HttpTransport.MISSING_FILE -> finish(item, false, answer)
            answer.statusCode == TOO_MANY_REQUESTS -> holdOff(answer.retryAfterSeconds, sentNow.get())
            answer.statusCode in TRANSIENT_CODES || answer.statusCode >= SERVER_ERROR -> retryLater(item)
            else -> finish(item, false, answer)
        }
    }

    private fun holdOff(retryAfterSeconds: Int?, unsentBytes: Long) {
        sentBytes.addAndGet(-unsentBytes)
        report()
        val seconds = (retryAfterSeconds ?: DEFAULT_HOLD_OFF_SECONDS).coerceIn(1, MAX_HOLD_OFF_SECONDS)
        var left = seconds * MILLIS_PER_SECOND
        while (left > 0 && keepGoing()) {
            val slice = minOf(left, HOLD_OFF_SLICE_MILLIS)
            try {
                pause(slice)
            } catch (error: InterruptedException) {
                return
            }
            left -= slice
        }
    }

    private fun retryLater(item: UploadItem) {
        val next = store.recordAttempt(item) ?: return
        if (next.attempts >= UploadItem.MAX_ATTEMPTS) {
            finish(next, false, null)
            return
        }
        synchronized(skipped) { skipped.add(item.taskId) }
        transientFailures.incrementAndGet()
    }

    private fun failQuietly(item: UploadItem) {
        try {
            finish(item, false, null)
        } catch (error: IOException) {
            storageFailed = true
            stopped = true
        }
    }

    private fun finish(item: UploadItem, complete: Boolean, answer: TransportAnswer?) {
        val code = answer?.statusCode?.takeIf { it > 0 }
        val body = answer?.body?.takeIf { it.length <= HttpTransport.MAX_BODY_BYTES }
        if (store.finish(UploadResult(item, complete, code, body))) {
            coordinator.announceResults()
        }
    }

    private companion object {
        val SUCCESS = 200..299
        val TRANSIENT_CODES = setOf(408, 425)
        const val TOO_MANY_REQUESTS = 429
        const val DEFAULT_HOLD_OFF_SECONDS = 30
        const val MAX_HOLD_OFF_SECONDS = 60
        const val MILLIS_PER_SECOND = 1000L
        const val HOLD_OFF_SLICE_MILLIS = 500L
        const val SERVER_ERROR = 500
        const val SLOT_WAIT_MILLIS = 500L
        const val NO_TOKEN = -1L
    }
}
