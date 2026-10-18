package xyz.luan.audioplayers.player

import android.content.Context
import android.media.AudioDeviceInfo
import android.media.AudioManager
import android.os.Build

internal object PreferredOutputDevice {
    fun find(context: Context, deviceId: String?): AudioDeviceInfo? {
        if (deviceId == null || Build.VERSION.SDK_INT < Build.VERSION_CODES.M) {
            return null
        }
        val audioManager = context.getSystemService(Context.AUDIO_SERVICE) as? AudioManager ?: return null
        return audioManager.getDevices(AudioManager.GET_DEVICES_OUTPUTS).firstOrNull { idOf(it) == deviceId }
    }

    private fun idOf(device: AudioDeviceInfo): String {
        val base = "${device.type}:${device.productName}"
        val address = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.P) device.address.orEmpty() else ""
        return if (address.isEmpty()) base else "$base:$address"
    }
}
