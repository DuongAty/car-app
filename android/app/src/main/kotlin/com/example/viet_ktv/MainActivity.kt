package com.example.viet_ktv

import android.content.Intent
import android.net.ConnectivityManager
import android.net.NetworkCapabilities
import android.os.Build
import android.os.Environment
import android.os.StatFs
import com.ryanheise.audioservice.AudioServiceActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel
import org.json.JSONArray
import org.json.JSONObject
import vn.kod.vkmusic.VkMusicLib

class MainActivity : AudioServiceActivity() {
    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)

        MethodChannel(
            flutterEngine.dartExecutor.binaryMessenger,
            CHANNEL_NAME,
        ).setMethodCallHandler(::onMethodCall)
        MethodChannel(
            flutterEngine.dartExecutor.binaryMessenger,
            SYSTEM_CHANNEL_NAME,
        ).setMethodCallHandler(::onSystemMethodCall)
    }

    private fun onMethodCall(call: MethodCall, result: MethodChannel.Result) {
        when (call.method) {
            "init" -> initializeSdk(call, result)
            "search" -> search(call, result)
            "getPlayableLink" -> getPlayableLink(call, result)
            else -> result.notImplemented()
        }
    }

    private fun onSystemMethodCall(call: MethodCall, result: MethodChannel.Result) {
        when (call.method) {
            "getSystemInfo" -> result.success(systemInfo())
            "restartApp" -> restartApp(result)
            "shutdownDevice" -> shutdownDevice(result)
            "requestNotificationPermission" -> requestNotificationPermission(result)
            else -> result.notImplemented()
        }
    }

    private fun initializeSdk(call: MethodCall, result: MethodChannel.Result) {
        val licenseKey = call.argument<String>("licenseKey")?.trim()
        if (licenseKey.isNullOrEmpty()) {
            result.error(
                "music_sdk_invalid_license_key",
                "A non-empty MusicSDK license key is required.",
                null,
            )
            return
        }

        VkMusicLib.init(
            applicationContext.packageName,
            licenseKey,
            object : VkMusicLib.Callback {
                override fun onSuccess(value: String?) {
                    isInitialized = true
                    runOnUiThread { result.success(true) }
                }

                override fun onError(error: String) {
                    runOnUiThread {
                        result.error(
                            "music_sdk_init_failed",
                            error.ifBlank { "MusicSDK initialization failed." },
                            null,
                        )
                    }
                }
            },
        )
    }

    private fun search(call: MethodCall, result: MethodChannel.Result) {
        if (!ensureInitialized(result)) {
            return
        }

        val source = call.argument<String>("source")
        val query = call.argument<String>("query")?.trim()
        if (source.isNullOrEmpty() || query.isNullOrEmpty()) {
            result.error(
                "music_sdk_invalid_search_args",
                "Search requires both a source and a non-empty query.",
                null,
            )
            return
        }

        val callback = object : VkMusicLib.Callback {
            override fun onSuccess(value: String?) {
                try {
                    runOnUiThread { result.success(parseSearchResults(value.orEmpty(), source)) }
                } catch (error: Throwable) {
                    runOnUiThread {
                        result.error(
                            "music_sdk_search_parse_failed",
                            error.message ?: "MusicSDK search response parsing failed.",
                            error.stackTraceToString(),
                        )
                    }
                }
            }

            override fun onError(error: String) {
                runOnUiThread {
                    result.error(
                        "music_sdk_search_failed",
                        error.ifBlank { "MusicSDK search failed." },
                        null,
                    )
                }
            }
        }

        when (source) {
            SOURCE_YOUTUBE -> VkMusicLib.searchYoutube(query, callback)
            SOURCE_SOUNDCLOUD -> VkMusicLib.searchSoundCloud(query, callback)
            else -> result.error(
                "music_sdk_unknown_source",
                "Unsupported MusicSDK source: $source",
                null,
            )
        }
    }

    private fun getPlayableLink(call: MethodCall, result: MethodChannel.Result) {
        if (!ensureInitialized(result)) {
            return
        }

        val source = call.argument<String>("source")
        val trackId = call.argument<String>("trackId")?.trim()
        if (source.isNullOrEmpty() || trackId.isNullOrEmpty()) {
            result.error(
                "music_sdk_invalid_playable_link_args",
                "Playable link requests require both a source and a track id.",
                null,
            )
            return
        }

        val callback = object : VkMusicLib.Callback {
            override fun onSuccess(value: String?) {
                runOnUiThread { result.success(value.orEmpty()) }
            }

            override fun onError(error: String) {
                runOnUiThread {
                    result.error(
                        "music_sdk_playable_link_failed",
                        error.ifBlank { "MusicSDK playable link lookup failed." },
                        null,
                    )
                }
            }
        }

        when (source) {
            SOURCE_YOUTUBE -> VkMusicLib.getYoutubeLink(trackId, callback)
            SOURCE_SOUNDCLOUD -> VkMusicLib.getSoundCloudLink(trackId, callback)
            else -> result.error(
                "music_sdk_unknown_source",
                "Unsupported MusicSDK source: $source",
                null,
            )
        }
    }

    private fun ensureInitialized(result: MethodChannel.Result): Boolean {
        if (isInitialized) {
            return true
        }

        result.error(
            "music_sdk_not_initialized",
            "MusicSDK must be initialized before use.",
            null,
        )
        return false
    }

    private fun parseSearchResults(response: String, source: String): List<HashMap<String, Any?>> {
        if (response.isBlank()) {
            return emptyList()
        }

        val items = JSONArray(response)
        return List(items.length()) { index ->
            val item = items.optJSONObject(index) ?: JSONObject()
            hashMapOf(
                "id" to item.optString("video_id"),
                "title" to item.optString("title"),
                "subtitle" to sourceDisplayName(source),
                "duration" to formatDuration(item.optInt("duration", 0)),
                "imageUrl" to item.optString("img_url"),
                "badge" to null,
            )
        }
    }

    private fun formatDuration(durationSeconds: Int): String {
        val hours = durationSeconds / 3600
        val minutes = (durationSeconds % 3600) / 60
        val seconds = durationSeconds % 60

        return if (hours > 0) {
            "%d:%02d:%02d".format(hours, minutes, seconds)
        } else {
            "%02d:%02d".format(minutes, seconds)
        }
    }

    private fun sourceDisplayName(source: String): String {
        return when (source) {
            SOURCE_YOUTUBE -> "YouTube"
            SOURCE_SOUNDCLOUD -> "SoundCloud"
            else -> source
        }
    }

    private fun systemInfo(): HashMap<String, Any?> {
        return hashMapOf(
            "networkStatus" to networkStatus(),
            "deviceName" to "${Build.MANUFACTURER} ${Build.MODEL}".trim(),
            "androidVersion" to "Android ${Build.VERSION.RELEASE} (API ${Build.VERSION.SDK_INT})",
            "appVersion" to appVersion(),
            "storageSummary" to storageSummary(),
        )
    }

    private fun networkStatus(): String {
        val manager = getSystemService(CONNECTIVITY_SERVICE) as? ConnectivityManager
            ?: return "Unavailable"
        val network = manager.activeNetwork ?: return "Offline"
        val capabilities = manager.getNetworkCapabilities(network) ?: return "Offline"
        return when {
            capabilities.hasTransport(NetworkCapabilities.TRANSPORT_WIFI) -> "WiFi"
            capabilities.hasTransport(NetworkCapabilities.TRANSPORT_ETHERNET) -> "Ethernet"
            capabilities.hasTransport(NetworkCapabilities.TRANSPORT_CELLULAR) -> "Mobile data"
            capabilities.hasCapability(NetworkCapabilities.NET_CAPABILITY_INTERNET) -> "Online"
            else -> "Offline"
        }
    }

    private fun appVersion(): String {
        return try {
            val info = packageManager.getPackageInfo(packageName, 0)
            "${info.versionName ?: "1.0.0"} (${info.longVersionCode})"
        } catch (_: Throwable) {
            "1.0.0"
        }
    }

    private fun storageSummary(): String {
        return try {
            val stat = StatFs(Environment.getDataDirectory().path)
            val total = stat.blockCountLong * stat.blockSizeLong
            val free = stat.availableBlocksLong * stat.blockSizeLong
            val used = total - free
            "${formatBytes(used)} / ${formatBytes(total)}"
        } catch (_: Throwable) {
            "--"
        }
    }

    private fun formatBytes(value: Long): String {
        val gib = value.toDouble() / 1024.0 / 1024.0 / 1024.0
        return "%.1fGB".format(gib)
    }

    private fun restartApp(result: MethodChannel.Result) {
        val intent = packageManager.getLaunchIntentForPackage(packageName)
        if (intent == null) {
            result.error("restart_unavailable", "Launch intent is unavailable.", null)
            return
        }
        intent.addFlags(Intent.FLAG_ACTIVITY_NEW_TASK or Intent.FLAG_ACTIVITY_CLEAR_TASK)
        startActivity(intent)
        finish()
        result.success(true)
    }

    private fun shutdownDevice(result: MethodChannel.Result) {
        try {
            val intent = Intent("android.intent.action.ACTION_REQUEST_SHUTDOWN")
            intent.putExtra("android.intent.extra.KEY_CONFIRM", true)
            startActivity(intent)
            result.success(true)
        } catch (error: Throwable) {
            result.error(
                "shutdown_unavailable",
                error.message ?: "Device firmware does not allow shutdown.",
                null,
            )
        }
    }

    /**
     * Android 13+ hides the media notification unless POST_NOTIFICATIONS is
     * granted. The foreground service still runs without it, so a denial is
     * reported rather than treated as an error.
     */
    private fun requestNotificationPermission(result: MethodChannel.Result) {
        if (Build.VERSION.SDK_INT < Build.VERSION_CODES.TIRAMISU) {
            result.success(true)
            return
        }
        if (checkSelfPermission(android.Manifest.permission.POST_NOTIFICATIONS) ==
            android.content.pm.PackageManager.PERMISSION_GRANTED
        ) {
            result.success(true)
            return
        }
        requestPermissions(
            arrayOf(android.Manifest.permission.POST_NOTIFICATIONS),
            NOTIFICATION_PERMISSION_REQUEST_CODE,
        )
        // The dialog is asynchronous; report the current (not yet granted)
        // state and let the next launch see the updated value.
        result.success(false)
    }

    companion object {
        private const val CHANNEL_NAME = "viet_ktv/music_sdk"
        private const val SYSTEM_CHANNEL_NAME = "viet_ktv/system"
        private const val SOURCE_YOUTUBE = "youtube"
        private const val SOURCE_SOUNDCLOUD = "soundcloud"
        private const val NOTIFICATION_PERMISSION_REQUEST_CODE = 1001

        private var isInitialized: Boolean = false
    }
}
