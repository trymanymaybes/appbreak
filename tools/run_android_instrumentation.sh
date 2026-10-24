#!/usr/bin/env bash
# Executes the native tests on an emulator. Does not sign or publish a release.
set -euo pipefail
sdk="${ANDROID_HOME:-${ANDROID_SDK_ROOT:-}}"
: "${sdk:?Android SDK required}"
export PATH="$sdk/platform-tools:$sdk/emulator:$sdk/cmdline-tools/latest/bin:$PATH"
log_dir="${RUNNER_TEMP:-/tmp}/appbreak-device-checks"
mkdir -p "$log_dir"
if [[ -e /dev/kvm && ! -w /dev/kvm ]]; then sudo chmod a+rw /dev/kvm; fi
sdkmanager 'emulator' 'platform-tools' 'system-images;android-29;default;x86_64'
printf 'no\n' | avdmanager create avd --force --name appbreak-check --package 'system-images;android-29;default;x86_64'
emulator -avd appbreak-check -no-window -no-audio -no-boot-anim -no-snapshot -gpu swiftshader_indirect -memory 2048 >"$log_dir/emulator.log" 2>&1 &
emulator_pid=$!
trap 'adb logcat -d >"$log_dir/logcat.txt" 2>/dev/null || true; kill "$emulator_pid" 2>/dev/null || true' EXIT
adb wait-for-device
booted=false
for attempt in $(seq 1 120); do
  if [[ "$(adb shell getprop sys.boot_completed 2>/dev/null | tr -d '\r')" == '1' ]]; then booted=true; break; fi
  sleep 2
done
if [[ "$booted" != true ]]; then echo 'Emulator did not finish booting'; exit 1; fi
adb shell input keyevent 82
(cd android && ./gradlew :app:connectedFossDebugAndroidTest --no-daemon)
