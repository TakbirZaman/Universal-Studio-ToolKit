package dev.universalstudio.universal_studio_toolkit

import android.app.Activity
import android.content.Intent
import android.net.Uri
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import java.security.MessageDigest
import java.util.concurrent.Executors

/** SAF create-copy adapter. Content URIs are never converted to filesystem paths. */
class MainActivity : FlutterActivity() {
    private val writer = Executors.newSingleThreadExecutor()
    private var pending: MethodChannel.Result? = null
    private var pendingBytes: ByteArray? = null
    private val requestSave = 7102

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, "dev.universalstudio/documents")
            .setMethodCallHandler { call, result ->
                if (call.method != "saveCopy") { result.notImplemented(); return@setMethodCallHandler }
                if (pending != null) { result.error("busy", "Finish the current save first.", null); return@setMethodCallHandler }
                val bytes = call.argument<ByteArray>("bytes")
                val name = call.argument<String>("name")
                val mime = call.argument<String>("mime")
                if (bytes == null || bytes.isEmpty() || bytes.size > 64 * 1024 * 1024 || name.isNullOrBlank() || name.contains('/') || name.contains('\\') || mime !in listOf("image/jpeg", "image/png", "application/pdf", "application/zip", "application/json")) {
                    result.error("invalid", "The output or filename is invalid.", null); return@setMethodCallHandler
                }
                pending = result
                pendingBytes = bytes
                try {
                    val intent = Intent(Intent.ACTION_CREATE_DOCUMENT)
                        .addCategory(Intent.CATEGORY_OPENABLE)
                        .setType(mime)
                        .putExtra(Intent.EXTRA_TITLE, name)
                    startActivityForResult(intent, requestSave)
                } catch (_: Exception) {
                    pending = null; pendingBytes = null
                    result.error("provider", "No document provider is available for saving.", null)
                }
            }
    }

    @Deprecated("SAF activity result adapter; migrate with the embedding's ActivityResult support")
    override fun onActivityResult(requestCode: Int, resultCode: Int, data: Intent?) {
        super.onActivityResult(requestCode, resultCode, data)
        if (requestCode != requestSave) return
        val result = pending ?: return
        val bytes = pendingBytes
        val uri = data?.data
        if (resultCode != Activity.RESULT_OK || uri == null || bytes == null) {
            pending = null; pendingBytes = null; result.success(null); return
        }
        writer.execute {
            try {
                contentResolver.openOutputStream(uri, "wt")?.use { output -> output.write(bytes); output.flush() }
                    ?: throw IllegalStateException("Provider did not open an output stream")
                val expected = MessageDigest.getInstance("SHA-256").digest(bytes)
                val digest = MessageDigest.getInstance("SHA-256")
                var length = 0L
                contentResolver.openInputStream(uri)?.use { input ->
                    val buffer = ByteArray(64 * 1024)
                    while (true) {
                        val read = input.read(buffer); if (read < 0) break
                        length += read
                        if (length > bytes.size) throw IllegalStateException("Provider length mismatch")
                        digest.update(buffer, 0, read)
                    }
                } ?: throw IllegalStateException("Provider did not reopen the saved document")
                if (length != bytes.size.toLong() || !MessageDigest.isEqual(expected, digest.digest())) throw IllegalStateException("Provider verification failed")
                runOnUiThread { pending = null; pendingBytes = null; result.success(uri.toString()) }
            } catch (_: Exception) {
                // A provider may not allow deletion or atomic replacement. Do not silently delete it.
                runOnUiThread {
                    pending = null; pendingBytes = null
                    result.error("save_unverified", "The saved copy could not be verified. A partial file may remain in the chosen location; inspect or delete that copy. Your source file is unchanged.", null)
                }
            }
        }
    }
}
