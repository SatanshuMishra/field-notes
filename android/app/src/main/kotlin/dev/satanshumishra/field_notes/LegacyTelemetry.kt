package dev.satanshumishra.field_notes

import android.app.job.JobScheduler
import android.content.Context

object LegacyTelemetry {
    private const val PREFIX = "com.google.android.datatransport"
    private const val PREFERENCES = "field_notes_privacy"
    private const val CLEANED = "telemetryCleaned"
    private val databases = listOf("com.google.android.datatransport.events")
    private val preferenceFiles = listOf("com.google.mlkit.internal")

    fun clean(context: Context) {
        val own = context.getSharedPreferences(PREFERENCES, Context.MODE_PRIVATE)
        if (own.getBoolean(CLEANED, false)) {
            return
        }
        context.getSystemService(JobScheduler::class.java)?.let { jobs ->
            jobs.allPendingJobs
                .filter { it.service.className.startsWith(PREFIX) }
                .forEach { jobs.cancel(it.id) }
        }
        databases.forEach { context.deleteDatabase(it) }
        preferenceFiles.forEach { context.deleteSharedPreferences(it) }
        own.edit().putBoolean(CLEANED, true).apply()
    }
}
