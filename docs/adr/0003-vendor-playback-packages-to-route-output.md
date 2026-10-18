# Vendor the playback packages to choose the output device

Status: accepted

No published Flutter playback package (just_audio, video_player, audioplayers) can choose an output device, so the app vendors their platform packages under third_party and adds one call to each that sets the native player's output. Changing the system default output instead would have moved every other app's sound. Upgrading any of these packages now means re-applying that call to the new version.
