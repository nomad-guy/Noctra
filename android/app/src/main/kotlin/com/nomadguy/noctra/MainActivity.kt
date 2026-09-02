package com.nomadguy.noctra

import android.app.NotificationChannel
import android.app.NotificationManager
import android.app.PendingIntent
import android.content.Intent
import android.media.audiofx.Visualizer
import android.util.Log
import androidx.core.app.NotificationCompat
import com.ryanheise.audioservice.AudioServiceActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.EventChannel
import io.flutter.plugin.common.MethodChannel
import java.util.concurrent.Executors

class MainActivity : AudioServiceActivity() {

    companion object {
        private const val TAG = "NoctraMainActivity"
    }

    private val RESOLVER_CHANNEL = "com.nomadguy.noctra/native_resolver"
    private val ICON_CHANNEL = "com.nomadguy.noctra/launcher_icon"
    private val UPDATE_NOTIFY_CHANNEL = "com.nomadguy.noctra/update_notify"
    private val VISUALIZER_CHANNEL = "com.nomadguy.noctra/audio_visualizer"
    private val ROUTER_CHANNEL = "com.nomadguy.noctra/audio_router"
    private val DEVICES_EVENT_CHANNEL = "com.nomadguy.noctra/audio_devices"
    private val EFFECTS_CHANNEL = "com.nomadguy.noctra/audio_effects"
    private val STEM_CHANNEL = "com.nomadguy.noctra/audio_stem_separation"
    private val QUALITY_CHANNEL = "com.nomadguy.noctra/audio_quality"

    /** Delegates icon changes — serialized, no race conditions. */
    private lateinit var launcherIconManager: LauncherIconManager
    private val iconExecutor = Executors.newSingleThreadExecutor()
    /** Shared executor for native resolver operations (replaces raw Thread). */
    private val nativeExecutor = Executors.newCachedThreadPool()

    private var visualizer: Visualizer? = null
    private var audioRouter: NoctraAudioRouter? = null
    private val effectsEngine = NoctraAudioEffectsEngine()

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        launcherIconManager = LauncherIconManager(applicationContext)
        try { audioRouter = NoctraAudioRouter(applicationContext) } catch (e: Throwable) {
            Log.e(TAG, "AudioRouter init failed", e)
        }

