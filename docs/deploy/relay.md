# Deploying the Field Notes relay

The relay is the small server that stores and forwards your journal's ciphertext between devices. It never sees plaintext. This guide sets it up on the Arch server (10.0.0.189) behind the Cloudflare tunnel, explains the owner's commands, and sets up backups.

Two relays run side by side from the same image:

| Service | Public address | Data folder on the server |
|---|---|---|
| `fn-relay` | `https://sync.satanshu.tech` | `/srv/field-notes-relay/` |
| `fn-relay-test` | `https://sync-test.satanshu.tech` | `/srv/field-notes-relay-test/` |

Each relay keeps its database (`relay.sqlite3`) and its encrypted media (`media/`) inside its data folder. Nothing at run time depends on the Synology being reachable: the NAS only receives the nightly copy.

## 1. Cloudflare

The domain `satanshu.tech` stays registered at Porkbun, and its DNS is on Cloudflare's free plan.

1. In Cloudflare Zero Trust, open Networks, then Tunnels, then the tunnel `penguin`.
2. Under Public hostnames, add two routes:
   - `sync.satanshu.tech` to the service `http://fn-relay:8080`
   - `sync-test.satanshu.tech` to the service `http://fn-relay-test:8080`
3. In the `satanshu.tech` zone, open Security, then WAF, then Custom rules, and create a rule named "Field Notes relay":
   - Expression: `(http.host in {"sync.satanshu.tech" "sync-test.satanshu.tech"})`
   - Action: Skip. Tick only the managed challenge, Browser Integrity Check and Security Level. Leave "All remaining custom rules", "All rate limiting rules" and "All managed rules" unticked, so the rate limit in step 5 and Cloudflare's free managed rules still protect the relay. The exact labels in the form were not re-checked for this guide.
   - The app talks to the relay directly and cannot answer a browser challenge, so a challenge would stop sync. Those three features are the ones that challenge a client; everything else keeps working for the relay hostnames.
