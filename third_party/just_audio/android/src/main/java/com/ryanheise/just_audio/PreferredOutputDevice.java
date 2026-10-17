package com.ryanheise.just_audio;

import android.content.Context;
import android.media.AudioDeviceInfo;
import android.media.AudioManager;
import android.os.Build;

final class PreferredOutputDevice {
    private PreferredOutputDevice() {}

    static AudioDeviceInfo find(Context context, String deviceId) {
        if (deviceId == null || Build.VERSION.SDK_INT < Build.VERSION_CODES.M) {
            return null;
        }
        AudioManager audioManager = (AudioManager) context.getSystemService(Context.AUDIO_SERVICE);
        if (audioManager == null) {
            return null;
        }
        for (AudioDeviceInfo device : audioManager.getDevices(AudioManager.GET_DEVICES_OUTPUTS)) {
            if (deviceId.equals(idOf(device))) {
                return device;
            }
        }
        return null;
    }

    private static String idOf(AudioDeviceInfo device) {
        String base = device.getType() + ":" + device.getProductName();
        String address = Build.VERSION.SDK_INT >= Build.VERSION_CODES.P ? device.getAddress() : null;
        return address == null || address.isEmpty() ? base : base + ":" + address;
    }
}
