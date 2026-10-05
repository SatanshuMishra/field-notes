#!/usr/bin/env bash
set -euo pipefail

if [ "$(id -u)" -eq 0 ]; then
  echo "Run this as satanshumishra, not with sudo." >&2
  exit 1
fi

script_dir="$(cd "$(dirname "$0")" && pwd)"
install_dir="/usr/local/lib/field-notes"
unit_dir="${XDG_CONFIG_HOME:-$HOME/.config}/systemd/user"

for script in nightly-copy.sh restore-drill.sh alert.sh; do
  if [ ! -x "$install_dir/$script" ]; then
    echo "$install_dir/$script is missing. Run root-setup.sh with sudo first." >&2
    exit 1
  fi
done

install -d -m 0755 "$unit_dir"
for unit in fn-nightly-copy.service fn-nightly-copy.timer fn-restore-drill.service fn-restore-drill.timer; do
  install -m 0644 "$script_dir/systemd/$unit" "$unit_dir/$unit"
done

systemctl --user daemon-reload
systemctl --user enable --now fn-nightly-copy.timer fn-restore-drill.timer
systemctl --user list-timers 'fn-*' --no-pager
