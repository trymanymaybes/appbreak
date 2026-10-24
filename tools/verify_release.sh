#!/usr/bin/env bash
# Read-only verification of an already owner-signed 0.6.0 APK. Never signs/uploads.
set -euo pipefail
apk="${1:?Usage: verify_release.sh path/to/owner-signed.apk}"
[[ -f "$apk" ]] || { echo 'APK does not exist' >&2; exit 1; }
cert='1868764f4b22be353f7ea6ca714f2fb83e9ba8d7d9e1aaba1e9e22c732b7fa23'
verification="$("${APKSIGNER:-apksigner}" verify --verbose --print-certs "$apk")"
actual="$(printf '%s\n' "$verification" | sed -n 's/^Signer #1 certificate SHA-256 digest: //p' | tr '[:upper:]' '[:lower:]')"
[[ "$actual" == "$cert" ]] || { echo 'Signing certificate does not match the existing 0.4/0.5 release identity' >&2; exit 1; }
badging="$("${AAPT:-aapt}" dump badging "$apk")"
printf '%s\n' "$badging" | rg -q "^package: name='org.appbreak.companion' versionCode='6' versionName='0.6.0'"
printf '%s\n' "$badging" | rg -q "native-code: 'arm64-v8a'"
"${ZIPALIGN:-zipalign}" -c -P 16 -v 4 "$apk"
sha256sum "$apk"
echo 'Signature, package, version, ARM64 ABI and alignment verified. Physical-device acceptance is a separate gate.'
