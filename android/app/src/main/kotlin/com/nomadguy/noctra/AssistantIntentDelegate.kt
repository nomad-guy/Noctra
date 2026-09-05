package com.nomadguy.noctra

import android.app.SearchManager
import android.content.Intent
import android.os.Bundle
import android.util.Log
import io.flutter.plugin.common.BinaryMessenger
import io.flutter.plugin.common.MethodChannel

/**
 * Handles incoming Assistant/voice search intents (`android.media.action.MEDIA_PLAY_FROM_SEARCH`)
 * and routes them to Flutter's AssistantCommandRouter.
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

        if (action == "android.media.action.MEDIA_PLAY_FROM_SEARCH" ||
            action == "android.media.action.MEDIA_SEARCH" ||
            action == Intent.ACTION_SEARCH
        ) {
            val query = intent.getStringExtra(SearchManager.QUERY) ?: ""
            val extrasMap = bundleToMap(intent.extras)

            val payload = mapOf(
                "query" to query,
                "action" to action,
                "extras" to extrasMap
            )

            Log.d(TAG, "Captured media search intent: query='$query', extras=$extrasMap")

            val channel = methodChannel
            if (channel != null) {
                channel.invokeMethod("onMediaPlayFromSearch", payload)
            } else {
                pendingIntentData = payload
            }
            return true
        }
        return false
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
