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
   - Action: Skip, and tick every security feature the form offers to skip (the remaining custom rules, Security Level, Browser Integrity Check and any challenge features listed).
   - The app talks to the relay directly and cannot answer a browser challenge, so a challenge would stop sync.
4. If Bot Fight Mode is turned on for the zone, turn it off. Cloudflare's documentation says a Skip rule cannot exempt hostnames from Bot Fight Mode (not re-checked for this guide).

The tunnel connector already runs as its own compose service in Dokploy's "Field Notes" project. Its definition is recorded in `server/deploy/tunnel.compose.yaml`: image `cloudflare/cloudflared:2026.9.3`, its token read from `/home/satanshumishra/.config/field-notes/cloudflared.token`, running as user 1000 with a read-only root filesystem, no capabilities, `no-new-privileges`, on the `fn-edge` network. Recreate it from that file if it is ever lost.

## 2. The data folders

Create both folders, owned by user 1000, which is the user the relay runs as:

```sh
sudo install -d -o 1000 -g 1000 -m 0750 /srv/field-notes-relay /srv/field-notes-relay-test
```

On this server `/srv` is a btrfs subvolume with copy-on-write turned off, which suits SQLite. The database must never live on a network share: SQLite's locking is not safe over one, and a relay that stores the database there can corrupt it.

## 3. Reaching Dokploy

Dokploy answers only on the server itself. Open an SSH tunnel from the Mac and leave it running:

```sh
ssh -N -L 3000:127.0.0.1:3000 satanshumishra@10.0.0.189
```

Then open `http://localhost:3000` in a browser.

## 4. The image

GitHub Actions builds the image (`.github/workflows/relay-image.yml`) on every push to `main` that touches `server/` or `packages/sync_protocol/`. It builds with `dart build cli`, starts the image with empty temporary folders and expects `GET /health` to answer 200 (`server/tool/smoke.sh`), and only then pushes:

- `ghcr.io/satanshumishra/field-notes-relay:main`, which the servers run
- `ghcr.io/satanshumishra/field-notes-relay:sha-<commit>`, kept for rolling back

After the first push, open the package on GitHub (your profile, then Packages, then `field-notes-relay`, then Package settings) and set its visibility to Public if GitHub has not already. The server then pulls it without signing in. The image holds no secrets.

## 5. The Dokploy services

1. In Dokploy, open the "Field Notes" project and create a Compose application named `relay`.
2. Paste the contents of `server/compose.yaml` as its compose file. It defines the two services `fn-relay` and `fn-relay-test`. Each one:
   - runs the GHCR image as user `1000:1000`
   - has a read-only root filesystem with a temporary in-memory `/tmp`
   - drops every capability and sets `no-new-privileges`
   - bind-mounts its data folder at the same path inside the container and sets `RELAY_DATABASE` and `RELAY_MEDIA_DIR` inside it
   - joins the external attachable overlay network `fn-edge` and publishes no ports, so only the tunnel connector can reach it
   - restarts unless stopped
3. Deploy. At start-up each relay creates or migrates its database. Before applying a migration to a database that already has tables, it writes a copy beside it named `relay.sqlite3.bak-<UTC time>`. If a migration fails, the relay refuses to start.
4. Check both relays from the Mac:

```sh
curl -fsS https://sync.satanshu.tech/health
curl -fsS https://sync-test.satanshu.tech/health
```

Each prints `ok`. The relay answers 503 instead when its database does not answer or its media folder is not writable.

The relay logs one JSON line per request with only the time, the route pattern, the account and device ids, the byte count, the status and the duration. It never logs bodies, headers, invite codes or tokens.

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
| `account delete <account-id>` | Erases the account's records, files, uploads, keys and pairing mailboxes, then deletes the account. Its devices are told the journal was erased. |
| `mark-restored` | Gives the relay a new generation and ends every session and upload pass. Run it after restoring the relay's data from any backup (section 8). |
| `snapshot-db --to <file>` | Writes a consistent, checked copy of the database and a manifest beside it. The nightly copy uses it. |
| `verify-copy --db <file> --media <dir> --manifest <file>` | Checks a copy's integrity and that every record and file in its manifest is present. The restore drill uses it. |

