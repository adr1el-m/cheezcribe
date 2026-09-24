package dev.appcon.appcon_starter

import android.app.Activity
import android.content.Intent
import android.graphics.Bitmap
import android.graphics.BitmapFactory
import android.graphics.Color
import android.graphics.Paint
import android.graphics.pdf.PdfDocument
import android.graphics.pdf.PdfRenderer
import android.net.Uri
import android.os.Handler
import android.os.Looper
import android.os.ParcelFileDescriptor
import android.provider.OpenableColumns
import com.google.mlkit.vision.common.InputImage
import com.google.mlkit.vision.text.TextRecognition
import com.google.mlkit.vision.text.latin.TextRecognizerOptions
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel
import java.io.ByteArrayOutputStream
import java.io.File
import java.security.MessageDigest
import java.util.concurrent.CountDownLatch
import java.util.concurrent.Executors
import java.util.concurrent.TimeUnit
import kotlin.math.max
import kotlin.math.min

class MainActivity : FlutterActivity() {
    private val channelName = "dev.appcon.legacylens/document"
    private val pickCode = 7111
    private val exportCode = 7112
    private val worker = Executors.newSingleThreadExecutor()
    private val mainHandler = Handler(Looper.getMainLooper())
    private var pendingImport: MethodChannel.Result? = null
    private var pendingExport: MethodChannel.Result? = null
    private var exportBytes: ByteArray? = null

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, channelName)
            .setMethodCallHandler { call, result ->
                when (call.method) {
                    "pickAndRecognize" -> pick(result)
                    "recognizeSample" -> {
                        val bytes = call.arguments as? ByteArray
                        if (bytes == null) result.error("sample", "Demo sample unavailable", null)
                        else processAsync(bytes, "PRINT_ME_tagbilaran_blueprint_1915.pdf", true, result)
                    }
                    "exportFile" -> export(call, result)
                    "exportSummaryPdf" -> exportSummaryPdf(call, result)
                    "deleteSavedSource" -> {
                        val path = call.arguments as? String
                        if (path != null) {
                            try {
                                val file = java.io.File(path)
                                if (file.exists()) {
                                    file.delete()
                                }
                            } catch (_: Exception) {}
                        }
                        result.success(true)
                    }
                    else -> result.notImplemented()
                }
            }
    }

    private fun pick(result: MethodChannel.Result) {
        if (pendingImport != null || pendingExport != null) {
            result.error("busy", "A document picker is already open", null)
            return
        }
        pendingImport = result
        val intent = Intent(Intent.ACTION_OPEN_DOCUMENT).apply {
            addCategory(Intent.CATEGORY_OPENABLE)
            type = "*/*"
            putExtra(Intent.EXTRA_MIME_TYPES, arrayOf("image/*", "application/pdf"))
        }
        try { startActivityForResult(intent, pickCode) }
        catch (_: Exception) {
            pendingImport = null
            result.error("import", "Could not open the document picker", null)
        }
    }

    private fun export(call: MethodCall, result: MethodChannel.Result) {
        if (pendingImport != null || pendingExport != null) {
            result.error("busy", "A document picker is already open", null)
            return
        }
        val args = call.arguments as? Map<*, *>
        val name = args?.get("name") as? String
        val content = args?.get("content") as? String
        if (name == null || content == null ||
            listOf(".csv", ".json", ".svg", ".dxf").none { name.endsWith(it) }) {
            result.error("export", "Export is unavailable", null)
            return
        }
        pendingExport = result
        exportBytes = content.toByteArray(Charsets.UTF_8)
        val intent = Intent(Intent.ACTION_CREATE_DOCUMENT).apply {
            addCategory(Intent.CATEGORY_OPENABLE)
            type = when {
                name.endsWith(".csv") -> "text/csv"
                name.endsWith(".json") -> "application/json"
                name.endsWith(".svg") -> "image/svg+xml"
                else -> "application/dxf"
            }
            putExtra(Intent.EXTRA_TITLE, File(name).name)
        }
        try { startActivityForResult(intent, exportCode) }
        catch (_: Exception) {
            pendingExport = null
            exportBytes = null
            result.error("export", "Could not open the save picker", null)
        }
    }

    private fun exportSummaryPdf(call: MethodCall, result: MethodChannel.Result) {
        if (pendingImport != null || pendingExport != null) {
            result.error("busy", "A document picker is already open", null)
            return
        }
        val args = call.arguments as? Map<*, *>
        val title = args?.get("title") as? String
        val filename = args?.get("filename") as? String
        val documentType = args?.get("documentType") as? String
        val abstractText = args?.get("abstract") as? String
        if (title == null || filename == null || documentType == null || abstractText == null) {
            result.error("pdf", "Summary data invalid", null)
            return
        }

        val pdf = PdfDocument()
        try {
            val page = pdf.startPage(PdfDocument.PageInfo.Builder(612, 792, 1).create())
            val canvas = page.canvas
            val paint = Paint(Paint.ANTI_ALIAS_FLAG)
            paint.color = Color.rgb(15, 23, 42)
            canvas.drawRect(36f, 36f, 576f, 92f, paint)
            paint.color = Color.rgb(56, 189, 248)
            paint.textSize = 13f
            paint.isFakeBoldText = true
            canvas.drawText("PAPERAZZI  •  EXECUTIVE DOCUMENT DOSSIER", 48f, 60f, paint)
            paint.color = Color.WHITE
            paint.textSize = 9.5f
            paint.isFakeBoldText = false
            canvas.drawText("Evidence-linked digitization and review summary", 48f, 78f, paint)

            paint.color = Color.rgb(15, 23, 42)
            paint.textSize = 17f
            paint.isFakeBoldText = true
            canvas.drawText(title.take(70), 36f, 120f, paint)
            paint.textSize = 9.5f
            paint.isFakeBoldText = false
            canvas.drawText("Source: ${filename.take(55)}  |  Classification: ${documentType.take(45)}", 36f, 140f, paint)

            paint.color = Color.rgb(37, 99, 235)
            paint.textSize = 11f
            paint.isFakeBoldText = true
            canvas.drawText("1. REVIEWABLE SUMMARY", 36f, 168f, paint)
            paint.color = Color.rgb(51, 65, 85)
            paint.textSize = 9.5f
            paint.isFakeBoldText = false
            var y = drawWrapped(canvas, abstractText, 36f, 188f, 540f, 13f, paint)

            y += 18f
            paint.color = Color.rgb(37, 99, 235)
            paint.textSize = 11f
            paint.isFakeBoldText = true
            canvas.drawText("2. KEY REVIEW ITEMS", 36f, y, paint)
            y += 18f
            paint.color = Color.rgb(51, 65, 85)
            paint.textSize = 9f
            paint.isFakeBoldText = false
            @Suppress("UNCHECKED_CAST")
            val entities = args["keyEntities"] as? List<Map<String, String>> ?: emptyList()
            for (entity in entities.take(25)) {
                if (y > 748f) break
                val line = "${entity["name"] ?: "field"}: ${entity["value"] ?: ""}  [${entity["status"] ?: "review"}]"
                canvas.drawText(line.take(105), 44f, y, paint)
                y += 16f
            }
            paint.color = Color.DKGRAY
            paint.textSize = 8f
            canvas.drawText("Generated locally. Confidence indicators are not an accuracy guarantee.", 36f, 770f, paint)
            pdf.finishPage(page)
            val output = ByteArrayOutputStream()
            pdf.writeTo(output)
            exportBytes = output.toByteArray()
        } catch (error: Exception) {
            result.error("pdf", error.message ?: "Could not create summary PDF", null)
            return
        } finally {
            pdf.close()
        }

        pendingExport = result
        val safeBase = File(filename).nameWithoutExtension.replace(Regex("[^A-Za-z0-9_-]"), "_")
        val intent = Intent(Intent.ACTION_CREATE_DOCUMENT).apply {
            addCategory(Intent.CATEGORY_OPENABLE)
            type = "application/pdf"
            putExtra(Intent.EXTRA_TITLE, "${safeBase}_executive_summary.pdf")
        }
        try { startActivityForResult(intent, exportCode) }
        catch (_: Exception) {
            pendingExport = null
            exportBytes = null
            result.error("pdf", "Could not open the save picker", null)
        }
    }

    private fun drawWrapped(canvas: android.graphics.Canvas, text: String, x: Float, startY: Float,
                            width: Float, lineHeight: Float, paint: Paint): Float {
        var y = startY
        var line = ""
        for (word in text.split(Regex("\\s+"))) {
            val candidate = if (line.isEmpty()) word else "$line $word"
            if (paint.measureText(candidate) > width && line.isNotEmpty()) {
                canvas.drawText(line, x, y, paint)
                y += lineHeight
                line = word
            } else line = candidate
        }
        if (line.isNotEmpty()) {
            canvas.drawText(line, x, y, paint)
            y += lineHeight
        }
        return y
    }

    @Deprecated("The system picker callback is supported on FlutterActivity")
    override fun onActivityResult(requestCode: Int, resultCode: Int, data: Intent?) {
        super.onActivityResult(requestCode, resultCode, data)
        if (requestCode == pickCode) {
            val callback = pendingImport ?: return
            pendingImport = null
            val uri = if (resultCode == Activity.RESULT_OK) data?.data else null
            if (uri == null) { callback.success(null); return }
            val mime = contentResolver.getType(uri)
            val name = displayName(uri)
            if (mime != "application/pdf" && !mime.orEmpty().startsWith("image/") &&
                !name.endsWith(".pdf", ignoreCase = true)) {
                callback.error("import", "Choose an image or PDF", null)
                return
            }
            worker.execute {
                try {
                    val bytes = readLimited(uri)
                    val output = process(bytes, name,
                        mime == "application/pdf" || name.endsWith(".pdf", ignoreCase = true))
                    mainHandler.post { callback.success(output) }
                } catch (error: Exception) {
                    mainHandler.post {
                        callback.error("import", error.message ?: "Could not read this document", null)
                    }
                }
            }
        } else if (requestCode == exportCode) {
            val callback = pendingExport ?: return
            val content = exportBytes
            pendingExport = null
            exportBytes = null
            val uri = if (resultCode == Activity.RESULT_OK) data?.data else null
            if (uri == null || content == null) { callback.success(false); return }
            worker.execute {
                try {
                    contentResolver.openOutputStream(uri)?.use {
                        it.write(content)
                    } ?: error("Could not open the selected save location")
                    mainHandler.post { callback.success(true) }
                } catch (error: Exception) {
                    mainHandler.post {
                        callback.error("export", error.message ?: "Could not save the export", null)
                    }
                }
            }
        }
    }

    private fun displayName(uri: Uri): String {
        contentResolver.query(uri, arrayOf(OpenableColumns.DISPLAY_NAME), null, null, null)?.use {
            if (it.moveToFirst()) return it.getString(0) ?: "document"
        }
        return uri.lastPathSegment ?: "document"
    }

    private fun readLimited(uri: Uri): ByteArray {
        val stream = contentResolver.openInputStream(uri) ?: error("Could not open this file")
        return stream.use { input ->
            val output = ByteArrayOutputStream()
            val chunk = ByteArray(8192)
            while (true) {
                val read = input.read(chunk)
                if (read < 0) break
                if (output.size() + read > 100_000_000) error("Choose a file under 100 MB")
                output.write(chunk, 0, read)
            }
            output.toByteArray()
        }
    }

    private fun processAsync(bytes: ByteArray, name: String, pdf: Boolean,
                             callback: MethodChannel.Result) {
        worker.execute {
            try {
                val output = process(bytes, name, pdf)
                mainHandler.post { callback.success(output) }
            } catch (error: Exception) {
                mainHandler.post {
                    callback.error("sample", error.message ?: "Could not read the sample", null)
                }
            }
        }
    }

    private fun process(bytes: ByteArray, name: String, pdf: Boolean): Map<String, Any> {
        val pages = mutableListOf<Map<String, Any>>()
        if (pdf) {
            val file = File.createTempFile("paperazzi-", ".pdf", cacheDir)
            try {
                file.writeBytes(bytes)
                ParcelFileDescriptor.open(file, ParcelFileDescriptor.MODE_READ_ONLY).use { descriptor ->
                    PdfRenderer(descriptor).use { renderer ->
                        if (renderer.pageCount == 0) error("This PDF has no pages")
                        if (renderer.pageCount > 100) error("Choose a PDF with 100 pages or fewer per batch")
                        for (index in 0 until renderer.pageCount) {
                            renderer.openPage(index).use { page ->
                                val scale = min(1700f / page.width, 2200f / page.height)
                                val width = max(1, (page.width * scale).toInt())
                                val height = max(1, (page.height * scale).toInt())
                                val bitmap = Bitmap.createBitmap(width, height, Bitmap.Config.ARGB_8888)
                                bitmap.eraseColor(Color.WHITE)
                                try {
                                    page.render(bitmap, null, null, PdfRenderer.Page.RENDER_MODE_FOR_DISPLAY)
                                    pages.add(recognize(bitmap, index + 1))
                                } finally { bitmap.recycle() }
                            }
                        }
                    }
                }
            } finally { file.delete() }
        } else {
            val options = BitmapFactory.Options().apply { inJustDecodeBounds = true }
            BitmapFactory.decodeByteArray(bytes, 0, bytes.size, options)
            var sampleSize = 1
            while (options.outWidth / sampleSize > 2200 || options.outHeight / sampleSize > 2200) {
                sampleSize *= 2
            }
            val bitmap = BitmapFactory.decodeByteArray(bytes, 0, bytes.size,
                BitmapFactory.Options().apply { inSampleSize = sampleSize })
                ?: error("This image could not be opened")
            try { pages.add(recognize(bitmap, 1)) }
            finally { bitmap.recycle() }
        }
        val fingerprint = MessageDigest.getInstance("SHA-256")
            .digest(bytes)
            .joinToString("") { "%02x".format(it) }
        return mapOf(
            "name" to name,
            "pages" to pages,
            "sourceFingerprint" to fingerprint
        )
    }

    private fun recognize(bitmap: Bitmap, number: Int): Map<String, Any> {
        val recognizer = TextRecognition.getClient(TextRecognizerOptions.DEFAULT_OPTIONS)
        val latch = CountDownLatch(1)
        var detected: com.google.mlkit.vision.text.Text? = null
        var failure: Exception? = null
        try {
            recognizer.process(InputImage.fromBitmap(bitmap, 0))
                .addOnSuccessListener { detected = it; latch.countDown() }
                .addOnFailureListener { failure = it; latch.countDown() }
            if (!latch.await(35, TimeUnit.SECONDS)) error("OCR timed out")
            failure?.let { throw it }
            val lines = detected?.textBlocks?.flatMap { it.lines }?.sortedWith(
                compareBy<com.google.mlkit.vision.text.Text.Line> {
                    it.boundingBox?.centerY() ?: 0
                }.thenBy { it.boundingBox?.left ?: 0 }) ?: emptyList()
            var cropBudget = 40
            val entries = lines.mapIndexedNotNull { index, line ->
                val bounds = line.boundingBox ?: return@mapIndexedNotNull null
                val left = max(0, bounds.left - 12)
                val top = max(0, bounds.top - 12)
                val right = min(bitmap.width, bounds.right + 12)
                val bottom = min(bitmap.height, bounds.bottom + 12)
                if (right <= left || bottom <= top) return@mapIndexedNotNull null
                val shouldCrop = cropBudget > 0 && (index < 12 || line.confidence < 0.85f)
                val cropBytes = if (shouldCrop) {
                    cropBudget--
                    val crop = Bitmap.createBitmap(bitmap, left, top, right - left, bottom - top)
                    try { jpeg(crop, 85) } finally { crop.recycle() }
                } else ByteArray(0)
                mapOf(
                    "text" to line.text,
                    "confidence" to line.confidence.toDouble(),
                    "box" to listOf(bounds.left.toDouble() / bitmap.width,
                        bounds.top.toDouble() / bitmap.height,
                        bounds.width().toDouble() / bitmap.width,
                        bounds.height().toDouble() / bitmap.height),
                    "crop" to cropBytes
                )
            }
            return mapOf(
                "number" to number,
                "image" to jpeg(bitmap, 84),
                "lines" to entries,
                "drawingObjects" to emptyList<Map<String, Any>>()
            )
        } finally { recognizer.close() }
    }

    private fun jpeg(bitmap: Bitmap, quality: Int): ByteArray {
        val output = ByteArrayOutputStream()
        if (!bitmap.compress(Bitmap.CompressFormat.JPEG, quality, output)) {
            error("Could not encode a page image")
        }
        return output.toByteArray()
    }
}
