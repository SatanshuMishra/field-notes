# Update signing key

Every tagged release signs its update files with one Ed25519 key. The release job signs `SHA256SUMS.txt` into `SHA256SUMS.txt.sig` and signs the macOS disk image for `appcast.xml`. Field Notes on Windows and Android installs a download only when `SHA256SUMS.txt` carries a valid signature from the public key built into the app, and Field Notes on macOS installs only a disk image whose appcast signature Sparkle verifies with the same key.

The private key is the `UPDATE_SIGNING_KEY` repository secret. The public key is the `UPDATE_PUBLIC_KEY` repository variable. A tag build fails when either is missing or when they do not belong together.

## Create the key once

Do this once, on your own machine, in a folder outside the repository. It needs OpenSSL 3; the `openssl` that ships with macOS is LibreSSL and cannot do it, so use Homebrew's (`brew install openssl@3`, then `/opt/homebrew/opt/openssl@3/bin/openssl`).

1. Create the private key:

   ```sh
   openssl genpkey -algorithm ed25519 -out field-notes-update.pem
   ```

2. Derive the public key, the base64 of its 32 raw bytes:

   ```sh
   openssl pkey -in field-notes-update.pem -pubout -outform DER | tail -c 32 | base64
   ```

3. In the repository on GitHub, open Settings > Secrets and variables > Actions.
   - On the Secrets tab, add a repository secret named `UPDATE_SIGNING_KEY` and paste the whole content of `field-notes-update.pem`, including its `BEGIN PRIVATE KEY` and `END PRIVATE KEY` lines.
   - On the Variables tab, add a repository variable named `UPDATE_PUBLIC_KEY` and paste the one line that step 2 printed.

4. Keep `field-notes-update.pem` offline: on an encrypted drive or in a password manager, with a backup. Never commit it, never paste it anywhere but the secret, and delete any other copy.

## What the release does with it

Each tag build passes `UPDATE_PUBLIC_KEY` into every build with `--dart-define=FIELD_NOTES_UPDATE_PUBLIC_KEY=...`, and the macOS build also receives it as the `FIELD_NOTES_UPDATE_PUBLIC_KEY` build setting, which becomes Sparkle's `SUPublicEDKey`. The release job reads the secret only from its step environment, writes it to a temporary file only the runner user can read, checks that its public half matches `UPDATE_PUBLIC_KEY`, signs with `tool/release/sign_update.sh`, writes `appcast.xml` with `tool/release/macos/make_appcast.sh`, and deletes the file when the step ends. Local and debug builds carry no key, so they never install an update and offer the download page instead.

## Never change the key

The key is built into every installed copy. A copy trusts only the key it was built with, so a release signed by a different key is refused everywhere: on macOS, Sparkle rejects the update; on Windows and Android, the signature check fails.

Changing the key therefore means every Mac user has to download and reinstall Field Notes once by hand, and every Windows and Android user installed from GitHub has to do the same, before updates work again. Losing the private key has the same effect, and leaking it lets anyone who has it sign files your users would install. Back it up, keep it offline, and keep it.
