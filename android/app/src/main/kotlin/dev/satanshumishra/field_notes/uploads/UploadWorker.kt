package dev.satanshumishra.field_notes.uploads

import android.content.Context
import android.content.pm.ServiceInfo
import androidx.work.ForegroundInfo
import androidx.work.Worker
import androidx.work.WorkerParameters
import java.util.concurrent.ExecutionException

class UploadWorker(context: Context, params: WorkerParameters) : Worker(context, params) {
    @Volatile
    private var runner: UploadRunner? = null

    override fun doWork(): Result {
        val lane = Lane.ofName(inputData.getString(LANE_KEY)) ?: return Result.success()
        val notifications = UploadNotifications(applicationContext)
        val inForeground = moveToForeground(ForegroundInfo(lane.notificationId, notifications.build(lane, 0, 0), DATA_SYNC))
        val throttle = ProgressThrottle()
        val current = UploadRunner(
            store = UploadStore.of(applicationContext),
            transport = HttpTransport(null, applicationContext.dataDir),
            lane = lane,
            onProgress = { sent, total ->
                if (inForeground && throttle.due(sent, total)) {
                    moveToForeground(ForegroundInfo(lane.notificationId, notifications.build(lane, sent, total), DATA_SYNC))
                }
            },
        )
        runner = current
        if (isStopped) {
            return Result.retry()
        }
        return when (current.run()) {
            UploadRunner.Outcome.DONE -> Result.success()
            UploadRunner.Outcome.RETRY, UploadRunner.Outcome.STOPPED -> Result.retry()
        }
    }

    override fun onStopped() {
        runner?.stop()
    }

    private fun moveToForeground(info: ForegroundInfo): Boolean = try {
        setForegroundAsync(info).get()
        true
    } catch (error: ExecutionException) {
        false
    } catch (error: IllegalStateException) {
        false
    } catch (error: InterruptedException) {
        Thread.currentThread().interrupt()
        false
    }

    companion object {
        const val LANE_KEY = "lane"
        private const val DATA_SYNC = ServiceInfo.FOREGROUND_SERVICE_TYPE_DATA_SYNC
    }
}
