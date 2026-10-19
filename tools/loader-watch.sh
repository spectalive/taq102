#!/bin/sh
# Sit and wait for the tablet to appear in loader mode, then flash an image and
# get out of the way. Written because the two-button dance is unreliable on this
# board: the window is in the first second of boot, most attempts miss it, and
# catching the one that lands means somebody watching a terminal.
#
#   tools/loader-watch.sh boot <image>       write it to the boot partition
#   tools/loader-watch.sh recovery <image>   write it to recovery, set the BCB
#   tools/loader-watch.sh bcb                just zero the BCB and reset
#
# It polls every two seconds, logs what it did with a timestamp, and exits.
# Each poll is killed after RK_TIMEOUT seconds (default 10), so a wedged
# libusb is reported instead of hanging the watch; the writes are never cut.
set -eu

here=$(cd "$(dirname "$0")" && pwd)
RK=${RK:-"$here/vendor/rkdeveloptool/rkdeveloptool"}
ZERO=${ZERO:-/Volumes/Datos4TB2/denver-taq102/gate3-build/misc-zero8.img}
WHAT=${1:?usage: loader-watch.sh boot|recovery|bcb [image]}
IMG=${2:-}
TIMEOUT=${TIMEOUT:-7200}
RK_TIMEOUT=${RK_TIMEOUT:-10}

# One `rkdeveloptool ld`, killed by SIGALRM (status 142) after RK_TIMEOUT
# seconds. macOS has no timeout(1); perl ships with it, and its alarm
# survives the exec.
rk_list() {
    perl -e 'alarm shift; exec @ARGV or exit 127' "$RK_TIMEOUT" "$RK" ld 2>/dev/null
}

[ "$WHAT" = bcb ] || [ -f "$IMG" ] || { echo "no such image: $IMG" >&2; exit 1; }

echo "$(date +%H:%M:%S) waiting for loader mode; do the button dance whenever you like"
deadline=$(( $(date +%s) + TIMEOUT ))
while [ "$(date +%s)" -lt "$deadline" ]; do
    status=0
    listing=$(rk_list) || status=$?
    if [ "$status" -eq 142 ]; then
        echo "$(date +%H:%M:%S) rkdeveloptool ld gave no answer in ${RK_TIMEOUT}s:" \
            "libusb is wedged (something else holds the USB device, or the stack" \
            "itself); this is not the tablet. Free the device or replug; still polling"
    elif printf '%s\n' "$listing" | grep -qiE "loader|maskrom"; then
        echo "$(date +%H:%M:%S) caught it: $(printf '%s\n' "$listing" | head -1)"
        case "$WHAT" in
            boot)     sh "$here/flash-boot.sh" "$IMG" ;;
            recovery) sh "$here/flash-recovery.sh" "$IMG" ;;
            bcb)      "$RK" wl 24608 "$ZERO" && echo "BCB zeroed" && "$RK" rd ;;
        esac
        echo "$(date +%H:%M:%S) done"
        exit 0
    fi
    sleep 2
done
echo "$(date +%H:%M:%S) gave up after ${TIMEOUT}s"
exit 1
