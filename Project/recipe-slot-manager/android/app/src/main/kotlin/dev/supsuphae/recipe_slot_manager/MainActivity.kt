package dev.supsuphae.recipe_slot_manager

import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterActivity() {
    private var ptpChannel: PtpChannel? = null
    private var ocrChannel: OcrChannel? = null
    private var photoChannel: PhotoChannel? = null

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        val channel = PtpChannel(applicationContext)
        ptpChannel = channel
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, PtpChannel.CHANNEL)
            .setMethodCallHandler(channel)
        val ocr = OcrChannel()
        ocrChannel = ocr
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, OcrChannel.CHANNEL)
            .setMethodCallHandler(ocr)
        val photos = PhotoChannel(this)
        photoChannel = photos
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, PhotoChannel.CHANNEL)
            .setMethodCallHandler(photos)
    }

    override fun onRequestPermissionsResult(
        requestCode: Int,
        permissions: Array<out String>,
        grantResults: IntArray,
    ) {
        if (photoChannel?.onPermissionResult(requestCode) == true) return
        super.onRequestPermissionsResult(requestCode, permissions, grantResults)
    }

    override fun cleanUpFlutterEngine(flutterEngine: FlutterEngine) {
        ptpChannel?.dispose()
        ptpChannel = null
        ocrChannel?.dispose()
        ocrChannel = null
        photoChannel?.dispose()
        photoChannel = null
        super.cleanUpFlutterEngine(flutterEngine)
    }
}
