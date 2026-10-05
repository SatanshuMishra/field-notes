package dev.satanshumishra.field_notes.uploads

import android.content.Context
import android.os.Handler
import android.os.Looper
import io.flutter.plugin.common.BinaryMessenger
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel
import org.json.JSONException
import org.json.JSONObject
import java.io.IOException
import java.util.concurrent.Executors

class UploadChannel(private val context: Context) {
    private val store = UploadStore.of(context)
    private val scheduler = UploadScheduler(context, store)
    private val worker = Executors.newSingleThreadExecutor { runnable -> Thread(runnable, "uploads-channel") }
    private val main = Handler(Looper.getMainLooper())

    fun register(messenger: BinaryMessenger) {
        val channel = MethodChannel(messenger, CHANNEL)
        channel.setMethodCallHandler { call, result -> worker.execute { answer(call, result) } }
        UploadCoordinator.shared.onResults = {
            main.post { channel.invokeMethod(RESULTS_READY, null) }
        }
    }

    private fun answer(call: MethodCall, result: MethodChannel.Result) {
        val reply: Any? = try {
            when (call.method) {
                "configure" -> configure(call)
                "enqueue" -> enqueue(call)
                "queued" -> store.pending().map { it.taskJson().toString() }
                "cancel" -> scheduler.cancel(call.argument<List<String>>("taskIds") ?: emptyList())
                "cancelAll" -> scheduler.cancelAll()
                "takeResults" -> store.takeResults().map { it.toString() }
                else -> {
                    main.post { result.notImplemented() }
                    return
                }
            }
        } catch (error: JSONException) {
            main.post { result.error("invalid", error.message, null) }
            return
        } catch (error: IllegalArgumentException) {
            main.post { result.error("invalid", error.message, null) }
            return
        } catch (error: IOException) {
            main.post { result.error("storage", error.message, null) }
            return
        }
        main.post { result.success(if (reply is Unit) null else reply) }
    }

    private fun configure(call: MethodCall) {
        UploadCopy.save(
            context,
            UploadCopy(
                title = call.argument<String>("title") ?: "",
                body = call.argument<String>("body") ?: "",
                bodyWaitingForWiFi = call.argument<String>("bodyWaitingForWiFi") ?: "",
                channelName = call.argument<String>("channelName") ?: "",
            ),
        )
    }

    private fun enqueue(call: MethodCall): Boolean {
        val tasks = call.argument<List<String>>("tasks") ?: emptyList()
        for (task in tasks) {
            store.put(UploadItem.fromJson(JSONObject(task)))
        }
        scheduler.schedule()
        return true
    }

    private companion object {
        const val CHANNEL = "field_notes/background_uploads"
        const val RESULTS_READY = "resultsReady"
    }
}
