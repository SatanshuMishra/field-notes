#ifndef PACKAGES_CAMERA_CAMERA_WINDOWS_WINDOWS_AUDIO_INPUT_PREFERENCE_H_
#define PACKAGES_CAMERA_CAMERA_WINDOWS_WINDOWS_AUDIO_INPUT_PREFERENCE_H_

#include <string>

namespace camera_windows {

std::wstring GetPreferredAudioEndpointId();

void SetPreferredAudioEndpointId(const std::wstring& endpoint_id);

}

#endif
