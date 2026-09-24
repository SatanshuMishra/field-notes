package dev.satanshumishra.field_notes

import android.content.ClipboardManager
import android.content.Context
import android.net.Uri
import android.os.Handler
import android.os.Looper
import io.flutter.plugin.common.BinaryMessenger
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel
import java.util.concurrent.ExecutorService
import java.util.concurrent.Executors

class ClipboardImageBridge(private val context: Context) {
    private val mainHandler = Handler(Looper.getMainLooper())

    fun register(messenger: BinaryMessenger) {
        MethodChannel(messenger, CHANNEL).setMethodCallHandler { call, result ->
            handle(call, result)
        }
    }

    private fun handle(call: MethodCall, result: MethodChannel.Result) {
        when (call.method) {
            "hasImage" -> answerHasImage(result)
            "image" -> answerImage(result)
            else -> result.notImplemented()
        }
    }

    private fun answerHasImage(result: MethodChannel.Result) {
        try {
            result.success(firstImage() != null)
        } catch (error: SecurityException) {
            result.error("unreadable", error.message, null)
        }
    }

    private fun answerImage(result: MethodChannel.Result) {
        val image: Pair<Uri, String>?
        try {
            image = firstImage()
        } catch (error: SecurityException) {
            result.error("unreadable", error.message, null)
            return
        }
        if (image == null) {
            result.success(null)
            return
        }
        val (uri, mime) = image
        reader.execute { readImage(uri, mime, result) }
    }

    private fun readImage(uri: Uri, mime: String, result: MethodChannel.Result) {
        val bytes: ByteArray? = try {
            context.contentResolver.openInputStream(uri)?.use { it.readBytes() }
        } catch (error: Exception) {
            mainHandler.post { result.error("unreadable", error.message, null) }
            return
        } catch (error: OutOfMemoryError) {
            mainHandler.post { result.error("unreadable", error.message, null) }
            return
        }
        mainHandler.post {
            if (bytes == null) {
                result.error("unreadable", "The clipboard image could not be opened.", null)
            } else {
                result.success(mapOf("bytes" to bytes, "mime" to mime))
            }
        }
    }

    private fun firstImage(): Pair<Uri, String>? {
        val clipboard = context.getSystemService(Context.CLIPBOARD_SERVICE) as? ClipboardManager
            ?: return null
        val clip = clipboard.primaryClip ?: return null
        for (index in 0 until clip.itemCount) {
            val uri = clip.getItemAt(index).uri ?: continue
            val mime = context.contentResolver.getType(uri) ?: continue
            if (mime.startsWith("image/")) {
                return Pair(uri, mime)
            }
        }
        return null
    }

    companion object {
        const val CHANNEL = "field_notes/clipboard_image"
        private val reader: ExecutorService = Executors.newSingleThreadExecutor()
    }
}
