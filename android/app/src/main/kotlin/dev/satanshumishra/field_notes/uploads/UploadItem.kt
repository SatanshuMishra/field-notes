package dev.satanshumishra.field_notes.uploads

import org.json.JSONObject

enum class Lane(val jobId: Int, val workName: String, val notificationId: Int) {
    ANY(41_001, "field_notes_uploads_any", 41_001),
    UNMETERED(41_002, "field_notes_uploads_unmetered", 41_002);

    companion object {
        fun ofJob(jobId: Int): Lane? = entries.firstOrNull { it.jobId == jobId }

        fun ofName(name: String?): Lane? = entries.firstOrNull { it.name == name }
    }
}

data class UploadItem(
    val taskId: String,
    val group: String,
    val url: String,
    val method: String,
    val headers: Map<String, String>,
    val filePath: String,
    val mimeType: String,
    val requiresWiFi: Boolean,
    val metaData: String,
    val attempts: Int = 0,
    val epoch: String = "",
    val order: Long = 0,
) {
    val isPush: Boolean get() = group == PUSH_GROUP

    val lane: Lane get() = if (requiresWiFi) Lane.UNMETERED else Lane.ANY

    fun taskJson(): JSONObject = JSONObject()
        .put(TASK_ID, taskId)
        .put(GROUP, group)
        .put(URL, url)
        .put(METHOD, method)
        .put(HEADERS, JSONObject(headers.toMap()))
        .put(FILE, filePath)
        .put(MIME_TYPE, mimeType)
        .put(REQUIRES_WIFI, requiresWiFi)
        .put(META_DATA, metaData)

    fun storedJson(): JSONObject = taskJson()
        .put(ATTEMPTS, attempts)
        .put(EPOCH, epoch)
        .put(ORDER, order)

    companion object {
        const val PUSH_GROUP = "field_notes_records"
        const val MAX_ATTEMPTS = 10
        private const val TASK_ID = "taskId"
        private const val GROUP = "group"
        private const val URL = "url"
        private const val METHOD = "method"
        private const val HEADERS = "headers"
        private const val FILE = "file"
        private const val MIME_TYPE = "mimeType"
        private const val REQUIRES_WIFI = "requiresWiFi"
        private const val META_DATA = "metaData"
        private const val ATTEMPTS = "attempts"
        private const val EPOCH = "epoch"
        private const val ORDER = "order"
        private val SAFE_ID = Regex("^[A-Za-z0-9._-]{1,200}$")

        fun isSafeId(taskId: String): Boolean = SAFE_ID.matches(taskId)

        fun fromJson(json: JSONObject): UploadItem {
            val headersJson = json.getJSONObject(HEADERS)
            val headers = buildMap {
                for (key in headersJson.keys()) {
                    put(key, headersJson.getString(key))
                }
            }
            val taskId = json.getString(TASK_ID)
            require(isSafeId(taskId)) { "unsafe task id" }
            return UploadItem(
                taskId = taskId,
                group = json.getString(GROUP),
                url = json.getString(URL),
                method = json.getString(METHOD),
                headers = headers,
                filePath = json.getString(FILE),
                mimeType = json.getString(MIME_TYPE),
                requiresWiFi = json.getBoolean(REQUIRES_WIFI),
                metaData = json.getString(META_DATA),
                attempts = json.optInt(ATTEMPTS, 0),
                epoch = json.optString(EPOCH, ""),
                order = json.optLong(ORDER, 0),
            )
        }
    }
}

data class UploadResult(
    val item: UploadItem,
    val complete: Boolean,
    val statusCode: Int?,
    val body: String?,
) {
    fun toJson(): JSONObject = JSONObject()
        .put("task", item.taskJson())
        .put("status", if (complete) "complete" else "failed")
        .put("statusCode", statusCode ?: JSONObject.NULL)
        .put("body", body ?: JSONObject.NULL)
}
