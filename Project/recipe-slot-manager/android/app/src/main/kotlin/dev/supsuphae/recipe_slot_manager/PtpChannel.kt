package dev.supsuphae.recipe_slot_manager

import android.app.PendingIntent
import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent
import android.content.IntentFilter
import android.hardware.usb.UsbConstants
import android.hardware.usb.UsbDevice
import android.hardware.usb.UsbDeviceConnection
import android.hardware.usb.UsbEndpoint
import android.hardware.usb.UsbInterface
import android.hardware.usb.UsbManager
import android.os.Build
import android.os.Handler
import android.os.Looper
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel
import java.util.concurrent.Executors

/**
 * Dart `AndroidPtpTransport` 와 USB bulk 바이트를 주고받는다.
 * 세션 열기와 컨테이너 조립·해석은 Dart 가 맡고, 여기서는 장치를 열고 바이트를 그대로 옮긴다.
 * USB 작업은 모두 한 작업 스레드에서 차례로 하고, 결과는 메인 스레드에서 돌려준다.
 */
class PtpChannel(private val context: Context) : MethodChannel.MethodCallHandler {
    companion object {
        const val CHANNEL = "recipe_slot_manager/ptp"
        private const val FUJIFILM_VENDOR_ID = 0x04CB
        private const val TRANSFER_TIMEOUT_MS = 5000

        /** 큰 데이터(RAF, 현상 결과)는 이 크기씩 나눠 주고받아, 한 번의 전송이 시간 제한 안에 끝나게 한다. */
        private const val CHUNK_SIZE = 1024 * 1024
        private const val ACTION_USB_PERMISSION =
            "dev.supsuphae.recipe_slot_manager.USB_PERMISSION"
    }

    /** 채널로 돌려줄 오류. [code] 는 Swift `PtpChannel` 과 같은 이름을 쓴다. */
    private class PtpError(val code: String, message: String) : Exception(message)

    private class Link(
        val device: UsbDevice,
        val connection: UsbDeviceConnection,
        val usbInterface: UsbInterface,
        val bulkIn: UsbEndpoint,
        val bulkOut: UsbEndpoint,
    )

    private val usb = context.getSystemService(Context.USB_SERVICE) as UsbManager
    private val worker = Executors.newSingleThreadExecutor()
    private val main = Handler(Looper.getMainLooper())

    /** 작업 스레드에서만 읽고 쓴다. */
    private var link: Link? = null

    /** 지금 연결한 카메라가 빠지면 연결을 정리한다. 다음 명령은 disconnected 로 끝난다. */
    private val detachReceiver = object : BroadcastReceiver() {
        override fun onReceive(context: Context, intent: Intent) {
            val detached = detachedDevice(intent) ?: return
            worker.execute {
                if (detached.deviceName == link?.device?.deviceName) close()
            }
        }
    }

    init {
        register(detachReceiver, IntentFilter(UsbManager.ACTION_USB_DEVICE_DETACHED))
    }

    /** 액티비티가 끝날 때 부른다. 리시버를 풀고, 연결을 닫고, 작업 스레드를 끝낸다. */
    fun dispose() {
        context.unregisterReceiver(detachReceiver)
        worker.execute { close() }
        worker.shutdown()
    }

    override fun onMethodCall(call: MethodCall, result: MethodChannel.Result) {
        when (call.method) {
            "open" -> open(result)
            "write" -> {
                val bytes = call.arguments as? ByteArray
                    ?: return result.error("arguments", "보낼 바이트가 없다", null)
                runOnWorker(result) { write(bytes); null }
            }
            "read" -> {
                val timeoutMs = (call.arguments as? Number)?.toInt() ?: TRANSFER_TIMEOUT_MS
                runOnWorker(result) { read(timeoutMs) }
            }
            "close" -> runOnWorker(result) { close(); null }
            else -> result.notImplemented()
        }
    }

    // ---------- open ----------

    private fun open(result: MethodChannel.Result) {
        val device = usb.deviceList.values.firstOrNull {
            it.vendorId == FUJIFILM_VENDOR_ID && stillImageInterface(it) != null
        }
        if (device == null) {
            result.error(
                "connect",
                "후지필름 카메라를 찾지 못했다. USB 연결과 PC 연결 모드를 확인할 것",
                null,
            )
            return
        }
        if (usb.hasPermission(device)) {
            runOnWorker(result) { connect(device) }
            return
        }
        requestPermission(device) { granted ->
            if (granted) {
                runOnWorker(result) { connect(device) }
            } else {
                result.error("permission", "USB 권한이 거부됐다", null)
            }
        }
    }

