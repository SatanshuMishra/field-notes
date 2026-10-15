package dev.satanshumishra.field_notes

import android.media.AudioFormat
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
import java.io.FileOutputStream
import java.io.IOException
import java.io.RandomAccessFile
import java.nio.ByteBuffer
import java.nio.ByteOrder
import java.nio.channels.FileChannel
import java.util.concurrent.Executors
import kotlin.math.roundToInt

class AudioCleanChannel {
    private val worker = Executors.newSingleThreadExecutor()
    private val main = Handler(Looper.getMainLooper())

    fun register(messenger: BinaryMessenger) {
        MethodChannel(messenger, CHANNEL).setMethodCallHandler { call, result ->
            when (call.method) {
                DECODE_AUDIO -> {
                    val input = text(call, "input")
                    val output = text(call, "output")
                    if (input == null || output == null || samePath(input, output)) {
                        result.error(BAD_ARGUMENTS, "An input path and a separate output path are required", null)
                    } else {
                        answer(result, output) { decodeAudio(input, output) }
                    }
                }
                REPLACE_AUDIO -> {
                    val input = text(call, "input")
                    val audio = text(call, "audio")
                    val output = text(call, "output")
                    val bitRate = (call.arguments as? Map<*, *>)?.get("bitRate") as? Int
                    if (input == null || audio == null || output == null || bitRate == null || bitRate <= 0 ||
                        samePath(input, output) || samePath(audio, output)
                    ) {
                        result.error(
                            BAD_ARGUMENTS,
                            "An input, an audio file, a separate output path and a bit rate are required",
                            null,
                        )
                    } else {
                        answer(result, output) { replaceAudio(input, audio, output, bitRate) }
                    }
                }
                else -> result.notImplemented()
            }
        }
    }

    private fun text(call: MethodCall, key: String): String? =
        ((call.arguments as? Map<*, *>)?.get(key) as? String)?.takeIf { it.isNotEmpty() }

    private fun samePath(first: String, second: String): Boolean =
        File(first).absoluteFile.normalize() == File(second).absoluteFile.normalize()

    private fun answer(result: MethodChannel.Result, output: String, work: () -> Any) {
        worker.execute {
            val reply = try {
                work()
            } catch (error: Exception) {
                failed(result, output, error)
                return@execute
            } catch (error: OutOfMemoryError) {
                failed(result, output, error)
                return@execute
            }
            main.post { result.success(reply) }
        }
    }

    private fun failed(result: MethodChannel.Result, output: String, error: Throwable) {
        File(output).delete()
        main.post { result.error(CLEAN_FAILED, error.message ?: FAILED_MESSAGE, null) }
    }

    private fun decodeAudio(input: String, output: String): Map<String, Any> =
        FileOutputStream(output).use { stream ->
            val wav = WavWriter(stream.channel)
            PcmDecoder(input).decode(wav::add)
            wav.finish()
        }

    private fun replaceAudio(input: String, audio: String, output: String, bitRate: Int): String {
        val extractor = MediaExtractor()
        var encoder: MediaCodec? = null
        var muxer: MediaMuxer? = null
        try {
            RandomAccessFile(audio, "r").use { wav ->
                val pcm = pcmData(wav)
                extractor.setDataSource(input)
                val video = videoTrack(extractor)
                val degrees = video?.let { format -> rotation(format) }
                val writer = MediaMuxer(output, MediaMuxer.OutputFormat.MUXER_OUTPUT_MPEG_4)
                muxer = writer
                val copy = video?.let { format ->
                    degrees?.let { writer.setOrientationHint(it) }
                    VideoCopy(extractor, writer, writer.addTrack(format), format)
                }
                val aac = MediaCodec.createEncoderByType(MediaFormat.MIMETYPE_AUDIO_AAC)
                encoder = aac
                aac.configure(aacFormat(bitRate), null, null, MediaCodec.CONFIGURE_FLAG_ENCODE)
                aac.start()
                encode(aac, wav.channel, pcm, writer, copy)
                copy?.copyUntil(Long.MAX_VALUE)
                writer.stop()
            }
        } finally {
            encoder?.let { started ->
                try {
                    started.stop()
                } catch (error: IllegalStateException) {
                    Unit
                }
                started.release()
            }
            muxer?.let { writer ->
                try {
                    writer.release()
                } catch (error: IllegalStateException) {
                    Unit
                }
            }
            extractor.release()
        }
        return output
    }

