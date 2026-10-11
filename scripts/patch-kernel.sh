#!/usr/bin/env bash
#
# patch-kernel.sh — patch MuMuPlayer Pro's kernel with the custom kpimg + APatch.
#
# Usage:
#   scripts/patch-kernel.sh 'YOUR_SUPERKEY'
#
# It backs up MuMu's original kernel, patches a copy with KernelPatch (using the
# custom kpimg that disables the crashing SELinux hook), and installs it.
# Quit MuMuPlayer Pro before running. Start it again afterwards.
#
# Your SuperKey is your root password — choose 8-63 chars, keep it secret.
set -euo pipefail

SUPERKEY="${1:-}"
[ -n "$SUPERKEY" ] || { echo "usage: $0 'YOUR_SUPERKEY'"; exit 1; }

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
KPIMG="${ROOT}/prebuilt/kpimg-noavc"          # or build/kpimg-noavc from build-kpimg.sh
WORK="${ROOT}/build"; mkdir -p "$WORK"
KPTOOLS="${WORK}/kptools-mac"

# MuMuPlayer Pro's kernel image inside the app bundle:
IMG="/Applications/MuMuPlayer Pro.app/Contents/MacOS/MuMu Android Device.app/Contents/Resources/vms.bundle/Contents/Resources/Image"
[ -f "$IMG" ] || { echo "Kernel image not found at:\n  $IMG\nIs MuMuPlayer Pro installed?"; exit 1; }
[ -f "$KPIMG" ] || { echo "kpimg not found: $KPIMG (run scripts/build-kpimg.sh first, or use prebuilt/)"; exit 1; }

echo "==> Fetching kptools (KernelPatch 0.13.9, macOS)"
[ -f "$KPTOOLS" ] || curl -sSL -o "$KPTOOLS" https://github.com/bmax121/KernelPatch/releases/download/0.13.9/kptools-mac
chmod +x "$KPTOOLS"; xattr -d com.apple.quarantine "$KPTOOLS" 2>/dev/null || true

echo "==> Backing up original kernel -> build/Image.orig"
[ -f "$WORK/Image.orig" ] || cp "$IMG" "$WORK/Image.orig"

echo "==> Patching kernel"
"$KPTOOLS" -p -i "$WORK/Image.orig" -k "$KPIMG" -s "$SUPERKEY" -o "$WORK/Image.patched"
"$KPTOOLS" -l -i "$WORK/Image.patched" | grep -E "patched=|version=" || true

echo "==> Installing patched kernel"
cp "$WORK/Image.patched" "$IMG"

echo
echo "==> Done. Start MuMuPlayer Pro."
echo "    To revert: cp build/Image.orig to the kernel path above."
