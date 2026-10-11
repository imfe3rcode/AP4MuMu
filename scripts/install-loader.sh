#!/usr/bin/env bash
#
# install-loader.sh — install the vaddress boot loader into MuMu over adb.
#
# Run this while MuMu is on its ORIGINAL (unpatched) kernel, with MuMu's
# built-in Root enabled (Settings) so adb/su can write to /system. Afterwards
# patch the kernel (scripts/patch-kernel.sh) and start MuMu.
#
# Usage:
#   scripts/install-loader.sh [adb-serial]
# If no serial is given, the first attached device is used. MuMu's adb port
# varies (5555 / 16384 / 26624 ...); run `adb devices` to see it, or connect
# with `adb connect 127.0.0.1:<port>` first.
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
WRAPPER="${ROOT}/scripts/nemuinit_loader.sh"

SERIAL="${1:-$(adb devices | awk 'NR>1 && $2=="device"{print $1; exit}')}"
[ -n "$SERIAL" ] || { echo "No adb device. Start MuMu and/or 'adb connect 127.0.0.1:<port>'."; exit 1; }
echo "==> Using device: $SERIAL"

A() { adb -s "$SERIAL" "$@"; }

# Confirm we can get root (MuMu built-in Root must be ON).
if ! A shell 'su -c id' 2>/dev/null | grep -q 'uid=0'; then
    echo "Root not available. Enable MuMu's built-in Root (Settings) and reboot, then retry."
    exit 1
fi

echo "==> Pushing loader"
A push "$WRAPPER" /data/local/tmp/nemuinit_loader.sh >/dev/null

cat > /tmp/_ap4mumu_install.sh <<'SH'
set -e
RC=/system/etc/init/hw/init.comm.rc
cp /data/local/tmp/nemuinit_loader.sh /system/bin/nemuinit_loader.sh
chmod 755 /system/bin/nemuinit_loader.sh
# Route the nemuinit service through the loader (idempotent) and give it init context.
if grep -q '^service nemuinit /system/bin/nemuinit$' "$RC"; then
    cp "$RC" "$RC.ap4mumu.bak"
    sed -i 's#^service nemuinit /system/bin/nemuinit$#service nemuinit /system/bin/sh /system/bin/nemuinit_loader.sh\n    seclabel u:r:init:s0#' "$RC"
    echo "init.comm.rc updated"
else
    echo "init.comm.rc already routed (or unexpected format) — check manually"
fi
grep -A3 'service nemuinit' "$RC"
sync
SH
A push /tmp/_ap4mumu_install.sh /data/local/tmp/_ap4mumu_install.sh >/dev/null
A shell 'su -c "sh /data/local/tmp/_ap4mumu_install.sh"'
rm -f /tmp/_ap4mumu_install.sh

echo
echo "==> Loader installed. Next: quit MuMu, run scripts/patch-kernel.sh 'YOUR_SUPERKEY', then start MuMu."