4. Keep Bot Fight Mode off for the zone. On the free plan it applies to every request in the zone and cannot be skipped for a hostname or a path, so turning it on would challenge the app's requests and stop sync. (Super Bot Fight Mode, which can be skipped, needs a paid plan.)
5. Open Security, then WAF, then Rate limiting rules, and create one rule named "Field Notes open routes" for the routes that answer without a session:
   - Expression: `(http.host in {"sync.satanshu.tech" "sync-test.satanshu.tech"} and (http.request.uri.path in {"/v1/invites/redeem" "/v1/session/challenge" "/v1/session"} or starts_with(http.request.uri.path, "/v1/restore") or starts_with(http.request.uri.path, "/v1/pairing/")))`
   - Counting: by IP, 30 requests per 10 seconds.
   - Action: Block, for the shortest duration the plan offers.
   - A device signs in with two requests, and a pairing or restore takes a handful plus a status check every few seconds, so a household stays well under the limit; someone guessing invite codes or pairing secrets from one address is blocked once they pass 30 tries in 10 seconds. The free plan allows one rate limiting rule; if its rule builder refuses a field or function in this expression, keep the path conditions and drop the host condition (not re-checked against the free plan's builder).

The relay keeps its own limit on the same routes, so it stays protected even if this rule is missing or changed. Each address may make 60 requests at once on the routes that answer without a session and on the pairing mailbox routes, then 1 per second; anything faster gets 429 `too_many_requests` with a `Retry-After` header holding the seconds to wait. The app waits that long and says "Too many tries. Wait a minute and try again." Signed-in calls are never limited this way. The relay reads the address from the `CF-Connecting-IP` header Cloudflare adds, which it can trust only because it publishes no port and is reached through the tunnel alone. It never logs or stores the address: it keeps a keyed hash of it in memory, and forgets it 10 minutes after the last request.

The tunnel connector already runs as its own compose service in Dokploy's "Field Notes" project. Its definition is recorded in `server/deploy/tunnel.compose.yaml`: image `cloudflare/cloudflared:2026.9.3`, its token read from `/home/satanshumishra/.config/field-notes/cloudflared.token`, running as user 1000 with a read-only root filesystem, no capabilities, `no-new-privileges`, on the `fn-edge` network. Recreate it from that file if it is ever lost.

## 2. The data folders

`root-setup.sh` (section 8, step 3) creates both data folders and their `media/` folders, owned by user 1000, which is the user the relay runs as. Run it before the relays first start, so it can also set up their upload staging folders. If you need the folders before that, create them by hand:

```sh
sudo install -d -o 1000 -g 1000 -m 0750 /srv/field-notes-relay /srv/field-notes-relay-test
```

On this server `/srv` is a btrfs subvolume with copy-on-write turned off, which suits SQLite. The database must never live on a network share: SQLite's locking is not safe over one, and a relay that stores the database there can corrupt it.

Each relay keeps the parts of unfinished uploads in `media/.uploads/`, up to 4 GiB per account. `root-setup.sh` creates that folder as a nested btrfs subvolume, owned by 1000:1000, when the media folder is on btrfs and `.uploads` does not exist yet. A btrfs snapshot of `/srv` does not include nested subvolumes, so the hourly snapshots never hold staged parts: they would otherwise keep up to several GiB of half-uploaded video alive for a day after the uploads finished. The script leaves an existing `.uploads` alone, because its parts belong to uploads the database still lists. To convert one on a relay that has already run, stop that relay, then:

```sh
cd /srv/field-notes-relay/media
sudo mv .uploads .uploads-plain
sudo btrfs subvolume create .uploads
sudo chown 1000:1000 .uploads
sudo chmod 0750 .uploads
sudo cp -a .uploads-plain/. .uploads/
sudo rm -rf .uploads-plain
```

Start the relay again afterwards. Do the same in `/srv/field-notes-relay-test/media` for the test relay.

## 3. Reaching Dokploy

Dokploy answers only on the server itself. Open an SSH tunnel from the Mac and leave it running:

```sh
ssh -N -L 3000:127.0.0.1:3000 satanshumishra@10.0.0.189
```

Then open `http://localhost:3000` in a browser.

## 4. The image

GitHub Actions builds the image (`.github/workflows/relay-image.yml`) on every push to `main` that touches `server/` or `packages/sync_protocol/`, in two jobs:

1. `build` can only read the repository. It checks out without keeping the token, builds with `dart build cli`, starts the image with empty temporary folders and expects `GET /health` to answer 200 (`server/tool/smoke.sh`), then saves the image as a workflow artifact. It writes the build cache only for `main`.
2. `push` runs only for `main`, after `build` succeeds. It is the only job that may write packages or ask GitHub for an identity token. It loads the saved image, signs in to GHCR with the workflow's own token through `docker login --password-stdin`, pushes `ghcr.io/satanshumishra/field-notes-relay:main` and `ghcr.io/satanshumishra/field-notes-relay:sha-<commit>`, then signs the pushed image's digest with cosign, keylessly.

Every action is pinned to a full commit SHA, and both base images in `server/Dockerfile` (`dart:3.13.4` and `debian:trixie-slim`) are pinned by digest, so a moved tag upstream cannot change what is built. Updating one means replacing its SHA or digest in a reviewed change.

### Why the servers run only an image they have verified

A tag such as `:main` is a label, and anyone who can push to the package can move it to another image: a leaked token, a hijacked GitHub session or one mistaken push is enough, and the next deploy would run that image beside your journal's data. A digest (`@sha256:...`) is the image's own fingerprint. It names exactly one image, and nobody can change what it points to.

Keyless signing ties each image to the workflow that built it. When the `push` job signs, GitHub hands it a short-lived identity token, Sigstore issues a certificate for that identity (this repository's `relay-image.yml` running on `refs/heads/main`), and the signature goes into Sigstore's public log and into GHCR beside the image. There is no signing key to steal or lose.

`relay-update.sh` joins the two. It pulls a tag, reads the digest the tag resolved to, and runs `cosign verify` on that digest, accepting only a signature whose certificate GitHub Actions obtained for this repository's image workflow on `main`. Only then does it record the digest, and the servers run that digest and nothing else. An image pushed to GHCR by anyone or anything but this repository's workflow fails verification and never reaches either relay, and because the relays run by digest, moving a tag after the check changes nothing they run.

### First deploy

1. After the first push to `main` has finished, open the package on GitHub (your profile, then Packages, then `field-notes-relay`, then Package settings) and set its visibility to Public if GitHub has not already. The server then pulls it without signing in. The image holds no secrets.
2. On the server, as `satanshumishra`, once `root-setup.sh` has installed cosign and the scripts (section 8):

   ```sh
   /usr/local/lib/field-notes/relay-update.sh
   ```

   It prints a line such as `RELAY_IMAGE=ghcr.io/satanshumishra/field-notes-relay@sha256:...`, saves it in `~/.config/field-notes/relay-image.env` (mode 0600), and lists the next steps. If the pull or the verification fails, it saves nothing, emails an alert naming the step that failed and exits with an error.
3. In Dokploy, open the relay compose app (section 5), then Environment, and set both variables to the printed reference:

   ```
   RELAY_TEST_IMAGE=ghcr.io/satanshumishra/field-notes-relay@sha256:...
   RELAY_IMAGE=ghcr.io/satanshumishra/field-notes-relay@sha256:...
   ```

   The compose file refuses to deploy while either one is missing, so the first deploy needs both. Deploy, then check both relays as section 5 shows.

### Every later update

1. Wait for the workflow run on `main` to finish. It pushes and signs the new image.
2. On the server, as `satanshumishra`, run `/usr/local/lib/field-notes/relay-update.sh`. It verifies the new `:main` and prints its `RELAY_IMAGE=...` line.
3. In Dokploy's Environment for the relay compose app, set `RELAY_TEST_IMAGE` to the printed reference and deploy. Only `fn-relay-test` changes: `fn-relay` still names the same digest, so Compose leaves it running.
4. Check the test relay: `curl -fsS https://sync-test.satanshu.tech/health` prints `ok`. If the change touches sync, sync a device signed in to the test relay too.
5. Set `RELAY_IMAGE` to the same reference and deploy again.

### Rolling back

Every digest `relay-update.sh` has verified is listed in `~/.config/field-notes/relay-image.history`, one line each with the time, the tag or digest asked for, and the `RELAY_IMAGE=` line. To go back:

- to an earlier verified digest, pick its line and run `/usr/local/lib/field-notes/relay-update.sh sha256:<that digest>`;
- to the build of one commit, run `/usr/local/lib/field-notes/relay-update.sh sha-<first 12 characters of the commit>`.

Either way the image is verified again and recorded in `relay-image.env`, which the restore drill and the owner commands use, so they run what the relays run. Then set `RELAY_TEST_IMAGE`, check, and set `RELAY_IMAGE`, exactly as for an update.

## 5. The Dokploy services

1. In Dokploy, open the "Field Notes" project and create a Compose application named `relay`.
2. Paste the contents of `server/compose.yaml` as its compose file, and set `RELAY_TEST_IMAGE` and `RELAY_IMAGE` under Environment as section 4 shows. The compose file names no tag, so it runs nothing until both are set. It defines the two services `fn-relay` and `fn-relay-test`. Each one:
   - runs the verified digest named by `RELAY_IMAGE` (`fn-relay`) or `RELAY_TEST_IMAGE` (`fn-relay-test`), with `pull_policy: missing`, so it pulls that digest only when the server does not have it yet
   - runs as user `1000:1000`
   - has a read-only root filesystem with a temporary in-memory `/tmp`
   - drops every capability and sets `no-new-privileges`
   - bind-mounts its data folder at the same path inside the container and sets `RELAY_DATABASE` and `RELAY_MEDIA_DIR` inside it
   - joins the external attachable overlay network `fn-edge` and publishes no ports, so only the tunnel connector can reach it
   - is limited to 1 GB of memory and 256 processes (`mem_limit`, `pids_limit`), so a flood of requests cannot take the server down with it
   - restarts unless stopped
3. Deploy. At start-up each relay creates or migrates its database. Before applying a migration to a database that already has tables, it writes a copy beside it named `relay.sqlite3.bak-<UTC time>`. If a migration fails, the relay refuses to start.
4. Check both relays from the Mac:

```sh
curl -fsS https://sync.satanshu.tech/health
curl -fsS https://sync-test.satanshu.tech/health
```

Each prints `ok`. The relay answers 503 instead when its database does not answer or its media folder is not writable. It checks both at most once every 5 seconds and answers from that result in between, so a flood of health checks cannot wear the disk.

The relay logs one JSON line per request with only the time, the route pattern, the account and device ids, the byte count, the status and the duration. It never logs bodies, headers, invite codes or tokens. An unexpected error outside a request, such as a download whose file cannot be read, is logged as `{"ts": ..., "event": "internal_error"}` with nothing else, never a message, path or file name.

The relay refuses what would let one account or one bad client exhaust the server:

| Limit | Value | Answer |
|---|---|---|
| Request body on the routes without a session, the pairing mailbox routes and device removal | 64 KiB | 400 |
| Request body for pairing completion and the unused and referenced file reports | 1 MiB | 400 |
| Request body for a records push | 8 MiB | 400 |
| One file | 2 GiB, in at most 256 parts of at most 8 MiB | 400 |
| Unfinished uploads per account | 32 | 507, shown as "your server is full" |
| Staged parts per account | 4 GiB | 507 |
| Free space on the media drive | uploads stop below `RELAY_MIN_FREE_BYTES`, 2 GiB unless set | 507 |
| Live connections per device | 4; a fifth closes the oldest | close code 4002 |
| One live message | 4 KiB | close code 1009 |
| Requests from one address on the routes without a session and the pairing mailbox routes | 60 at once, then 1 per second | 429 with `Retry-After` |

To keep more space free, add `RELAY_MIN_FREE_BYTES` (a byte count) to the service's `environment` in `server/compose.yaml`. The request limit per address comes from `RELAY_RATE_BURST` (requests at once, default 60) and `RELAY_RATE_PER_SECOND` (default 1.0), set the same way.

## 6. The firewall

The server firewall is already in place in `/etc/nftables.conf`, managed from `~/field-notes-firewall/` with its apply, confirm and undo scripts. Containers cannot reach the home network or the tailnet. Nothing in this guide changes it.

## 7. Owner commands

Admin is command-line only; there is no admin web page. Every command runs the relay binary against the relay's own database. While the relay runs, use `docker exec` on its container:

```sh
relay="$(docker ps --quiet --filter label=com.docker.compose.service=fn-relay)"
docker exec "$relay" /app/bin/relay invite create --note "Alex"
```

For the test relay, filter on `fn-relay-test` instead.

| Command | What it does |
|---|---|
| `invite create --note <text>` | Creates a single-use invite valid for 7 days and prints its id, its code and its expiry. Only a hash of the code is stored, so note the code now. |
| `invite list` | Prints each invite's id, note, creation time, expiry and state (open, used, expired or revoked). |
| `invite revoke <invite-id>` | Revokes an unused invite. |
| `account list` | Prints each account's id, note, status, active device count, bytes stored and last-seen time, and nothing else. |
| `account suspend <account-id>` | Refuses every call from the account's devices with "sync suspended" (403). |
| `account resume <account-id>` | Lets a suspended account sync again. |
| `account delete <account-id>` | Erases the account's records, uploads, keys and pairing mailboxes and deletes the account, then moves its files to `media/.trash/` and deletes them there. Its devices are told the journal was erased, and their open connections close within 5 seconds. |
| `snapshot-db --to <file>` | Writes a consistent, checked copy of the database and a manifest beside it. The nightly copy uses it. |
| `verify-copy --db <file> --media <dir> --manifest <file>` | Checks a copy's integrity and that every record and file in its manifest is present. The restore drill uses it. |

`account suspend` and `account delete` reach a running relay within 5 seconds: it closes the account's open connections on its next check.

`mark-restored` gives the relay a new generation and ends every session and upload pass. Run it only after restoring the relay's data from a backup (section 8), and only on the stopped relay, so no device can push to the restored data before it is marked. Never run it with `docker exec`. Run it in a throwaway container on the verified image, with the same bind mount, user and `RELAY_*` settings:

```sh
. /home/satanshumishra/.config/field-notes/relay-image.env
docker run --rm --user 1000:1000 \
  --volume /srv/field-notes-relay:/srv/field-notes-relay \
  --env RELAY_DATABASE=/srv/field-notes-relay/relay.sqlite3 \
  --env RELAY_MEDIA_DIR=/srv/field-notes-relay/media \
  "$RELAY_IMAGE" mark-restored
```

The first line loads the digest `relay-update.sh` verified last. If an update is half done (deployed to the test relay only), finish it or roll it back first, so the throwaway container runs what `fn-relay` runs. Any other command in the table can run the same way when the relay is stopped.

When a journal is erased from the app or with `account delete`, its database rows are deleted first and its media folder is then moved to `media/.trash/<account>-<time>` and deleted in the background. If the relay stops before that finishes, it deletes whatever is left in `media/.trash/` at its next start, together with any media or upload folder no account or upload owns any more.

## 8. Backups

Every copy holds only what the relay holds: ciphertext, opaque keys and public keys. Restoring a journal from a copy still needs that journal's 12-word phrase or one of its devices. Secrets live only in private files under `/home/satanshumishra/.config/field-notes/` on the server, never in the repository or the image.

### What each layer protects against

| Layer | Schedule | Protects against | Does not protect against |
|---|---|---|---|
| btrfs snapshots of `/srv` (snapper config `srv`) | Hourly, keeping 24 hourly and 7 daily | A mistake such as a deleted folder or a bad migration, undone in minutes | Losing the server's drive: the snapshots live on it, so they are not a copy |
| Nightly copy to the NAS (`nightly-copy.sh`) | 01:30, retried once after 10 minutes | Losing the server or its drive | A mistake that is copied over before anyone notices |
| NAS snapshots of both backup folders | Daily at 03:00, each locked for 14 days, keeping 7 daily, 4 weekly and 12 monthly | A mistake or a corruption mirrored to the NAS; deletion through the backup account, which cannot delete snapshots | Losing the NAS and the server together |
| Monthly scrubs (server btrfs and NAS) and `smartd` | Monthly scrubs; `smartd` always | Silent corruption and a failing drive, caught early | Damage that happens between checks |
| Restore drill (`restore-drill.sh`) | 1st of each month at 04:00 | A copy that looks fine but cannot be restored | Anything after the last copy |
| Alert email and Healthchecks.io | On every failure; Healthchecks.io when a check-in is missed | Failures nobody sees, and a dead or powered-off server | |

There is no off-site copy, by the owner's choice. A fire or theft at home can lose media held only by the server and the NAS.

The nightly copy, for the relay and then the test relay:

1. runs `relay snapshot-db` inside the container into `backup/relay-<UTC date>.sqlite3`, using SQLite's `VACUUM INTO` and failing unless `PRAGMA integrity_check` answers `ok`, with a manifest of every record key and file name beside it;
2. keeps the last 7 snapshots in `backup/`;
3. sends `backup/` and `media/` in one rsync command over SSH to `fn-backup@10.0.0.246:/volume1/field-notes-backup/` (the test relay to `/volume1/field-notes-backup-test/`), trying 10.0.0.247 if 10.0.0.246 fails. It mirrors deletions, never copies the live `relay.sqlite3`, `-wal` or `-shm` files or the `.uploads` folder of unfinished uploads, leaves the NAS's own `#snapshot` and `@eaDir` folders alone, and gives up on a connection that stays silent for 10 minutes.

The restore drill pulls the latest copy of `field-notes-backup` from the NAS over SSH into a scratch folder under `/var/tmp/field-notes-drill/`, outside `/srv` so the hourly snapshots never hold a second copy of the media, runs `relay verify-copy`, starts a throwaway relay on the copy with no network but its own, expects `GET /health` to answer 200, and removes everything afterwards. It runs both steps on the image in `~/.config/field-notes/relay-image.env`, the digest `relay-update.sh` verified last (section 4), never on a tag, and fails with an alert when that file is missing or holds no digest. It pulls with `rsync -a --no-links`, so a link planted in a copy on the NAS cannot point the drill at a file outside its scratch folder. The scratch root must be a folder (not a link) owned by `satanshumishra` with mode 0700; `root-setup.sh` creates it that way, and the drill creates it the same way if it has been cleaned away. Any other owner or mode, which would let another account on the server swap files under the drill, makes the drill refuse to run and send an alert.

Both jobs check `rsync --version` first and refuse to run, with an alert, when rsync is older than 3.4.0, the release that fixed the January 2025 rsync security holes. Update rsync with `sudo pacman -Syu rsync` if that alert arrives.

Both jobs report their start, success or failure to Healthchecks.io. On a failure they send one email naming the step that failed, through `alert.sh` and `msmtp`, to satanshumishra@outlook.com.

### How the copies reach the NAS

Both jobs reach the Synology by rsync over SSH as the non-admin account `fn-backup`, so the copy is encrypted on the home network and no password exists to leak. The SSH settings live in `~/.config/field-notes/nas.env` (mode 0600):

| Setting | Default | Meaning |
|---|---|---|
| `NAS_HOSTS` | `10.0.0.246 10.0.0.247` | The NAS's addresses, tried in this order |
| `NAS_SSH_PORT` | `22` | The NAS's rsync SSH encryption port |
| `NAS_USER` | `fn-backup` | The account the copies use |
| `NAS_VOLUME` | `/volume1` | The volume holding both backup folders |
| `NAS_ALLOW_FROM` | `10.0.0.0/24` | The addresses the NAS accepts these keys from |

Each share and direction has its own ed25519 key in `~/.config/field-notes/nas-keys/` (mode 0700, each key 0600), and each key works for exactly one command:

| Key | Used by | Allowed to |
|---|---|---|
| `push-field-notes-backup` | nightly copy | write the relay's copy into `/volume1/field-notes-backup/` |
| `push-field-notes-backup-test` | nightly copy | write the test relay's copy into `/volume1/field-notes-backup-test/` |
| `pull-field-notes-backup` | restore drill | read `/volume1/field-notes-backup/` |
| `pull-field-notes-backup-test` | a drill run with `FN_DRILL_SHARE=field-notes-backup-test` | read `/volume1/field-notes-backup-test/` |

Why one key per command: DSM lets an account like `fn-backup` run only commands that start with `rsync` and contain no `;`, `|` or backtick, but it hands them to `/bin/sh -c`, so `&&` or `$(...)` slips past that check. Each line in `fn-backup`'s `authorized_keys` therefore starts with `restrict,from="10.0.0.0/24",command="<exact rsync server command>"`: the NAS runs that command whatever the client asks for, accepts the key only from the home network, and allows no shell, forwarding or terminal. The pinned command itself starts with `rsync` and avoids those characters, which rules out wrapper scripts such as `rrsync`. A stolen push key can only send into its one folder, which the locked NAS snapshots protect, and a stolen pull key can only read ciphertext.

The commands are worked out, never typed. `nas-ssh-keys.sh authorized` runs the same rsync argument builder the two jobs use (`nas-rsync.sh`) with a stand-in in place of ssh that only records the command rsync would ask the NAS to run, and writes those commands to `~/.config/field-notes/nas-keys/pinned`. Before connecting, both jobs work them out again the same way. If they differ from `pinned`, for example after an rsync upgrade changed its flags, the job connects to nothing and emails an alert telling you to run `nas-ssh-keys.sh authorized` and update `authorized_keys` on the NAS.

The NAS's own host key is pinned in `~/.config/field-notes/nas_known_hosts`, and ssh runs with `StrictHostKeyChecking=yes` and `BatchMode=yes`, so a machine pretending to be the NAS gets no connection and no copy. Remote paths are always absolute (`/volume1/...`): a relative path would land in `fn-backup`'s home folder instead of the backup folder.

### One-time steps on the server

Copy the repository's `server/deploy/` folder to the server (for example by cloning the repository there), then:

1. Create a Gmail account used only for these alerts. Turn on 2-Step Verification, create an app password, and store it without echoing it to the screen. Type the 16 letters without spaces:

   ```sh
   install -d -m 0700 ~/.config/field-notes
   (umask 077; read -rs -p 'Gmail app password: ' secret; printf '%s\n' "$secret" > ~/.config/field-notes/gmail.pass; unset secret; echo)
   ```

2. In Healthchecks.io, create two checks with cron schedules in the server's time zone, and copy their ping URLs:
   - "Field Notes nightly copy": `30 1 * * *`, grace time 1 hour
   - "Field Notes restore drill": `0 4 1 * *`, grace time 6 hours

   Store the URLs in a private file:

   ```sh
   (umask 077; printf 'FN_NIGHTLY_PING_URL=%s\nFN_DRILL_PING_URL=%s\n' 'https://hc-ping.com/<nightly-uuid>' 'https://hc-ping.com/<drill-uuid>' > ~/.config/field-notes/heartbeat.env)
   ```

3. Read `root-setup.sh`, then run it once with sudo, giving it the alert Gmail address:

   ```sh
   sudo ./root-setup.sh field.notes.alerts@gmail.com
   ```

   It installs `msmtp` and `msmtp-mta` (and `smartmontools`, `snapper`, `btrfs-progs`, `openssh` and `rsync` only if they are missing), and `cosign` with `pacman -S --needed --noconfirm cosign` for `relay-update.sh`. It creates the relay data folders and their `.uploads` subvolumes as section 2 describes, and the restore drill's scratch root `/var/tmp/field-notes-drill/` owned by `satanshumishra` with mode 0700. It installs `nightly-copy.sh`, `restore-drill.sh`, `alert.sh`, `nas-ssh-keys.sh`, `relay-update.sh` and the shared `nas-rsync.sh` to `/usr/local/lib/field-notes/`, owned by root and read-only, because root's scrub and `smartd` hooks run `alert.sh` and must never run a file your account can change. It writes `/etc/msmtprc` for the Gmail account (smtp.gmail.com, port 465, TLS, reading the password from `gmail.pass`). It creates the snapper config `srv` for `/srv` with 24 hourly and 7 daily snapshots and nothing longer, and makes sure `snapper-timeline.timer` and `snapper-cleanup.timer` are enabled. It enables the monthly `btrfs-scrub@-.timer` with a hook that emails when the scrub reports errors, configures `smartd` to watch `/dev/nvme0` and email through `alert.sh`, and turns on lingering for `satanshumishra`. It touches no firewall, network or Docker setting, and running it again changes nothing that is already in place.

4. As `satanshumishra`, install and start the two timers:

   ```sh
   ./install-user-timers.sh
   ```

   It installs `fn-nightly-copy.timer` (01:30 daily) and `fn-restore-drill.timer` (04:00 on the 1st) as user units that run the installed scripts. Your account is in the `docker` group, so the scripts need no sudo.

5. If an older setup left `~/.config/field-notes/nas-rsync.pass` behind, delete it: nothing reads it any more.

### Connecting the server to the NAS over SSH

Update the NAS to DSM 7.3.2 or later first. DSM ships its own rsync (3.1.2 on DSM 7.2), and Synology fixes CVE-2024-12085, an rsync flaw that lets the other end of a connection read leftover memory from the rsync process, only from DSM 7.3.2. The server side refuses rsync older than 3.4.0 for the same family of flaws.

On the server, as `satanshumishra`:

1. Write the NAS settings (change a value only if your NAS differs):

   ```sh
   (umask 077; printf '%s\n' 'NAS_HOSTS="10.0.0.246 10.0.0.247"' 'NAS_SSH_PORT=22' 'NAS_USER=fn-backup' 'NAS_VOLUME=/volume1' 'NAS_ALLOW_FROM=10.0.0.0/24' > ~/.config/field-notes/nas.env)
   ```

2. Create the four keys. Running it again keeps existing keys and never overwrites one:

   ```sh
   /usr/local/lib/field-notes/nas-ssh-keys.sh keys
   ```

3. Print the four `authorized_keys` lines into a file, which also records the pinned commands:

   ```sh
   /usr/local/lib/field-notes/nas-ssh-keys.sh authorized > ~/fn-backup.authorized_keys
   ```

   The lines hold only public keys.

On the NAS, in DSM as an administrator:

4. In Control Panel, File Services, rsync, turn on the rsync service and keep its SSH encryption port at 22 (or set `NAS_SSH_PORT` to the port shown there). This port is the only way an account like `fn-backup` may run rsync over SSH.
5. Keep "Enable rsync account" off. It only serves the rsync daemon, which these jobs no longer use; if an older setup turned it on, turn it off.
6. In Control Panel, Application Privileges, give `fn-backup` the rsync privilege. In Shared Folder, check that `fn-backup` has Read/Write on `field-notes-backup` and `field-notes-backup-test` and no access to anything else.
7. In Control Panel, User & Group, Advanced, turn on the user home service. The key file lives in `fn-backup`'s home, `/var/services/homes/fn-backup/.ssh/authorized_keys`, and SSH reads it only while homes exist.
8. Read the NAS's host key, which DSM shows on no screen. In Control Panel, Task Scheduler, create a scheduled task with a user-defined script, run as `root`, with its output sent by email or saved to a folder, and this script:

   ```sh
   for f in /etc/ssh/ssh_host_*_key.pub; do ssh-keygen -l -f "$f"; cat "$f"; done
   ```

   Run it once, save its whole output as a text file, copy that file to the server as `~/nas-host-keys.txt`, and delete the task.
9. Install the keys from a temporary administrator SSH session. In Control Panel, Terminal & SNMP, turn on the SSH service. From the server, copy the file over and sign in with your DSM administrator account; when ssh asks whether to trust the NAS, compare the ED25519 fingerprint it shows with the one in `~/nas-host-keys.txt` first:

   ```sh
   ssh <admin>@10.0.0.246 'cat > /tmp/fn-backup.authorized_keys' < ~/fn-backup.authorized_keys
   ssh <admin>@10.0.0.246
   ```

   Then, on the NAS:

   ```sh
   sudo mkdir -p /var/services/homes/fn-backup/.ssh
   sudo cp /tmp/fn-backup.authorized_keys /var/services/homes/fn-backup/.ssh/authorized_keys
   sudo chown -R fn-backup:users /var/services/homes/fn-backup/.ssh
   sudo chmod 700 /var/services/homes/fn-backup/.ssh
   sudo chmod 600 /var/services/homes/fn-backup/.ssh/authorized_keys
   sudo chmod go-w /var/services/homes/fn-backup
   rm /tmp/fn-backup.authorized_keys
   exit
   ```

   SSH ignores a key file whose folder or home others can write to, hence the last `chmod`. Turn the SSH service in Terminal & SNMP off again afterwards; `fn-backup` keeps reaching rsync through the rsync service's port.

Back on the server, as `satanshumishra`:

10. Pin the NAS's host key:

    ```sh
    /usr/local/lib/field-notes/nas-ssh-keys.sh pin-host ~/nas-host-keys.txt
    ```

    It prints the key's fingerprint. Compare it with the ED25519 line in `~/nas-host-keys.txt`; if they differ, delete `~/.config/field-notes/nas_known_hosts` and stop. It writes `nas_known_hosts` for every address in `NAS_HOSTS` with the configured port.
11. Run each job once by hand and read its log. The drill needs a copy on the NAS and the verified image from section 4:

    ```sh
    systemctl --user start fn-nightly-copy.service
    journalctl --user -u fn-nightly-copy.service -n 30 --no-pager
    systemctl --user start fn-restore-drill.service
    journalctl --user -u fn-restore-drill.service -n 30 --no-pager
    ```

12. Delete `~/fn-backup.authorized_keys` and `~/nas-host-keys.txt`.

When the pinned-command alert arrives after an rsync update, run step 3 again and repeat step 9 with the new file.

### NAS settings

On the Synology DS923+ ("Pulsar"):

1. In Snapshot Replication, for each of `field-notes-backup` and `field-notes-backup-test`:
   - schedule a snapshot daily at 03:00, after the nightly copy has finished;
   - lock each snapshot against deletion for 14 days (DSM calls these immutable snapshots);
   - set retention to keep 7 daily, 4 weekly and 12 monthly snapshots.
2. In Storage Manager, schedule a monthly data scrub, and check that the RAID 10 pool offers data scrubbing.
3. In Control Panel, Notification, Email, turn on email notifications through the same Gmail account (smtp.gmail.com, port 465, SSL, with its app password) to satanshumishra@outlook.com, and keep the disk and RAID events selected.

The `fn-backup` account writes only to the two backup folders and cannot delete snapshots.

### Restoring the relay by hand

1. Stop the relay (in Dokploy, or `docker stop` on its container).
2. Bring back its data, either way:
   - From a server snapshot: list them with `sudo snapper -c srv list`, then copy the relay's folder back from `/srv/.snapshots/<number>/snapshot/field-notes-relay/`.
   - From the NAS: pull the copy with the drill's own key and options, which are the only ones its pinned command accepts:

     ```sh
     cfg=/home/satanshumishra/.config/field-notes
     install -d -m 0700 /var/tmp/field-notes-drill/restore
     rsync -a --no-links --timeout=600 --exclude='#snapshot/' --exclude='@eaDir/' \
       -e "ssh -p 22 -i $cfg/nas-keys/pull-field-notes-backup -o IdentitiesOnly=yes -o BatchMode=yes -o StrictHostKeyChecking=yes -o UserKnownHostsFile=$cfg/nas_known_hosts -o ConnectTimeout=30" \
       fn-backup@10.0.0.246:/volume1/field-notes-backup/ /var/tmp/field-notes-drill/restore/
     ```

     Then copy the chosen `backup/relay-<date>.sqlite3` to `/srv/field-notes-relay/relay.sqlite3`, delete any `relay.sqlite3-wal` and `relay.sqlite3-shm` files beside it, copy the `media/` folder back, and delete the `restore` folder. For the test relay use the `pull-field-notes-backup-test` key and `/volume1/field-notes-backup-test/`.
3. Run `mark-restored` with `docker run --rm` exactly as section 7 shows, while the relay is still stopped.
4. Start the relay. Every device sees the new generation, signs in again and offers again everything the restore lost.

A snapshot of `/srv` does not hold `media/.uploads/`, so after a restore that folder still holds today's staged parts. When the relay starts, it deletes the staged parts of uploads the restored database does not list; the rest expire within 7 days. Devices start their unfinished uploads again after the mark.

Never skip the mark. Without it, a device notices the restore only while its saved position is above the relay's latest sequence number, and the first device to offer its records again lifts that number past the other devices' positions, so they stop noticing and their lost changes stay lost.

A restore also loses device changes made after the backup:

- A device paired since the backup can no longer sign in and shows "This device was removed from your journal". Pair it again.
- A device removed since the backup is active again until the device that removed it next syncs and sends the removal again. Check the device list in Settings and remove it again, especially if the device that removed it is gone.

### Moving the relay to a new address

1. Make a consistent copy on the old relay while it keeps running:

   ```sh
   docker exec "$relay" /app/bin/relay snapshot-db --to /srv/field-notes-relay/backup/move.sqlite3
   ```

2. Copy `move.sqlite3` to the new server's data folder as `relay.sqlite3`, and copy the `media/` folder without `media/.uploads/`.
3. Start the new relay and check that `GET /health` answers 200 at its address.
4. On one device, open Settings and use "Change" next to the server address. The other devices switch by themselves on their next sync.

Devices offer their records to the new relay again by themselves, so changes the old relay accepted after the copy are not lost. Retire the old relay once `account list` on the new relay shows every device seen after the change.

### Checking it after deploy

These run only on the server, the NAS and the email accounts, so they are confirmed by hand after deploying:

- `systemctl --user list-timers 'fn-*'` lists both timers, and `sudo snapper -c srv list` shows hourly snapshots.
- `sudo systemctl list-timers 'btrfs-scrub*'` and `systemctl status smartd` show the scrub timer and `smartd` running.
- A test alert arrives: `/usr/local/lib/field-notes/alert.sh "test alert" "Checking that alert email arrives."`
- A forced failure alerts and reports to Healthchecks.io: `FN_NAS_HOSTS=192.0.2.1 FN_RETRY_DELAY=5 /usr/local/lib/field-notes/nightly-copy.sh` sends one email naming the failed copy, and the nightly check turns red.
- `fn-backup`'s keys do nothing else: `ssh -p 22 -i ~/.config/field-notes/nas-keys/push-field-notes-backup -o IdentitiesOnly=yes fn-backup@10.0.0.246 'ls /'` gives no listing, because the NAS runs the pinned rsync command instead.
- A real nightly copy and restore drill succeed: `systemctl --user start fn-nightly-copy.service`, then `systemctl --user start fn-restore-drill.service`.
- On the NAS, a locked snapshot cannot be deleted, and Healthchecks.io emails when a check-in is missed.
