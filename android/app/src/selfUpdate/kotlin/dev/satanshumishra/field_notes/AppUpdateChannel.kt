package dev.satanshumishra.field_notes

import android.Manifest
import android.app.Activity
import android.app.PendingIntent
import android.content.ActivityNotFoundException
import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent
import android.content.IntentFilter
import android.content.pm.PackageInfo
import android.content.pm.PackageInstaller
import android.content.pm.PackageManager
import android.net.Uri
import android.os.Build
import android.os.Handler
import android.os.Looper
import android.provider.Settings
import androidx.core.content.ContextCompat
import io.flutter.plugin.common.BinaryMessenger
import io.flutter.plugin.common.MethodChannel
import java.io.File
import java.util.concurrent.Executors

class AppUpdateChannel(private val activity: Activity) {
    private val context: Context = activity.applicationContext
    private val worker = Executors.newSingleThreadExecutor()
    private val main = Handler(Looper.getMainLooper())

    fun register(messenger: BinaryMessenger) {
        MethodChannel(messenger, CHANNEL).setMethodCallHandler { call, result ->
            when (call.method) {
                CAN_SELF_UPDATE -> result.success(canSelfUpdate())
                CAN_REQUEST_INSTALLS -> result.success(context.packageManager.canRequestPackageInstalls())
                OPEN_INSTALL_PERMISSION -> openInstallPermission(result)
                INSTALL -> install(call.argument<String>("path"), result)
                else -> result.notImplemented()
            }
        }
    }

    private fun canSelfUpdate(): Boolean {
        val requested: Array<String>? = try {
            packageInfo(PackageManager.GET_PERMISSIONS).requestedPermissions
        } catch (error: PackageManager.NameNotFoundException) {
            null
        }
        return requested?.contains(Manifest.permission.REQUEST_INSTALL_PACKAGES) == true
    }

    private fun packageInfo(flags: Int): PackageInfo =
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.TIRAMISU) {
            context.packageManager.getPackageInfo(
                context.packageName,
                PackageManager.PackageInfoFlags.of(flags.toLong()),
            )
        } else {
            @Suppress("DEPRECATION")
            context.packageManager.getPackageInfo(context.packageName, flags)
        }

    private fun openInstallPermission(result: MethodChannel.Result) {
        val intent = Intent(
            Settings.ACTION_MANAGE_UNKNOWN_APP_SOURCES,
            Uri.fromParts("package", context.packageName, null),
        )
        try {
            activity.startActivity(intent)
            result.success(null)
        } catch (error: ActivityNotFoundException) {
            result.error("unavailable", error.message, null)
        }
    }

    private fun install(path: String?, result: MethodChannel.Result) {
        if (path == null) {
            result.error("bad_arguments", "A path is required", null)
            return
        }
        val apk = File(path)
        worker.execute {
            val failure: Exception? = try {
                commit(apk)
                null
            } catch (error: Exception) {
                error
            }
            main.post {
                if (failure == null) {
                    result.success(true)
                } else {
                    result.error("install_failed", failure.message, null)
                }
            }
        }
    }

    private fun commit(apk: File) {
        if (!apk.isFile) {
            throw IllegalArgumentException("No update package at ${apk.path}")
        }
        val installer = context.packageManager.packageInstaller
        val params = PackageInstaller.SessionParams(PackageInstaller.SessionParams.MODE_FULL_INSTALL)
        params.setAppPackageName(context.packageName)
        params.setSize(apk.length())
        val sessionId = installer.createSession(params)
        try {
            installer.openSession(sessionId).use { session ->
                apk.inputStream().use { input ->
                    session.openWrite(APK_ENTRY, 0, apk.length()).use { output ->
                        input.copyTo(output)
                        session.fsync(output)
                    }
                }
                val action = "${context.packageName}.$STATUS_ACTION.$sessionId"
                val receiver = StatusReceiver()
                ContextCompat.registerReceiver(
                    context,
                    receiver,
                    IntentFilter(action),
                    ContextCompat.RECEIVER_NOT_EXPORTED,
                )
                try {
                    session.commit(statusIntent(action, sessionId).intentSender)
                } catch (error: Exception) {
                    context.unregisterReceiver(receiver)
                    throw error
                }
            }
        } catch (error: Exception) {
            runCatching { installer.abandonSession(sessionId) }
            throw error
        }
    }

    private fun statusIntent(action: String, sessionId: Int): PendingIntent =
        PendingIntent.getBroadcast(
            context,
            sessionId,
            Intent(action).setPackage(context.packageName),
            PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_MUTABLE,
        )

    private inner class StatusReceiver : BroadcastReceiver() {
        override fun onReceive(received: Context, intent: Intent) {
            val status = intent.getIntExtra(PackageInstaller.EXTRA_STATUS, PackageInstaller.STATUS_FAILURE)
            if (status == PackageInstaller.STATUS_PENDING_USER_ACTION) {
                confirmation(intent)?.let { confirm(it) }
            } else {
                context.unregisterReceiver(this)
            }
        }
    }

    private fun confirmation(intent: Intent): Intent? =
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.TIRAMISU) {
            intent.getParcelableExtra(Intent.EXTRA_INTENT, Intent::class.java)
        } else {
            @Suppress("DEPRECATION")
            intent.getParcelableExtra(Intent.EXTRA_INTENT)
        }

    private fun confirm(confirmation: Intent) {
        try {
            context.startActivity(confirmation.addFlags(Intent.FLAG_ACTIVITY_NEW_TASK))
        } catch (error: ActivityNotFoundException) {
            return
        }
    }

    private companion object {
        const val CHANNEL = "field_notes/app_update"
        const val CAN_SELF_UPDATE = "canSelfUpdate"
        const val CAN_REQUEST_INSTALLS = "canRequestInstalls"
        const val OPEN_INSTALL_PERMISSION = "openInstallPermission"
        const val INSTALL = "install"
        const val APK_ENTRY = "field-notes.apk"
        const val STATUS_ACTION = "APP_UPDATE_STATUS"
    }
}
