#!/usr/bin/env bash
#
# build-kpimg.sh — build a custom KernelPatch "kpimg" for MuMuPlayer Pro (macOS, Apple Silicon)
#
# MuMu's 4.19 kernel runs SELinux permissive and has no real TEE, and its
# compiler emitted avc_denied as an IPA-SRA clone whose argument layout breaks
# KernelPatch's SELinux allow-override hook -> the stock kpimg panics at boot.
# This script rebuilds kpimg with that (here unnecessary) hook disabled.
#
# Output: ./build/kpimg-noavc   (also handy: a prebuilt copy lives in ../prebuilt/)
#
# Requirements: macOS on Apple Silicon, curl, tar, make, git.
set -euo pipefail

KP_TAG="0.13.9"
TC_VER="12.2.rel1"
TC_NAME="arm-gnu-toolchain-${TC_VER}-darwin-arm64-aarch64-none-elf"
TC_URL="https://developer.arm.com/-/media/Files/downloads/gnu/${TC_VER}/binrel/${TC_NAME}.tar.xz"

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
WORK="${ROOT}/build"
PATCH="${ROOT}/patches/0001-skip-avc-hooks-permissive-mumu.patch"
mkdir -p "$WORK"
cd "$WORK"

echo "==> Fetching ARM bare-metal toolchain (${TC_VER})"
[ -d "$TC_NAME" ] || { curl -sSL -o tc.tar.xz "$TC_URL"; tar -Jxf tc.tar.xz; rm -f tc.tar.xz; }
xattr -dr com.apple.quarantine "$TC_NAME" 2>/dev/null || true

# The KernelPatch Makefile uses $(TARGET_COMPILE) unquoted, so the prefix must
# not contain spaces. Symlink the toolchain's bin to a space-free path.
TCBIN="$(/usr/bin/mktemp -d /tmp/kptc.XXXXXX)/bin"
ln -sfn "$WORK/$TC_NAME/bin" "$TCBIN"

echo "==> Fetching KernelPatch source (${KP_TAG})"
[ -d KernelPatch ] || git clone -q --depth 1 --branch "$KP_TAG" https://github.com/bmax121/KernelPatch.git
cd KernelPatch
git checkout -q -- kernel/patch/common/accctl.c 2>/dev/null || true

echo "==> Applying MuMu permissive/isra patch"
if ! patch -p1 --dry-run -s < "$PATCH" >/dev/null 2>&1; then
    echo "   (patch already applied or does not match cleanly — continuing)"
else
    patch -p1 < "$PATCH"
fi

echo "==> Building kpimg"
cd kernel
export TARGET_COMPILE="$TCBIN/aarch64-none-elf-"
export ANDROID=1
make clean >/dev/null 2>&1 || true
make kpimg

cp -f kpimg "$WORK/kpimg-noavc"
echo
echo "==> Done: $WORK/kpimg-noavc"
echo "    (a prebuilt copy is also in ${ROOT}/prebuilt/kpimg-noavc)"
