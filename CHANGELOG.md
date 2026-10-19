# Changelog

Each release has a section `## [X.Y.Z] - YYYY-MM-DD` with an optional intro paragraph and `### New`, `### Improved` and `### Fixed` lists.

Write the entries in plain English for the people who use Field Notes: say clearly what they will notice, and leave out technical detail such as frame rates, graphics memory figures or the names of the app's internal parts.

## [Unreleased]

## [1.3.1] - 2026-10-18

### Fixed

- On macOS, Field Notes no longer asks to use your keychain every time you open it. After an update it asks once; choose Always Allow and it will not ask again until the next update.
- The first time you open this version on macOS, you may be asked a few times while Field Notes gathers its saved sync keys into one place. Choose Always Allow each time.

## [1.3.0] - 2026-10-18

### New

- Choose which speakers or headphones Field Notes plays through, and set its output volume, in Settings > Voice. On macOS and Windows you can also change the output from the recorder's Input panel.
- In the past-day pop-up on macOS and Windows, voice and video logs now open in the right-hand column. Tap a card to open it paused, or its play button to start playing, then go full screen when you want more room.
- Arrows in the past-day pop-up, and in the day sheet on Android, move to the day before or after without closing it.

### Improved

- Background noise is now removed while you record, so a Voice Isolation recording appears as soon as you keep it, with nothing left to process.
- Voice Isolation now keeps a little of the room under your voice, softens hard "s" sounds, brings quiet and loud recordings to an even level, and keeps loud moments from distorting.
- The input level meter moves with your voice in Settings and in the recorder, including while you record.
- Microphone and input profile choices open as a menu under their row instead of a list that pushes the page down.
- On Android, recordings use a microphone source that skips the phone's own noise reduction and volume adjustment.

### Fixed

- Voice Isolation recordings show their waveform again instead of a flat line, including ones saved before this update.
- The prompt in the past-day pop-up's empty right-hand column is now centred.

## [1.2.0] - 2026-10-15

### New

- On macOS and Windows, you can pause a video recording and carry on where you left off. Keep saves it as one video.
- Choose which microphone Field Notes records from with the new Input button in the voice and video recorders, which also sets the input volume and shows a live level meter. On Android, video recordings use the microphone Android chooses.
- A new Voice page in Settings: Voice Isolation clears background noise like fans, traffic and typing from your voice when you keep a recording of 30 minutes or less, and Studio, the default, keeps your microphone as it is.
- On macOS and Windows, the Input panel shows where sound is playing and opens your computer's sound settings.

### Improved

- On macOS and Windows, the recorder's buttons now sit below the window's title bar, clear of the window's own buttons.

### Fixed

- Turning the camera off before a video recording now turns the camera off and records only your voice. Before, the camera kept recording while hidden.

## [1.1.0] - 2026-10-14

### Improved

- A short countdown before recording starts.
- A new live visualiser while you record.
- Voice waveforms now show the shape of your recording.

### Fixed

- On Windows, Field Notes no longer closes when you switch back to it while reminders are on.
- Settings now use the same background colours as the rest of the app.
- A voice note in a past day keeps playing when you move the pointer away from it.
- The Restarting Field Notes screen no longer shows a yellow underline under its text.

## [1.0.2] - 2026-10-13

### Fixed

- On Windows, Field Notes no longer closes unexpectedly while the Meadow is showing, in onboarding or on the Meadow page.
- On Windows, the Meadow page opens much faster, and changing the time of day or switching to full screen no longer makes it stutter or freeze.
- On Windows, the Meadow animation in onboarding plays smoothly instead of stuttering.

## [1.0.1] - 2026-10-12

### Improved

- Field Notes from Google Play leaves out sync, so it needs no permission to upload in the background. Sync stays in the version from GitHub.

## [1.0.0] - 2026-10-12

### New

- An About page in Settings shows the version of Field Notes you have, who made it and its licence.
- Check for updates from Settings > About, or let Field Notes check once a day by itself. Nothing installs until you choose.
- On macOS and Windows, an update downloads, installs and restarts Field Notes for you, with your journal and any open draft saved first.
- On Android, Field Notes downloads the new APK, checks it and hands it to Android to install. Copies installed from Google Play open Google Play to update.

### Improved

- Settings on macOS and Windows has a new look: a list of sections on the left, with the open section beside it in clear groups and smaller controls.

### Fixed

- The glow around the voice recorder's orb follows your voice as you speak, instead of breathing on a fixed cycle.
- Recording a voice or video note keeps your phone, Mac or Windows PC awake, so the screen timeout or sleep no longer cuts a recording short.
