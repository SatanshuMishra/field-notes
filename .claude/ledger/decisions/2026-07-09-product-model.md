Status: accepted
Date: 2026-07-09
Thread: journal-app-design

## Context
Defining the core product model and daily rhythm.

## Decision
- Data: a Day has 1+ Entries (voice/video/text). Photos ("memories") attach to an entry for context; each Day also has a pooled Memories gallery browsable independently (tap a photo jumps to its parent entry).
- Mood: one flower per day, optional. 10 moods to flowers: Peony=Happy, Rose=Loved, Sunflower=Warm, Lavender=Calm, Bleeding Heart=Sad, Red Spider Lily=Angry, Aster=Anxious, Daffodil=Hopeful, Poppy=Tired, Chrysanthemum=Grateful.
- Streak: any entry OR photo that day keeps it; day boundary at local midnight; a miss resets.
- Reminders: one daily local notification at a user-set time, both devices, auto-suppressed once logged today.
- Navigation (from prototype): Today, Garden (calendar + ambient meadow), plus Capture, Explore, Settings.

## Consequences
- Mood list confirmed at 10 (the Directions doc's "7 moods" is outdated).
- Navigation grew from 4 agreed sections to the prototype's 5 (reconciliation point #4).
