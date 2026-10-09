# Field Notes privacy policy

Effective 9 October 2026.

This policy covers the Field Notes app for Android, macOS and Windows, made by Satanshu Mishra. In it, "I" means me, the developer, and "you" means the person using the app.

## In short

- Your journal stays on your device unless you turn on sync.
- With sync on, your entries, moods, photos, voice notes, videos and device names are encrypted on your device before they leave it. Only your own devices hold the keys, so the sync server, and I, cannot read them.
- Field Notes has no ads, no analytics, no crash reporting and no tracking. I do not sell or share your data.

## What stays on your device

Everything you write, record or choose is stored in the app's private storage on your device:

- journal entries, moods, photos, voice notes and videos;
- drafts you have not saved yet;
- your settings, such as reminder time, theme and text size.

The app uses these device features only when you act:

- **Camera**: to record a video entry, take a photo for an entry, or scan a pairing code. Pairing-code frames are not stored.
- **Microphone**: to record a voice note or the sound of a video entry.
- **Photos**: you choose photos with your device's photo picker. The app sees only the photos you pick.
- **Notifications**: for the daily reminder you set and for sync progress. Reminders are scheduled on your device.
- **Spell check**: off by default. When you turn it on, the text you type is checked by your device's own spell checker.

## Sync (optional)

Sync is off until you turn it on. You turn it on by entering a sync server's address with an invite code, or by pairing with another of your devices.

**Who runs the server.** You choose the server. It may be one you run yourself, or one I run at `sync.satanshu.tech` for people I invite. Turning sync on with an invite creates an account on that server.

**What leaves your device.** Your journal entries, moods, photos, voice notes, videos and device names are encrypted on your device (XChaCha20-Poly1305) before upload. The keys are created on your device and shared only between your own devices, sealed to each device's key. The server stores and forwards only the encrypted data.

**What the server can see.** To do its job, a sync server can see:

- a random account ID and random device IDs, and your devices' public keys;
- when your devices connect, how many records and files your journal has, and their approximate sizes;
- the internet address each connection comes from.

**On servers I run** (`sync.satanshu.tech`):

- Each request is logged with its time, route, account ID, device ID, size, result and duration. Request contents, invite codes and tokens are never logged.
- Internet addresses are never logged or stored. A keyed hash of the address is kept in memory to limit abuse and is forgotten 10 minutes after the last request.
- Traffic reaches the server over HTTPS through Cloudflare, which handles the connection. See [Cloudflare's privacy policy](https://www.cloudflare.com/privacypolicy/).
- Encrypted backup copies are kept so a hardware failure does not lose your journal: server snapshots for up to 7 days, and backup snapshots on a private storage device for up to 12 months. Backups hold only encrypted data.

**Recovery phrase.** When you set up sync you get a 12-word recovery phrase. A copy of your journal key, encrypted with that phrase, is stored on the server so you can restore your journal on a new device. Only you hold the phrase. Nobody, including the server's operator, can recover your journal without it.

## Deleting your data

**On one device.** Settings > Data > Delete all erases your entries, moods, photos, recordings and drafts from that device. On Android, uninstalling the app also removes everything it stored. On macOS and Windows, removing the app keeps your journal so a reinstall finds it, so use Delete all first if you want it gone.

**With sync on.** Settings > Data > Delete all offers two choices:

- **Delete journal everywhere** erases your journal and its account on the sync server. Your other devices erase their copy the next time they connect.
- **Remove from this device** erases the journal from this device and removes the device from your journal, while your other devices keep it.

**If you can no longer use the app.** For an account on a server I run, email satanshu.mishra.edu@gmail.com with the name of your journal (the name shown under "Is this your journal?" when a device joins). I will delete the account and everything it stored on the server within 30 days and confirm by email. Encrypted copies in backups expire on their own within 12 months.

For a server you or someone else runs, ask that server's operator.

## Exporting your data

Settings > Data > Export saves a zip file of your journal, its photos and recordings. The zip is not encrypted, so keep it somewhere safe.

## Children

Field Notes is meant for adults and is not directed at children.

## Changes to this policy

If this policy changes, the new version will be posted here with a new effective date. Earlier versions stay visible in this file's history on GitHub.

## Contact

Satanshu Mishra, satanshu.mishra.edu@gmail.com
