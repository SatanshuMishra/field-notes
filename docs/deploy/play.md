# Publishing to Google Play

Every `v*` tag builds an Android App Bundle beside the APK. Once Play upload is switched on, the `play` job in `.github/workflows/release.yml` sends that bundle to Google Play after the GitHub release is published.

## Where each tag goes

| Tag | Play track |
|---|---|
| A pre-release tag, such as `v1.2.0-rc.1` | Internal testing |
| A final tag, such as `v1.2.0` | `PLAY_RELEASE_TRACK`, which defaults to `alpha` (closed testing) |

The Play version code is the release workflow's run number, so it always increases. Uploads run one at a time, and only one more can wait: a third tag pushed meanwhile cancels the waiting upload, and waiting uploads can start out of version order, so push release tags one at a time. Recover a cancelled upload the same way as a failed one.

## When an upload fails

Open the failed run and choose **Re-run failed jobs**. Re-running all jobs fails at the GitHub release step, because that release already exists, so the upload never runs again. Re-running a run whose upload already succeeded also fails, because Play refuses a version code twice; push a new tag instead.

## Repository settings

Set these under Settings > Secrets and variables > Actions, except the secret, which belongs to the `google-play` environment.

| Name | Kind | Value |
|---|---|---|
| `PLAY_SERVICE_ACCOUNT_JSON` | Secret in the `google-play` environment | The whole JSON key file of the service account that uploads to Play |
| `PLAY_UPLOAD` | Repository variable | `true` to send tags to Play. Anything else, or unset, skips the `play` job. It must be a repository variable: GitHub decides whether to run the job before it loads the environment |
| `PLAY_RELEASE_TRACK` | Variable | Optional. The track for final tags: `alpha` (default), `beta` or `production` |
| `PLAY_RELEASE_STATUS` | Variable | Optional. `completed` (default) rolls the release out; `draft` leaves it in Play Console for you to roll out |

## One-time setup

1. **Signing.** Play App Signing holds the key that signs what users install from Play, and the key in the `ANDROID_KEYSTORE_*` secrets becomes the upload key that signs what the workflow sends. Field Notes uses a key Google generates. The APK on GitHub releases is signed with the upload key instead, so a Play install and a GitHub install of Field Notes cannot update each other: someone moving from the GitHub APK to Play has to uninstall first, which deletes the journal on that phone unless it is synced or exported. Uploading the release key as the app signing key would keep the two compatible; the choice is made once, in step 3, and cannot be changed back.
2. **Environment.** Under Settings > Environments, create `google-play`. Under Deployment branches and tags, choose Selected branches and tags and add the tag rule `v*`, so only version tags can read its secret.
3. **First upload by hand.** Google's API cannot make an app's first upload. Download the `android` artifact from a tag's release run. In Play Console, open Test and release > Testing > Internal testing > Create new release. When it asks for the app signing key, keep the Google-generated key (see step 1). Upload the `.aab`, save, and start the rollout to internal testing. Until that first release is rolled out, Google accepts only draft uploads, so set `PLAY_RELEASE_STATUS` to `draft` if you switch uploads on before then.
4. **Service account.** In Google Cloud, create a project, enable the Google Play Android Developer API, create a service account with no Cloud roles, and create a JSON key for it. Save the key's contents as the `PLAY_SERVICE_ACCOUNT_JSON` secret of the `google-play` environment, then delete the downloaded file.
5. **Play access.** In Play Console, open Users and permissions, invite the service account's email, and give it these permissions for Field Notes: Release apps to testing tracks; and, once the app has production access, Release to production, exclude devices, and use Play App Signing.
6. **Switch on.** Set `PLAY_UPLOAD` to `true`.

## What Play builds leave out

Google Play restricts permissions that the app used before it was published there, so the Android app no longer asks for them:

| Permission | Effect |
|---|---|
| Exact alarms | The daily reminder arrives within about an hour after the chosen time on Android 14 and later |
| Ignoring battery optimisation | The battery prompt for background uploads opens Samsung's Never sleeping apps list on Samsung phones and the app's system settings page elsewhere, where the user sets battery use to Unrestricted |
| Reading photos and videos | Photos come through Android's photo picker, which needs no permission |

## Going public

New personal developer accounts must run a closed test with at least 12 testers, opted in for 14 days in a row, before they can apply for production access in Play Console. Final tags go to closed testing until then. Once production access is granted, set `PLAY_RELEASE_TRACK` to `production`.
