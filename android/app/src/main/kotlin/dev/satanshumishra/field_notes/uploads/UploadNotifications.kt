package dev.satanshumishra.field_notes.uploads

import android.app.Notification
import android.app.NotificationChannel
import android.app.NotificationManager
import android.app.PendingIntent
import android.content.Context
import android.os.SystemClock
import dev.satanshumishra.field_notes.MainActivity
import dev.satanshumishra.field_notes.R

class UploadNotifications(private val context: Context) {
    fun build(lane: Lane, sent: Long, total: Long): Notification {
        ensureChannel()
        val copy = UploadCopy.read(context)
        val percent = if (total > 0) ((sent * 100) / total).toInt().coerceIn(0, 100) else 0
        val template = if (lane == Lane.UNMETERED) copy.bodyWaitingForWiFi else copy.body
        val builder = Notification.Builder(context, CHANNEL_ID)
            .setSmallIcon(R.drawable.ic_stat_peony)
            .setContentTitle(copy.title)
            .setOnlyAlertOnce(true)
            .setOngoing(true)
            .setShowWhen(false)
            .setCategory(Notification.CATEGORY_PROGRESS)
            .setContentIntent(openApp())
        if (total > 0) {
            builder.setContentText(template.replace(PROGRESS_PLACEHOLDER, "$percent%"))
            builder.setProgress(100, percent, false)
        } else {
            builder.setProgress(0, 0, true)
        }
        return builder.build()
    }

    private fun openApp(): PendingIntent {
        val intent = context.packageManager.getLaunchIntentForPackage(context.packageName)
            ?: android.content.Intent(context, MainActivity::class.java)
        return PendingIntent.getActivity(context, 0, intent, PendingIntent.FLAG_IMMUTABLE or PendingIntent.FLAG_UPDATE_CURRENT)
    }

    private fun ensureChannel() {
        val manager = context.getSystemService(NotificationManager::class.java) ?: return
        if (manager.getNotificationChannel(CHANNEL_ID) == null) {
            manager.createNotificationChannel(
                NotificationChannel(CHANNEL_ID, UploadCopy.read(context).channelName, NotificationManager.IMPORTANCE_LOW),
            )
        }
    }

    companion object {
        const val CHANNEL_ID = "field_notes_uploads"
        const val PROGRESS_PLACEHOLDER = "{progress}"
    }
}

class ProgressThrottle(private val intervalMillis: Long = 1_000L) {
    private var last = 0L
    private var lastPercent = -1

    @Synchronized
    fun due(sent: Long, total: Long): Boolean {
        val percent = if (total > 0) ((sent * 100) / total).toInt() else 0
        val now = SystemClock.elapsedRealtime()
        if (percent == lastPercent || (now - last < intervalMillis && percent < 100)) {
            return false
        }
        last = now
        lastPercent = percent
        return true
    }
}

data class UploadCopy(
    val title: String,
    val body: String,
    val bodyWaitingForWiFi: String,
    val channelName: String,
) {
    companion object {
        private const val PREFERENCES = "field_notes_uploads"

        fun save(context: Context, copy: UploadCopy) {
            context.getSharedPreferences(PREFERENCES, Context.MODE_PRIVATE).edit()
                .putString("title", copy.title)
                .putString("body", copy.body)
                .putString("bodyWaitingForWiFi", copy.bodyWaitingForWiFi)
                .putString("channelName", copy.channelName)
                .apply()
        }

        fun read(context: Context): UploadCopy {
            val preferences = context.getSharedPreferences(PREFERENCES, Context.MODE_PRIVATE)
            return UploadCopy(
                title = preferences.getString("title", null) ?: "Uploading to your journal",
                body = preferences.getString("body", null) ?: "{progress}",
                bodyWaitingForWiFi = preferences.getString("bodyWaitingForWiFi", null) ?: "{progress}",
                channelName = preferences.getString("channelName", null) ?: "Uploads",
            )
        }
    }
}
