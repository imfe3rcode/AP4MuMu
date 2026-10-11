#!/system/bin/sh
# nemuinit_loader.sh — runs on the emulator, in place of nemuinit.
#
# Under the APatch/KernelPatch kernel, MuMu's early `on init` insmod of the
# vaddress driver does not bring up /dev/vaddress (MuMu hides the stock
# /system/lib64/vaddress.ko path), so nemuinit can't start and boot hangs.
# Load the driver from the (non-hidden) modules directory first, then exec the
# real nemuinit so it runs as the normal init service.
if ! grep -q '^vaddress ' /proc/modules; then
    for ko in /system/lib/modules/*/extra/vaddress.ko /system/lib64/vaddress.ko; do
        [ -f "$ko" ] && insmod "$ko" 2>/dev/null && break
    done
fi
i=0
while [ ! -e /dev/vaddress ] && [ $i -lt 40 ]; do sleep 0.1; i=$((i+1)); done
[ -e /dev/vaddress ] && chmod 666 /dev/vaddress
exec /system/bin/nemuinit "$@"
