package dev.satanshumishra.field_notes.uploads

import android.content.Context
import org.json.JSONException
import org.json.JSONObject
import java.io.File
import java.io.FileOutputStream
import java.io.IOException
import java.util.UUID

class UploadStore(root: File) {
    private val tasks = File(root, "tasks")
    private val results = File(root, "results")

    fun put(item: UploadItem): UploadItem = synchronized(LOCK) {
        require(UploadItem.isSafeId(item.taskId)) { "unsafe task id" }
        val stored = item.copy(attempts = 0, epoch = UUID.randomUUID().toString(), order = nextOrder())
        writeAtomically(taskFile(item.taskId), stored.storedJson())
        resultFile(item.taskId).delete()
        stored
    }

    fun pending(): List<UploadItem> = synchronized(LOCK) {
        val files = tasks.listFiles { file -> file.name.endsWith(JSON) } ?: return emptyList()
        files.mapNotNull { file ->
            try {
                UploadItem.fromJson(JSONObject(file.readText()))
            } catch (error: JSONException) {
                file.delete()
                null
            } catch (error: IllegalArgumentException) {
                file.delete()
                null
            } catch (error: IOException) {
                null
            }
        }.sortedWith(compareBy<UploadItem> { it.order }.thenBy { it.taskId })
    }

    fun recordAttempt(item: UploadItem): UploadItem? = synchronized(LOCK) {
        if (currentEpoch(item.taskId) != item.epoch) {
            return null
        }
        val next = item.copy(attempts = item.attempts + 1)
        writeAtomically(taskFile(item.taskId), next.storedJson())
        next
    }

    fun finish(result: UploadResult): Boolean = synchronized(LOCK) {
        if (currentEpoch(result.item.taskId) != result.item.epoch) {
            return false
        }
        writeAtomically(resultFile(result.item.taskId), result.toJson())
        taskFile(result.item.taskId).delete()
        true
    }

    fun takeResults(limit: Int = RESULTS_PER_TAKE): List<JSONObject> = synchronized(LOCK) {
        val files = results.listFiles { file -> file.name.endsWith(JSON) } ?: return emptyList()
        files.sortedBy { it.lastModified() }.take(limit).mapNotNull { file ->
            val json = try {
                JSONObject(file.readText())
            } catch (error: JSONException) {
                null
            } catch (error: IOException) {
                null
            }
            file.delete()
            json
        }
    }

    fun cancel(taskIds: Collection<String>) = synchronized(LOCK) {
        for (taskId in taskIds) {
            if (UploadItem.isSafeId(taskId)) {
                taskFile(taskId).delete()
            }
        }
    }

    fun cancelAll() = synchronized(LOCK) {
        tasks.listFiles()?.forEach { it.delete() }
    }

    private fun nextOrder(): Long {
        val now = System.currentTimeMillis() * ORDER_SPREAD
        lastOrder = if (now > lastOrder) now else lastOrder + 1
        return lastOrder
    }

    private fun currentEpoch(taskId: String): String? = try {
        val file = taskFile(taskId)
        if (file.exists()) JSONObject(file.readText()).optString("epoch", "") else null
    } catch (error: JSONException) {
        null
    } catch (error: IOException) {
        null
    }

    private fun taskFile(taskId: String) = File(tasks, "$taskId$JSON")

    private fun resultFile(taskId: String) = File(results, "$taskId$JSON")

    private fun writeAtomically(target: File, json: JSONObject) {
        val folder = target.parentFile ?: throw IOException("no folder for ${target.name}")
        if (!folder.isDirectory && !folder.mkdirs()) {
            throw IOException("cannot create ${folder.name}")
        }
        val temporary = File(folder, ".${target.name}.${UUID.randomUUID()}")
        FileOutputStream(temporary).use { output ->
            output.write(json.toString().toByteArray(Charsets.UTF_8))
            output.fd.sync()
        }
        if (!temporary.renameTo(target)) {
            temporary.delete()
            throw IOException("cannot write ${target.name}")
        }
    }

    companion object {
        private const val JSON = ".json"
        private const val ORDER_SPREAD = 1_000L
        const val RESULTS_PER_TAKE = 100
        private val LOCK = Any()
        private var lastOrder = 0L

        fun of(context: Context): UploadStore = UploadStore(File(context.noBackupFilesDir, "uploads"))
    }
}
