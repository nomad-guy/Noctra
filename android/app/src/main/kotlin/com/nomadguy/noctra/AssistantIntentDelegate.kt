package com.nomadguy.noctra

import android.app.SearchManager
import android.content.Intent
import android.os.Bundle
import android.util.Log
import io.flutter.plugin.common.BinaryMessenger
import io.flutter.plugin.common.MethodChannel

/**
 * Handles incoming Assistant, voice search, and deep link intents
 * (`android.media.action.MEDIA_PLAY_FROM_SEARCH`, `android.intent.action.VIEW`, etc.)
 * and reliably forwards them to Flutter's AssistantCommandRouter.
 */
class AssistantIntentDelegate {
    companion object {
        private const val TAG = "AssistantIntentDelegate"
        private const val CHANNEL = "com.nomadguy.noctra/assistant_intent"
    }

    private var methodChannel: MethodChannel? = null
    private var pendingIntentData: Map<String, Any?>? = null

    fun register(messenger: BinaryMessenger) {
        methodChannel = MethodChannel(messenger, CHANNEL).apply {
            setMethodCallHandler { call, result ->
                when (call.method) {
                    "getInitialIntent" -> {
                        val data = pendingIntentData
                        pendingIntentData = null
                        result.success(data)
                    }
                    else -> result.notImplemented()
                }
            }
        }
    }

    fun handleIntent(intent: Intent?): Boolean {
        if (intent == null) return false
        val action = intent.action ?: return false

        val isMediaSearch = action == "android.media.action.MEDIA_PLAY_FROM_SEARCH" ||
                action == "android.media.action.MEDIA_SEARCH" ||
                action == Intent.ACTION_SEARCH

        val isView = action == Intent.ACTION_VIEW

        if (!isMediaSearch && !isView) return false

        val extrasMap = bundleToMap(intent.extras)
        val query = intent.getStringExtra(SearchManager.QUERY)
            ?: intent.getStringExtra("query")
            ?: intent.getStringExtra("android.intent.extra.title")
            ?: intent.getStringExtra("music.recording.name")
            ?: ""

        val dataString = intent.dataString

        val payload = mapOf(
            "query" to query,
            "action" to action,
            "data" to dataString,
            "extras" to extrasMap
        )

        Log.d(TAG, "Captured assistant/media intent: action=$action, query='$query', data='$dataString'")

        // Always cache as pending intent to survive cold start
        pendingIntentData = payload

        // If channel is ready, notify Dart listener immediately
        val channel = methodChannel
        if (channel != null) {
            val method = if (isView) "onViewIntent" else "onMediaPlayFromSearch"
            channel.invokeMethod(method, payload)
        }
        return true
    }

    private fun bundleToMap(bundle: Bundle?): Map<String, Any?> {
        if (bundle == null) return emptyMap()
        val map = mutableMapOf<String, Any?>()
        for (key in bundle.keySet()) {
            val value = bundle.get(key)
            if (value is String || value is Number || value is Boolean) {
                map[key] = value
            } else if (value != null) {
                map[key] = value.toString()
            }
        }
        return map
    }
}
