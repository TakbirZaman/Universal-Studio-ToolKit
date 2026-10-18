# ADR 010 — explicit local-only Android backup policy

Status: implemented; APK compilation/manifest checks and device transport tests pending.

The manifest previously inherited Android's default allowBackup=true. Private scan drafts and settings must not implicitly participate in cloud backup. Set allowBackup=false, provide both legacy full-backup-content and Android 12+ data-extraction-rules exclusions, and cover all nine documented credential/device-protected/app-external domains. Preserve existing local data and original exports; no storage migration or deletion occurs.

Use a small original BackupAgent with empty onBackup, onRestore and onFullBackup handlers as defense in depth. No app files or backup data are written by these callbacks. Some OEM transfers do not follow allowBackup the same way as cloud backup; exclusions and the no-data full-backup callback address the standard paths. No guarantee against privileged OEM tools, manual copies or existing server backups is made. This does not claim physical secure erasure.

Android 16 QPR2 adds cross-platform transfer XML. Do not invent an iOS bundle/team identity or put unvalidated new tags into older platform rule files. The no-data agent does not select a transport and writes no full-backup content regardless of transport flags. Device/OEM behavior remains a separate acceptance gate.

Verify source exclusions and compiled APK flags/resources. Reject Internet permission in non-debuggable builds and reject broad external-storage permissions. Keep an explicitly named optimized development release APK signed only by the standard local development key; production signing remains private and separate. No new third-party library/model is introduced.

Primary Android documentation checked 2026-10-17:
- https://developer.android.com/identity/data/autobackup (defaults, domains, legacy/modern rules, no-backup storage and agent callbacks)
- https://developer.android.com/about/versions/12/behavior-changes-12 (OEM device-to-device behavior)

Compilation/static inspection is not a transport test and does not establish clean-device compatibility. Do not mark the APK gate passed until actual build output and compiled manifests are checked.

## Packaging recovery — 2026-10-18

Hosted run 39028960308 compiled both release and debug APKs, then exited in the post-build packaging section without identifying the command. The script assumed a debug keystore at $HOME/.android, although SDK user-home overrides can change its location. Generate an explicit ephemeral development key instead, remove it on exit, and label failing packaging stages. A local boundary test uses real keytool and substitutes only absent Android signing/alignment binaries; it verifies the key alias, restrictive permissions, output and cleanup without a conventional Gradle key. This does not replace real APK signature/device checks. Rerun the hosted Android build before merging or claiming this packaging change works.
