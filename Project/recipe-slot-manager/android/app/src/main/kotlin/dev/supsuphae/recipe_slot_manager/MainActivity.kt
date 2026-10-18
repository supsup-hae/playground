package dev.supsuphae.recipe_slot_manager

import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterActivity() {
    private var ptpChannel: PtpChannel? = null

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        val channel = PtpChannel(applicationContext)
        ptpChannel = channel
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, PtpChannel.CHANNEL)
            .setMethodCallHandler(channel)
    }

    override fun cleanUpFlutterEngine(flutterEngine: FlutterEngine) {
        ptpChannel?.dispose()
        ptpChannel = null
        super.cleanUpFlutterEngine(flutterEngine)
    }
}
