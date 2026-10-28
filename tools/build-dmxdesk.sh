#!/bin/sh
# Cross-build the desk with the existing OrbStack Buildroot toolchain.
# The source is spectalive/dmxdesk at the tag the Buildroot dmxdesk package
# pins (tools/get-dmxdesk.sh), or DMXDESK_DIR for a local checkout; its
# source list (src/dmxdesk.sources, or dmxdesk.sources after the split) is
# the file list both builds compile. Both compile the
# pinned cJSON into the executable, keeping today's hand-assembled ramdisks
# independent of a new shared library.
set -eu
here=$(cd "$(dirname "$0")/.." && pwd)
machine=${ORB_MACHINE:-taq102}
out=${DMXDESK_OUT:-$here/output}
dmxdesk=${DMXDESK_DIR:-$("$here/tools/get-dmxdesk.sh")}
dmxdesk=$(cd "$dmxdesk" && pwd)
[ -f "$dmxdesk/tools/vendor/cjson/cJSON.c" ] || "$dmxdesk/tools/get-cjson.sh"
mkdir -p "$out"
out=$(cd "$out" && pwd)
orb -m "$machine" -u root bash -s -- "$dmxdesk" "$out" <<'BUILD'
set -eu
dmxdesk=$1
out=$2
VENDOR=$dmxdesk/tools/vendor/cjson
BUILD=$out/build
export TMPDIR=$out/tmp
SYSROOT=/work/output/host/arm-buildroot-linux-gnueabihf/sysroot
CC=/work/output/host/bin/arm-buildroot-linux-gnueabihf-gcc
mkdir -p "$BUILD/include/cjson" "$TMPDIR"
cp "$VENDOR/cJSON.h" "$BUILD/include/cjson/"
# Third-party code on its own terms; project code under -Werror.
"$CC" -O2 -w -I"$SYSROOT/usr/include" -c "$VENDOR/cJSON.c" -o "$BUILD/cJSON.o"
# Up to v0.1.10 everything is in src/ with a bare source list; from the
# core/platform split (2026-10-27) dmxdesk.sources sits at the root with paths.
if [ -f "$dmxdesk/dmxdesk.sources" ]; then
    list=$dmxdesk/dmxdesk.sources
    root=$dmxdesk
    set -- -I"$dmxdesk/core" -I"$dmxdesk/platform/linux-fb"
else
    list=$dmxdesk/src/dmxdesk.sources
    root=$dmxdesk/src
    set -- -I"$dmxdesk/src"
fi
includes="$*"
set --
while IFS= read -r source; do
    [ -n "$source" ] && set -- "$@" "$root/$source"
done < "$list"
# shellcheck disable=SC2086 # two -I flags, paths without spaces
"$CC" -std=gnu99 -Wall -Wextra -Werror -O2 \
    $includes -I"$BUILD/include" -I"$SYSROOT/usr/include" -I"$SYSROOT/usr/include/libdrm" \
    -o "$BUILD/dmxdesk" "$@" "$BUILD/cJSON.o" -L"$SYSROOT/usr/lib" -ldrm -lm -pthread
"$CC" -v 2>&1 | tail -1
cp "$BUILD/dmxdesk" "$out/dmxdesk"
BUILD
ls -l "$out/dmxdesk"
file "$out/dmxdesk"
