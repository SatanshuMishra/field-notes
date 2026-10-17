package dev.satanshumishra.field_notes

import android.media.MediaCodec
import android.media.MediaCodecInfo
import android.media.MediaExtractor
import android.media.MediaFormat
import android.media.MediaMuxer
import android.os.Handler
import android.os.Looper
import io.flutter.plugin.common.BinaryMessenger
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel
import java.io.File
import java.nio.ByteBuffer
import java.util.concurrent.ExecutorService
import java.util.concurrent.Executors

class LiveAudioChannel {
    private val main = Handler(Looper.getMainLooper())
    private val encoders = HashMap<Int, Encoder>()
    private var nextId = 1

    fun register(messenger: BinaryMessenger) {
        MethodChannel(messenger, CHANNEL).setMethodCallHandler { call, result ->
            when (call.method) {
                OPEN_ENCODER -> openEncoder(call, result)
                APPEND_PCM -> appendPcm(call, result)
                CLOSE_ENCODER -> closeEncoder(call, result)
                CANCEL_ENCODER -> cancelEncoder(call, result)
                JOIN_AUDIO -> joinAudio(call, result)
                else -> result.notImplemented()
            }
        }
    }

    private fun arguments(call: MethodCall): Map<*, *> = call.arguments as? Map<*, *> ?: emptyMap<Any, Any>()

    private fun text(call: MethodCall, key: String): String? =
        (arguments(call)[key] as? String)?.takeIf { it.isNotEmpty() }

    private fun number(call: MethodCall, key: String): Int? = (arguments(call)[key] as? Number)?.toInt()

    private fun openEncoder(call: MethodCall, result: MethodChannel.Result) {
        val path = text(call, "path")
        val sampleRate = number(call, "sampleRate")
        val channels = number(call, "channels")
        val bitRate = number(call, "bitRate")
        if (path == null || sampleRate == null || channels == null || bitRate == null ||
            sampleRate <= 0 || channels <= 0 || bitRate <= 0
        ) {
            result.error(ENCODE_FAILED, "A path, a sample rate, a channel count and a bit rate are required", null)
            return
        }
        val id = nextId
        nextId += 1
        val encoder = Encoder(path, sampleRate, channels, bitRate)
        encoder.executor.execute {
            try {
                encoder.open()
            } catch (error: Exception) {
                encoder.cancel()
                encoder.executor.shutdown()
                main.post { result.error(ENCODE_FAILED, error.message ?: ENCODE_FAILED_MESSAGE, null) }
                return@execute
            }
            main.post {
                encoders[id] = encoder
                result.success(id)
            }
        }
    }

    private fun appendPcm(call: MethodCall, result: MethodChannel.Result) {
        val encoder = number(call, "id")?.let { id -> encoders[id] }
        val pcm = arguments(call)["pcm"] as? ByteArray
        if (encoder == null || pcm == null) {
            result.error(ENCODE_FAILED, "An open encoder id and PCM bytes are required", null)
            return
        }
        encoder.run(main, result) {
            encoder.append(pcm)
            null
        }
    }

    private fun closeEncoder(call: MethodCall, result: MethodChannel.Result) {
        val encoder = number(call, "id")?.let { id -> encoders.remove(id) }
        if (encoder == null) {
            result.error(ENCODE_FAILED, "An open encoder id is required", null)
            return
        }
        encoder.run(main, result) {
            try {
                encoder.close()
            } catch (error: Exception) {
                encoder.cancel()
                throw error
            } finally {
                encoder.executor.shutdown()
            }
        }
    }

    private fun cancelEncoder(call: MethodCall, result: MethodChannel.Result) {
        val encoder = number(call, "id")?.let { id -> encoders.remove(id) }
        if (encoder == null) {
            result.error(ENCODE_FAILED, "An open encoder id is required", null)
            return
        }
        encoder.run(main, result) {
            try {
                encoder.cancel()
            } finally {
                encoder.executor.shutdown()
            }
            null
        }
    }

