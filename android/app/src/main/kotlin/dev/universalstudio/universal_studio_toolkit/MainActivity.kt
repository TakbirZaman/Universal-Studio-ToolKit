package dev.universalstudio.universal_studio_toolkit

import android.app.Activity
import android.content.Intent
import android.content.ClipData
import android.provider.MediaStore
import android.graphics.BitmapFactory
import androidx.core.content.FileProvider
import java.io.File
import java.io.ByteArrayOutputStream
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
    private val requestCapture = 7103
    private var captureResult: MethodChannel.Result? = null
    private var captureFile: File? = null
    private var captureUri: Uri? = null

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, "dev.universalstudio/camera")
            .setMethodCallHandler { call, result ->
                when (call.method) {
                    "available" -> result.success(Intent(MediaStore.ACTION_IMAGE_CAPTURE).resolveActivity(packageManager) != null)
                    "capture" -> capture(result)
                    else -> result.notImplemented()
                }
            }
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, "dev.universalstudio/documents")
            .setMethodCallHandler { call, result ->
                if (call.method != "saveCopy") { result.notImplemented(); return@setMethodCallHandler }
                if (pending != null || captureResult != null) { result.error("busy", "Finish the current save first.", null); return@setMethodCallHandler }
                val bytes = call.argument<ByteArray>("bytes")
                val name = call.argument<String>("name")
                val mime = call.argument<String>("mime")
                if (bytes == null || bytes.isEmpty() || bytes.size > 64 * 1024 * 1024 || name.isNullOrBlank() || name.contains('/') || name.contains('\\') || mime !in listOf("image/jpeg", "image/png", "application/pdf", "application/zip", "application/json", "text/plain")) {
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
        if (requestCode == requestCapture) {
            finishCapture(resultCode)
            return
        }
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
    private fun capture(result: MethodChannel.Result) {
        if (captureResult != null || pending != null) {
            result.error("busy", "Finish the current capture or save first.", null)
            return
        }
        try {
            val directory = File(cacheDir, "camera-captures")
            if (!directory.exists() && !directory.mkdirs()) throw IllegalStateException()
            // Remove only app-created stale cache files; never gallery originals.
            directory.listFiles()?.filter { it.name.startsWith("capture-") && it.extension == "jpg" && it.lastModified() < System.currentTimeMillis() - 86400000L }?.forEach { it.delete() }
            val file = File.createTempFile("capture-", ".jpg", directory)
            captureFile = file
            val uri = FileProvider.getUriForFile(this, "$packageName.capture", file)
            captureUri = uri
            val intent = Intent(MediaStore.ACTION_IMAGE_CAPTURE)
                .putExtra(MediaStore.EXTRA_OUTPUT, uri)
                .addFlags(Intent.FLAG_GRANT_READ_URI_PERMISSION or Intent.FLAG_GRANT_WRITE_URI_PERMISSION)
            intent.clipData = ClipData.newRawUri("Captured scan page", uri)
            captureResult = result
            startActivityForResult(intent, requestCapture)
        } catch (_: Exception) {
            clearCapture()
            result.error("camera_unavailable", "The camera could not open. You can still import a page image.", null)
        }
    }

    private fun clearCapture() {
        captureUri?.let { revokeUriPermission(it, Intent.FLAG_GRANT_READ_URI_PERMISSION or Intent.FLAG_GRANT_WRITE_URI_PERMISSION) }
        captureFile?.delete()
        captureResult = null
        captureFile = null
        captureUri = null
    }

    private fun finishCapture(resultCode: Int) {
        val result = captureResult ?: return
        val file = captureFile
        if (resultCode != Activity.RESULT_OK || file == null) {
            clearCapture()
            result.success(null)
            return
        }
        writer.execute {
            try {
                val limit = 64 * 1024 * 1024
                if (file.length() !in 1..limit.toLong()) throw IllegalArgumentException()
                val output = ByteArrayOutputStream()
                file.inputStream().use { input ->
                    val buffer = ByteArray(64 * 1024)
                    while (true) {
                        val count = input.read(buffer)
                        if (count < 0) break
                        if (output.size() + count > limit) throw IllegalArgumentException()
                        output.write(buffer, 0, count)
                    }
                }
                val bytes = output.toByteArray()
                val options = BitmapFactory.Options().apply { inJustDecodeBounds = true }
                BitmapFactory.decodeByteArray(bytes, 0, bytes.size, options)
                if (options.outMimeType != "image/jpeg" || options.outWidth !in 1..12000 || options.outHeight !in 1..12000 || options.outWidth.toLong() * options.outHeight > 24000000L) throw IllegalArgumentException()
                runOnUiThread { clearCapture(); result.success(bytes) }
            } catch (_: Exception) {
                runOnUiThread {
                    clearCapture()
                    result.error("capture_invalid", "The photo could not be read. Use JPEG at most 24 megapixels and 64 MiB, or import another page image.", null)
                }
            }
        }
    }

}
