# Publishing to Google Play

Every `v*` tag builds an Android App Bundle beside the APK. Once Play upload is switched on, the `play` job in `.github/workflows/release.yml` sends that bundle to Google Play after the GitHub release is published.

## Where each tag goes

| Tag | Play track |
|---|---|
| A pre-release tag, such as `v1.2.0-rc.1` | Internal testing |
| A final tag, such as `v1.2.0` | `PLAY_RELEASE_TRACK`, which defaults to `alpha` (closed testing) |

The Play version code is the release workflow's run number, so it always increases. Re-running a run whose upload already succeeded fails at the upload, because Play refuses a version code twice; push a new tag instead.

## Repository settings

Set these under Settings > Secrets and variables > Actions.

| Name | Kind | Value |
|---|---|---|
| `PLAY_SERVICE_ACCOUNT_JSON` | Secret | The whole JSON key file of the service account that uploads to Play |
| `PLAY_UPLOAD` | Variable | `true` to send tags to Play. Anything else, or unset, skips the `play` job |
| `PLAY_RELEASE_TRACK` | Variable | Optional. The track for final tags: `alpha` (default), `beta` or `production` |
| `PLAY_RELEASE_STATUS` | Variable | Optional. `completed` (default) rolls the release out; `draft` leaves it in Play Console for you to roll out |

## One-time setup

1. **Signing.** Play App Signing holds the key that signs what users install. The key in the `ANDROID_KEYSTORE_*` secrets is the upload key that signs what the workflow sends.
2. **First upload by hand.** Google's API cannot make an app's first upload. Download the `android` artifact from a tag's release run, and upload its `.aab` in Play Console under Test and release > Testing > Internal testing > Create new release.
3. **Service account.** In Google Cloud, create a project, enable the Google Play Android Developer API, create a service account with no Cloud roles, and create a JSON key for it. Save the key's contents as the `PLAY_SERVICE_ACCOUNT_JSON` secret, then delete the downloaded file.
4. **Play access.** In Play Console, open Users and permissions, invite the service account's email, and give it these permissions for Field Notes: Release apps to testing tracks; and, once the app has production access, Release to production, exclude devices, and use Play App Signing.
5. **Switch on.** Set `PLAY_UPLOAD` to `true`.

## Going public

New personal developer accounts must run a closed test with at least 12 testers, opted in for 14 days in a row, before they can apply for production access in Play Console. Final tags go to closed testing until then. Once production access is granted, set `PLAY_RELEASE_TRACK` to `production`.