    private fun videoTrack(extractor: MediaExtractor): MediaFormat? {
        val track = (0 until extractor.trackCount).firstOrNull { index ->
            extractor.getTrackFormat(index).getString(MediaFormat.KEY_MIME)?.startsWith(VIDEO_MIME_PREFIX) == true
        } ?: return null
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

    private fun aacFormat(bitRate: Int): MediaFormat =
        MediaFormat.createAudioFormat(MediaFormat.MIMETYPE_AUDIO_AAC, AAC_SAMPLE_RATE, AAC_CHANNELS).apply {
            setInteger(MediaFormat.KEY_AAC_PROFILE, MediaCodecInfo.CodecProfileLevel.AACObjectLC)
            setInteger(MediaFormat.KEY_BIT_RATE, bitRate)
        }

    private fun pcmData(wav: RandomAccessFile): PcmData {
        val length = wav.length()
        val riff = ByteArray(RIFF_HEADER_BYTES)
        wav.seek(0)
        wav.readFully(riff)
        if (!riff.copyOfRange(0, 4).contentEquals(RIFF) || !riff.copyOfRange(8, 12).contentEquals(WAVE)) {
            throw IOException("The audio is not a WAV file")
        }
        val chunk = ByteBuffer.allocate(CHUNK_HEADER_BYTES).order(ByteOrder.LITTLE_ENDIAN)
        var formatRead = false
        var position = RIFF_HEADER_BYTES.toLong()
        while (position + CHUNK_HEADER_BYTES <= length) {
            wav.seek(position)
            wav.readFully(chunk.array())
            val id = chunk.array().copyOfRange(0, 4)
            val size = chunk.getInt(4).toLong() and UINT32_MASK
            val body = position + CHUNK_HEADER_BYTES
            if (id.contentEquals(FMT)) {
                requirePcmFormat(wav, size)
                formatRead = true
            } else if (id.contentEquals(DATA)) {
                if (!formatRead) {
                    throw IOException("The WAV data comes before its format")
                }
                if (size == 0L || size % INPUT_FRAME_BYTES != 0L || body + size > length) {
                    throw IOException("The WAV data chunk is malformed")
                }
                return PcmData(body, size)
            }
            position = body + size + (size and 1L)
        }
        throw IOException("The WAV file has no data chunk")
    }

    private fun requirePcmFormat(wav: RandomAccessFile, size: Long) {
        if (size < PCM_FORMAT_CHUNK_BYTES) {
            throw IOException("The WAV format chunk is too short")
        }
        val format = ByteBuffer.allocate(PCM_FORMAT_CHUNK_BYTES).order(ByteOrder.LITTLE_ENDIAN)
        wav.readFully(format.array())
        val encoding = format.getShort(0).toInt() and UINT16_MASK
        val channels = format.getShort(2).toInt() and UINT16_MASK
        val sampleRate = format.getInt(4)
        val bits = format.getShort(14).toInt() and UINT16_MASK
        if (encoding != PCM_FORMAT || channels != AAC_CHANNELS || sampleRate != AAC_SAMPLE_RATE ||
            bits != BITS_PER_SAMPLE
        ) {
            throw IOException("The audio must be 16-bit PCM at 48000 Hz with one channel")
        }
    }

    private fun encode(encoder: MediaCodec, wav: FileChannel, pcm: PcmData, muxer: MediaMuxer, video: VideoCopy?) {
        wav.position(pcm.offset)
        val info = MediaCodec.BufferInfo()
        var remaining = pcm.bytes
        var framesQueued = 0L
        var inputDone = false
        var audioTrack = NO_TRACK
        var idleTries = 0
        while (true) {
            var progressed = false
            if (!inputDone) {
                val inputIndex = encoder.dequeueInputBuffer(TIMEOUT_US)
                if (inputIndex >= 0) {
                    val input = encoder.getInputBuffer(inputIndex)
                        ?: throw IllegalStateException("No input buffer")
                    input.clear()
                    val room = input.capacity() / INPUT_FRAME_BYTES * INPUT_FRAME_BYTES
                    if (room == 0) {
                        throw IllegalStateException("The encoder input buffer holds no frame")
                    }
                    val size = minOf(remaining, room.toLong()).toInt()
                    val timeUs = framesQueued * MICROS_PER_SECOND / AAC_SAMPLE_RATE
                    if (size == 0) {
                        encoder.queueInputBuffer(inputIndex, 0, 0, timeUs, MediaCodec.BUFFER_FLAG_END_OF_STREAM)
                        inputDone = true
                    } else {
                        input.limit(size)
                        while (input.hasRemaining()) {
                            if (wav.read(input) < 0) {
                                throw IOException("The WAV data ended early")
                            }
                        }
                        encoder.queueInputBuffer(inputIndex, 0, size, timeUs, 0)
                        framesQueued += size / INPUT_FRAME_BYTES
                        remaining -= size
                    }
                    progressed = true
                }
            }
            val outputIndex = encoder.dequeueOutputBuffer(info, TIMEOUT_US)
            if (outputIndex == MediaCodec.INFO_OUTPUT_FORMAT_CHANGED) {
                if (audioTrack != NO_TRACK) {
                    throw IllegalStateException("The encoder changed its format after the file started")
                }
                audioTrack = muxer.addTrack(encoder.outputFormat)
                muxer.start()
                progressed = true
            } else if (outputIndex >= 0) {
                val output = encoder.getOutputBuffer(outputIndex)
                val config = info.flags and MediaCodec.BUFFER_FLAG_CODEC_CONFIG != 0
                if (output != null && info.size > 0 && !config) {
                    if (audioTrack == NO_TRACK) {
                        throw IllegalStateException("The encoder wrote audio before its format")
                    }
                    video?.copyUntil(info.presentationTimeUs)
                    output.position(info.offset)
                    output.limit(info.offset + info.size)
                    muxer.writeSampleData(audioTrack, output, info)
                }
                encoder.releaseOutputBuffer(outputIndex, false)
                if (info.flags and MediaCodec.BUFFER_FLAG_END_OF_STREAM != 0) {
                    if (audioTrack == NO_TRACK) {
                        throw IllegalStateException("The encoder wrote no audio")
                    }
                    return
                }
                progressed = true
            }
            idleTries = if (progressed) 0 else idleTries + 1
            if (idleTries > MAX_IDLE_TRIES) {
                throw IllegalStateException("The encoder stopped producing audio")
            }
        }
    }

    private class PcmData(val offset: Long, val bytes: Long)

    private class VideoCopy(
        private val extractor: MediaExtractor,
        private val muxer: MediaMuxer,
        private val track: Int,
        format: MediaFormat,
    ) {
        private val buffer = ByteBuffer.allocateDirect(videoSampleBytes(format))
        private val info = MediaCodec.BufferInfo()
        private var done = false

        fun copyUntil(timeUs: Long) {
            while (!done && extractor.sampleTime <= timeUs) {
                buffer.clear()
                val size = extractor.readSampleData(buffer, 0)
                if (size < 0) {
                    done = true
                } else {
                    val flags = if (extractor.sampleFlags and MediaExtractor.SAMPLE_FLAG_SYNC != 0) {
                        MediaCodec.BUFFER_FLAG_KEY_FRAME
                    } else {
                        0
                    }
                    info.set(0, size, extractor.sampleTime, flags)
                    muxer.writeSampleData(track, buffer, info)
                    extractor.advance()
                }
            }
        }
    }

    private class WavWriter(private val file: FileChannel) {
        private var scratch = ByteBuffer.allocate(0).order(ByteOrder.LITTLE_ENDIAN)
        private var format: MediaFormat? = null
        private var sampleRate = 0
        private var channels = 0
        private var floatSamples = false
        private var samples = 0L

        init {
            writeFully(ByteBuffer.allocate(WAV_HEADER_BYTES))
        }

        fun add(pcm: ByteBuffer, current: MediaFormat) {
            if (current !== format) {
                reformat(current)
            }
            val bytes = if (floatSamples) fromFloats(pcm) else fromShorts(pcm)
            samples += bytes.remaining() / BYTES_PER_SAMPLE
            writeFully(bytes)
        }

        fun finish(): Map<String, Any> {
            if (channels == 0 || samples == 0L) {
                throw IllegalStateException("The audio holds no samples")
            }
            if (samples % channels != 0L) {
                throw IllegalStateException("The audio ends inside a frame")
            }
            val dataBytes = samples * BYTES_PER_SAMPLE
            if (dataBytes > MAX_WAV_DATA_BYTES) {
                throw IllegalStateException("The audio is too long for a WAV file")
            }
            val header = header(dataBytes)
            var position = 0L
            while (header.hasRemaining()) {
                position += file.write(header, position)
            }
            return mapOf("sampleRate" to sampleRate, "channels" to channels, "frames" to samples / channels)
        }

        private fun reformat(output: MediaFormat) {
            val rate = positive(output, MediaFormat.KEY_SAMPLE_RATE)
            val count = positive(output, MediaFormat.KEY_CHANNEL_COUNT)
            if (format != null && (rate != sampleRate || count != channels)) {
                throw IllegalStateException("The audio format changed while it was decoded")
            }
            val encoding = if (output.containsKey(MediaFormat.KEY_PCM_ENCODING)) {
                output.getInteger(MediaFormat.KEY_PCM_ENCODING)
            } else {
                AudioFormat.ENCODING_PCM_16BIT
            }
            floatSamples = when (encoding) {
                AudioFormat.ENCODING_PCM_16BIT -> false
                AudioFormat.ENCODING_PCM_FLOAT -> true
                else -> throw IllegalStateException("The decoder wrote PCM encoding $encoding")
            }
            sampleRate = rate
            channels = count
            format = output
        }

        private fun positive(output: MediaFormat, key: String): Int {
            val value = if (output.containsKey(key)) output.getInteger(key) else 0
            if (value <= 0) {
                throw IllegalStateException("The audio format has no $key")
            }
            return value
        }

        private fun fromShorts(pcm: ByteBuffer): ByteBuffer {
            val shorts = pcm.asShortBuffer()
            val bytes = scratch(shorts.remaining() * BYTES_PER_SAMPLE)
            bytes.asShortBuffer().put(shorts)
            return bytes
        }

        private fun fromFloats(pcm: ByteBuffer): ByteBuffer {
            val floats = pcm.asFloatBuffer()
            val bytes = scratch(floats.remaining() * BYTES_PER_SAMPLE)
            val shorts = bytes.asShortBuffer()
            while (floats.hasRemaining()) {
                shorts.put(pcm16(floats.get()))
            }
            return bytes
        }

        private fun pcm16(sample: Float): Short {
            if (sample.isNaN()) {
                return 0
            }
            return (sample * PCM_16_MAX).roundToInt()
                .coerceIn(Short.MIN_VALUE.toInt(), Short.MAX_VALUE.toInt())
                .toShort()
        }

        private fun scratch(size: Int): ByteBuffer {
            if (scratch.capacity() < size) {
                scratch = ByteBuffer.allocate(size).order(ByteOrder.LITTLE_ENDIAN)
            }
            scratch.clear()
            scratch.limit(size)
            return scratch
        }

        private fun writeFully(bytes: ByteBuffer) {
            while (bytes.hasRemaining()) {
                file.write(bytes)
            }
        }

        private fun header(dataBytes: Long): ByteBuffer {
            val header = ByteBuffer.allocate(WAV_HEADER_BYTES).order(ByteOrder.LITTLE_ENDIAN)
            header.put(RIFF)
            header.putInt((dataBytes + WAV_HEADER_BYTES - CHUNK_HEADER_BYTES).toInt())
            header.put(WAVE)
            header.put(FMT)
            header.putInt(PCM_FORMAT_CHUNK_BYTES)
            header.putShort(PCM_FORMAT.toShort())
            header.putShort(channels.toShort())
            header.putInt(sampleRate)
            header.putInt(sampleRate * channels * BYTES_PER_SAMPLE)
            header.putShort((channels * BYTES_PER_SAMPLE).toShort())
            header.putShort(BITS_PER_SAMPLE.toShort())
            header.put(DATA)
            header.putInt(dataBytes.toInt())
            header.flip()
            return header
        }
    }

    private companion object {
        const val CHANNEL = "field_notes/audio_clean"
        const val DECODE_AUDIO = "decodeAudio"
        const val REPLACE_AUDIO = "replaceAudio"
        const val BAD_ARGUMENTS = "bad_arguments"
        const val CLEAN_FAILED = "clean-failed"
        const val FAILED_MESSAGE = "The audio could not be cleaned."
        const val VIDEO_MIME_PREFIX = "video/"
        const val AAC_SAMPLE_RATE = 48000
        const val AAC_CHANNELS = 1
        const val BITS_PER_SAMPLE = 16
        const val BYTES_PER_SAMPLE = 2
        const val INPUT_FRAME_BYTES = BYTES_PER_SAMPLE * AAC_CHANNELS
        const val PCM_FORMAT = 1
        const val PCM_FORMAT_CHUNK_BYTES = 16
        const val RIFF_HEADER_BYTES = 12
        const val CHUNK_HEADER_BYTES = 8
        const val WAV_HEADER_BYTES = 44
        const val UINT16_MASK = 0xFFFF
        const val UINT32_MASK = 0xFFFFFFFFL
        const val MAX_WAV_DATA_BYTES = UINT32_MASK - (WAV_HEADER_BYTES - CHUNK_HEADER_BYTES)
        const val PCM_16_MAX = 32767f
        const val MICROS_PER_SECOND = 1_000_000L
        const val DEFAULT_VIDEO_SAMPLE_BYTES = 8 * 1024 * 1024
        const val NO_TRACK = -1
        const val TIMEOUT_US = 10_000L
        const val MAX_IDLE_TRIES = 500
        val MUXER_ROTATIONS = setOf(0, 90, 180, 270)
        val RIFF = "RIFF".toByteArray(Charsets.US_ASCII)
        val WAVE = "WAVE".toByteArray(Charsets.US_ASCII)
        val FMT = "fmt ".toByteArray(Charsets.US_ASCII)
        val DATA = "data".toByteArray(Charsets.US_ASCII)

        fun videoSampleBytes(format: MediaFormat): Int =
            if (format.containsKey(MediaFormat.KEY_MAX_INPUT_SIZE) && format.getInteger(MediaFormat.KEY_MAX_INPUT_SIZE) > 0) {
                format.getInteger(MediaFormat.KEY_MAX_INPUT_SIZE)
            } else {
                DEFAULT_VIDEO_SAMPLE_BYTES
            }
    }
}
