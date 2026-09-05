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
                "notifySessionChanged" -> {
                    // Dart pushes the current audio session id whenever
                    // the player swap stream fires. The visualizer
                    // delegate is the source of truth for that stream,
                    // so the Dart side forwards it here on every change
                    // so the effect graph is rebuilt even when no
                    // visualizer widget is mounted.
                    val sid = call.argument<Int>("sessionId") ?: 0
                    if (sid <= 0) {
                        result.success(false)
                    } else {
                        result.success(effectsEngine.attachSession(sid))
                    }
                }
                "applyEqualizer" -> {
                    val sid = call.argument<Int>("sessionId") ?: 0
                    if (sid > 0) {
                        effectsEngine.attachSession(sid)
                    }
                    val bands = call.argument<List<Double>>("bands") ?: emptyList()
                    val bass = call.argument<Double>("bassBoost") ?: 0.0
                    val virt = call.argument<Double>("virtualizer") ?: 0.0
                    result.success(effectsEngine.applyBands(bands, bass, virt))
                }
                "applyStudioMode" -> {
                    val sid = call.argument<Int>("sessionId") ?: 0
                    if (sid > 0) {
                        effectsEngine.attachSession(sid)
                    }
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
                        // Surface the structured RouteResult to the
                        // Dart side as a {ok: bool, status: String}
                        // map so the caller can distinguish "device
                        // not found" from "routing failed".
                        result.success(routeResultToMap(audioRouter?.setPreferredOutputDevice(deviceId)))
                    }
                    "setMultiOutput" -> {
                        val enabled = call.argument<Boolean>("enabled") ?: false
                        val ids = call.argument<List<Int>>("deviceIds") ?: emptyList()
                        if (!enabled || ids.isEmpty()) {
                            // Disabling multi-output: route to first
                            // device if any, otherwise no-op.
                            val firstId = ids.firstOrNull()
                            if (firstId == null) {
                                result.success(
                                    mapOf("ok" to true, "status" to "disabled_no_devices")
                                )
                            } else {
                                result.success(
                                    routeResultToMap(audioRouter?.setPreferredOutputDevice(firstId))
                                )
                            }
                        } else {
                            result.success(
                                speakerPlusBluetoothResultToMap(
                                    audioRouter?.enableSpeakerPlusBluetooth(ids)
                                )
                            )
                        }
                    }
                    "openSystemMediaSwitcher" -> {
                        result.success(audioRouter?.openSystemMediaOutputSwitcher() ?: false)
                    }
                    else -> result.notImplemented()
                }
            } catch (e: Throwable) {
                Log.e(TAG, "Router channel error", e)
                result.success(mapOf("ok" to false, "status" to "exception", "reason" to (e.message ?: "")))
            }
        }
    }

    private fun routeResultToMap(r: NoctraAudioRouter.RouteResult?): Map<String, Any> = when (r) {
        is NoctraAudioRouter.RouteResult.Ok -> mapOf("ok" to true, "status" to "ok")
        is NoctraAudioRouter.RouteResult.DeviceNotFound ->
            mapOf("ok" to false, "status" to "device_not_found")
        is NoctraAudioRouter.RouteResult.Failed ->
            mapOf("ok" to false, "status" to "failed", "reason" to r.reason)
        null -> mapOf("ok" to false, "status" to "no_router")
    }

    private fun speakerPlusBluetoothResultToMap(
        r: NoctraAudioRouter.SpeakerPlusBluetoothResult?
    ): Map<String, Any> = when (r) {
        is NoctraAudioRouter.SpeakerPlusBluetoothResult.Ok ->
            mapOf("ok" to true, "status" to "ok")
        is NoctraAudioRouter.SpeakerPlusBluetoothResult.NothingSelected ->
            mapOf("ok" to false, "status" to "nothing_selected")
        is NoctraAudioRouter.SpeakerPlusBluetoothResult.DeviceNotFound ->
            mapOf("ok" to false, "status" to "device_not_found")
        is NoctraAudioRouter.SpeakerPlusBluetoothResult.SpeakerOnly ->
            // API 31+ has no public multi-sink API. The speaker is on;
            // the user must use the system media output panel for
            // their Bluetooth device. The Dart side can offer that
            // affordance directly from this response.
            mapOf("ok" to true, "status" to "speaker_only", "needsSystemPanel" to true)
        is NoctraAudioRouter.SpeakerPlusBluetoothResult.SingleDeviceRouted ->
            mapOf("ok" to true, "status" to "single_device_routed")
        is NoctraAudioRouter.SpeakerPlusBluetoothResult.Failed ->
            mapOf("ok" to false, "status" to "failed", "reason" to r.reason)
        null -> mapOf("ok" to false, "status" to "no_router")
    }
}
