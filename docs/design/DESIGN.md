# Field Notes design rules

These rules pick the container for every screen. They apply to every later sweep of the app, so that no surface is flattened into one small sheet again.

## Platform first

Design each platform for how it is held and used. The phone is held in one or two hands and reached with a thumb; macOS is a window driven by a pointer and a keyboard. Content, copy, data, tokens, the paper, ink and flower visual language and the shared glass (lib/design/glass/glass_surface.dart) stay shared between the two. The layout does not: never shrink the macOS layout onto the phone, and never stretch the phone layout onto macOS.

## Choosing a surface

Pick the container from the task and the content, never from a platform rule. Ask three questions, in this order.

1. What is the user here to do: decide quickly, read, watch, listen, scan, type or browse?
2. What does the content need: its natural size and shape, such as a 3-line note, a 2,000-word note, a portrait video, or a QR code that must fit a camera?
3. Does the screen behind still matter? If yes, keep it visible. If no, take the space.

Using the same container everywhere is false consistency. Real consistency is the same reasoning giving the right container each time.

| Surface | When | Phone | macOS |
| --- | --- | --- | --- |
| Small sheet or popover | Quick decisions where the context behind still matters: confirms, pickers, single-field edits, the capture chooser | Bottom sheet with a grabber and actions in a footer row | Anchored popover or small centred dialog |
| Content-sized sheet or panel | Reading content of varying length: notes, a day's logs | Sheet sized to the content that grows to near full height and drags to full | Large centred reading panel or side-by-side detail |
| Full-screen view | The task is the media or the camera: video, photo, voice, scanning, showing a code | The whole screen with glass controls in the thumb zone | The whole window below the title bar, with Space, Left, Right and Esc |
| Full-screen task | Two-handed or keyboard work: writing, recording, typing a code or phrase, multi-field setup | Full screen with the keyboard in mind | Full window or large panel |

## Hard rules

- One-handed reach comes from where the controls sit, not from how small the surface is.
- Media is never a card inside a sheet.
- Show what the task needs and nothing else. Date and mood are one quiet line, and actions sit on glass controls.
- Content fills the space it is given. Width is limited only for reading comfort, at about 68 characters.
- Primary actions stay solid rose #B8566A. Glass is only for controls floating over a scene.
- On the phone, primary controls sit in the bottom third, about 70 to 150 points above the bottom edge, never in the far corners and never against the gesture bar. Layouts respect the status bar and gesture bar insets.
- The smallest hit target is 48 dp on Android, 40 px on Windows, and on macOS 32 points for an icon and 36 for a button.
- Anything with its own drag behaviour (waveforms, scrubbers, sliders, text fields) never also triggers page swipes.
- Each log type has its own viewer. A note opens in a content-sized sheet or panel. A photo, a video and a voice log open in a full-screen view. There is no transcript.

## Dark glass

Over media and the camera, use GlassTone.media with these values. The voice and video recorders are one exception: by decision they keep the scene glass until the owner settles whether they move to media glass. Viewer controls are the other: see Viewer controls below.

- Fill rgba(28,22,16,.38).
- Blur 18 with saturation 1.5.
- A 1-point border rgba(255,250,240,.22).
- Inner top highlight rgba(255,255,255,.16).
- Drop shadow 0 10 24 -12 rgba(0,0,0,.55).
- Light text #F3E6D1.

On the phone, every dark full-screen surface asks for light status bar icons.

## Viewer controls

The controls of the voice and video viewers take the theme's own colours: the top bar, the edge arrows, the transport, the speed menu and the time preview. This replaces dark glass over media for viewer controls only. Everything else over media and the camera keeps the dark glass above, and photo viewing does not change.

- In Dark the controls fade into rgba(28,25,25).
- In Light they fade into paper, rgba(251,243,228), with dark ink on top.
- Colours come from the media tokens on FieldNotesColors, never from values written in a feature.

## Tilt

Things you collect tilt. Things you read closely or could regret stay straight.

- Tilted: feed cards, the chooser's scraps, tape.
- Straight: confirmations, the editor, players, day sheets, search results.
- A card's tilt comes from the log, so it stays put.
- Tilt switches off when someone enlarges their text.

## One focus rule

Tab into a control and it gets one ring. Click, tap or type and it gets none. This holds for every control, including a button that takes focus by itself when a dialog opens.

## Confirmations

Every confirmation is one component, a straight sticker dialog on desktop and a sheet on the phone. Only the words change.

- The safe button always says what stays, such as Keep going, Keep it or Keep my journal.
- The safe button takes focus, so Enter is harmless, and it shows a ring only after Tab.
- Escape or tapping outside means safe.
- Button order follows the platform: on macOS safe then action, on Windows action then safe, and on Android a sheet with action above safe.

## Where the surfaces sit

- Log viewers: voice and video are full-screen views, a photo opened from a note is a full-screen view, and a note is a content-sized sheet or panel.
- Join my journal: on the phone the camera is a full-screen view and typing the code is a full page. On macOS it is one window with scanning and typing side by side.
- Add a device: a full page on the phone and a large panel on macOS.
- Start syncing and restore: a full page on the phone and a dialog on macOS.
- The small steps that stay small: join confirmations, change server address, battery, delete journal, confirms and pickers.
- Settings: on the phone a section list, then a page per section. On macOS, rows fill the window.
- Day detail: a content-sized sheet on the phone and a two-pane panel on macOS.
