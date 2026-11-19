# Field Notes

A private journal for Mac, Windows and Android where each day holds logs of text, voice, video and photos.

## Opening

**Opening**:
The short drawing played once over the app when it starts fresh: one pen inks a planted peony, then three curls of wind blow it away to reveal Today.
_Avoid_: Splash, intro, launch animation, launch screen

## Capture

**Log**:
One journal item on a day: a note, a voice recording, a video or a photo.
_Avoid_: Entry (in user-facing words), post, item

**Take**:
One recording in progress, from the first press of record until it is kept or discarded.
_Avoid_: Session, clip

**Recorder chrome**:
The words and controls of the video recorder that fade away a few seconds into a take and come back on any input.
_Avoid_: Overlay, HUD, controls layer

**Picture fill**:
The dim, heavily blurred live copy of the picture that fills the space around the whole picture, behind the recorded frame in the video recorder and behind the playing video in every video player.
_Avoid_: Letterbox, bands, background, glow, ambient

**Microphone panel**:
The drop-down from a recorder's microphone button that chooses the input and shows the level the recorder hears.
_Avoid_: Mic dropdown, input menu

**Full-window route**:
A surface that covers the whole window over a backdrop that does nothing when clicked: the voice and video recorders, the note composer, the full view and the photo viewer.
_Avoid_: Modal, dialog (for these)

**Keep**:
The act that saves a take as a log.
_Avoid_: Save, finish

**Hearing**:
Whether an open recorder is receiving sound from the microphone: opening, hearing, can't hear (nothing arrives, or only digital silence) or lost (sound stopped mid-take and is being reopened). A take cannot start while the recorder can't hear.
_Avoid_: Mic status, signal

**Input profile**:
How the microphone is treated while recording: Voice Isolation or Studio.
_Avoid_: Mode, preset

**Voice Isolation**:
The input profile that removes background noise and shapes the voice to sound natural.
_Avoid_: Noise cancellation, denoise mode

**Studio**:
The input profile that records the microphone as it is, with only the input volume applied.
_Avoid_: Raw mode

**Attenuation limit**:
How far Voice Isolation lowers the room's sound, in decibels, so that pauses keep a little of the room instead of going silent.
_Avoid_: Noise floor, strength

## Listening

**Output device**:
The speaker or headphones the app plays through, chosen in Settings or left as the system output.
_Avoid_: Speaker (for the setting), sink

**Output volume**:
The level of everything the app plays, under the system volume.
_Avoid_: Playback gain

**Waveform**:
The bars drawn from a saved voice log's stored levels, each as tall as the sound was loud against the loudest moment of that log.
_Avoid_: Visualiser, spectrum, level meter (the recorders' live meters are separate)

**Full view**:
The full-window view of one log, opened from a card or the day pop-up, with its own transport and previous and next arrows.
_Avoid_: Log viewer (to people), lightbox

**Shade**:
The soft black gradient, eased at both ends, behind the controls over a video, the same in light and dark and fading with the controls.
_Avoid_: Scrim (for this), fade band, overlay

**Play mark**:
The circle that swells and fades in the centre of a video after a click, showing the new play state.
_Avoid_: Flash, toast

## Days

**Day pop-up**:
The window on Mac and Windows that shows one day's logs in a left column and the chosen log in a right column.
_Avoid_: Day modal, day dialog

**Day sheet**:
The phone form of the day pop-up, a single column sliding up from the bottom.
_Avoid_: Bottom sheet (for this view)

## Meadow

**Heaviest stretch**:
The 16-day window of a year, holding at least 6 days with a mood, whose average mood is the lowest of the year; it counts only when that average is below zero.
_Avoid_: hard stretch, heaviest window

**Brightest stretch**:
The 16-day window of a year, holding at least 6 days with a mood, whose average mood is the highest of the year; it counts only when that average is above zero.
_Avoid_: bright window

**Mist**:
The low fog the Meadow lays over the heaviest stretch's flowers, lying around their stems with the blooms rising out of it.
_Avoid_: fog pocket, hollow fog

## Accessibility

**Sweep**:
The committed run that checks every main-path state of the app, on each platform and theme, against the UI standard's rules.
_Avoid_: audit run, a11y pass

**Baseline line**:
One finding the sweep still reports, kept in the baseline for its area, platform and theme together with the written reason it remains.
_Avoid_: known issue, allowlist entry

**Open line**:
A baseline line whose reason says it is still to be fixed.
_Avoid_: todo line

**Accepted deviation**:
A place where Field Notes knowingly departs from a platform rule, recorded with the reason, such as the phone bottom bar's centre capture button.
_Avoid_: exception, waiver

**Destructive look**:
The one appearance of an action that deletes or discards: danger ink without a fill, never the default action.
_Avoid_: red button, danger fill
