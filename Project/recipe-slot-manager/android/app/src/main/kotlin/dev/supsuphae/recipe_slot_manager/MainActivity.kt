package dev.supsuphae.recipe_slot_manager

import android.content.Intent
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterActivity() {
    private var ptpChannel: PtpChannel? = null
    private var ocrChannel: OcrChannel? = null
    private var photoChannel: PhotoChannel? = null
    private var geocoderChannel: GeocoderChannel? = null

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
        val geocoder = GeocoderChannel(applicationContext)
        geocoderChannel = geocoder
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, GeocoderChannel.CHANNEL)
            .setMethodCallHandler(geocoder)
    }

    override fun onRequestPermissionsResult(
        requestCode: Int,
        permissions: Array<out String>,
        grantResults: IntArray,
    ) {
        if (photoChannel?.onPermissionResult(requestCode) == true) return
        super.onRequestPermissionsResult(requestCode, permissions, grantResults)
    }

    @Deprecated("FlutterActivity 가 아직 Activity Result API 대신 이 콜백을 넘긴다")
    override fun onActivityResult(requestCode: Int, resultCode: Int, data: Intent?) {
        if (photoChannel?.onActivityResult(requestCode, resultCode, data) == true) return
        @Suppress("DEPRECATION")
        super.onActivityResult(requestCode, resultCode, data)
    }

    override fun cleanUpFlutterEngine(flutterEngine: FlutterEngine) {
        ptpChannel?.dispose()
        ptpChannel = null
        ocrChannel?.dispose()
        ocrChannel = null
        photoChannel?.dispose()
        photoChannel = null
        geocoderChannel?.dispose()
        geocoderChannel = null
        super.cleanUpFlutterEngine(flutterEngine)
    }
}
