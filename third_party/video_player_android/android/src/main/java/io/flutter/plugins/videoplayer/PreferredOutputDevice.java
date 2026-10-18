package io.flutter.plugins.videoplayer;

import android.content.Context;
import android.media.AudioDeviceInfo;
import android.media.AudioManager;
import android.os.Build;
import androidx.annotation.NonNull;
import androidx.annotation.Nullable;

final class PreferredOutputDevice {
  private PreferredOutputDevice() {}

  @Nullable
  static AudioDeviceInfo find(@NonNull Context context, @Nullable String deviceId) {
    if (deviceId == null) {
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

  @NonNull
  private static String idOf(@NonNull AudioDeviceInfo device) {
    String base = device.getType() + ":" + device.getProductName();
    String address = Build.VERSION.SDK_INT >= Build.VERSION_CODES.P ? device.getAddress() : null;
    return address == null || address.isEmpty() ? base : base + ":" + address;
  }
}
