#!/bin/sh
# Run the optional Qt desk for at most thirty minutes and restore the C desk.
set -eu

trial=/data/qt-full
capture=
if [ "$#" -eq 2 ] && [ "$1" = "--capture" ]; then
    capture=$2
elif [ "$#" -ne 0 ]; then
    exit 2
fi
[ -x "$trial/qt-desk" ] && [ -x "$trial/dmxdesk-backend" ] || exit 1
[ -f "$trial/qml/Main.qml" ] && [ -f "$trial/kms.json" ] || exit 1

power_node=
for event in /sys/class/input/event*; do
    if [ "$(cat "$event/device/name" 2>/dev/null)" = "rk805 pwrkey" ]; then
        power_node=/dev/input/${event##*/}
        break
    fi
done

# shellcheck disable=SC2329
restore() {
    trap - EXIT HUP INT TERM
    if [ -n "${qt_pid:-}" ]; then
        kill "$qt_pid" 2>/dev/null || true
        wait "$qt_pid" 2>/dev/null || true
    fi
    printf 0 > /sys/class/backlight/backlight/bl_power 2>/dev/null || true
    printf 0 > /sys/class/graphics/fb0/blank 2>/dev/null || true
    nohup /usr/bin/taq102-app > "$trial/c-desk-recovery.log" 2>&1 < /dev/null &
}
trap restore EXIT HUP INT TERM

killall taq102-app 2>/dev/null || true
killall dmxdesk 2>/dev/null || true
sleep 2
export LD_LIBRARY_PATH="$trial/usr/lib${LD_LIBRARY_PATH:+:$LD_LIBRARY_PATH}"
export QT_QPA_PLATFORM=eglfs
export QT_QPA_EGLFS_KMS_CONFIG="$trial/kms.json"
export QT_PLUGIN_PATH="$trial/usr/lib/qt6/plugins"
export QML_IMPORT_PATH="$trial/usr/lib/qt6/qml"
export QT_QPA_FONTDIR=/usr/share/fonts/taq102

set -- --backend "$trial/dmxdesk-backend" \
    --map /usr/share/dmxdesk/vibra.desk.json \
    --qml "$trial/qml/Main.qml"
if [ -n "$power_node" ]; then
    set -- "$@" --power "$power_node"
fi
if [ -n "$capture" ]; then
    set -- "$@" --capture "$capture"
fi
timeout 1800 "$trial/qt-desk" "$@" > "$trial/qt-desk.log" 2>&1 &
qt_pid=$!
trial_rc=0
wait "$qt_pid" || trial_rc=$?
qt_pid=
exit "$trial_rc"
