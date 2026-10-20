package dev.supsuphae.recipe_slot_manager

import android.content.Context
import android.location.Address
import android.location.Geocoder
import android.os.Build
import android.os.Handler
import android.os.Looper
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel
import java.io.IOException
import java.util.Locale
import java.util.concurrent.Executors

/**
 * Dart `geocoder.dart` 의 좌표를 한국어 주소 칸으로 바꾼다 (android.location.Geocoder).
 *
 * - `reverse({latitude, longitude})`: `{country, admin, locality, subLocality, thoroughfare}`
 *   (없는 칸은 빠짐) 또는 결과가 없으면 null. 기기에 주소 변환이 없으면 `unavailable`,
 *   네트워크 오류는 `network` 오류
 */
class GeocoderChannel(context: Context) : MethodChannel.MethodCallHandler {
    companion object {
        const val CHANNEL = "recipe_slot_manager/geocoder"
    }

    private val geocoder = Geocoder(context, Locale.KOREAN)
    private val worker = Executors.newSingleThreadExecutor()
    private val main = Handler(Looper.getMainLooper())

    override fun onMethodCall(call: MethodCall, result: MethodChannel.Result) {
        if (call.method != "reverse") return result.notImplemented()
        val latitude = call.argument<Double>("latitude")
        val longitude = call.argument<Double>("longitude")
        if (latitude == null || longitude == null) {
            return result.error("arguments", "좌표가 없다", null)
        }
        if (!Geocoder.isPresent()) {
            return result.error("unavailable", "이 기기에는 주소 변환 기능이 없다", null)
        }
        if (Build.VERSION.SDK_INT >= 33) {
            geocoder.getFromLocation(latitude, longitude, 1, object : Geocoder.GeocodeListener {
                override fun onGeocode(addresses: MutableList<Address>) {
                    main.post { result.success(fields(addresses.firstOrNull())) }
                }

                override fun onError(errorMessage: String?) {
                    main.post { result.error("network", errorMessage, null) }
                }
            })
        } else {
            worker.execute {
                val reply = runCatching {
                    @Suppress("DEPRECATION")
                    geocoder.getFromLocation(latitude, longitude, 1)?.firstOrNull()
                }
                main.post {
                    reply.fold(
                        onSuccess = { result.success(fields(it)) },
                        onFailure = { e ->
                            val code = if (e is IOException) "network" else "geocode"
                            result.error(code, e.message, null)
                        },
                    )
                }
            }
        }
    }

    /** 주소 칸을 채널 형식으로. locality 가 비면 subAdminArea 를 도시 칸으로 쓴다. */
    private fun fields(address: Address?): Map<String, String>? = address?.let {
        listOf(
            "country" to it.countryName,
            "admin" to it.adminArea,
            "locality" to (it.locality ?: it.subAdminArea),
            "subLocality" to it.subLocality,
            "thoroughfare" to it.thoroughfare,
        ).mapNotNull { (key, value) -> value?.let { key to it } }.toMap()
    }

    /** 액티비티가 끝날 때 부른다. */
    fun dispose() {
        worker.shutdown()
    }
}
