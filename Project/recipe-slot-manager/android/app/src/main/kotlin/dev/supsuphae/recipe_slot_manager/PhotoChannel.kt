package dev.supsuphae.recipe_slot_manager

import android.Manifest
import android.app.Activity
import android.content.pm.PackageManager
import android.net.Uri
import android.os.Build
import android.os.Handler
import android.os.Looper
import android.provider.MediaStore
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel
import java.util.concurrent.Executors

/**
 * Dart `album_reader.dart` 의 요청을 MediaStore 로 처리한다. JPEG 만 다룬다.
 *
 * - `requestAccess`: 사진 읽기·사진 위치 권한을 요청하고 `{images, location}` 을 돌려준다
 * - `albums`: JPEG 가 있는 버킷 `[{id, name, count}]`
 * - `photos(bucketId)`: `[{id: content URI, name, size, modified(ms)}]`
 * - `readHead({id, length})`: 앞 `length` 바이트와 `locationRedacted`. 위치 권한이 있으면 원본을 연다
 *
 * 쿼리와 읽기는 작업 스레드에서 하고, 결과는 메인 스레드로 돌려준다.
 */
class PhotoChannel(private val activity: Activity) : MethodChannel.MethodCallHandler {
    companion object {
        const val CHANNEL = "recipe_slot_manager/photos"
        private const val REQUEST_CODE = 4021
        private const val JPEG = "image/jpeg"
    }

    private val worker = Executors.newSingleThreadExecutor()
    private val main = Handler(Looper.getMainLooper())
    private var pendingAccess: MethodChannel.Result? = null

    private val imagePermission =
        if (Build.VERSION.SDK_INT >= 33) Manifest.permission.READ_MEDIA_IMAGES
        else Manifest.permission.READ_EXTERNAL_STORAGE

    override fun onMethodCall(call: MethodCall, result: MethodChannel.Result) {
        when (call.method) {
            "requestAccess" -> requestAccess(result)
            "albums" -> background(result) { albums() }
            "photos" -> {
                val bucket = call.arguments as? String
                    ?: return result.error("arguments", "앨범 id 가 없다", null)
                background(result) { photos(bucket) }
            }
            "readHead" -> {
                val id = call.argument<String>("id")
                val length = call.argument<Int>("length")
                if (id == null || length == null) {
                    return result.error("arguments", "사진 id 나 길이가 없다", null)
                }
                background(result) { readHead(Uri.parse(id), length) }
            }
            else -> result.notImplemented()
        }
    }

    private fun granted(permission: String) =
        activity.checkSelfPermission(permission) == PackageManager.PERMISSION_GRANTED

    private fun locationGranted() =
        Build.VERSION.SDK_INT < 29 || granted(Manifest.permission.ACCESS_MEDIA_LOCATION)

    private fun accessState() = mapOf(
        "images" to granted(imagePermission),
        "location" to locationGranted(),
    )

    private fun requestAccess(result: MethodChannel.Result) {
        val missing = buildList {
            if (!granted(imagePermission)) add(imagePermission)
            if (Build.VERSION.SDK_INT >= 29 && !locationGranted()) {
                add(Manifest.permission.ACCESS_MEDIA_LOCATION)
            }
        }
        if (missing.isEmpty()) return result.success(accessState())
        if (pendingAccess != null) return result.error("busy", "권한 요청이 진행 중이다", null)
        pendingAccess = result
        activity.requestPermissions(missing.toTypedArray(), REQUEST_CODE)
    }

    /** [MainActivity.onRequestPermissionsResult] 가 넘긴다. 이 채널의 요청이면 true. */
    fun onPermissionResult(requestCode: Int): Boolean {
        if (requestCode != REQUEST_CODE) return false
        pendingAccess?.success(accessState())
        pendingAccess = null
        return true
    }

    private fun requireImages() {
        if (!granted(imagePermission)) throw PermissionMissing()
    }

