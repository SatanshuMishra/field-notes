package dev.satanshumishra.field_notes.uploads

import android.net.Network
import java.io.ByteArrayOutputStream
import java.io.File
import java.io.InputStream
import java.net.HttpURLConnection
import java.net.URL
import java.util.Collections

data class TransportAnswer(val statusCode: Int, val body: String)

interface UploadTransport {
    fun send(item: UploadItem, onBytes: (Long) -> Unit): TransportAnswer

    fun abortAll()
}

class HttpTransport(private val network: () -> Network?, fileRoot: File) : UploadTransport {
    private val open = Collections.synchronizedSet(mutableSetOf<HttpURLConnection>())
    private val root = fileRoot.canonicalPath + File.separator

    override fun send(item: UploadItem, onBytes: (Long) -> Unit): TransportAnswer {
        val file = File(item.filePath).canonicalFile
        if (!file.path.startsWith(root) || !file.isFile) {
            return TransportAnswer(MISSING_FILE, "")
        }
        val url = URL(item.url)
        val connection = (network()?.openConnection(url) ?: url.openConnection()) as? HttpURLConnection
            ?: return TransportAnswer(MISSING_FILE, "")
        open.add(connection)
        try {
            connection.connectTimeout = CONNECT_TIMEOUT_MILLIS
            connection.readTimeout = READ_TIMEOUT_MILLIS
            connection.requestMethod = item.method
            connection.doOutput = true
            connection.useCaches = false
            connection.instanceFollowRedirects = false
            for ((name, value) in item.headers) {
                connection.setRequestProperty(name, value)
            }
            connection.setRequestProperty("Content-Type", item.mimeType)
            connection.setFixedLengthStreamingMode(file.length())
            connection.outputStream.use { output ->
                file.inputStream().use { input ->
                    val buffer = ByteArray(CHUNK_BYTES)
                    while (true) {
                        val read = input.read(buffer)
                        if (read < 0) {
                            break
                        }
                        output.write(buffer, 0, read)
                        onBytes(read.toLong())
                    }
                }
            }
            val status = connection.responseCode
            val stream = if (status >= 400) connection.errorStream else connection.inputStream
            return TransportAnswer(status, stream?.let(::readCapped) ?: "")
        } finally {
            open.remove(connection)
            connection.disconnect()
        }
    }

    override fun abortAll() {
        val connections = synchronized(open) { open.toList() }
        for (connection in connections) {
            connection.disconnect()
        }
    }

    private fun readCapped(stream: InputStream): String = stream.use { input ->
        val output = ByteArrayOutputStream()
        val buffer = ByteArray(CHUNK_BYTES)
        while (output.size() < READ_LIMIT) {
            val read = input.read(buffer)
            if (read < 0) {
                break
            }
            output.write(buffer, 0, minOf(read, READ_LIMIT - output.size()))
        }
        output.toString(Charsets.UTF_8.name())
    }

    companion object {
        const val MISSING_FILE = -1
        private const val CONNECT_TIMEOUT_MILLIS = 30_000
        private const val READ_TIMEOUT_MILLIS = 120_000
        private const val CHUNK_BYTES = 64 * 1024
        const val MAX_BODY_BYTES = 256 * 1024
        private const val READ_LIMIT = MAX_BODY_BYTES + 1
    }
}