    private fun joinAudio(call: MethodCall, result: MethodChannel.Result) {
        val video = text(call, "video")
        val audio = text(call, "audio")
        val output = text(call, "output")
        if (video == null || audio == null || output == null || samePath(video, output) || samePath(audio, output)) {
            result.error(JOIN_FAILED, "A video, an audio file and a separate output path are required", null)
            return
        }
        val executor = Executors.newSingleThreadExecutor()
        executor.execute {
            val reply = try {
                Join(video, audio, output).write()
            } catch (error: Exception) {
                File(output).delete()
                main.post { result.error(JOIN_FAILED, error.message ?: JOIN_FAILED_MESSAGE, null) }
                return@execute
            } finally {
                executor.shutdown()
            }
            main.post { result.success(reply) }
        }
    }

    private fun samePath(first: String, second: String): Boolean =
        File(first).absoluteFile.normalize() == File(second).absoluteFile.normalize()

    private class Encoder(
        private val path: String,
        private val sampleRate: Int,
        private val channels: Int,
        private val bitRate: Int,
    ) {
        val executor: ExecutorService = Executors.newSingleThreadExecutor()
        private val frameBytes = channels * BYTES_PER_SAMPLE
        private val info = MediaCodec.BufferInfo()
        private var codec: MediaCodec? = null
        private var muxer: MediaMuxer? = null
        private var track = NO_TRACK
        private var muxerStarted = false
        private var framesQueued = 0L

        fun run(main: Handler, result: MethodChannel.Result, work: () -> Any?) {
            executor.execute {
                val reply = try {
                    work()
                } catch (error: Exception) {
                    main.post { result.error(ENCODE_FAILED, error.message ?: ENCODE_FAILED_MESSAGE, null) }
                    return@execute
                }
                main.post { result.success(reply) }
            }
        }

        fun open() {
            val format = MediaFormat.createAudioFormat(MediaFormat.MIMETYPE_AUDIO_AAC, sampleRate, channels).apply {
                setInteger(MediaFormat.KEY_AAC_PROFILE, MediaCodecInfo.CodecProfileLevel.AACObjectLC)
                setInteger(MediaFormat.KEY_BIT_RATE, bitRate)
            }
            val aac = MediaCodec.createEncoderByType(MediaFormat.MIMETYPE_AUDIO_AAC)
            codec = aac
            aac.configure(format, null, null, MediaCodec.CONFIGURE_FLAG_ENCODE)
            muxer = MediaMuxer(path, MediaMuxer.OutputFormat.MUXER_OUTPUT_MPEG_4)
            aac.start()
        }

        fun append(pcm: ByteArray) {
            val aac = codec ?: throw IllegalStateException("The encoder is not open")
            if (pcm.size % frameBytes != 0) {
                throw IllegalArgumentException("The PCM ends inside a frame")
            }
            var offset = 0
            var idleTries = 0
            while (offset < pcm.size) {
                val inputIndex = aac.dequeueInputBuffer(TIMEOUT_US)
                if (inputIndex >= 0) {
                    val input = aac.getInputBuffer(inputIndex) ?: throw IllegalStateException("No input buffer")
                    input.clear()
                    val room = input.remaining() / frameBytes * frameBytes
                    if (room == 0) {
                        throw IllegalStateException("The encoder input buffer holds no frame")
                    }
                    val size = minOf(room, pcm.size - offset)
                    input.put(pcm, offset, size)
                    aac.queueInputBuffer(inputIndex, 0, size, presentationTimeUs(), 0)
                    framesQueued += size / frameBytes
                    offset += size
                    idleTries = 0
                } else {
                    idleTries += 1
                    if (idleTries > MAX_IDLE_TRIES) {
                        throw IllegalStateException("The encoder stopped taking audio")
                    }
                }
                drain(aac, false)
            }
        }

        fun close(): String {
            val aac = codec ?: throw IllegalStateException("The encoder is not open")
            var idleTries = 0
            while (true) {
                val inputIndex = aac.dequeueInputBuffer(TIMEOUT_US)
                if (inputIndex >= 0) {
                    aac.queueInputBuffer(inputIndex, 0, 0, presentationTimeUs(), MediaCodec.BUFFER_FLAG_END_OF_STREAM)
                    break
                }
                drain(aac, false)
                idleTries += 1
                if (idleTries > MAX_IDLE_TRIES) {
                    throw IllegalStateException("The encoder stopped taking audio")
                }
            }
            drain(aac, true)
            if (!muxerStarted) {
                throw IllegalStateException("The encoder wrote no audio")
            }
            muxer?.stop()
            muxerStarted = false
            release()
            return path
        }

        fun cancel() {
            release()
            File(path).delete()
        }

        private fun presentationTimeUs(): Long = framesQueued * MICROS_PER_SECOND / sampleRate

        private fun drain(aac: MediaCodec, endOfStream: Boolean) {
            var idleTries = 0
            while (true) {
                val outputIndex = aac.dequeueOutputBuffer(info, if (endOfStream) TIMEOUT_US else 0L)
                if (outputIndex == MediaCodec.INFO_TRY_AGAIN_LATER) {
                    if (!endOfStream) {
                        return
                    }
                    idleTries += 1
                    if (idleTries > MAX_IDLE_TRIES) {
                        throw IllegalStateException("The encoder stopped producing audio")
                    }
                } else if (outputIndex == MediaCodec.INFO_OUTPUT_FORMAT_CHANGED) {
                    val writer = muxer ?: throw IllegalStateException("The muxer is not open")
                    if (muxerStarted) {
                        throw IllegalStateException("The encoder changed its format after the file started")
                    }
                    track = writer.addTrack(aac.outputFormat)
                    writer.start()
                    muxerStarted = true
                } else if (outputIndex >= 0) {
                    val output = aac.getOutputBuffer(outputIndex)
                    val config = info.flags and MediaCodec.BUFFER_FLAG_CODEC_CONFIG != 0
                    if (output != null && info.size > 0 && !config) {
                        if (!muxerStarted) {
                            throw IllegalStateException("The encoder wrote audio before its format")
                        }
                        output.position(info.offset)
                        output.limit(info.offset + info.size)
                        muxer?.writeSampleData(track, output, info)
                    }
                    aac.releaseOutputBuffer(outputIndex, false)
                    if (info.flags and MediaCodec.BUFFER_FLAG_END_OF_STREAM != 0) {
                        return
                    }
                    idleTries = 0
                }
            }
        }

        private fun release() {
            codec?.let { started ->
                try {
                    started.stop()
                } catch (error: IllegalStateException) {
                    Unit
                }
                started.release()
            }
            codec = null
            muxer?.let { writer ->
                if (muxerStarted) {
                    try {
                        writer.stop()
                    } catch (error: IllegalStateException) {
                        Unit
                    }
                }
                try {
                    writer.release()
                } catch (error: IllegalStateException) {
                    Unit
                }
            }
            muxer = null
            muxerStarted = false
        }
    }

