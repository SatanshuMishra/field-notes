package dev.satanshumishra.field_notes

import android.app.Activity
import io.flutter.plugin.common.BinaryMessenger
import io.flutter.plugin.common.MethodChannel

class AppUpdateChannel(activity: Activity) {
    fun register(messenger: BinaryMessenger) {
        MethodChannel(messenger, CHANNEL).setMethodCallHandler { call, result ->
            when (call.method) {
                CAN_SELF_UPDATE, CAN_REQUEST_INSTALLS -> result.success(false)
                else -> result.error("unavailable", "This copy of Field Notes updates through its store.", null)
            }
        }
    }

    private companion object {
        const val CHANNEL = "field_notes/app_update"
        const val CAN_SELF_UPDATE = "canSelfUpdate"
        const val CAN_REQUEST_INSTALLS = "canRequestInstalls"
    }
}
