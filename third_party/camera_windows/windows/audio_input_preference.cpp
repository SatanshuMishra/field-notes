#include "audio_input_preference.h"

#include <mutex>

namespace camera_windows {

namespace {

std::mutex& PreferenceMutex() {
  static std::mutex mutex;
  return mutex;
}

std::wstring& PreferredEndpointId() {
  static std::wstring endpoint_id;
  return endpoint_id;
}

}

std::wstring GetPreferredAudioEndpointId() {
  std::lock_guard<std::mutex> lock(PreferenceMutex());
  return PreferredEndpointId();
}

void SetPreferredAudioEndpointId(const std::wstring& endpoint_id) {
  std::lock_guard<std::mutex> lock(PreferenceMutex());
  PreferredEndpointId() = endpoint_id;
}

}
