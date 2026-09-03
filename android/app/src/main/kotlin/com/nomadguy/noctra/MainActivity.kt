package com.nomadguy.noctra

import android.os.Bundle
import android.util.Log
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import java.util.concurrent.Executors

class MainActivity : FlutterActivity() {
    companion object {
        private const val TAG = "MainActivity"
        private const val STEM_CHANNEL = "com.nomadguy.noctra/audio_stem_separation"
        private const val QUALITY_CHANNEL = "com.nomadguy.noctra/audio_quality"
    }

    private val iconExecutor = Executors.newSingleThreadExecutor()
    private val nativeExecutor = Executors.newFixedThreadPool(4)
    private lateinit var launcherIconManager: LauncherIconManager
    private var audioRouter: NoctraAudioRouter? = null
    private val effectsEngine = NoctraAudioEffectsEngine()
    private lateinit var visualizerDelegate: VisualizerChannelDelegate

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        visualizerDelegate = VisualizerChannelDelegate(effectsEngine)
    }

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        launcherIconManager = LauncherIconManager(applicationContext)
        try {
            audioRouter = NoctraAudioRouter(applicationContext)
        } catch (e: Throwable) {
            Log.e(TAG, "AudioRouter init failed", e)
        }

        val messenger = flutterEngine.dartExecutor

        // 1. Visualizer EventChannel
        visualizerDelegate.register(messenger)

        // 2. Audio devices, effects, and router channels
        AudioChannelsDelegate.register(messenger, audioRouter, effectsEngine)

        // 3. Stream resolver channel
        ResolverChannelDelegate.register(messenger, ::safeResult)

        // 4. Update notifications, signing cert, and installer check
        InstallerChannelDelegate.register(this, messenger)

        // 5. Dynamic launcher icon switching
        LauncherIconChannelDelegate.register(this, messenger, launcherIconManager, iconExecutor)

        // 6. Audio stem separation
        MethodChannel(messenger, STEM_CHANNEL).setMethodCallHandler { call, result ->
            when (call.method) {
                "separateStems" -> {
                    val inputPath = call.argument<String>("inputPath") ?: ""
                    val outputDir = call.argument<String>("outputDir") ?: ""
                    val model = call.argument<String>("model") ?: "light"
                    safeResult(result) {
                        NoctraAudioStemEngine.separateStems(inputPath, outputDir, model)
                    }
                }
                else -> result.notImplemented()
            }
        }

        // 7. Audio quality / preferred bitrate & codec
        MethodChannel(messenger, QUALITY_CHANNEL).setMethodCallHandler { call, result ->
            when (call.method) {
                "setStreamQuality" -> {
                    val bitrate = call.argument<Int>("bitrate") ?: 320
                    val codec = call.argument<String>("codec") ?: "mp3"
                    val prefs = getSharedPreferences("noctra_audio_quality", MODE_PRIVATE)
                    prefs.edit().putInt("preferred_bitrate", bitrate)
                        .putString("preferred_codec", codec).apply()
                    result.success(true)
                }
                "setPreferredCodec" -> {
                    val codec = call.argument<String>("codec") ?: "mp3"
                    val prefs = getSharedPreferences("noctra_audio_quality", MODE_PRIVATE)
                    prefs.edit().putString("preferred_codec", codec).apply()
                    result.success(true)
                }
                else -> result.notImplemented()
            }
        }
    }

    override fun onDestroy() {
        try { visualizerDelegate.release() } catch (_: Throwable) {}
        try { audioRouter?.stopListening() } catch (_: Throwable) {}
        try { effectsEngine.release() } catch (_: Throwable) {}
        iconExecutor.shutdownNow()
        nativeExecutor.shutdownNow()
        super.onDestroy()
    }

    private fun safeResult(result: MethodChannel.Result, block: () -> Any?) {
        nativeExecutor.execute {
            try {
                val data = block()
                runOnUiThread {
                    try {
                        result.success(data)
                    } catch (e: Throwable) {
                        Log.e(TAG, "MethodChannel result callback failed", e)
                    }
                }
            } catch (e: Throwable) {
                Log.e(TAG, "Native resolver block failed", e)
                runOnUiThread {
                    try {
                        result.success(null)
                    } catch (e2: Throwable) {
                        Log.e(TAG, "Failed to send null result", e2)
                    }
                }
            }
        }
    }
}