    private class Join(
        private val video: String,
        private val audio: String,
        private val output: String,
    ) {
        fun write(): String {
            val picture = MediaExtractor()
            val sound = MediaExtractor()
            var muxer: MediaMuxer? = null
            var started = false
            try {
                picture.setDataSource(video)
                sound.setDataSource(audio)
                val videoFormat = selectTrack(picture, VIDEO_MIME_PREFIX)
                val audioFormat = selectTrack(sound, AUDIO_MIME_PREFIX)
                val degrees = rotation(videoFormat)
                val writer = MediaMuxer(output, MediaMuxer.OutputFormat.MUXER_OUTPUT_MPEG_4)
                muxer = writer
                degrees?.let { writer.setOrientationHint(it) }
                val videoCopy = SampleCopy(picture, writer, writer.addTrack(videoFormat), videoFormat)
                val audioCopy = SampleCopy(sound, writer, writer.addTrack(audioFormat), audioFormat)
                writer.start()
                started = true
                while (!videoCopy.done || !audioCopy.done) {
                    val next = when {
                        videoCopy.done -> audioCopy
                        audioCopy.done -> videoCopy
                        audioCopy.nextTimeUs < videoCopy.nextTimeUs -> audioCopy
                        else -> videoCopy
                    }
                    next.copyOne()
                }
                writer.stop()
                started = false
            } finally {
                muxer?.let { writer ->
                    if (started) {
                        try {
                            writer.stop()
                        } catch (error: IllegalStateException) {
                            Unit
                        }
                    }
                    try {
                        writer.release()
                    } catch (error: IllegalStateException) {
                        Unit
                    }
                }
                picture.release()
                sound.release()
            }
            return output
        }

        private fun selectTrack(extractor: MediaExtractor, prefix: String): MediaFormat {
            val track = (0 until extractor.trackCount).firstOrNull { index ->
                extractor.getTrackFormat(index).getString(MediaFormat.KEY_MIME)?.startsWith(prefix) == true
            } ?: throw IllegalArgumentException("The file has no $prefix track")
            extractor.selectTrack(track)
            return extractor.getTrackFormat(track)
        }

        private fun rotation(format: MediaFormat): Int? {
            if (!format.containsKey(MediaFormat.KEY_ROTATION)) {
                return null
            }
            val degrees = format.getInteger(MediaFormat.KEY_ROTATION)
            if (degrees !in MUXER_ROTATIONS) {
                throw IllegalArgumentException("The video track is rotated by $degrees degrees")
            }
            return degrees
        }
    }

