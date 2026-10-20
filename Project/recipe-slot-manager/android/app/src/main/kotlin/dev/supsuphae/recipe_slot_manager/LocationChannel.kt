package dev.supsuphae.recipe_slot_manager

import android.Manifest
import android.app.Activity
import android.content.Context
import android.content.pm.PackageManager
import android.location.Location
import android.location.LocationManager
import android.os.Build
import android.os.SystemClock
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel

/**
 * Dart `locator.dart` 의 요청으로 휴대폰 현재 위치를 한 번 받는다 (LocationManager).
 *
 * - `requestAccess`: 위치 권한(정확·대략)이 있으면 true, 없으면 요청 창을 띄우고 결과를 돌려준다
 * - `current`: `{latitude, longitude, accuracy}` 또는 받지 못하면 null.
 *   권한이 없으면 `denied`, 위치가 꺼져 있으면 `disabled` 오류
 */
class LocationChannel(private val activity: Activity) : MethodChannel.MethodCallHandler {
    companion object {
        const val CHANNEL = "recipe_slot_manager/location"
        private const val REQUEST_CODE = 4031

        /** API 29 이하에서 이보다 오래된 마지막 위치는 지금 위치로 쓰지 않는다. */
        private const val MAX_LAST_LOCATION_AGE_NANOS = 2L * 60 * 1_000_000_000
    }

    private val manager = activity.getSystemService(Context.LOCATION_SERVICE) as LocationManager
    private var pendingAccess: MethodChannel.Result? = null

    override fun onMethodCall(call: MethodCall, result: MethodChannel.Result) {
        when (call.method) {
            "requestAccess" -> requestAccess(result)
            "current" -> current(result)
            else -> result.notImplemented()
        }
    }

    /** 대략적 위치만 허용해도 true. */
    private fun granted() = listOf(
        Manifest.permission.ACCESS_FINE_LOCATION,
        Manifest.permission.ACCESS_COARSE_LOCATION,
    ).any { activity.checkSelfPermission(it) == PackageManager.PERMISSION_GRANTED }

    private fun requestAccess(result: MethodChannel.Result) {
        if (granted()) return result.success(true)
        if (pendingAccess != null) return result.error("busy", "권한 요청이 진행 중이다", null)
        pendingAccess = result
        // 함께 요청해야 Android 12+ 에서 "정확한 위치"와 "대략적 위치"를 고를 수 있다.
        activity.requestPermissions(
            arrayOf(
                Manifest.permission.ACCESS_FINE_LOCATION,
                Manifest.permission.ACCESS_COARSE_LOCATION,
            ),
            REQUEST_CODE,
        )
    }

    /** [MainActivity.onRequestPermissionsResult] 가 넘긴다. 이 채널의 요청이면 true. */
    fun onPermissionResult(requestCode: Int): Boolean {
        if (requestCode != REQUEST_CODE) return false
        pendingAccess?.success(granted())
        pendingAccess = null
        return true
    }

    private fun current(result: MethodChannel.Result) {
        if (!granted()) return result.error("denied", "위치 권한이 없다", null)
        // passive 는 위치를 꺼도 목록에 남고 스스로 위치를 구하지 않으므로 뺀다.
        val providers = manager.getProviders(true) - LocationManager.PASSIVE_PROVIDER
        val enabled = if (Build.VERSION.SDK_INT >= 28) manager.isLocationEnabled else true
        if (!enabled || providers.isEmpty()) {
            return result.error("disabled", "위치가 꺼져 있다", null)
        }
        try {
            if (Build.VERSION.SDK_INT >= 30) {
                val provider = when {
                    Build.VERSION.SDK_INT >= 31 && LocationManager.FUSED_PROVIDER in providers ->
                        LocationManager.FUSED_PROVIDER
                    LocationManager.GPS_PROVIDER in providers -> LocationManager.GPS_PROVIDER
                    LocationManager.NETWORK_PROVIDER in providers -> LocationManager.NETWORK_PROVIDER
                    else -> providers.first()
                }
                // 결과는 메인 스레드에서 받는다.
                manager.getCurrentLocation(provider, null, activity.mainExecutor) {
                    result.success(fields(it))
                }
            } else {
                // API 29 이하는 한 번 받기 API 가 없어 가장 최근 위치를 쓴다. 오래된 위치는 버린다.
                val now = SystemClock.elapsedRealtimeNanos()
                val last = providers.mapNotNull { manager.getLastKnownLocation(it) }
                    .filter { now - it.elapsedRealtimeNanos <= MAX_LAST_LOCATION_AGE_NANOS }
                    .maxByOrNull { it.elapsedRealtimeNanos }
                result.success(fields(last))
            }
        } catch (e: SecurityException) {
            result.error("denied", e.message, null)
        }
    }

    private fun fields(location: Location?): Map<String, Double>? = location?.let {
        buildMap {
            put("latitude", it.latitude)
            put("longitude", it.longitude)
            if (it.hasAccuracy()) put("accuracy", it.accuracy.toDouble())
        }
    }

    /** 액티비티가 끝날 때 부른다. 기다리는 권한 요청이 있으면 거부로 끝낸다. */
    fun dispose() {
        pendingAccess?.success(false)
        pendingAccess = null
    }
}
