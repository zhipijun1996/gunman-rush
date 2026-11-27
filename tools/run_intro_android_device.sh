#!/usr/bin/env bash
set -euo pipefail
# This entry point is for the disposable emulator owned by the review workflow.
adb_bin="$ANDROID_HOME/platform-tools/adb"
serial="emulator-5554"
out="build/intro-android/device"
mkdir -p "$out"
"$adb_bin" devices -l
"$adb_bin" -s "$serial" shell getprop ro.product.cpu.abilist
"$adb_bin" -s "$serial" shell wm dismiss-keyguard
"$adb_bin" -s "$serial" shell wm size 540x960
"$adb_bin" -s "$serial" shell screenrecord --time-limit 90 --bit-rate 3000000 /data/local/tmp/opening-review.mp4 > /dev/null 2>&1 &
finish_recording() {
    "$adb_bin" -s "$serial" shell pkill -2 screenrecord || true
    sleep 1
    "$adb_bin" -s "$serial" pull /data/local/tmp/opening-review.mp4 "$out/touch.mp4" || true
}
trap finish_recording EXIT
python tools/test_intro_android.py build/intro-android/Plains-review.apk "$out" --adb "$adb_bin" --serial "$serial"
