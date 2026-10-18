package dev.satanshumishra.field_notes

import android.content.Context
import android.media.AudioDeviceInfo
import android.media.AudioManager
import android.os.Build
import io.flutter.plugin.common.BinaryMessenger
import io.flutter.plugin.common.MethodChannel

class AudioOutputChannel(private val context: Context) {
    fun register(messenger: BinaryMessenger) {
        MethodChannel(messenger, CHANNEL).setMethodCallHandler { call, result ->
            when (call.method) {
                LIST_OUTPUTS -> result.success(listOutputs())
                else -> result.notImplemented()
            }
        }
    }

    private fun listOutputs(): List<Map<String, String>> {
        val audio = context.getSystemService(AudioManager::class.java) ?: return emptyList()
        val listed = listedTypes()
        return audio.getDevices(AudioManager.GET_DEVICES_OUTPUTS)
            .filter { it.type in listed }
            .map { mapOf(ID to idOf(it), NAME to nameOf(it)) }
            .distinctBy { it[ID] }
    }

    private fun listedTypes(): Set<Int> =
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.S) {
            OUTPUT_TYPES + BLE_OUTPUT_TYPES
        } else {
            OUTPUT_TYPES
        }

    private fun idOf(device: AudioDeviceInfo): String {
        val base = "${device.type}:${device.productName}"
        val address = device.address
        return if (address.isNullOrEmpty()) base else "$base:$address"
    }

    private fun nameOf(device: AudioDeviceInfo): String =
        when (device.type) {
            AudioDeviceInfo.TYPE_BUILTIN_SPEAKER -> PHONE_SPEAKER
            AudioDeviceInfo.TYPE_WIRED_HEADSET,
            AudioDeviceInfo.TYPE_WIRED_HEADPHONES -> WIRED_HEADPHONES
            AudioDeviceInfo.TYPE_USB_DEVICE,
            AudioDeviceInfo.TYPE_USB_HEADSET -> USB_AUDIO
            else -> device.productName?.toString()?.takeIf { it.isNotBlank() } ?: BLUETOOTH_AUDIO
        }

    private companion object {
        const val CHANNEL = "field_notes/audio_output"
        const val LIST_OUTPUTS = "listOutputs"
        const val ID = "id"
        const val NAME = "name"
        const val PHONE_SPEAKER = "Phone speaker"
        const val WIRED_HEADPHONES = "Wired headphones"
        const val USB_AUDIO = "USB audio"
        const val BLUETOOTH_AUDIO = "Bluetooth audio"
        val OUTPUT_TYPES = setOf(
            AudioDeviceInfo.TYPE_BUILTIN_SPEAKER,
            AudioDeviceInfo.TYPE_WIRED_HEADSET,
            AudioDeviceInfo.TYPE_WIRED_HEADPHONES,
            AudioDeviceInfo.TYPE_USB_DEVICE,
            AudioDeviceInfo.TYPE_USB_HEADSET,
            AudioDeviceInfo.TYPE_BLUETOOTH_A2DP,
        )
        val BLE_OUTPUT_TYPES = setOf(
            AudioDeviceInfo.TYPE_BLE_HEADSET,
            AudioDeviceInfo.TYPE_BLE_SPEAKER,
        )
    }
}
