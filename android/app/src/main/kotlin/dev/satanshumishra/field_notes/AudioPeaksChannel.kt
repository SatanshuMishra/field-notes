package dev.satanshumishra.field_notes

import android.media.AudioFormat
import android.media.MediaFormat
import android.os.Handler
import android.os.Looper
import io.flutter.plugin.common.BinaryMessenger
import io.flutter.plugin.common.MethodChannel
import java.io.IOException
import java.nio.ByteBuffer
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
        val windows = RmsWindows(windowMs)
        return try {
            PcmDecoder(path).decode(windows::add)
            windows.finish()
        } catch (error: IOException) {
            null
        } catch (error: IllegalArgumentException) {
            null
        } catch (error: IllegalStateException) {
            null
        }
    }

    private class RmsWindows(private val windowMs: Int) {
        private val values = ArrayList<Double>()
        private var format: MediaFormat? = null
        private var channels = 0
        private var windowFrames = 0
        private var floatSamples = false
        private var sum = 0.0
        private var filled = 0

        fun add(pcm: ByteBuffer, current: MediaFormat) {
            if (current !== format) {
                reformat(current)
            }
            if (channels <= 0) {
                throw IllegalStateException("The audio has no channels")
            }
            if (windowFrames <= 0) {
                throw IllegalStateException("The audio has no sample rate")
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

        private fun reformat(output: MediaFormat) {
            format = output
            if (output.containsKey(MediaFormat.KEY_CHANNEL_COUNT)) {
                channels = output.getInteger(MediaFormat.KEY_CHANNEL_COUNT)
            }
            if (output.containsKey(MediaFormat.KEY_SAMPLE_RATE)) {
                windowFrames = framesPerWindow(output.getInteger(MediaFormat.KEY_SAMPLE_RATE))
            }
            floatSamples = output.containsKey(MediaFormat.KEY_PCM_ENCODING) &&
                output.getInteger(MediaFormat.KEY_PCM_ENCODING) == AudioFormat.ENCODING_PCM_FLOAT
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
        const val PCM_16_SCALE = 32768.0
    }
}
