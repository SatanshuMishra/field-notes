---
date: 2026-07-24
status: accepted
thread: journal-app-design
---
# macOS video crash = videoRotationAngle setter, NOT a save-path bug

Real root cause of "video recording doesn't work": the app CRASHES in
CameraMacosPlugin.initCamera the instant camera TCC is granted, BEFORE any preview/recording.
`connection.videoRotationAngle = self.orientation`
(third_party/camera_macos/macos/Classes/CameraMacosPlugin.swift:507/524/541) throws
NSInvalidArgumentException "-[AVCaptureConnection_Tundra setVideoOrientation:] Not supported"
even though the guarding `isVideoRotationAngleSupported(...)` returns true — a macOS 26
"_Tundra" capture-connection quirk (the rotation setter routes through the unsupported legacy
orientation path). Swift cannot catch the ObjC NSException, so the app terminates.

PROOF (chased hard): crash-report camera_macos UUID 16970FA8 == our fresh build's UUID (otool)
-> it IS our own binary, not a stale one (stale-bundle theory disproven). The reason string
names setVideoOrientation because AVFoundation emits it; our binary's objc_methname table
(otool) contains ONLY setVideoRotationAngle:, never setVideoOrientation:. No [VIDCAP] logs
fired because the crash is UPSTREAM of the recording path.

FIX: delete the three videoRotationAngle assignments (rotation is cosmetic on a desktop webcam
- frames are upright; orientation defaults to 0). Supersedes the framing that video was a
save-hang/finalize bug: all PR #32/#33 save-path work was downstream of a crash that never let
capture start. Verify: after fix, a human `flutter run -d macos` should reach preview -> record
-> stop, and the [VIDCAP] logs should finally exercise the save path.
