package dev.satanshumishra.field_notes

import android.media.AudioFormat
import android.media.MediaCodec
import android.media.MediaExtractor
import android.media.MediaFormat
import android.os.Handler
import android.os.Looper
import io.flutter.plugin.common.BinaryMessenger
import io.flutter.plugin.common.MethodChannel
import java.io.IOException
import java.nio.ByteBuffer
import java.nio.ByteOrder
import java.util.concurrent.Executors
import kotlin.math.roundToInt
import kotlin.math.sqrt

class AudioPeaksChannel {
    private val worker = Executors.newSingleThreadExecutor()
    private val main = Handler(Looper.getMainLooper())

    fun register(messenger: BinaryMessenger) {
        MethodChannel(messenger, CHANNEL).setMethodCallHandler { call, result ->
            when (call.method) {
                WINDOW_RMS -> {
                    val path = call.argument<String>("path")
                    val windowMs = call.argument<Int>("windowMs")
                    if (path == null || windowMs == null || windowMs <= 0) {
                        result.error("bad_arguments", "A path and a window length are required", null)
                    } else {
                        worker.execute {
                            val rms = windowRms(path, windowMs)
                            main.post {
                                if (rms == null) {
                                    result.error(DECODE_FAILED, "The recording could not be decoded.", null)
                                } else {
                                    result.success(rms)
                                }
                            }
                        }
                    }
                }
                else -> result.notImplemented()
            }
        }
    }

    private fun windowRms(path: String, windowMs: Int): List<Double>? {
        val extractor = MediaExtractor()
        var codec: MediaCodec? = null
        return try {
            extractor.setDataSource(path)
            val track = (0 until extractor.trackCount).firstOrNull { index ->
                extractor.getTrackFormat(index).getString(MediaFormat.KEY_MIME)?.startsWith(AUDIO_MIME_PREFIX) == true
            } ?: return null
            val format = extractor.getTrackFormat(track)
            val mime = format.getString(MediaFormat.KEY_MIME) ?: return null
            extractor.selectTrack(track)
            val decoder = MediaCodec.createDecoderByType(mime)
            codec = decoder
            decoder.configure(format, null, null, 0)
            decoder.start()
            decode(extractor, decoder, RmsWindows(format, windowMs))
        } catch (error: IOException) {
            null
        } catch (error: IllegalArgumentException) {
            null
        } catch (error: IllegalStateException) {
            null
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

    private fun decode(extractor: MediaExtractor, codec: MediaCodec, windows: RmsWindows): List<Double> {
        val info = MediaCodec.BufferInfo()
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
                windows.reformat(codec.outputFormat)
                progressed = true
            } else if (outputIndex >= 0) {
                val output = codec.getOutputBuffer(outputIndex)
                if (output != null && info.size > 0) {
                    output.position(info.offset)
                    output.limit(info.offset + info.size)
                    windows.add(output.slice().order(ByteOrder.nativeOrder()))
                }
                codec.releaseOutputBuffer(outputIndex, false)
                if (info.flags and MediaCodec.BUFFER_FLAG_END_OF_STREAM != 0) {
                    return windows.finish()
                }
                progressed = true
            }
            idleTries = if (progressed) 0 else idleTries + 1
            if (idleTries > MAX_IDLE_TRIES) {
                throw IllegalStateException("The decoder stopped producing audio")
            }
        }
    }

    private class RmsWindows(input: MediaFormat, private val windowMs: Int) {
        private val values = ArrayList<Double>()
        private var channels = requiredInteger(input, MediaFormat.KEY_CHANNEL_COUNT)
        private var windowFrames = framesPerWindow(requiredInteger(input, MediaFormat.KEY_SAMPLE_RATE))
        private var floatSamples = false
        private var sum = 0.0
        private var filled = 0

        fun reformat(output: MediaFormat) {
            if (output.containsKey(MediaFormat.KEY_CHANNEL_COUNT)) {
                channels = output.getInteger(MediaFormat.KEY_CHANNEL_COUNT)
            }
            if (output.containsKey(MediaFormat.KEY_SAMPLE_RATE)) {
                windowFrames = framesPerWindow(output.getInteger(MediaFormat.KEY_SAMPLE_RATE))
            }
            floatSamples = output.containsKey(MediaFormat.KEY_PCM_ENCODING) &&
                output.getInteger(MediaFormat.KEY_PCM_ENCODING) == AudioFormat.ENCODING_PCM_FLOAT
        }

        fun add(pcm: ByteBuffer) {
            if (channels <= 0) {
                throw IllegalStateException("The audio has no channels")
            }
            if (floatSamples) {
                val samples = pcm.asFloatBuffer()
                while (samples.remaining() >= channels) {
                    var mono = 0.0
                    for (channel in 0 until channels) {
                        mono += samples.get().toDouble()
                    }
                    addFrame(mono / channels)
                }
            } else {
                val samples = pcm.asShortBuffer()
                while (samples.remaining() >= channels) {
                    var mono = 0.0
                    for (channel in 0 until channels) {
                        mono += samples.get() / PCM_16_SCALE
                    }
                    addFrame(mono / channels)
                }
            }
        }

        fun finish(): List<Double> {
            if (filled > 0) {
                values.add(sqrt(sum / filled))
                sum = 0.0
                filled = 0
            }
            return values
        }

        private fun addFrame(mono: Double) {
            sum += mono * mono
            filled += 1
            if (filled >= windowFrames) {
                values.add(sqrt(sum / filled))
                sum = 0.0
                filled = 0
            }
        }

        private fun requiredInteger(format: MediaFormat, key: String): Int {
            if (!format.containsKey(key)) {
                throw IllegalStateException("The audio format has no $key")
            }
            return format.getInteger(key)
        }

        private fun framesPerWindow(sampleRate: Int): Int {
            if (sampleRate <= 0) {
                throw IllegalStateException("The audio has no sample rate")
            }
            return maxOf(1, (sampleRate * windowMs / 1000.0).roundToInt())
        }
    }

    private companion object {
        const val CHANNEL = "field_notes/audio_peaks"
        const val WINDOW_RMS = "windowRms"
        const val DECODE_FAILED = "decode-failed"
        const val AUDIO_MIME_PREFIX = "audio/"
        const val TIMEOUT_US = 10_000L
        const val MAX_IDLE_TRIES = 500
        const val PCM_16_SCALE = 32768.0
    }
}
