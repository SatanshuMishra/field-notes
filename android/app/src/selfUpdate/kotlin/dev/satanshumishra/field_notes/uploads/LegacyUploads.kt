package dev.satanshumishra.field_notes.uploads

import android.app.job.JobScheduler
import android.content.Context
import androidx.work.WorkManager

object LegacyUploads {
    private const val PREFIX = "com.bbflight.background_downloader"
    private const val TAG = "BackgroundDownloader"
    private const val PREFERENCES = "field_notes_uploads"
    private const val CLEANED = "legacyCleaned"

    fun clean(context: Context) {
        val own = context.getSharedPreferences(PREFERENCES, Context.MODE_PRIVATE)
        if (own.getBoolean(CLEANED, false)) {
            return
        }
        val defaults = context.getSharedPreferences("${context.packageName}_preferences", Context.MODE_PRIVATE)
        val stale = defaults.all.keys.filter { it.startsWith(PREFIX) }
        if (stale.isNotEmpty()) {
            defaults.edit().apply { stale.forEach(::remove) }.commit()
        }
        context.getSystemService(JobScheduler::class.java)?.let { jobs ->
            jobs.allPendingJobs
                .filter { it.service.className.startsWith(PREFIX) }
                .forEach { jobs.cancel(it.id) }
        }
        val work = WorkManager.getInstance(context)
        work.cancelAllWorkByTag(TAG)
        work.pruneWork()
        own.edit().putBoolean(CLEANED, true).apply()
    }
}
