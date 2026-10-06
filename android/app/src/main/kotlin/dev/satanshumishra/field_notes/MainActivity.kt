package dev.satanshumishra.field_notes

import android.content.ActivityNotFoundException
import android.content.Intent
import android.net.Uri
import android.os.Build
import android.os.Bundle
import android.os.PowerManager
import android.provider.Settings
import android.view.View
import dev.satanshumishra.field_notes.uploads.UploadChannel
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterActivity() {
    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            findViewById<View>(FLUTTER_VIEW_ID)?.defaultFocusHighlightEnabled = false
        }
    }

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        LegacyTelemetry.clean(applicationContext)
        ClipboardImageBridge(applicationContext).register(flutterEngine.dartExecutor.binaryMessenger)
        UploadChannel(applicationContext).register(flutterEngine.dartExecutor.binaryMessenger)
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, NOTIFICATION_SETTINGS_CHANNEL)
            .setMethodCallHandler { call, result ->
                when (call.method) {
                    "open" -> openNotificationSettings(result)
                    else -> result.notImplemented()
                }
            }
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, BATTERY_SETTINGS_CHANNEL)
            .setMethodCallHandler { call, result ->
                when (call.method) {
                    "isIgnoringBatteryOptimizations" -> result.success(isIgnoringBatteryOptimizations())
                    "manufacturer" -> result.success(Build.MANUFACTURER ?: "")
                    "requestIgnoreBatteryOptimizations" -> startSettings(
                        Intent(
                            Settings.ACTION_REQUEST_IGNORE_BATTERY_OPTIMIZATIONS,
                            Uri.fromParts("package", packageName, null),
                        ),
                        result,
                    )
                    "openNeverSleepingApps" -> startSettings(
                        Intent(SAMSUNG_CHECKABLE_LIST_ACTION)
                            .setPackage(SAMSUNG_DEVICE_CARE_PACKAGE)
                            .putExtra(SAMSUNG_ACTIVITY_TYPE_EXTRA, SAMSUNG_NEVER_SLEEPING_TYPE),
                        result,
                    )
                    "openAppDetails" -> startSettings(
                        Intent(
                            Settings.ACTION_APPLICATION_DETAILS_SETTINGS,
                            Uri.fromParts("package", packageName, null),
                        ),
                        result,
                    )
                    else -> result.notImplemented()
                }
            }
    }

    private fun isIgnoringBatteryOptimizations(): Boolean {
        val power = getSystemService(POWER_SERVICE) as? PowerManager ?: return false
        return power.isIgnoringBatteryOptimizations(packageName)
    }

    private fun startSettings(intent: Intent, result: MethodChannel.Result) {
        try {
            startActivity(intent)
            result.success(null)
        } catch (error: ActivityNotFoundException) {
            result.error("unavailable", error.message, null)
        } catch (error: SecurityException) {
            result.error("unavailable", error.message, null)
        }
    }

    private fun openNotificationSettings(result: MethodChannel.Result) {
        val intent = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            Intent(Settings.ACTION_APP_NOTIFICATION_SETTINGS)
                .putExtra(Settings.EXTRA_APP_PACKAGE, packageName)
        } else {
            Intent(
                Settings.ACTION_APPLICATION_DETAILS_SETTINGS,
                Uri.fromParts("package", packageName, null),
            )
        }
        try {
            startActivity(intent)
            result.success(null)
        } catch (error: ActivityNotFoundException) {
            result.error("unavailable", error.message, null)
        }
    }

    private companion object {
        const val NOTIFICATION_SETTINGS_CHANNEL = "field_notes/notification_settings"
        const val BATTERY_SETTINGS_CHANNEL = "field_notes/battery_settings"
        const val SAMSUNG_CHECKABLE_LIST_ACTION = "com.samsung.android.sm.ACTION_OPEN_CHECKABLE_LISTACTIVITY"
        const val SAMSUNG_DEVICE_CARE_PACKAGE = "com.samsung.android.lool"
        const val SAMSUNG_ACTIVITY_TYPE_EXTRA = "activity_type"
        const val SAMSUNG_NEVER_SLEEPING_TYPE = 2
    }
}
