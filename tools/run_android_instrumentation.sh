#!/usr/bin/env bash
# Executes the native tests on an emulator. Does not sign or publish a release.
set -euo pipefail
sdk="${ANDROID_HOME:-${ANDROID_SDK_ROOT:-}}"
: "${sdk:?Android SDK required}"
export PATH="$sdk/platform-tools:$sdk/emulator:$sdk/cmdline-tools/latest/bin:$PATH"
log_dir="${RUNNER_TEMP:-/tmp}/appbreak-device-checks"
mkdir -p "$log_dir"
# Recent emulator and older cmdline-tools may choose different default AVD homes.
export ANDROID_AVD_HOME="${RUNNER_TEMP:-/tmp}/appbreak-avd"
mkdir -p "$ANDROID_AVD_HOME"
if [[ -e /dev/kvm && ! -w /dev/kvm ]]; then sudo chmod a+rw /dev/kvm; fi
sdkmanager 'emulator' 'platform-tools' 'system-images;android-29;default;x86_64'
printf 'no\n' | avdmanager create avd --force --name appbreak-check --package 'system-images;android-29;default;x86_64' --path "$ANDROID_AVD_HOME/appbreak-check.avd"
printf 'avd.ini.encoding=UTF-8\npath=%s\ntarget=android-29\n' "$ANDROID_AVD_HOME/appbreak-check.avd" > "$ANDROID_AVD_HOME/appbreak-check.ini"
# AVD defaults vary by emulator image. The oversized-backup rejection fixture
# intentionally allocates 24 MiB; a default 16 MiB Java heap fails before validation.
sed -i '/^vm.heapSize=/d' "$ANDROID_AVD_HOME/appbreak-check.avd/config.ini"
printf '\nvm.heapSize=256\n' >> "$ANDROID_AVD_HOME/appbreak-check.avd/config.ini"
emulator -list-avds | grep -x 'appbreak-check'
emulator -avd appbreak-check -no-window -no-audio -no-boot-anim -no-snapshot -gpu swiftshader_indirect -memory 2048 >"$log_dir/emulator.log" 2>&1 &
emulator_pid=$!
trap 'timeout 10 adb logcat -d >"$log_dir/logcat.txt" 2>/dev/null || true; kill "$emulator_pid" 2>/dev/null || true' EXIT
if ! timeout 120 adb wait-for-device; then
  cat "$log_dir/emulator.log"
  echo "Emulator did not connect to ADB within two minutes" >&2
  exit 1
fi
booted=false
for attempt in $(seq 1 120); do
  if ! kill -0 "$emulator_pid" 2>/dev/null; then cat "$log_dir/emulator.log"; exit 1; fi
  if [[ "$(adb shell getprop sys.boot_completed 2>/dev/null | tr -d '\r')" == '1' ]]; then booted=true; break; fi
  sleep 2
done
if [[ "$booted" != true ]]; then echo 'Emulator did not finish booting'; exit 1; fi
adb shell getprop dalvik.vm.heapsize | tee "$log_dir/java-heap.txt"
adb shell input keyevent 82
(cd android && ./gradlew :app:connectedFossDebugAndroidTest --no-daemon)
