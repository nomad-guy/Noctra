package com.nomadguy.noctra

import android.util.Log
import io.flutter.embedding.engine.dart.DartExecutor
import io.flutter.plugin.common.EventChannel
import io.flutter.plugin.common.MethodChannel

object AudioChannelsDelegate {
    private const val TAG = "AudioChannelsDelegate"
    private const val DEVICES_EVENT_CHANNEL = "com.nomadguy.noctra/audio_devices"
    private const val EFFECTS_CHANNEL = "com.nomadguy.noctra/audio_effects"
    private const val ROUTER_CHANNEL = "com.nomadguy.noctra/audio_router"

    fun register(
        messenger: DartExecutor,
        audioRouter: NoctraAudioRouter?,
        effectsEngine: NoctraAudioEffectsEngine
    ) {
        // ====== AUDIO DEVICES EVENT ======
        EventChannel(messenger, DEVICES_EVENT_CHANNEL).setStreamHandler(object : EventChannel.StreamHandler {
            override fun onListen(arguments: Any?, events: EventChannel.EventSink?) {
                try {
                    audioRouter?.startListening(events)
                } catch (e: Throwable) {
                    Log.e(TAG, "AudioRouter listen failed", e)
                }
            }

            override fun onCancel(arguments: Any?) {
                try {
                    audioRouter?.stopListening()
                } catch (e: Throwable) {
                    Log.e(TAG, "AudioRouter cancel failed", e)
                }
            }
        })

        // ====== AUDIO EFFECTS ======
        MethodChannel(messenger, EFFECTS_CHANNEL).setMethodCallHandler { call, result ->
            when (call.method) {
                "attachSession" -> {
                    val sid = call.argument<Int>("sessionId") ?: 0
                    result.success(effectsEngine.attachSession(sid))
                }
                "applyEqualizer" -> {
                    val bands = call.argument<List<Double>>("bands") ?: emptyList()
                    val bass = call.argument<Double>("bassBoost") ?: 0.0
                    val virt = call.argument<Double>("virtualizer") ?: 0.0
                    result.success(effectsEngine.applyBands(bands, bass, virt))
                }
                "applyStudioMode" -> {
                    val mode = call.argument<String>("mode") ?: "off"
                    result.success(effectsEngine.applyPresetMode(mode))
                }
                else -> result.notImplemented()
            }
        }

        // ====== AUDIO ROUTER ======
        MethodChannel(messenger, ROUTER_CHANNEL).setMethodCallHandler { call, result ->
            try {
                when (call.method) {
                    "getConnectedDevices" -> result.success(
                        audioRouter?.getConnectedAudioDevices() ?: emptyList<Map<String, Any>>()
                    )
                    "setOutputDevice" -> {
                        val deviceId = call.argument<Int>("deviceId") ?: 0
                        result.success(audioRouter?.setPreferredOutputDevice(deviceId) ?: false)
                    }
                    "setMultiOutput" -> {
                        val enabled = call.argument<Boolean>("enabled") ?: false
                        val ids = call.argument<List<Int>>("deviceIds") ?: emptyList()
                        result.success(audioRouter?.setMultiOutputMode(enabled, ids) ?: false)
                    }
                    "openSystemMediaSwitcher" -> {
                        result.success(audioRouter?.openSystemMediaOutputSwitcher() ?: false)
                    }
                    else -> result.notImplemented()
                }
            } catch (e: Throwable) {
                Log.e(TAG, "Router channel error", e)
                result.success(false)
            }
        }
    }
}
