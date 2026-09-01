package com.nomadguy.noctra

import android.app.NotificationChannel
import android.app.NotificationManager
import android.app.PendingIntent
import android.content.ComponentName
import android.content.Intent
import android.content.pm.PackageManager
import android.media.audiofx.Visualizer
import androidx.core.app.NotificationCompat
import com.ryanheise.audioservice.AudioServiceActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.EventChannel
import io.flutter.plugin.common.MethodChannel
import kotlin.concurrent.thread

class MainActivity : AudioServiceActivity() {
    private val RESOLVER_CHANNEL = "com.noctra.app/native_resolver"
    private val ICON_CHANNEL = "com.noctra.app/launcher_icon"
    private val UPDATE_NOTIFY_CHANNEL = "com.noctra.app/update_notify"
    private val VISUALIZER_CHANNEL = "com.noctra.app/audio_visualizer"
    private val ROUTER_CHANNEL = "com.noctra.app/audio_router"
    private val DEVICES_EVENT_CHANNEL = "com.noctra.app/audio_devices"
    private val EFFECTS_CHANNEL = "com.noctra.app/audio_effects"
    private val STEM_CHANNEL = "com.noctra.app/audio_stem_separation"
    private val QUALITY_CHANNEL = "com.noctra.app/audio_quality"

    private var visualizer: Visualizer? = null
    private var audioRouter: NoctraAudioRouter? = null
    private val effectsEngine = NoctraAudioEffectsEngine()

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        try { audioRouter = NoctraAudioRouter(applicationContext) } catch (_: Throwable) {}

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
                                        val raw = (Math.hypot(rk, ik) / 64.0).coerceIn(0.0, 1.0)
                                        magnitudes[i] = Math.pow(raw, 0.75)
                                    }
                                    runOnUiThread { try { events.success(magnitudes.toList()) } catch (_: Throwable) {} }
                                }
                            }
                        }, Visualizer.getMaxCaptureRate() / 2, true, true)
                        enabled = true
                    }
                } catch (_: Throwable) {}
            }

            override fun onCancel(arguments: Any?) {
                try {
                    visualizer?.enabled = false
                    visualizer?.release()
                    visualizer = null
                } catch (_: Throwable) {}
            }
        })

        EventChannel(flutterEngine.dartExecutor.binaryMessenger, DEVICES_EVENT_CHANNEL).setStreamHandler(object : EventChannel.StreamHandler {
            override fun onListen(arguments: Any?, events: EventChannel.EventSink?) {
                try { audioRouter?.startListening(events) } catch (_: Throwable) {}
            }
            override fun onCancel(arguments: Any?) {
                try { audioRouter?.stopListening() } catch (_: Throwable) {}
            }
        })

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
            } catch (_: Throwable) { result.success(false) }
        }

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
                    try { result.success(JioSaavnNativeEngine.decryptMediaUrl(encUrl)) } catch (_: Throwable) { result.success(null) }
                }
                else -> result.notImplemented()
            }
        }

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
                } catch (_: Throwable) { result.success(false) }
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
                    result.error("INSTALL_ERROR", e.message, null)
                }
            } else { result.notImplemented() }
        }

        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, ICON_CHANNEL).setMethodCallHandler { call, result ->
            when (call.method) {
                "setLauncherIcon" -> {
                    val iconKey = call.argument<String>("icon") ?: "noir_black"
                    // Just queue — actual toggle happens in applyPendingIcon
                    getSharedPreferences("noctra_theme", MODE_PRIVATE)
                        .edit().putString("pending_icon", iconKey).apply()
                    result.success(true)
                }
                "applyPendingIcon" -> {
                    val iconKey = call.argument<String>("icon") ?: "noir_black"
                    setLauncherIconAlias(iconKey)
                    result.success(true)
                }
                else -> result.notImplemented()
            }
        }

        // Audio Stem Separation channel — delegates to native ML pipeline
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

        // Audio Quality / CODEC settings channel — persists preferences
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, QUALITY_CHANNEL).setMethodCallHandler { call, result ->
            when (call.method) {
                "setStreamQuality" -> {
                    val bitrate = call.argument<Int>("bitrate") ?: 320
                    val codec = call.argument<String>("codec") ?: "mp3"
                    // Persist to SharedPreferences for native resolvers
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

    /**
     * Toggle the launcher icon by enabling the matching activity-alias
     * and disabling all others.  Executes on a background thread with a
     * short delay so the icon change doesn't kill the foreground task.
     */
    /**
     * Swap the launcher icon by enabling the matching activity-alias and
     * disabling all others. MainActivity always keeps its LAUNCHER filter
     * so it serves as the guaranteed entry point — disabling aliases is safe.
     */
    private fun setLauncherIconAlias(iconKey: String) {
        thread {
            try {
                val pm = packageManager
                val pkg = packageName

                // ALL aliases including .default — only ONE should be enabled at a time
                val allAliases = listOf(
                    "$pkg.MainActivity.default",
                    "$pkg.MainActivity.noir_black",
                    "$pkg.MainActivity.noir_white",
                    "$pkg.MainActivity.amoled",
                    "$pkg.MainActivity.liquid_glass",
                )

                val targetAlias = "$pkg.MainActivity.$iconKey"

                // 1. Enable the target alias first (safe — enabling never kills)
                try {
                    pm.setComponentEnabledSetting(
                        ComponentName(pkg, targetAlias),
                        PackageManager.COMPONENT_ENABLED_STATE_ENABLED,
                        PackageManager.DONT_KILL_APP
                    )
                } catch (_: Throwable) {}

                // 2. Disable all OTHER aliases (including .default)
                //    Since only one alias is enabled, the launcher shows exactly one icon.
                for (alias in allAliases) {
                    if (alias == targetAlias) continue
                    try {
                        pm.setComponentEnabledSetting(
                            ComponentName(pkg, alias),
                            PackageManager.COMPONENT_ENABLED_STATE_DISABLED,
                            PackageManager.DONT_KILL_APP
                        )
                    } catch (_: Throwable) {}
                }

                // Persist the choice
                getSharedPreferences("noctra_theme", MODE_PRIVATE)
                    .edit().putString("launcher_icon", iconKey).apply()

                // Force launcher to refresh
                try {
                    sendBroadcast(Intent(Intent.ACTION_PACKAGE_CHANGED).apply {
                        data = android.net.Uri.fromParts("package", pkg, null)
                    })
                } catch (_: Throwable) {}
            } catch (_: Throwable) {}
        }
    }

    private fun safeResult(result: MethodChannel.Result, block: () -> Any?) {
        thread {
            try {
                val data = block()
                runOnUiThread {
                    if (!isFinishing && !isDestroyed) {
                        try { result.success(data) } catch (_: Throwable) {}
                    }
                }
            } catch (_: Throwable) {
                runOnUiThread {
                    if (!isFinishing && !isDestroyed) {
                        try { result.success(null) } catch (_: Throwable) {}
                    }
                }
            }
        }
    }
}
