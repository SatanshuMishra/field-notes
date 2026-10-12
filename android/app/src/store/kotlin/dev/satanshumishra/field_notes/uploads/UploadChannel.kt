package dev.satanshumishra.field_notes.uploads

import android.content.Context
import io.flutter.plugin.common.BinaryMessenger
import io.flutter.plugin.common.MethodChannel

class UploadChannel(private val context: Context) {
    fun register(messenger: BinaryMessenger) {
        MethodChannel(messenger, CHANNEL).setMethodCallHandler { call, result ->
            when (call.method) {
                AVAILABLE -> result.success(false)
                else -> result.error("unavailable", "This copy of Field Notes does not sync.", null)
            }
        }
    }

    private companion object {
        const val CHANNEL = "field_notes/background_uploads"
        const val AVAILABLE = "available"
    }
}
