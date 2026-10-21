package dev.universalstudio.universal_studio_toolkit

import android.app.Activity
import android.content.ClipData
import android.content.Intent
import android.net.Uri
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel
import java.security.MessageDigest
import java.util.concurrent.ExecutorService

/** Only verified copies created during this Activity session can be handed off. */
class SavedDocumentsAdapter(private val activity: Activity, private val worker: ExecutorService) {
    private data class Receipt(val uri: Uri, val mime: String, val digest: ByteArray, val bytes: Long)
    private val receipts = linkedMapOf<String, Receipt>()
    private var actionPending = false

    fun register(uri: Uri, mime: String, digest: ByteArray, bytes: Long) {
        if (uri.scheme != "content") return
        receipts[uri.toString()] = Receipt(uri, mime, digest.clone(), bytes)
        while (receipts.size > 128) receipts.remove(receipts.keys.first())
    }
    private fun intent(receipt: Receipt, share: Boolean): Intent {
        val result = if (share) {
            Intent(Intent.ACTION_SEND).setType(receipt.mime).putExtra(Intent.EXTRA_STREAM, receipt.uri)
        } else {
            Intent(Intent.ACTION_VIEW).setDataAndType(receipt.uri, receipt.mime)
        }
        result.clipData = ClipData.newRawUri("Saved copy", receipt.uri)
        result.addFlags(Intent.FLAG_GRANT_READ_URI_PERMISSION)
        return result
    }
    private fun supported(receipt: Receipt, share: Boolean): Boolean =
        intent(receipt, share).resolveActivity(activity.packageManager) != null

    fun handle(call: MethodCall, result: MethodChannel.Result) {
        val location = call.argument<String>("location")
        val receipt = if (location != null && location.length <= 32768) receipts[location] else null
        if (call.method == "capabilities") {
            try {
                result.success(mapOf("open" to (receipt != null && supported(receipt, false)),
                    "share" to (receipt != null && supported(receipt, true)), "reveal" to false))
            } catch (_: Exception) { result.success(mapOf("open" to false, "share" to false, "reveal" to false)) }
            return
        }
        if (call.method !in listOf("open", "share")) { result.notImplemented(); return }
        if (receipt == null) { result.error("unavailable", "Save this copy again before opening or sharing it.", null); return }
        if (actionPending) { result.error("busy", "Finish the current document action first.", null); return }
        actionPending = true
        worker.execute {
            try {
                val digest = MessageDigest.getInstance("SHA-256")
                var length = 0L
                activity.contentResolver.openInputStream(receipt.uri)?.use { input ->
                    val buffer = ByteArray(64 * 1024)
                    while (true) {
                        val count = input.read(buffer); if (count < 0) break
                        length += count
                        if (length > receipt.bytes || length > 64L * 1024 * 1024) throw IllegalStateException()
                        digest.update(buffer, 0, count)
                    }
                } ?: throw IllegalStateException()
                if (length != receipt.bytes || !MessageDigest.isEqual(receipt.digest, digest.digest())) throw IllegalStateException()
                activity.runOnUiThread {
                    try {
                        if (activity.isFinishing || activity.isDestroyed) throw IllegalStateException()
                        val share = call.method == "share"
                        if (!supported(receipt, share)) throw IllegalStateException()
                        val target = intent(receipt, share)
                        val launch = if (share) Intent.createChooser(target, "Share saved copy").apply {
                            clipData = target.clipData
                            addFlags(Intent.FLAG_GRANT_READ_URI_PERMISSION)
                        } else target
                        activity.startActivity(launch)
                        result.success(null)
                    } catch (_: Exception) {
                        result.error("handoff_failed", "No available application could open or share this copy.", null)
                    } finally { actionPending = false }
                }
            } catch (_: Exception) {
                activity.runOnUiThread {
                    actionPending = false
                    result.error("changed", "The saved copy changed or could not be read again. Check it before opening or sharing.", null)
                }
            }
        }
    }
}
