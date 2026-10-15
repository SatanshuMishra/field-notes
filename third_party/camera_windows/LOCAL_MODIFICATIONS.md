# camera_windows — local modifications

This is a vendored copy of `camera_windows` (pub name `camera_windows`, version `0.3.0`),
by the Flutter authors, sourced from https://github.com/flutter/packages/tree/main/packages/camera/camera_windows
through the pub cache (`~/.pub-cache/hosted/pub.dev/camera_windows-0.3.0`).

Copied: `LICENSE`, `AUTHORS`, `CHANGELOG.md`, `README.md`, `pubspec.yaml`, `lib/`, `pigeons/`
and `windows/` (with the plugin's native tests under `windows/test/`). Left out: `example/`
and the Dart `test/` folder.

Field Notes changes only how the plugin picks the microphone a video records from. A future
re-vendor (bumping the upstream version or re-copying) MUST re-apply the deltas below, or Windows
video takes go back to recording from whichever microphone Windows lists first. Verify each item
is still present after any upstream sync.

## Delta

1. Dart method `CameraWindows.setAudioInputDevice(String? endpointId)` in
   `lib/camera_windows.dart`: a static method that invokes `setAudioInputDevice` with the
   argument `{'endpointId': endpointId}` on its own method channel,
   `plugins.flutter.io/camera_windows/audio_input`. The id is a Windows capture endpoint id,
   the `IMMDevice` id that `record` lists microphones by. Upstream has no such method.

2. Stored endpoint id: `windows/audio_input_preference.h` and `windows/audio_input_preference.cpp`
   hold one process-wide `std::wstring`, guarded by a mutex, with
   `GetPreferredAudioEndpointId()` and `SetPreferredAudioEndpointId()`. Both files are listed in
   `PLUGIN_SOURCES` in `windows/CMakeLists.txt`.

3. Channel handler: `CameraPlugin::RegisterWithRegistrar` in `windows/camera_plugin.cpp`
   registers a handler for `plugins.flutter.io/camera_windows/audio_input`. On
   `setAudioInputDevice` it stores the `endpointId` string, converted to UTF-16, and replies
   success; a null, missing or empty id clears the stored one. Any other method replies not
   implemented.

4. Audio source choice: `CaptureControllerImpl::CreateDefaultAudioCaptureSource` in
   `windows/capture_controller.cpp` still enumerates the audio capture devices with
   `MFEnumDeviceSources`, reads each one's `MF_DEVSOURCE_ATTRIBUTE_SOURCE_TYPE_AUDCAP_ENDPOINT_ID`
   and releases each `IMFActivate`, then creates the audio source from the device whose endpoint
   id equals the stored id. When no id is stored or none matches, it uses the device whose
   endpoint id equals the Windows default capture endpoint
   (`IMMDeviceEnumerator::GetDefaultAudioEndpoint(eCapture, eConsole)` and `IMMDevice::GetId`).
   Only when that also fails does it fall back to the first device, as upstream always does.
   Upstream takes the first device (its comment "Use first audio device.", now removed) and
   never releases the enumerated `IMFActivate` objects.
