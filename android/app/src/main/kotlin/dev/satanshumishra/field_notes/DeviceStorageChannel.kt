package dev.satanshumishra.field_notes

import android.content.Context
import android.os.Handler
import android.os.Looper
import android.os.storage.StorageManager
import io.flutter.plugin.common.BinaryMessenger
import io.flutter.plugin.common.MethodChannel
import java.io.File
import java.io.IOException
import java.util.concurrent.Executors

class DeviceStorageChannel(private val context: Context) {
    private val worker = Executors.newSingleThreadExecutor()
    private val main = Handler(Looper.getMainLooper())

    fun register(messenger: BinaryMessenger) {
        MethodChannel(messenger, CHANNEL).setMethodCallHandler { call, result ->
            when (call.method) {
                FREE_BYTES -> {
                    val path = call.argument<String>("path")
                    if (path == null) {
                        result.error("bad_arguments", "A path is required", null)
                    } else {
                        worker.execute {
                            val free = freeBytes(File(path))
                            main.post { result.success(free) }
                        }
                    }
                }
                else -> result.notImplemented()
            }
        }
    }

    private fun freeBytes(near: File): Long? {
        val existing = generateSequence(near) { it.parentFile }.firstOrNull { it.exists() }
            ?: return null
        val storage = context.getSystemService(StorageManager::class.java)
        return try {
            val allocatable = storage?.getAllocatableBytes(storage.getUuidForPath(existing))
                ?: existing.usableSpace
            minOf(allocatable, existing.usableSpace)
        } catch (error: IOException) {
            existing.usableSpace
        } catch (error: SecurityException) {
            existing.usableSpace
        }
    }

    private companion object {
        const val CHANNEL = "field_notes/device_storage"
        const val FREE_BYTES = "freeBytes"
    }
}
