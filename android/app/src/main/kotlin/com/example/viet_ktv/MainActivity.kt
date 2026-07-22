package com.example.viet_ktv

import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel
import vn.kod.vkmusic.MusicSDK
import vn.kod.vkmusic.MusicSearchItem

class MainActivity : FlutterActivity() {
    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)

        MethodChannel(
            flutterEngine.dartExecutor.binaryMessenger,
            CHANNEL_NAME,
        ).setMethodCallHandler(::onMethodCall)
    }

    private fun onMethodCall(call: MethodCall, result: MethodChannel.Result) {
        when (call.method) {
            "init" -> initializeSdk(call, result)
            "search" -> search(call, result)
            "getPlayableLink" -> getPlayableLink(call, result)
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

        MusicSDK.init(
            applicationContext,
            licenseKey,
            object : MusicSDK.ResultCallback<Boolean> {
                override fun onSuccess(value: Boolean) {
                    isInitialized = value
                    runOnUiThread { result.success(value) }
                }

                override fun onError(error: Throwable) {
                    runOnUiThread {
                        result.error(
                            "music_sdk_init_failed",
                            error.message ?: "MusicSDK initialization failed.",
                            error.stackTraceToString(),
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

        val callback = object : MusicSDK.ResultCallback<List<MusicSearchItem>> {
            override fun onSuccess(value: List<MusicSearchItem>) {
                val mapped = value.map { item ->
                    hashMapOf<String, Any?>(
                        "id" to item.videoId,
                        "title" to item.title,
                        "subtitle" to sourceDisplayName(source),
                        "duration" to formatDuration(item.duration),
                        "imageUrl" to item.imageUrl,
                        "badge" to null,
                    )
                }
                runOnUiThread { result.success(mapped) }
            }

            override fun onError(error: Throwable) {
                runOnUiThread {
                    result.error(
                        "music_sdk_search_failed",
                        error.message ?: "MusicSDK search failed.",
                        error.stackTraceToString(),
                    )
                }
            }
        }

        when (source) {
            SOURCE_YOUTUBE -> MusicSDK.searchYoutube(query, callback)
            SOURCE_SOUNDCLOUD -> MusicSDK.searchSoundCloud(query, callback)
            SOURCE_MIXCLOUD -> MusicSDK.searchMixCloud(query, callback)
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

        val callback = object : MusicSDK.ResultCallback<String> {
            override fun onSuccess(value: String) {
                runOnUiThread { result.success(value) }
            }

            override fun onError(error: Throwable) {
                runOnUiThread {
                    result.error(
                        "music_sdk_playable_link_failed",
                        error.message ?: "MusicSDK playable link lookup failed.",
                        error.stackTraceToString(),
                    )
                }
            }
        }

        when (source) {
            SOURCE_YOUTUBE -> MusicSDK.getYoutubeLink(trackId, callback)
            SOURCE_SOUNDCLOUD -> MusicSDK.getSoundCloudLink(trackId, callback)
            SOURCE_MIXCLOUD -> MusicSDK.getMixCloudLink(trackId, callback)
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
            SOURCE_MIXCLOUD -> "MixCloud"
            else -> source
        }
    }

    companion object {
        private const val CHANNEL_NAME = "viet_ktv/music_sdk"
        private const val SOURCE_YOUTUBE = "youtube"
        private const val SOURCE_SOUNDCLOUD = "soundcloud"
        private const val SOURCE_MIXCLOUD = "mixcloud"

        private var isInitialized: Boolean = false
    }
}
