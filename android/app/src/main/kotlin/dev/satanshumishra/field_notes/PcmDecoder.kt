package dev.satanshumishra.field_notes

import android.media.MediaCodec
import android.media.MediaExtractor
import android.media.MediaFormat
import java.io.IOException
import java.nio.ByteBuffer
import java.nio.ByteOrder

class PcmDecoder(private val path: String) {
    fun decode(receiver: (ByteBuffer, MediaFormat) -> Unit) {
        val extractor = MediaExtractor()
        var codec: MediaCodec? = null
        try {
            extractor.setDataSource(path)
            val track = (0 until extractor.trackCount).firstOrNull { index ->
                extractor.getTrackFormat(index).getString(MediaFormat.KEY_MIME)?.startsWith(AUDIO_MIME_PREFIX) == true
            } ?: throw IOException("The file has no audio track")
            val format = extractor.getTrackFormat(track)
            val mime = format.getString(MediaFormat.KEY_MIME) ?: throw IOException("The audio track has no type")
            extractor.selectTrack(track)
            val decoder = MediaCodec.createDecoderByType(mime)
            codec = decoder
            decoder.configure(format, null, null, 0)
            decoder.start()
            drain(extractor, decoder, format, receiver)
        } finally {
            codec?.let { started ->
                try {
                    started.stop()
                } catch (error: IllegalStateException) {
                    Unit
                }
                started.release()
            }
            extractor.release()
        }
    }

    private fun drain(
        extractor: MediaExtractor,
        codec: MediaCodec,
        trackFormat: MediaFormat,
        receiver: (ByteBuffer, MediaFormat) -> Unit,
    ) {
        val info = MediaCodec.BufferInfo()
        var outputFormat = trackFormat
        var inputDone = false
        var idleTries = 0
        while (true) {
            var progressed = false
            if (!inputDone) {
                val inputIndex = codec.dequeueInputBuffer(TIMEOUT_US)
                if (inputIndex >= 0) {
                    val input = codec.getInputBuffer(inputIndex)
                        ?: throw IllegalStateException("No input buffer")
                    val size = extractor.readSampleData(input, 0)
                    if (size < 0) {
                        codec.queueInputBuffer(inputIndex, 0, 0, 0, MediaCodec.BUFFER_FLAG_END_OF_STREAM)
                        inputDone = true
                    } else {
                        codec.queueInputBuffer(inputIndex, 0, size, extractor.sampleTime, 0)
                        extractor.advance()
                    }
                    progressed = true
                }
            }
            val outputIndex = codec.dequeueOutputBuffer(info, TIMEOUT_US)
            if (outputIndex == MediaCodec.INFO_OUTPUT_FORMAT_CHANGED) {
                outputFormat = codec.outputFormat
                progressed = true
            } else if (outputIndex >= 0) {
                val output = codec.getOutputBuffer(outputIndex)
                if (output != null && info.size > 0) {
                    output.position(info.offset)
                    output.limit(info.offset + info.size)
                    receiver(output.slice().order(ByteOrder.nativeOrder()), outputFormat)
                }
                codec.releaseOutputBuffer(outputIndex, false)
                if (info.flags and MediaCodec.BUFFER_FLAG_END_OF_STREAM != 0) {
                    return
                }
                progressed = true
            }
            idleTries = if (progressed) 0 else idleTries + 1
            if (idleTries > MAX_IDLE_TRIES) {
                throw IllegalStateException("The decoder stopped producing audio")
            }
        }
    }

    private companion object {
        const val AUDIO_MIME_PREFIX = "audio/"
        const val TIMEOUT_US = 10_000L
        const val MAX_IDLE_TRIES = 500
    }
}
