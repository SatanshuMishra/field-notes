# Changelog

Each release has a section `## [X.Y.Z] - YYYY-MM-DD` with an optional intro paragraph and `### New`, `### Improved` and `### Fixed` lists.

Write the entries in plain English for the people who use Field Notes: say clearly what they will notice, and leave out technical detail such as frame rates, graphics memory figures or the names of the app's internal parts.

## [Unreleased]

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
