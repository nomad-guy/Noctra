package com.nomadguy.noctra

import android.content.Intent
import android.util.Log
import com.ryanheise.audioservice.AudioServiceActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import java.util.concurrent.Executors

// AudioServiceActivity provides audio_service's shared FlutterEngine. With a
// plain FlutterActivity, audio_service's engine cache is empty on cold start
// and it spins up a SECOND engine running main() again (double service
// instances, MissingPluginException, duplicated session restores).
class MainActivity : AudioServiceActivity() {
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

    // Field-initialized (not in onCreate) because with AudioServiceActivity the
    // engine is provided/configured before onCreate returns.
    private val visualizerDelegate = VisualizerChannelDelegate(effectsEngine)
    private val assistantDelegate = AssistantIntentDelegate()

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

        // 8. Assistant / Voice search intent channel
        assistantDelegate.register(messenger)
        assistantDelegate.handleIntent(intent)
    }

    override fun onNewIntent(intent: Intent) {
        super.onNewIntent(intent)
        setIntent(intent)
        assistantDelegate.handleIntent(intent)
    }

    override fun onDestroy() {
        try { visualizerDelegate.release() } catch (e: Throwable) {
            Log.w(TAG, "visualizerDelegate.release() failed in onDestroy", e)
        }
        try { audioRouter?.stopListening() } catch (e: Throwable) {
            Log.w(TAG, "audioRouter.stopListening() failed in onDestroy", e)
        }
        try { effectsEngine.release() } catch (e: Throwable) {
            Log.w(TAG, "effectsEngine.release() failed in onDestroy", e)
        }
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
