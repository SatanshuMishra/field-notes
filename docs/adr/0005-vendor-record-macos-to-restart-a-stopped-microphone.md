# Vendor record_macos to restart a stopped microphone

Status: accepted

macOS stops the audio engine whenever its input or output configuration changes, which a Bluetooth headset does each time it switches between its media and call modes, and record_macos 2.1.1 neither restarts the engine nor reports the stop, so a 6-minute video log saved 0.063 s of sound on 2026-10-18. The app vendors record_macos under third_party, restarts the engine on the configuration change, gives each recorder its own queue, bounds a native start to 2 seconds, and reports what it cannot restart as a stream error that the app's own watchdog answers by reopening the microphone. Upgrading record_macos now means re-applying these changes to the new version.
