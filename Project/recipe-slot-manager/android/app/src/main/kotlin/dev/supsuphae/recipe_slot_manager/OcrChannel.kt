package dev.supsuphae.recipe_slot_manager

import android.graphics.Bitmap
import android.graphics.BitmapFactory
import android.os.Handler
import android.os.Looper
import com.google.mlkit.vision.common.InputImage
import com.google.mlkit.vision.text.TextRecognition
import com.google.mlkit.vision.text.korean.KoreanTextRecognizerOptions
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel
import java.util.concurrent.Executors

/**
 * Dart `recognizeText` 가 보낸 이미지 바이트에서 글자를 줄 단위로 읽는다 (ML Kit 한국어 모델,
 * 라틴 글자도 함께 읽는다). 이미지는 작업 스레드에서 줄여 읽고, 결과는 메인 스레드로 온다.
 */
class OcrChannel : MethodChannel.MethodCallHandler {
    companion object {
        const val CHANNEL = "recipe_slot_manager/ocr"

        /** 긴 변을 이 길이 이하로 줄여 읽는다. 사진을 잘못 골라도 메모리가 크게 늘지 않는다. */
        private const val MAX_SIDE = 4096
    }

    private val recognizer =
        TextRecognition.getClient(KoreanTextRecognizerOptions.Builder().build())
    private val decoder = Executors.newSingleThreadExecutor()
    private val main = Handler(Looper.getMainLooper())

    override fun onMethodCall(call: MethodCall, result: MethodChannel.Result) {
        if (call.method != "recognize") return result.notImplemented()
        val bytes = call.arguments as? ByteArray
            ?: return result.error("arguments", "이미지 바이트가 없다", null)
        decoder.execute {
            val bitmap = decode(bytes)
            if (bitmap == null) {
                main.post { result.error("image", "이미지를 열지 못했다", null) }
                return@execute
            }
            recognizer.process(InputImage.fromBitmap(bitmap, 0))
                .addOnSuccessListener { text ->
                    result.success(text.textBlocks.flatMap { block -> block.lines.map { it.text } })
                }
                .addOnFailureListener { e -> result.error("ocr", e.message, null) }
        }
    }

    /** 긴 변이 [MAX_SIDE] 이하가 되도록 2의 거듭제곱 배율로 줄여 읽는다. */
    private fun decode(bytes: ByteArray): Bitmap? {
        val bounds = BitmapFactory.Options().apply { inJustDecodeBounds = true }
        BitmapFactory.decodeByteArray(bytes, 0, bytes.size, bounds)
        var sample = 1
        while (maxOf(bounds.outWidth, bounds.outHeight) / sample > MAX_SIDE) sample *= 2
        val options = BitmapFactory.Options().apply { inSampleSize = sample }
        return BitmapFactory.decodeByteArray(bytes, 0, bytes.size, options)
    }

    /** 액티비티가 끝날 때 부른다. */
    fun dispose() {
        recognizer.close()
        decoder.shutdown()
    }
}
