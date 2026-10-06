package dev.satanshumishra.field_notes.uploads

import android.app.job.JobInfo
import android.app.job.JobScheduler
import android.content.ComponentName
import android.content.Context
import android.os.Build
import androidx.annotation.RequiresApi
import androidx.work.BackoffPolicy
import androidx.work.Constraints
import androidx.work.Data
import androidx.work.ExistingWorkPolicy
import androidx.work.NetworkType
import androidx.work.OneTimeWorkRequest
import androidx.work.WorkInfo
import androidx.work.WorkManager
import java.io.File
import java.util.concurrent.ExecutionException
import java.util.concurrent.TimeUnit

class UploadScheduler(
    private val context: Context,
    private val store: UploadStore = UploadStore.of(context),
    private val coordinator: UploadCoordinator = UploadCoordinator.shared,
) {
    fun schedule() {
        val pending = store.pending()
        for (lane in Lane.entries) {
            val items = pending.filter { it.lane == lane }
            if (items.isEmpty() || coordinator.isActive(lane)) {
                continue
            }
            val bytes = items.sumOf { File(it.filePath).length() }
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.UPSIDE_DOWN_CAKE && scheduleUserInitiated(lane, bytes)) {
                continue
            }
            scheduleWork(lane)
        }
    }

    fun cancel(taskIds: Collection<String>) {
        store.cancel(taskIds)
        val pending = store.pending()
        cancelLanes(Lane.entries.filter { lane -> pending.none { it.lane == lane } })
    }

    fun cancelAll() {
        store.cancelAll()
        cancelLanes(Lane.entries)
    }

    private fun cancelLanes(lanes: List<Lane>) {
        val jobs = context.getSystemService(JobScheduler::class.java)
        val work = WorkManager.getInstance(context)
        for (lane in lanes) {
            jobs?.cancel(lane.jobId)
            work.cancelUniqueWork(lane.workName)
        }
    }

    @RequiresApi(Build.VERSION_CODES.UPSIDE_DOWN_CAKE)
    private fun scheduleUserInitiated(lane: Lane, bytes: Long): Boolean {
        val jobs = context.getSystemService(JobScheduler::class.java) ?: return false
        if (!jobs.canRunUserInitiatedJobs()) {
            return false
        }
        val info = JobInfo.Builder(lane.jobId, ComponentName(context, UploadJobService::class.java))
            .setUserInitiated(true)
            .setRequiredNetworkType(if (lane == Lane.UNMETERED) JobInfo.NETWORK_TYPE_UNMETERED else JobInfo.NETWORK_TYPE_ANY)
            .setEstimatedNetworkBytes(0, bytes)
            .setPersisted(true)
            .setBackoffCriteria(BACKOFF_MILLIS, JobInfo.BACKOFF_POLICY_EXPONENTIAL)
            .build()
        return try {
            jobs.schedule(info) == JobScheduler.RESULT_SUCCESS
        } catch (error: IllegalArgumentException) {
            false
        } catch (error: SecurityException) {
            false
        }
    }

    private fun scheduleWork(lane: Lane) {
        val manager = WorkManager.getInstance(context)
        val waiting = try {
            manager.getWorkInfosForUniqueWork(lane.workName).get().any {
                it.state == WorkInfo.State.ENQUEUED || it.state == WorkInfo.State.BLOCKED
            }
        } catch (error: ExecutionException) {
            false
        } catch (error: InterruptedException) {
            Thread.currentThread().interrupt()
            false
        }
        if (waiting) {
            return
        }
        val request = OneTimeWorkRequest.Builder(UploadWorker::class.java)
            .setConstraints(
                Constraints.Builder()
                    .setRequiredNetworkType(if (lane == Lane.UNMETERED) NetworkType.UNMETERED else NetworkType.CONNECTED)
                    .build(),
            )
            .setInputData(Data.Builder().putString(UploadWorker.LANE_KEY, lane.name).build())
            .setBackoffCriteria(BackoffPolicy.EXPONENTIAL, BACKOFF_MILLIS, TimeUnit.MILLISECONDS)
            .build()
        manager.enqueueUniqueWork(lane.workName, ExistingWorkPolicy.APPEND_OR_REPLACE, request)
    }

    private companion object {
        const val BACKOFF_MILLIS = 10_000L
    }
}