`mark-restored` must run while the relay is stopped, because the relay reads its generation at start-up. Run it in a throwaway container on the same image, with the same bind mount, user and `RELAY_*` settings:

```sh
docker run --rm --user 1000:1000 \
  --volume /srv/field-notes-relay:/srv/field-notes-relay \
  --env RELAY_DATABASE=/srv/field-notes-relay/relay.sqlite3 \
  --env RELAY_MEDIA_DIR=/srv/field-notes-relay/media \
  ghcr.io/satanshumishra/field-notes-relay:main mark-restored
```

Any other command can run the same way when the relay is stopped.

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
3. copies `backup/` and `media/` with rsync to `rsync://fn-backup@10.0.0.246/field-notes-backup/` (the test relay to `field-notes-backup-test`), trying 10.0.0.247 if 10.0.0.246 fails. It mirrors deletions, never copies the live `relay.sqlite3`, `-wal` or `-shm` files or the `.uploads` folder of unfinished uploads, and leaves the NAS's own `#snapshot` and `@eaDir` folders alone.

The restore drill pulls the latest copy from the NAS into a scratch folder under `/var/tmp/field-notes-drill/`, outside `/srv` so the hourly snapshots never hold a second copy of the media, runs `relay verify-copy`, starts a throwaway relay on the copy with no network but its own, expects `GET /health` to answer 200, and removes everything afterwards.

Both jobs report their start, success or failure to Healthchecks.io. On a failure they send one email naming the step that failed, through `alert.sh` and `msmtp`, to satanshumishra@outlook.com.

### One-time steps on the server

The NAS password file `/home/satanshumishra/.config/field-notes/nas-rsync.pass` already exists. Copy the repository's `server/deploy/` folder to the server (for example by cloning the repository there), then:

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

   It installs `msmtp` and `msmtp-mta` (and `smartmontools` and `snapper` only if they are missing). It installs `nightly-copy.sh`, `restore-drill.sh` and `alert.sh` to `/usr/local/lib/field-notes/`, owned by root and read-only, because root's scrub and `smartd` hooks run `alert.sh` and must never run a file your account can change. It writes `/etc/msmtprc` for the Gmail account (smtp.gmail.com, port 465, TLS, reading the password from `gmail.pass`). It creates the snapper config `srv` for `/srv` with 24 hourly and 7 daily snapshots and nothing longer, and makes sure `snapper-timeline.timer` and `snapper-cleanup.timer` are enabled. It enables the monthly `btrfs-scrub@-.timer` with a hook that emails when the scrub reports errors, configures `smartd` to watch `/dev/nvme0` and email through `alert.sh`, and turns on lingering for `satanshumishra`. It touches no firewall, network or Docker setting.

4. As `satanshumishra`, install and start the two timers:

   ```sh
   ./install-user-timers.sh
   ```

   It installs `fn-nightly-copy.timer` (01:30 daily) and `fn-restore-drill.timer` (04:00 on the 1st) as user units that run the installed scripts. Your account is in the `docker` group, so the scripts need no sudo.

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
   - From the NAS: copy the chosen `backup/relay-<date>.sqlite3` to `/srv/field-notes-relay/relay.sqlite3`, delete any `relay.sqlite3-wal` and `relay.sqlite3-shm` files beside it, and copy the `media/` folder back.
3. Run `mark-restored` with `docker run --rm` exactly as section 7 shows.
4. Start the relay. Every device sees the new generation, signs in again and offers again everything the restore lost.

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
- A real nightly copy and restore drill succeed: `systemctl --user start fn-nightly-copy.service`, then `systemctl --user start fn-restore-drill.service`.
- On the NAS, a locked snapshot cannot be deleted, and Healthchecks.io emails when a check-in is missed.
