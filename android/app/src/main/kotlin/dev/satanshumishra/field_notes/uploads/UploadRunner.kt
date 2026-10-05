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
    private val active = mutableMapOf<Lane, Int>()
    val partSlots = Semaphore(partsAtOnce, true)

    @Volatile
    var onResults: (() -> Unit)? = null

    fun begin(lane: Lane) = synchronized(lock) { active[lane] = (active[lane] ?: 0) + 1 }

    fun end(lane: Lane) = synchronized(lock) { active[lane] = maxOf(0, (active[lane] ?: 0) - 1) }

    fun isActive(lane: Lane): Boolean = synchronized(lock) { (active[lane] ?: 0) > 0 }

    fun endIfIdle(lane: Lane, hasWork: () -> Boolean): Boolean = synchronized(lock) {
        if (hasWork()) {
            false
        } else {
            active[lane] = maxOf(0, (active[lane] ?: 0) - 1)
            true
        }
    }

    fun claimNext(candidates: () -> List<UploadItem>): UploadItem? = synchronized(lock) {
        val next = candidates().firstOrNull { it.taskId !in claimed } ?: return null
        claimed.add(next.taskId)
        next
    }

    fun isClaimed(taskId: String): Boolean = synchronized(lock) { taskId in claimed }

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
) {
    enum class Outcome { DONE, RETRY, STOPPED }

    @Volatile
    private var stopped = false
    private val skipped = mutableSetOf<String>()
    private val transientFailures = AtomicInteger(0)
    private val counted = mutableSetOf<String>()
    private val sentBytes = AtomicLong(0)
    private val totalBytes = AtomicLong(0)

    fun stop() {
        stopped = true
        transport.abortAll()
    }

    fun run(): Outcome {
        coordinator.begin(lane)
        var ended = false
        try {
            countEligibleParts()
            while (true) {
                runPass()
                if (stopped) {
                    return Outcome.STOPPED
                }
                if (transientFailures.get() > 0) {
                    return Outcome.RETRY
                }
                if (coordinator.endIfIdle(lane) { candidates(push = true).isNotEmpty() || candidates(push = false).isNotEmpty() }) {
                    ended = true
                    return Outcome.DONE
                }
            }
        } finally {
            if (!ended) {
                coordinator.end(lane)
            }
        }
    }

    private fun runPass() {
        val workers = listOf(thread(name = "uploads-${lane.name.lowercase()}-pushes") { drain(push = true) }) +
            (1..UploadCoordinator.PARTS_AT_ONCE).map { index ->
                thread(name = "uploads-${lane.name.lowercase()}-parts-$index") { drain(push = false) }
            }
        workers.forEach { it.join() }
    }

    private fun drain(push: Boolean) {
        while (!stopped) {
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
        val answer = try {
            transport.send(item) { bytes ->
                if (!item.isPush) {
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
            answer.statusCode in TRANSIENT_CODES || answer.statusCode >= SERVER_ERROR -> retryLater(item)
            else -> finish(item, false, answer)
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

    private fun finish(item: UploadItem, complete: Boolean, answer: TransportAnswer?) {
        val code = answer?.statusCode?.takeIf { it > 0 }
        if (store.finish(UploadResult(item, complete, code, answer?.body))) {
            coordinator.announceResults()
        }
    }

    private companion object {
        val SUCCESS = 200..299
        val TRANSIENT_CODES = setOf(408, 425, 429)
        const val SERVER_ERROR = 500
        const val SLOT_WAIT_MILLIS = 500L
    }
}
