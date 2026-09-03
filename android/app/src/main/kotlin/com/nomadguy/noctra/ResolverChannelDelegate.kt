package com.nomadguy.noctra

import android.util.Log
import io.flutter.embedding.engine.dart.DartExecutor
import io.flutter.plugin.common.MethodChannel

object ResolverChannelDelegate {
    private const val TAG = "ResolverChannelDelegate"
    private const val RESOLVER_CHANNEL = "com.nomadguy.noctra/native_resolver"

    fun register(
        messenger: DartExecutor,
        safeResult: (MethodChannel.Result, () -> Any?) -> Unit
    ) {
        MethodChannel(messenger, RESOLVER_CHANNEL).setMethodCallHandler { call, result ->
            when (call.method) {
                "resolve320k" -> {
                    val title = call.argument<String>("title") ?: ""
                    val artist = call.argument<String>("artist") ?: ""
                    safeResult(result) { JioSaavnNativeEngine.resolveTrackStream(title, artist) }
                }
                "extractInnerTube" -> {
                    val videoId = call.argument<String>("videoId") ?: ""
                    safeResult(result) { NoctraNativeStreamEngine.extractInnerTubeStream(videoId) }
                }
                "fetchRadio" -> {
                    val videoId = call.argument<String>("videoId") ?: ""
                    safeResult(result) {
                        NoctraNativeStreamEngine.fetchRadioTracks(videoId) ?: emptyList<Map<String, Any>>()
                    }
                }
                "searchJioSaavn" -> {
                    val query = call.argument<String>("query") ?: ""
                    val limit = call.argument<Int>("limit") ?: 20
                    safeResult(result) {
                        JioSaavnNativeEngine.searchSongs(query, limit) ?: emptyList<Map<String, Any>>()
                    }
                }
                "decryptUrl" -> {
                    val encUrl = call.argument<String>("encryptedUrl") ?: ""
                    try {
                        result.success(JioSaavnNativeEngine.decryptMediaUrl(encUrl))
                    } catch (e: Throwable) {
                        Log.e(TAG, "decryptUrl failed", e)
                        result.success(null)
                    }
                }
                else -> result.notImplemented()
            }
        }
    }
}
