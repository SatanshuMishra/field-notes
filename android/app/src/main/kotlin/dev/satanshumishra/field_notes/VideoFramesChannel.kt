package dev.satanshumishra.field_notes

import android.graphics.Bitmap
import android.media.MediaMetadataRetriever
import android.os.Handler
import android.os.Looper
import io.flutter.plugin.common.BinaryMessenger
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel
import java.io.ByteArrayOutputStream
import java.io.IOException
import java.util.concurrent.ExecutorService
import java.util.concurrent.Executors

class VideoFramesChannel {
    private val main = Handler(Looper.getMainLooper())

    fun register(messenger: BinaryMessenger) {
        MethodChannel(messenger, CHANNEL).setMethodCallHandler { call, result ->
            when (call.method) {
                FRAME_AT -> answerFrameAt(call, result)
                else -> result.notImplemented()
            }
        }
    }

    private fun answerFrameAt(call: MethodCall, result: MethodChannel.Result) {
        val path = call.argument<String>("path")
        val positionMs = call.argument<Number>("positionMs")?.toLong()
        val width = call.argument<Number>("width")?.toInt()
        if (path.isNullOrEmpty() || positionMs == null || positionMs < 0 || width == null || width <= 0) {
            result.error("bad_arguments", "A path, a position and a width are required", null)
            return
        }
        worker.execute {
            val jpeg = jpegFrameAt(path, positionMs, width)
            main.post { result.success(jpeg) }
        }
    }

    private fun jpegFrameAt(path: String, positionMs: Long, width: Int): ByteArray? =
        try {
            MediaMetadataRetriever().use { retriever ->
                retriever.setDataSource(path)
                retriever.getScaledFrameAtTime(
                    positionMs * MICROSECONDS_PER_MILLISECOND,
                    MediaMetadataRetriever.OPTION_CLOSEST,
                    width,
                    width * TALLEST_FRAME_RATIO,
                )?.let(::jpegBytes)
            }
        } catch (error: IOException) {
            null
        } catch (error: RuntimeException) {
            null
        } catch (error: OutOfMemoryError) {
            null
        }

    private fun jpegBytes(frame: Bitmap): ByteArray? {
        val stream = ByteArrayOutputStream()
        val compressed = frame.compress(Bitmap.CompressFormat.JPEG, JPEG_QUALITY, stream)
        frame.recycle()
        return if (compressed) stream.toByteArray() else null
    }

    private companion object {
        const val CHANNEL = "field_notes/video_frames"
        const val FRAME_AT = "frameAt"
        const val MICROSECONDS_PER_MILLISECOND = 1000L
        const val TALLEST_FRAME_RATIO = 4
        const val JPEG_QUALITY = 80
        val worker: ExecutorService = Executors.newSingleThreadExecutor()
    }
}