        // ====== VISUALIZER ======
        EventChannel(flutterEngine.dartExecutor.binaryMessenger, VISUALIZER_CHANNEL).setStreamHandler(object : EventChannel.StreamHandler {
            override fun onListen(arguments: Any?, events: EventChannel.EventSink?) {
                try {
                    val sessionId = (arguments as? Map<*, *>)?.get("sessionId") as? Int ?: 0
                    if (sessionId <= 0) return
                    effectsEngine.attachSession(sessionId)
                    visualizer?.release()
                    val ranges = Visualizer.getCaptureSizeRange()
                    val capSize = if (ranges.size > 1) ranges[1] else ranges[0]
                    visualizer = Visualizer(sessionId).apply {
                        captureSize = capSize
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
                                    runOnUiThread { try { events.success(magnitudes.toList()) } catch (e: Throwable) { Log.e(TAG, "Visualizer event failed", e) } }
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
                                        val raw = (Math.hypot(rk, ik) / 64.0).coerceIn(0.0, 1.0)
                                        magnitudes[i] = Math.pow(raw, 0.75)
                                    }
                                    runOnUiThread { try { events.success(magnitudes.toList()) } catch (e: Throwable) { Log.e(TAG, "FFT event failed", e) } }
                                }
                            }
                        }, Visualizer.getMaxCaptureRate() / 2, true, true)
                        enabled = true
                    }
                } catch (e: Throwable) { Log.e(TAG, "Visualizer setup failed", e) }
            }

            override fun onCancel(arguments: Any?) {
                try {
                    visualizer?.enabled = false
                    visualizer?.release()
                    visualizer = null
                } catch (e: Throwable) { Log.e(TAG, "Visualizer cleanup failed", e) }
            }
        })

        // ====== AUDIO DEVICES EVENT ======
        EventChannel(flutterEngine.dartExecutor.binaryMessenger, DEVICES_EVENT_CHANNEL).setStreamHandler(object : EventChannel.StreamHandler {
            override fun onListen(arguments: Any?, events: EventChannel.EventSink?) {
                try { audioRouter?.startListening(events) } catch (e: Throwable) { Log.e(TAG, "AudioRouter listen failed", e) }
            }
            override fun onCancel(arguments: Any?) {
                try { audioRouter?.stopListening() } catch (e: Throwable) { Log.e(TAG, "AudioRouter cancel failed", e) }
            }
        })

        // ====== AUDIO EFFECTS ======
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, EFFECTS_CHANNEL).setMethodCallHandler { call, result ->
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
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, ROUTER_CHANNEL).setMethodCallHandler { call, result ->
            try {
                when (call.method) {
                    "getConnectedDevices" -> result.success(audioRouter?.getConnectedAudioDevices() ?: emptyList<Map<String, Any>>())
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

        // ====== STREAM RESOLVER ======
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, RESOLVER_CHANNEL).setMethodCallHandler { call, result ->
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
                    safeResult(result) { NoctraNativeStreamEngine.fetchRadioTracks(videoId) ?: emptyList<Map<String, Any>>() }
                }
                "searchJioSaavn" -> {
                    val query = call.argument<String>("query") ?: ""
                    val limit = call.argument<Int>("limit") ?: 20
                    safeResult(result) { JioSaavnNativeEngine.searchSongs(query, limit) ?: emptyList<Map<String, Any>>() }
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

        // ====== UPDATE NOTIFICATIONS ======
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, UPDATE_NOTIFY_CHANNEL).setMethodCallHandler { call, result ->
            if (call.method == "showUpdateNotification") {
                val title = call.argument<String>("title") ?: "Noctra update available"
                val body = call.argument<String>("body") ?: "Tap to download."
                val url = call.argument<String>("url") ?: ""
                try {
                    val nm = getSystemService(NOTIFICATION_SERVICE) as NotificationManager
                    val channelId = "noctra_updates"
                    if (android.os.Build.VERSION.SDK_INT >= android.os.Build.VERSION_CODES.O) {
                        val ch = NotificationChannel(channelId, "Noctra Updates", NotificationManager.IMPORTANCE_HIGH).apply {
                            description = "New version release alerts"
                        }
                        nm.createNotificationChannel(ch)
                    }
                    val intent = Intent(Intent.ACTION_VIEW, android.net.Uri.parse(url))
                    val pi = PendingIntent.getActivity(this, 0, intent, PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE)
                    val notification = NotificationCompat.Builder(this, channelId)
                        .setSmallIcon(R.drawable.ic_notification)
                        .setContentTitle(title)
                        .setContentText(body)
                        .setAutoCancel(true)
                        .setPriority(NotificationCompat.PRIORITY_HIGH)
                        .setContentIntent(pi)
                        .build()
                    nm.notify(9001, notification)
                    result.success(true)
                } catch (e: Throwable) {
                    Log.e(TAG, "Update notification failed", e)
                    result.success(false)
                }
            } else if (call.method == "installApk") {
                val filePath = call.argument<String>("filePath") ?: ""
                try {
                    val file = java.io.File(filePath)
                    if (file.exists()) {
                        val uri = androidx.core.content.FileProvider.getUriForFile(
                            applicationContext,
                            "${applicationContext.packageName}.fileprovider",
                            file
                        )
                        val installIntent = Intent(Intent.ACTION_VIEW).apply {
                            setDataAndType(uri, "application/vnd.android.package-archive")
                            flags = Intent.FLAG_ACTIVITY_NEW_TASK or Intent.FLAG_GRANT_READ_URI_PERMISSION
                        }
                        startActivity(installIntent)
                        result.success(true)
                    } else {
                        result.success(false)
                    }
                } catch (e: Throwable) {
                    Log.e(TAG, "APK install failed", e)
                    result.error("INSTALL_ERROR", e.message, null)
                }
            } else { result.notImplemented() }
        }

        // ====== ICON CHANNEL ======
        // All icon operations serialized through iconExecutor.
        // reconcileAndInit: combine reconcile + getCurrentIcon into one atomic operation.
        // setIcon: switch launcher icon transactionally.
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, ICON_CHANNEL).setMethodCallHandler { call, result ->
            when (call.method) {
                "reconcileAndInit" -> {
                    iconExecutor.execute {
                        try {
                            val iconResult = launcherIconManager.reconcileAndGetCurrentIcon()
                            runOnUiThread {
                                if (!isFinishing && !isDestroyed) {
                                    iconResult.fold(
                                        onSuccess = { icon -> result.success(icon) },
                                        onFailure = { error ->
                                            Log.e(TAG, "Icon reconciliation failed", error)
                                            result.error("ICON_STATE_UNRECOVERABLE", error.message, null)
                                        }
                                    )
                                }
                            }
                        } catch (e: Throwable) {
                            Log.e(TAG, "reconcileAndInit crashed", e)
                            runOnUiThread {
                                if (!isFinishing && !isDestroyed) {
                                    result.error("ICON_INIT_ERROR", e.message, null)
                                }
                            }
                        }
                    }
                }
                "setIcon" -> {
                    val iconKey = call.argument<String>("icon") ?: ""
                    if (iconKey.isEmpty()) {
                        result.error("INVALID_ICON", "Icon key must not be empty", null)
                        return@setMethodCallHandler
                    }
                    iconExecutor.execute {
                        val operation = launcherIconManager.setIcon(iconKey)
                        runOnUiThread {
                            if (!isFinishing && !isDestroyed) {
                                operation.fold(
                                    onSuccess = { result.success(true) },
                                    onFailure = { error ->
                                        Log.e(TAG, "Icon switch failed", error)
                                        result.error("ICON_CHANGE_FAILED", error.message, null)
                                    }
                                )
                            }
                        }
                    }
                }
                else -> result.notImplemented()
            }
        }

        // ====== STEM SEPARATION ======
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, STEM_CHANNEL).setMethodCallHandler { call, result ->
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

        // ====== AUDIO QUALITY / CODEC ======
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, QUALITY_CHANNEL).setMethodCallHandler { call, result ->
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
        iconExecutor.shutdownNow()
        nativeExecutor.shutdownNow()
        super.onDestroy()
    }

    private fun safeResult(result: MethodChannel.Result, block: () -> Any?) {
        nativeExecutor.execute {
            try {
                val data = block()
                runOnUiThread {
                    if (!isFinishing && !isDestroyed) {
                        try { result.success(data) } catch (e: Throwable) {
                            Log.e(TAG, "MethodChannel result callback failed", e)
                        }
                    }
                }
            } catch (e: Throwable) {
                Log.e(TAG, "Native resolver block failed", e)
                runOnUiThread {
                    if (!isFinishing && !isDestroyed) {
                        try { result.success(null) } catch (e2: Throwable) {
                            Log.e(TAG, "Failed to send null result", e2)
                        }
                    }
                }
            }
        }
    }
}
