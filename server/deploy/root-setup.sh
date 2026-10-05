#!/usr/bin/env bash
set -euo pipefail

if [ "$(id -u)" -ne 0 ]; then
  echo "Run this with sudo: sudo $0 <alert-gmail-address>" >&2
  exit 1
fi
if [ "$#" -ne 1 ] || [ -z "$1" ]; then
  echo "Usage: sudo $0 <alert-gmail-address>" >&2
  exit 64
fi

alert_address="$1"
user_name="satanshumishra"
config_dir="/home/$user_name/.config/field-notes"
script_dir="$(cd "$(dirname "$0")" && pwd)"
install_dir="/usr/local/lib/field-notes"
alert="$install_dir/alert.sh"
drive="/dev/nvme0"
relay_roots="/srv/field-notes-relay /srv/field-notes-relay-test"
relay_uid=1000
relay_gid=1000
drill_root="/var/tmp/field-notes-drill"

say() {
  printf '==> %s\n' "$*"
}

install_missing() {
  local wanted=""
  local package
  for package in "$@"; do
    if ! pacman -Qi "$package" >/dev/null 2>&1; then
      wanted="$wanted $package"
    fi
  done
  if [ -n "$wanted" ]; then
    say "Installing$wanted"
    pacman -S --needed --noconfirm $wanted
  fi
}

say "Packages"
install_missing msmtp msmtp-mta smartmontools snapper btrfs-progs openssh rsync

say "cosign, which verifies the relay image's signature"
pacman -S --needed --noconfirm cosign

say "Scripts in $install_dir, owned by root and read-only"
install -d -o root -g root -m 0755 "$install_dir"
for script in nightly-copy.sh restore-drill.sh alert.sh nas-ssh-keys.sh relay-update.sh; do
  install -o root -g root -m 0555 "$script_dir/$script" "$install_dir/$script"
done
install -o root -g root -m 0444 "$script_dir/nas-rsync.sh" "$install_dir/nas-rsync.sh"

say "Relay data folders, with unfinished uploads kept out of the /srv snapshots"
for relay_root in $relay_roots; do
  media="$relay_root/media"
  for folder in "$relay_root" "$media"; do
    if [ ! -d "$folder" ]; then
      install -d -o "$relay_uid" -g "$relay_gid" -m 0750 "$folder"
    fi
  done
  staging="$media/.uploads"
  filesystem="$(stat -f -c %T "$media")"
  if [ -e "$staging" ] || [ -L "$staging" ]; then
    if [ "$filesystem" = "btrfs" ] && ! btrfs subvolume show "$staging" >/dev/null 2>&1; then
      say "$staging is a plain folder; docs/deploy/relay.md explains how to convert it"
    fi
  elif [ "$filesystem" = "btrfs" ]; then
    btrfs subvolume create "$staging"
    chown "$relay_uid:$relay_gid" "$staging"
    chmod 0750 "$staging"
  else
    say "$media is on $filesystem, not btrfs, so the relay creates $staging itself"
  fi
done

say "Restore drill scratch root $drill_root, private to $user_name"
if [ -L "$drill_root" ]; then
  rm -f "$drill_root"
fi
install -d -o "$user_name" -g "$(id -gn "$user_name")" -m 0700 "$drill_root"

say "Mail through Gmail in /etc/msmtprc"
if [ -f /etc/msmtprc ] && [ ! -f /etc/msmtprc.before-field-notes ]; then
  cp -p /etc/msmtprc /etc/msmtprc.before-field-notes
fi
cat > /etc/msmtprc <<MSMTP
defaults
auth on
tls on
tls_starttls off
tls_trust_file /etc/ssl/certs/ca-certificates.crt
syslog on

account gmail
host smtp.gmail.com
port 465
from $alert_address
user $alert_address
passwordeval "cat $config_dir/gmail.pass"

account default : gmail
MSMTP
chmod 0644 /etc/msmtprc

say "Snapper config srv for /srv: 24 hourly and 7 daily snapshots"
if ! snapper -c srv get-config >/dev/null 2>&1; then
  snapper -c srv create-config /srv
fi
snapper -c srv set-config \
  TIMELINE_CREATE=yes \
  TIMELINE_CLEANUP=yes \
  TIMELINE_LIMIT_HOURLY=24 \
  TIMELINE_LIMIT_DAILY=7 \
  TIMELINE_LIMIT_WEEKLY=0 \
  TIMELINE_LIMIT_MONTHLY=0 \
  TIMELINE_LIMIT_QUARTERLY=0 \
  TIMELINE_LIMIT_YEARLY=0
systemctl enable --now snapper-timeline.timer snapper-cleanup.timer

say "Monthly btrfs scrub of / with an alert when it reports errors"
install -d -m 0755 /etc/systemd/system/btrfs-scrub@-.service.d
cat > /etc/systemd/system/btrfs-scrub@-.service.d/field-notes-alert.conf <<'UNIT'
[Service]
ExecStopPost=/bin/sh -c 'report="$$(/usr/bin/btrfs scrub status / 2>&1)"; if [ "$$SERVICE_RESULT" != "success" ] || ! printf "%%s" "$$report" | grep -q "no errors found"; then /usr/local/lib/field-notes/alert.sh "btrfs scrub reported errors" "$$report"; fi'
UNIT
systemctl daemon-reload
systemctl enable --now btrfs-scrub@-.timer

say "smartd watching $drive"
if [ -f /etc/smartd.conf ] && [ ! -f /etc/smartd.conf.before-field-notes ]; then
  cp -p /etc/smartd.conf /etc/smartd.conf.before-field-notes
fi
cat > /etc/smartd.conf <<SMARTD
$drive -a -m <nomailer> -M exec $alert
SMARTD
systemctl enable smartd.service
systemctl restart smartd.service

say "Lingering for $user_name"
loginctl enable-linger "$user_name"

say "Done. Next, as $user_name: $script_dir/install-user-timers.sh"
