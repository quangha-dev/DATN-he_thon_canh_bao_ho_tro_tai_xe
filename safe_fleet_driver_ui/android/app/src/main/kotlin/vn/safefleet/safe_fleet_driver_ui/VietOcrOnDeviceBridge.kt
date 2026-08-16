package vn.safefleet.safe_fleet_driver_ui

import android.content.Context
import android.graphics.Bitmap
import android.graphics.BitmapFactory
import android.graphics.Canvas
import android.graphics.Color
import android.graphics.Paint
import android.os.Handler
import android.os.Looper
import android.util.Log
import ai.onnxruntime.OnnxTensor
import ai.onnxruntime.OrtEnvironment
import ai.onnxruntime.OrtSession
import io.flutter.plugin.common.BinaryMessenger
import io.flutter.plugin.common.MethodChannel
import org.json.JSONObject
import java.io.Closeable
import java.io.File
import java.io.FileOutputStream
import java.nio.FloatBuffer
import java.nio.LongBuffer
import java.util.concurrent.Executors
import kotlin.math.roundToInt

class VietOcrOnDeviceBridge(
    private val context: Context,
    messenger: BinaryMessenger,
) : Closeable {
    private val channel = MethodChannel(messenger, CHANNEL)
    private val executor = Executors.newSingleThreadExecutor()
    private val mainHandler = Handler(Looper.getMainLooper())
    private val environment = OrtEnvironment.getEnvironment()
    @Volatile private var runtime: Runtime? = null

    init {
        channel.setMethodCallHandler { call, result ->
            when (call.method) {
                "recognizeLine" -> {
                    val bytes = call.argument<ByteArray>("bytes")
                    if (bytes == null) {
                        result.error("invalid_image", "Thiếu dữ liệu ảnh dòng chữ", null)
                        return@setMethodCallHandler
                    }
                    val maxTokens = call.argument<Int>("maxTokens")
                    executor.execute {
                        try {
                            val started = System.nanoTime()
                            val text = recognize(bytes, maxTokens)
                            val elapsedMs = (System.nanoTime() - started) / 1_000_000
                            mainHandler.post {
                                result.success(
                                    mapOf(
                                        "text" to text,
                                        "elapsedMs" to elapsedMs,
                                        "engine" to "vietocr-onnx-android",
                                    ),
                                )
                            }
                        } catch (error: Throwable) {
                            mainHandler.post {
                                result.error(
                                    "vietocr_failed",
                                    error.message ?: error.javaClass.simpleName,
                                    null,
                                )
                            }
                        }
                    }
                }
                else -> result.notImplemented()
            }
        }
    }

    private fun recognize(bytes: ByteArray, requestedMaxTokens: Int?): String {
        val bitmap = BitmapFactory.decodeByteArray(bytes, 0, bytes.size)
            ?: error("Không giải mã được ảnh dòng chữ")
        val input = preprocess(bitmap)
        if (bitmap !== input.bitmap) bitmap.recycle()
        input.bitmap.recycle()
        val current = runtime ?: synchronized(this) {
            runtime ?: createRuntime().also { runtime = it }
        }

        OnnxTensor.createTensor(
            environment,
            FloatBuffer.wrap(input.values),
            longArrayOf(1, 3, IMAGE_HEIGHT.toLong(), IMAGE_WIDTH.toLong()),
        ).use { imageTensor ->
            current.encoder.run(mapOf("image" to imageTensor)).use { encoderOutput ->
                val memory = encoderOutput[0] as OnnxTensor
                val maxSteps = (requestedMaxTokens ?: current.maxSequenceLength)
                    .coerceIn(1, current.maxSequenceLength)
                Log.i(TAG, "recognize start maxSteps=$maxSteps imageBytes=${bytes.size}")
                val tokens = LongArray(maxSteps + 1)
                tokens[0] = SOS_TOKEN.toLong()
                var generatedLength = 1
                var steps = 0
                while (
                    steps < maxSteps &&
                    tokens[generatedLength - 1].toInt() != EOS_TOKEN
                ) {
                    OnnxTensor.createTensor(
                        environment,
                        LongBuffer.wrap(tokens, 0, generatedLength),
                        longArrayOf(generatedLength.toLong(), 1),
                    ).use { tokenTensor ->
                        current.decoder.run(
                            mapOf("tokens" to tokenTensor, "memory" to memory),
                        ).use { decoderOutput ->
                            val logits = decoderOutput[0] as OnnxTensor
                            val shape = logits.info.shape
                            val vocabularySize = shape[2].toInt()
                            val offset = (generatedLength - 1) * vocabularySize
                            val values = logits.floatBuffer
                            var bestIndex = 0
                            var bestValue = Float.NEGATIVE_INFINITY
                            for (index in 0 until vocabularySize) {
                                val value = values.get(offset + index)
                                if (value > bestValue) {
                                    bestValue = value
                                    bestIndex = index
                                }
                            }
                            tokens[generatedLength] = bestIndex.toLong()
                            generatedLength++
                        }
                    }
                    steps++
                }
                return buildString {
                    for (index in 1 until generatedLength) {
                        val id = tokens[index].toInt()
                        if (id == EOS_TOKEN) break
                        val characterIndex = id - FIRST_CHARACTER_TOKEN
                        if (characterIndex in current.characters.indices) {
                            append(current.characters[characterIndex])
                        }
                    }
                }.also { text ->
                    Log.i(TAG, "recognize done steps=$steps characters=${text.length}")
                }
            }
        }
    }

    private fun preprocess(source: Bitmap): PreparedBitmap {
        val scaledWidth = (source.width * IMAGE_HEIGHT.toDouble() / source.height)
            .roundToInt()
            .coerceIn(MIN_IMAGE_WIDTH, IMAGE_WIDTH)
        val scaled = Bitmap.createScaledBitmap(source, scaledWidth, IMAGE_HEIGHT, true)
        val padded = Bitmap.createBitmap(IMAGE_WIDTH, IMAGE_HEIGHT, Bitmap.Config.ARGB_8888)
        Canvas(padded).apply {
            drawColor(Color.WHITE)
            drawBitmap(scaled, 0f, 0f, Paint(Paint.ANTI_ALIAS_FLAG or Paint.FILTER_BITMAP_FLAG))
        }
        if (scaled !== source) scaled.recycle()

        val pixels = IntArray(IMAGE_WIDTH * IMAGE_HEIGHT)
        padded.getPixels(pixels, 0, IMAGE_WIDTH, 0, 0, IMAGE_WIDTH, IMAGE_HEIGHT)
        val planeSize = IMAGE_WIDTH * IMAGE_HEIGHT
        val values = FloatArray(planeSize * 3) { 1f }
        for (index in pixels.indices) {
            val pixel = pixels[index]
            values[index] = Color.red(pixel) / 255f
            values[planeSize + index] = Color.green(pixel) / 255f
            values[planeSize * 2 + index] = Color.blue(pixel) / 255f
        }
        return PreparedBitmap(padded, values)
    }

    private fun createRuntime(): Runtime {
        val packagedMetadata = context.assets.open(METADATA_ASSET)
            .bufferedReader(Charsets.UTF_8)
            .use { it.readText() }
        val metadata = JSONObject(packagedMetadata)
        val metadataTarget = File(context.filesDir, "vietocr/${File(METADATA_ASSET).name}")
        val refreshModels = !metadataTarget.exists() ||
            metadataTarget.readText(Charsets.UTF_8) != packagedMetadata
        val options = OrtSession.SessionOptions().apply {
            // Two worker threads keep HyperOS responsive during long-line decoding.
            setIntraOpNumThreads(2)
            setInterOpNumThreads(1)
            setOptimizationLevel(OrtSession.SessionOptions.OptLevel.ALL_OPT)
        }
        val encoderFile = copyAndroidAsset(
            ENCODER_ASSET,
            metadata.getLong("encoder_bytes"),
            refreshModels,
        )
        val decoderFile = copyAndroidAsset(
            DECODER_ASSET,
            metadata.getLong("decoder_bytes"),
            refreshModels,
        )
        metadataTarget.parentFile?.mkdirs()
        metadataTarget.writeText(packagedMetadata, Charsets.UTF_8)
        return Runtime(
            encoder = environment.createSession(encoderFile.path, options),
            decoder = environment.createSession(decoderFile.path, options),
            characters = metadata.getString("characters").toCharArray(),
            maxSequenceLength = metadata.getInt("max_sequence_length"),
            options = options,
        )
    }

    private fun copyAndroidAsset(
        relativePath: String,
        expectedBytes: Long,
        forceRefresh: Boolean,
    ): File {
        val target = File(context.filesDir, "vietocr/${File(relativePath).name}")
        if (!forceRefresh && target.exists() && target.length() == expectedBytes) return target
        target.parentFile?.mkdirs()
        context.assets.open(relativePath).use { input ->
            FileOutputStream(target).use { output -> input.copyTo(output) }
        }
        return target
    }

    override fun close() {
        channel.setMethodCallHandler(null)
        executor.shutdownNow()
        runtime?.close()
        runtime = null
    }

    private data class PreparedBitmap(val bitmap: Bitmap, val values: FloatArray)

    private class Runtime(
        val encoder: OrtSession,
        val decoder: OrtSession,
        val characters: CharArray,
        val maxSequenceLength: Int,
        private val options: OrtSession.SessionOptions,
    ) : Closeable {
        override fun close() {
            encoder.close()
            decoder.close()
            options.close()
        }
    }

    companion object {
        private const val CHANNEL = "safefleet/vietocr"
        private const val TAG = "SafeFleetVietOCR"
        private const val IMAGE_HEIGHT = 32
        private const val IMAGE_WIDTH = 512
        private const val MIN_IMAGE_WIDTH = 32
        private const val SOS_TOKEN = 1
        private const val EOS_TOKEN = 2
        private const val FIRST_CHARACTER_TOKEN = 4
        private const val ENCODER_ASSET = "vietocr/vietocr_encoder.onnx"
        private const val DECODER_ASSET = "vietocr/vietocr_decoder.onnx"
        private const val METADATA_ASSET = "vietocr/vietocr_metadata.json"
    }
}
