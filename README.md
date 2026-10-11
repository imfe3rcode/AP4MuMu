# AP4MuMu

**APatch root on MuMuPlayer Pro (macOS, Apple Silicon).**

Stock [APatch](https://github.com/bmax121/APatch) crashes MuMuPlayer Pro at boot.
AP4MuMu is a small fix — a one-line change to KernelPatch plus the boot helper MuMu
needs — that gets APatch working on MuMu's kernel, with a plain step-by-step guide.

> Tested with MuMuPlayer Pro (Global) on Apple Silicon, Android 12, kernel
> `4.19.195-android-arm64`. Other MuMu builds may differ slightly.

---

## Why stock APatch doesn't work on MuMu

Two reasons, both handled here:

1. **Boot panic.** MuMu's kernel runs SELinux **permissive** and was compiled so that
   `avc_denied` became an optimized clone (`avc_denied.isra.N`) with a non-standard
   argument layout. KernelPatch hooks that function to override SELinux denials; on this
   kernel the hook reads a bad pointer and the kernel panics during early boot.
   Since the kernel is already permissive, that hook is unnecessary — so the custom
   KernelPatch build here simply skips it. (See `patches/`.)

2. **Boot hang.** Under the patched kernel, MuMu's early init can't bring up its
   `vaddress` device (MuMu hides the stock driver path), so its `nemuinit` service fails
   and boot hangs. A tiny boot helper loads the driver from the real module path so
   `nemuinit` can start. (See `scripts/nemuinit_loader.sh`.)

---

## What you need

- **MuMuPlayer Pro** installed (macOS, Apple Silicon).
- **adb** — `brew install android-platform-tools`.
- **APatch manager 11107** APK — download `APatch_11107_11107-release-signed.apk` from
  the [official release](https://github.com/bmax121/APatch/releases/tag/11107).
  Use **11107**, not the latest — newer managers can't authenticate a manually-patched
  kernel.
- This repo. A prebuilt custom `kpimg` is included in `prebuilt/`; `kptools` is fetched
  automatically.

---

## Repo contents

```
patches/0001-skip-avc-hooks-permissive-mumu.patch   the KernelPatch fix (vs upstream 0.13.9)
prebuilt/kpimg-noavc                                 prebuilt custom KernelPatch image
scripts/build-kpimg.sh                               build kpimg yourself (optional)
scripts/install-loader.sh                            install the boot helper over adb
scripts/nemuinit_loader.sh                           the boot helper (runs on the emulator)
scripts/patch-kernel.sh                              patch & install MuMu's kernel
```

---

## Install — step by step

You'll choose a **SuperKey**: your APatch root password, 8–63 characters, letters and
numbers. Keep it secret.

### 1. Enable MuMu's built-in Root (temporary)
In MuMuPlayer Pro **Settings → Root**, turn **Root ON**, and keep the system disk
**writable**. Start the emulator and let it reach the home screen. This lets the next
step write to `/system`.

### 2. Connect adb
```bash
adb devices        # should list one device; note its address
```
If nothing shows, find MuMu's adb port (MuMu Settings, or it's often `16384`/`5555`) and:
```bash
adb connect 127.0.0.1:<port>
```

### 3. Install the boot helper
```bash
scripts/install-loader.sh
```

### 4. Patch the kernel
Quit MuMuPlayer Pro completely (⌘Q), then:
```bash
scripts/patch-kernel.sh 'YOUR_SUPERKEY'
```
This backs up the original kernel to `build/Image.orig` and installs the patched one.

### 5. First boot
Start MuMuPlayer Pro. The first patched boot can take ~20–30s (the helper loads the
driver and `nemuinit` retries), then you reach the home screen.

### 6. Install the APatch manager
```bash
adb install APatch_11107_11107-release-signed.apk
```
Open **APatch**, enter your **SuperKey**, and when it offers to install KernelPatch /
AndroidPatch, accept it. The Home tab should show **KernelPatch 0.13.9** and your
device — root is working.

### 7. (Optional) Turn MuMu's built-in Root back off
Now that APatch provides root, you can disable MuMu's built-in Root in Settings for a
cleaner setup. Grant root per app in APatch's **Superuser** tab.

---

## Build the kpimg yourself (optional)

Instead of `prebuilt/kpimg-noavc`:
```bash
scripts/build-kpimg.sh      # downloads the ARM toolchain + KernelPatch 0.13.9, applies the patch, builds
```
Output: `build/kpimg-noavc`. `patch-kernel.sh` uses `prebuilt/kpimg-noavc` by default;
point it at your build if you prefer.

---

## Reverting

Quit MuMu, then restore the original kernel:
```bash
cp build/Image.orig "/Applications/MuMuPlayer Pro.app/Contents/MacOS/MuMu Android Device.app/Contents/Resources/vms.bundle/Contents/Resources/Image"
```
Re-enable MuMu's built-in Root in Settings if you turned it off.

---

## Notes

- **MuMu updates overwrite the kernel.** After an update, re-run `scripts/patch-kernel.sh`.
- Stay on **APatch manager 11107 + KernelPatch 0.13.9**. Don't tap "Update" in the
  manager (it would install an older KernelPatch that crashes MuMu), and don't upgrade
  the manager to a version that can't authenticate a manually-patched kernel.
- This modifies files inside the MuMuPlayer Pro app bundle. Use at your own risk.

## Credits & license

Built on [APatch / KernelPatch](https://github.com/bmax121/APatch) by bmax121.
The patch and scripts here are released under **GPL-3.0** (see `LICENSE`), matching
KernelPatch. `prebuilt/kpimg-noavc` is KernelPatch 0.13.9 built with `patches/`.