    private class SampleCopy(
        private val extractor: MediaExtractor,
        private val muxer: MediaMuxer,
        private val track: Int,
        format: MediaFormat,
    ) {
        private val buffer = ByteBuffer.allocateDirect(sampleBytes(format))
        private val info = MediaCodec.BufferInfo()
        var done = extractor.sampleTime < 0
            private set
        val nextTimeUs: Long
            get() = extractor.sampleTime

        fun copyOne() {
            buffer.clear()
            val size = extractor.readSampleData(buffer, 0)
            if (size < 0) {
                done = true
                return
            }
            info.set(0, size, extractor.sampleTime, bufferFlags(extractor.sampleFlags))
            muxer.writeSampleData(track, buffer, info)
            done = !extractor.advance()
        }

        private fun bufferFlags(sampleFlags: Int): Int {
            val keyFrame = if (sampleFlags and MediaExtractor.SAMPLE_FLAG_SYNC != 0) MediaCodec.BUFFER_FLAG_KEY_FRAME else 0
            val partial = if (sampleFlags and MediaExtractor.SAMPLE_FLAG_PARTIAL_FRAME != 0) {
                MediaCodec.BUFFER_FLAG_PARTIAL_FRAME
            } else {
                0
            }
            return keyFrame or partial
        }
    }

    private companion object {
        const val CHANNEL = "field_notes/live_audio"
        const val OPEN_ENCODER = "openEncoder"
        const val APPEND_PCM = "appendPcm"
        const val CLOSE_ENCODER = "closeEncoder"
        const val CANCEL_ENCODER = "cancelEncoder"
        const val JOIN_AUDIO = "joinAudio"
        const val ENCODE_FAILED = "encode-failed"
        const val JOIN_FAILED = "join-failed"
        const val ENCODE_FAILED_MESSAGE = "The audio could not be encoded."
        const val JOIN_FAILED_MESSAGE = "The audio could not be joined to the video."
        const val VIDEO_MIME_PREFIX = "video/"
        const val AUDIO_MIME_PREFIX = "audio/"
        const val BYTES_PER_SAMPLE = 2
        const val MICROS_PER_SECOND = 1_000_000L
        const val DEFAULT_SAMPLE_BYTES = 8 * 1024 * 1024
        const val NO_TRACK = -1
        const val TIMEOUT_US = 10_000L
        const val MAX_IDLE_TRIES = 500
        val MUXER_ROTATIONS = setOf(0, 90, 180, 270)

        fun sampleBytes(format: MediaFormat): Int =
            if (format.containsKey(MediaFormat.KEY_MAX_INPUT_SIZE) && format.getInteger(MediaFormat.KEY_MAX_INPUT_SIZE) > 0) {
                format.getInteger(MediaFormat.KEY_MAX_INPUT_SIZE)
            } else {
                DEFAULT_SAMPLE_BYTES
            }
    }
}