    private fun albums(): List<Map<String, Any>> {
        requireImages()
        val counts = linkedMapOf<String, Pair<String, Int>>()
        activity.contentResolver.query(
            MediaStore.Images.Media.EXTERNAL_CONTENT_URI,
            arrayOf(MediaStore.Images.Media.BUCKET_ID, MediaStore.Images.Media.BUCKET_DISPLAY_NAME),
            "${MediaStore.Images.Media.MIME_TYPE} = ?",
            arrayOf(JPEG),
            null,
        )?.use { cursor ->
            while (cursor.moveToNext()) {
                val id = cursor.getString(0) ?: continue
                val name = cursor.getString(1) ?: id
                val (_, count) = counts[id] ?: (name to 0)
                counts[id] = name to count + 1
            }
        }
        return counts.map { (id, value) -> mapOf("id" to id, "name" to value.first, "count" to value.second) }
    }

    private fun photos(bucket: String): List<Map<String, Any>> {
        requireImages()
        val collection = MediaStore.Images.Media.EXTERNAL_CONTENT_URI
        val photos = mutableListOf<Map<String, Any>>()
        activity.contentResolver.query(
            collection,
            arrayOf(
                MediaStore.Images.Media._ID,
                MediaStore.Images.Media.DISPLAY_NAME,
                MediaStore.Images.Media.SIZE,
                MediaStore.Images.Media.DATE_MODIFIED,
            ),
            "${MediaStore.Images.Media.BUCKET_ID} = ? AND ${MediaStore.Images.Media.MIME_TYPE} = ?",
            arrayOf(bucket, JPEG),
            null,
        )?.use { cursor ->
            while (cursor.moveToNext()) {
                photos += mapOf(
                    "id" to Uri.withAppendedPath(collection, cursor.getLong(0).toString()).toString(),
                    "name" to (cursor.getString(1) ?: ""),
                    "size" to cursor.getLong(2),
                    // DATE_MODIFIED 는 초 단위다.
                    "modified" to cursor.getLong(3) * 1000,
                )
            }
        }
        return photos
    }

    /** 위치 권한이 있으면 원본(위치 포함)을, 없거나 거부되면 위치가 지워진 사본을 읽는다. */
    private fun readHead(uri: Uri, length: Int): Map<String, Any> {
        requireImages()
        if (Build.VERSION.SDK_INT >= 29 && locationGranted()) {
            try {
                return mapOf("bytes" to read(MediaStore.setRequireOriginal(uri), length), "locationRedacted" to false)
            } catch (_: SecurityException) {
                // 원본 접근이 거부되면 아래의 사본으로 읽는다.
            }
        }
        return mapOf("bytes" to read(uri, length), "locationRedacted" to (Build.VERSION.SDK_INT >= 29))
    }

    private fun read(uri: Uri, length: Int): ByteArray =
        activity.contentResolver.openInputStream(uri)?.use { it.readNBytesCompat(length) }
            ?: throw java.io.FileNotFoundException(uri.toString())

    private fun java.io.InputStream.readNBytesCompat(length: Int): ByteArray {
        val buffer = ByteArray(length)
        var total = 0
        while (total < length) {
            val n = read(buffer, total, length - total)
            if (n < 0) break
            total += n
        }
        return buffer.copyOf(total)
    }

    private fun background(result: MethodChannel.Result, work: () -> Any) {
        worker.execute {
            val reply = runCatching(work)
            main.post {
                reply.fold(
                    onSuccess = { result.success(it) },
                    onFailure = { e ->
                        when (e) {
                            is PermissionMissing, is SecurityException ->
                                result.error("permission", e.message, null)
                            else -> result.error("io", e.message, null)
                        }
                    },
                )
            }
        }
    }

    private class PermissionMissing : Exception("사진 읽기 권한이 없다")

    /** 액티비티가 끝날 때 부른다. */
    fun dispose() {
        worker.shutdown()
        pendingAccess?.error("disposed", "액티비티가 끝났다", null)
        pendingAccess = null
    }
}
