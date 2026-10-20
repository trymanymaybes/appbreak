# AppBreak 0.4.0 signed candidate

The owner authorized a new signing identity on 2026-10-20. The merged source and
verified CI candidate from b1eff80 were signed with the new permanent RSA-4096 key.
APK v2/v3 verification and 16 KiB alignment checks pass. The private keystore and
recovery password are retained in the owner's private recovery bundle, never Git.

Certificate SHA-256:
1868764f4b22be353f7ea6ca714f2fb83e9ba8d7d9e1aaba1e9e22c732b7fa23

APK SHA-256 (appbreak-0.4.0-arm64.apk):
b9bf5f1332de52e557955441dc6f6bd2e389bb0f98da5ed3465a150ede3355ee

This replaces the old temporary signing identity. A 0.3 installation cannot be
updated in place. Export a backup including recordings first, verify the backup
exists outside app-private storage, uninstall the old app, install 0.4.0, then
restore the backup and grant required permissions. Do not uninstall before backup.
Future updates must reuse this new key.

The signed APK has been delivered privately to the owner. GitHub Release asset
publication is pending; it has not been uploaded there yet. Physical device
acceptance remains outstanding; do not label this as a hardware-verified release.
