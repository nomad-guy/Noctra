package com.nomadguy.noctra

import android.media.audiofx.Visualizer
import com.ryanheise.audioservice.AudioServiceActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.EventChannel
import io.flutter.plugin.common.MethodChannel
import kotlin.concurrent.thread

class MainActivity : AudioServiceActivity() {
    private val RESOLVER_CHANNEL = "com.noctra.app/native_resolver"
    private val ICON_CHANNEL = "com.noctra.app/launcher_icon"
    private val VISUALIZER_CHANNEL = "com.noctra.app/audio_visualizer"
    private val ROUTER_CHANNEL = "com.noctra.app/audio_router"
    private val DEVICES_EVENT_CHANNEL = "com.noctra.app/audio_devices"
    private var visualizer: Visualizer? = null
    private var audioRouter: NoctraAudioRouter? = null

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        try {
            audioRouter = NoctraAudioRouter(applicationContext)
        } catch (_: Throwable) {}

        // Native Hardware Audio Visualizer Event Stream (Safeguarded for Android 15/16)
        EventChannel(flutterEngine.dartExecutor.binaryMessenger, VISUALIZER_CHANNEL).setStreamHandler(object : EventChannel.StreamHandler {
            override fun onListen(arguments: Any?, events: EventChannel.EventSink?) {
                try {
                    val sessionId = (arguments as? Map<*, *>)?.get("sessionId") as? Int ?: 0
                    visualizer?.release()
                    visualizer = Visualizer(sessionId).apply {
                        captureSize = Visualizer.getCaptureSizeRange()[0]
                        setDataCaptureListener(object : Visualizer.OnDataCaptureListener {
                            override fun onWaveFormDataCapture(vis: Visualizer?, waveform: ByteArray?, samplingRate: Int) {
                                if (waveform != null && events != null) {
                                    val magnitudes = DoubleArray(32)
                                    val step = waveform.size / 32
                                    for (i in 0 until 32) {
                                        val idx = (i * step).coerceIn(0, waveform.size - 1)
                                        val sample = (waveform[idx].toInt() and 0xFF) - 128
                                        magnitudes[i] = (Math.abs(sample) / 128.0).coerceIn(0.0, 1.0)
                                    }
                                    runOnUiThread { try { events.success(magnitudes.toList()) } catch (_: Throwable) {} }
                                }
                            }
                            override fun onFftDataCapture(vis: Visualizer?, fft: ByteArray?, samplingRate: Int) {
                                if (fft != null && events != null) {
                                    val magnitudes = DoubleArray(32)
                                    val n = fft.size / 2
                                    for (i in 0 until 32) {
                                        val idx = (i * n) / 32
                                        val rk = fft[2 * idx].toDouble()
                                        val ik = fft[2 * idx + 1].toDouble()
                                        magnitudes[i] = (Math.hypot(rk, ik) / 128.0).coerceIn(0.0, 1.0)
                                    }
                                    runOnUiThread { try { events.success(magnitudes.toList()) } catch (_: Throwable) {} }
                                }
                            }
                        }, Visualizer.getMaxCaptureRate() / 2, true, true)
                        enabled = true
                    }
                } catch (_: Throwable) {
                    // Safe fallback on Android 15/16 if permission or audio session is restricted
                }
            }

            override fun onCancel(arguments: Any?) {
                try {
                    visualizer?.enabled = false
                    visualizer?.release()
                    visualizer = null
                } catch (_: Throwable) {}
            }
        })

        // Audio Device Event Channel (Real-time connection listener)
        EventChannel(flutterEngine.dartExecutor.binaryMessenger, DEVICES_EVENT_CHANNEL).setStreamHandler(object : EventChannel.StreamHandler {
            override fun onListen(arguments: Any?, events: EventChannel.EventSink?) {
                try { audioRouter?.startListening(events) } catch (_: Throwable) {}
            }
            override fun onCancel(arguments: Any?) {
                try { audioRouter?.stopListening() } catch (_: Throwable) {}
            }
        })

        // Audio Router Method Channel
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, ROUTER_CHANNEL).setMethodCallHandler { call, result ->
            try {
                when (call.method) {
                    "getConnectedDevices" -> {
                        val list = audioRouter?.getConnectedAudioDevices() ?: emptyList<Map<String, Any>>()
                        result.success(list)
                    }
                    "setOutputDevice" -> {
                        val deviceId = call.argument<Int>("deviceId") ?: 0
                        val ok = audioRouter?.setPreferredOutputDevice(deviceId) ?: false
                        result.success(ok)
                    }
                    "setMultiOutput" -> {
                        val enabled = call.argument<Boolean>("enabled") ?: false
                        val ids = call.argument<List<Int>>("deviceIds") ?: emptyList()
                        val ok = audioRouter?.setMultiOutputMode(enabled, ids) ?: false
                        result.success(ok)
                    }
                    else -> result.notImplemented()
                }
            } catch (t: Throwable) {
                result.success(false)
            }
        }

        // Native 320k Stream Resolver
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, RESOLVER_CHANNEL).setMethodCallHandler { call, result ->
            when (call.method) {
                "resolve320k" -> {
                    val title = call.argument<String>("title") ?: ""
                    val artist = call.argument<String>("artist") ?: ""
                    thread {
                        try {
                            val streamUrl = JioSaavnNativeEngine.resolveTrackStream(title, artist)
                            runOnUiThread { result.success(streamUrl) }
                        } catch (_: Throwable) {
                            runOnUiThread { result.success(null) }
                        }
                    }
                }
                "searchJioSaavn" -> {
                    val query = call.argument<String>("query") ?: ""
                    val limit = call.argument<Int>("limit") ?: 20
                    thread {
                        try {
                            val list = JioSaavnNativeEngine.searchSongs(query, limit)
                            runOnUiThread { result.success(list) }
                        } catch (_: Throwable) {
                            runOnUiThread { result.success(emptyList<Map<String, Any>>()) }
                        }
                    }
                }
                "decryptUrl" -> {
                    val encUrl = call.argument<String>("encryptedUrl") ?: ""
                    try {
                        val dec = JioSaavnNativeEngine.decryptMediaUrl(encUrl)
                        result.success(dec)
                    } catch (_: Throwable) {
                        result.success(null)
                    }
                }
                else -> result.notImplemented()
            }
        }

        // Non-destructive Launcher Icon Handler
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, ICON_CHANNEL).setMethodCallHandler { call, result ->
            if (call.method == "setLauncherIcon") {
                result.success(true)
            } else {
                result.notImplemented()
            }
        }
    }
}