    private fun requestPermission(device: UsbDevice, onResult: (Boolean) -> Unit) {
        val receiver = object : BroadcastReceiver() {
            override fun onReceive(context: Context, intent: Intent) {
                context.unregisterReceiver(this)
                onResult(intent.getBooleanExtra(UsbManager.EXTRA_PERMISSION_GRANTED, false))
            }
        }
        register(receiver, IntentFilter(ACTION_USB_PERMISSION))
        // 시스템이 결과를 extra 로 넣으므로 mutable 이어야 하고, 그래서 명시적 intent 여야 한다.
        val flags = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.S) {
            PendingIntent.FLAG_MUTABLE
        } else {
            0
        }
        val intent = Intent(ACTION_USB_PERMISSION).setPackage(context.packageName)
        usb.requestPermission(device, PendingIntent.getBroadcast(context, 0, intent, flags))
    }

    /** 작업 스레드에서 장치를 열고 PTP 인터페이스를 잡는다. 이미 열려 있으면 닫고 다시 연다. */
    private fun connect(device: UsbDevice): Map<String, String> {
        close()
        val usbInterface = stillImageInterface(device)
            ?: throw PtpError("connect", "카메라에 PTP 인터페이스가 없다")
        val bulkIn = bulkEndpoint(usbInterface, UsbConstants.USB_DIR_IN)
        val bulkOut = bulkEndpoint(usbInterface, UsbConstants.USB_DIR_OUT)
        if (bulkIn == null || bulkOut == null) {
            throw PtpError("connect", "카메라에 bulk 엔드포인트가 없다")
        }
        val connection = usb.openDevice(device)
            ?: throw PtpError("connect", "USB 장치를 열지 못했다")
        // force: 기본 MTP 처리가 잡은 커널 드라이버를 떼어 낸다.
        if (!connection.claimInterface(usbInterface, true)) {
            connection.close()
            throw PtpError("connect", "다른 앱이 카메라를 쓰고 있다. 사진 가져오기 알림을 닫고 다시 연결할 것")
        }
        link = Link(device, connection, usbInterface, bulkIn, bulkOut)
        return mapOf("name" to (device.productName ?: "Fujifilm"))
    }

    private fun stillImageInterface(device: UsbDevice): UsbInterface? =
        (0 until device.interfaceCount)
            .map { device.getInterface(it) }
            .firstOrNull { it.interfaceClass == UsbConstants.USB_CLASS_STILL_IMAGE }

    private fun bulkEndpoint(usbInterface: UsbInterface, direction: Int): UsbEndpoint? =
        (0 until usbInterface.endpointCount)
            .map { usbInterface.getEndpoint(it) }
            .firstOrNull {
                it.type == UsbConstants.USB_ENDPOINT_XFER_BULK && it.direction == direction
            }

    // ---------- write / read / close ----------

    private fun write(bytes: ByteArray) {
        val current = requireLink()
        var offset = 0
        while (offset < bytes.size) {
            val sent = current.connection.bulkTransfer(
                current.bulkOut, bytes, offset, minOf(bytes.size - offset, CHUNK_SIZE),
                TRANSFER_TIMEOUT_MS,
            )
            // 0 이면 offset 이 늘지 않아 같은 바이트를 끝없이 보내게 된다.
            if (sent <= 0) throw PtpError("timeout", "USB 쓰기 시간 초과")
            offset += sent
        }
        // 길이가 패킷 크기의 배수면 0바이트 패킷으로 전송 끝을 알린다.
        if (bytes.size % current.bulkOut.maxPacketSize == 0) {
            current.connection.bulkTransfer(current.bulkOut, ByteArray(0), 0, TRANSFER_TIMEOUT_MS)
        }
    }

    private fun read(timeoutMs: Int): ByteArray {
        val current = requireLink()
        val buffer = ByteArray(CHUNK_SIZE)
        val received = current.connection.bulkTransfer(
            current.bulkIn, buffer, buffer.size, timeoutMs,
        )
        if (received < 0) throw PtpError("timeout", "USB 응답 시간 초과")
        return buffer.copyOf(received)
    }

    private fun close() {
        val current = link ?: return
        link = null
        current.connection.releaseInterface(current.usbInterface)
        current.connection.close()
    }

    private fun requireLink(): Link =
        link ?: throw PtpError("disconnected", "카메라가 연결되지 않았다")

    // ---------- 도우미 ----------

    private fun runOnWorker(result: MethodChannel.Result, task: () -> Any?) {
        worker.execute {
            try {
                val value = task()
                main.post { result.success(value) }
            } catch (e: PtpError) {
                main.post { result.error(e.code, e.message, null) }
            }
        }
    }

    private fun detachedDevice(intent: Intent): UsbDevice? =
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.TIRAMISU) {
            intent.getParcelableExtra(UsbManager.EXTRA_DEVICE, UsbDevice::class.java)
        } else {
            @Suppress("DEPRECATION")
            intent.getParcelableExtra(UsbManager.EXTRA_DEVICE)
        }

    private fun register(receiver: BroadcastReceiver, filter: IntentFilter) {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.TIRAMISU) {
            context.registerReceiver(receiver, filter, Context.RECEIVER_NOT_EXPORTED)
        } else {
            context.registerReceiver(receiver, filter)
        }
    }
}
