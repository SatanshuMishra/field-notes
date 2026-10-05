package dev.satanshumishra.field_notes.uploads

import android.app.job.JobParameters
import android.app.job.JobService
import android.os.Build
import java.util.concurrent.ConcurrentHashMap
import kotlin.concurrent.thread

class UploadJobService : JobService() {
    private val runners = ConcurrentHashMap<Int, UploadRunner>()

    override fun onStartJob(params: JobParameters): Boolean {
        val lane = Lane.ofJob(params.jobId) ?: return false
        val notifications = UploadNotifications(applicationContext)
        val userInitiated = Build.VERSION.SDK_INT >= Build.VERSION_CODES.UPSIDE_DOWN_CAKE && params.isUserInitiatedJob
        if (userInitiated) {
            setNotification(params, lane.notificationId, notifications.build(lane, 0, 0), JOB_END_NOTIFICATION_POLICY_REMOVE)
        }
        val throttle = ProgressThrottle()
        val runner = UploadRunner(
            store = UploadStore.of(applicationContext),
            transport = HttpTransport(params.network),
            lane = lane,
            onProgress = { sent, total ->
                if (userInitiated && throttle.due(sent, total)) {
                    setNotification(params, lane.notificationId, notifications.build(lane, sent, total), JOB_END_NOTIFICATION_POLICY_REMOVE)
                    updateTransferredNetworkBytes(params, 0, sent)
                }
            },
        )
        runners[params.jobId] = runner
        thread(name = "uploads-job-${lane.name.lowercase()}") {
            val outcome = runner.run()
            if (runners.remove(params.jobId, runner) && outcome != UploadRunner.Outcome.STOPPED) {
                jobFinished(params, outcome == UploadRunner.Outcome.RETRY)
            }
        }
        return true
    }

    override fun onStopJob(params: JobParameters): Boolean {
        runners.remove(params.jobId)?.stop()
        return true
    }
}
