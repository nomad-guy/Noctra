package com.example.noctra

import android.content.ComponentName
import android.content.pm.PackageManager
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
    private var visualizer: Visualizer? = null

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)

        // Native Hardware Audio Visualizer Event Stream
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
                                    runOnUiThread {
                                        try { events.success(magnitudes.toList()) } catch (_: Exception) {}
                                    }
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
                                        val mag = Math.hypot(rk, ik) / 128.0
                                        magnitudes[i] = mag.coerceIn(0.0, 1.0)
                                    }
                                    runOnUiThread {
                                        try { events.success(magnitudes.toList()) } catch (_: Exception) {}
                                    }
                                }
                            }
                        }, Visualizer.getMaxCaptureRate() / 2, true, true)
                        enabled = true
                    }
                } catch (e: Exception) {
                    // Fallback gracefully
                }
            }

            override fun onCancel(arguments: Any?) {
                try {
                    visualizer?.enabled = false
                    visualizer?.release()
                    visualizer = null
                } catch (_: Exception) {}
            }
        })

        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, RESOLVER_CHANNEL).setMethodCallHandler { call, result ->
            when (call.method) {
                "resolve320k" -> {
                    val title = call.argument<String>("title") ?: ""
                    val artist = call.argument<String>("artist") ?: ""
                    thread {
                        val streamUrl = JioSaavnNativeEngine.resolveTrackStream(title, artist)
                        runOnUiThread { result.success(streamUrl) }
                    }
                }
                "searchJioSaavn" -> {
                    val query = call.argument<String>("query") ?: ""
                    val limit = call.argument<Int>("limit") ?: 20
                    thread {
                        val list = JioSaavnNativeEngine.searchSongs(query, limit)
                        runOnUiThread { result.success(list) }
                    }
                }
                "decryptUrl" -> {
                    val encUrl = call.argument<String>("encryptedUrl") ?: ""
                    val dec = JioSaavnNativeEngine.decryptMediaUrl(encUrl)
                    result.success(dec)
                }
                else -> result.notImplemented()
            }
        }

        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, ICON_CHANNEL).setMethodCallHandler { call, result ->
            if (call.method == "setLauncherIcon") {
                val isDark = call.argument<Boolean>("isDark") ?: (call.argument<String>("icon") != "NoirLight")
                thread {
                    try {
                        val pm = applicationContext.packageManager
                        val pkg = applicationContext.packageName
                        val darkAlias = ComponentName(pkg, "$pkg.MainActivityDark")
                        val lightAlias = ComponentName(pkg, "$pkg.MainActivityLight")

                        if (isDark) {
                            pm.setComponentEnabledSetting(darkAlias, PackageManager.COMPONENT_ENABLED_STATE_ENABLED, PackageManager.DONT_KILL_APP)
                            pm.setComponentEnabledSetting(lightAlias, PackageManager.COMPONENT_ENABLED_STATE_DISABLED, PackageManager.DONT_KILL_APP)
                        } else {
                            pm.setComponentEnabledSetting(lightAlias, PackageManager.COMPONENT_ENABLED_STATE_ENABLED, PackageManager.DONT_KILL_APP)
                            pm.setComponentEnabledSetting(darkAlias, PackageManager.COMPONENT_ENABLED_STATE_DISABLED, PackageManager.DONT_KILL_APP)
                        }
                        runOnUiThread { result.success(true) }
                    } catch (e: Exception) {
                        runOnUiThread { result.success(false) }
                    }
                }
            } else {
                result.notImplemented()
            }
        }
    }
}
