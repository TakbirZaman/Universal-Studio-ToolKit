package dev.universalstudio.universal_studio_toolkit

import android.app.backup.BackupAgent
import android.app.backup.BackupDataInput
import android.app.backup.BackupDataOutput
import android.app.backup.FullBackupDataOutput
import android.os.ParcelFileDescriptor

/**
 * Defense in depth for local-only drafts and settings. No app data is written
 * to key/value or full-backup transports, including transfers invoking this
 * agent despite allowBackup=false. Legacy/full restore rules exclude files.
 */
class LocalOnlyBackupAgent : BackupAgent() {
    override fun onBackup(
        oldState: ParcelFileDescriptor?,
        data: BackupDataOutput,
        newState: ParcelFileDescriptor
    ) = Unit

    override fun onRestore(
        data: BackupDataInput,
        appVersionCode: Int,
        newState: ParcelFileDescriptor
    ) = Unit

    override fun onFullBackup(data: FullBackupDataOutput) = Unit
}
