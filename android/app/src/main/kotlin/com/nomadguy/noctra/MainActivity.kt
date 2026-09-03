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
    private val SIGNING_CERT_CHANNEL = "com.nomadguy.noctra/signing_cert"
    private val INSTALLER_CHECK_CHANNEL = "com.nomadguy.noctra/installer_check"
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

    /**
     * Coalesce waveform + FFT samples for the same audio frame so the
     * platform thread receives at most ~30 events per second. Without
     * throttling, Visualizer.getMaxCaptureRate() can fire at up to
     * 24 kHz, which saturates the UI thread and the EventChannel queue.
     * The latest waveform / FFT sample are kept and flushed together as
     * a typed envelope so the Dart side can disambiguate the two.
     */
    private val visualizerHandler = android.os.Handler(android.os.Looper.getMainLooper())
    @Volatile private var visualizerWaveform: DoubleArray? = null
    @Volatile private var visualizerFft: DoubleArray? = null
    @Volatile private var visualizerTickQueued = false
    @Volatile private var visualizerSink: EventChannel.EventSink? = null

    private fun dispatchVisualizerFrame() {
        visualizerTickQueued = false
        val sink = visualizerSink ?: return
        val wf = visualizerWaveform
        val fft = visualizerFft
        // Each frame sends a typed envelope so the consumer knows
        // whether the array is a waveform or an FFT. We previously
        // conflated both into the same channel and treated the result
        // as an FFT stream, which broke the waveform visualizer.
        if (wf != null) {
            visualizerWaveform = null
            try { sink.success(mapOf("type" to "waveform", "data" to wf.toList())) } catch (_: Throwable) {}
        }
        if (fft != null) {
            visualizerFft = null
            try { sink.success(mapOf("type" to "fft", "data" to fft.toList())) } catch (_: Throwable) {}
        }
    }

    private fun scheduleVisualizerFlush() {
        if (visualizerTickQueued) return
        visualizerTickQueued = true
        visualizerHandler.postDelayed({ dispatchVisualizerFrame() }, 33L) // ~30 Hz
    }

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        launcherIconManager = LauncherIconManager(applicationContext)
        try { audioRouter = NoctraAudioRouter(applicationContext) } catch (e: Throwable) {
            Log.e(TAG, "AudioRouter init failed", e)
        }

        // ====== VISUALIZER ======
        // Consumers must handle envelopes of shape:
        //   { "type": "waveform", "data": [Double;32] }
        //   { "type": "fft",      "data": [Double;32] }
        // Frames are throttled to ~30 Hz via [scheduleVisualizerFlush].
        EventChannel(flutterEngine.dartExecutor.binaryMessenger, VISUALIZER_CHANNEL).setStreamHandler(object : EventChannel.StreamHandler {
            override fun onListen(arguments: Any?, events: EventChannel.EventSink?) {
                try {
                    val sessionId = (arguments as? Map<*, *>)?.get("sessionId") as? Int ?: 0
                    if (sessionId <= 0) return
                    effectsEngine.attachSession(sessionId)
                    visualizerSink = events
                    visualizer?.release()
                    val ranges = Visualizer.getCaptureSizeRange()
                    val capSize = if (ranges.size > 1) ranges[1] else ranges[0]
                    visualizer = Visualizer(sessionId).apply {
                        captureSize = capSize
                        setDataCaptureListener(object : Visualizer.OnDataCaptureListener {
                            override fun onWaveFormDataCapture(vis: Visualizer?, waveform: ByteArray?, samplingRate: Int) {
                                if (waveform != null) {
                                    val magnitudes = DoubleArray(32)
                                    val step = waveform.size / 32
                                    for (i in 0 until 32) {
                                        val idx = (i * step).coerceIn(0, waveform.size - 1)
                                        val sample = (waveform[idx].toInt() and 0xFF) - 128
                                        magnitudes[i] = (Math.abs(sample) / 128.0).coerceIn(0.0, 1.0)
                                    }
                                    visualizerWaveform = magnitudes
                                    scheduleVisualizerFlush()
                                }
                            }
                            override fun onFftDataCapture(vis: Visualizer?, fft: ByteArray?, samplingRate: Int) {
                                if (fft != null) {
                                    val magnitudes = DoubleArray(32)
                                    val n = fft.size / 2
                                    for (i in 0 until 32) {
                                        val idx = (i * n) / 32
                                        val rk = fft[2 * idx].toDouble()
                                        val ik = fft[2 * idx + 1].toDouble()
                                        val raw = (Math.hypot(rk, ik) / 64.0).coerceIn(0.0, 1.0)
                                        magnitudes[i] = Math.pow(raw, 0.75)
                                    }
                                    visualizerFft = magnitudes
                                    scheduleVisualizerFlush()
                                }
                            }
                        }, Visualizer.getMaxCaptureRate() / 2, true, true)
                        enabled = true
                    }
                } catch (e: Throwable) { Log.e(TAG, "Visualizer setup failed", e) }
            }

            override fun onCancel(arguments: Any?) {
                try {
                    visualizerHandler.removeCallbacksAndMessages(null)
                    visualizerTickQueued = false
                    visualizerWaveform = null
                    visualizerFft = null
                    visualizerSink = null
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

        // ====== SIGNING CERTIFICATE ======
        // Returns the SHA-256 digests of the *signing* certificate(s) of
        // the currently installed package. On Android 9+ this uses the
        // modern GET_SIGNING_CERTIFICATES path; on Android 7-8 it falls
        // back to the legacy PackageInfo.signatures field. For a single
        // signer we return signingCertificateHistory — the set of certs
        // the app has been signed with across key rotations — so a pin
        // against any historical cert keeps updates working after a
        // rotation. Multi-signer apps return all current signers.
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, SIGNING_CERT_CHANNEL).setMethodCallHandler { call, result ->
            if (call.method != "getInstalledSigningCertSha256") {
                result.notImplemented()
                return@setMethodCallHandler
            }
            try {
                result.success(installedSignerDigests(packageManager, packageName))
            } catch (e: Throwable) {
                Log.e(TAG, "signing cert lookup failed", e)
                result.error("SIGNING_CERT_ERROR", e.message, null)
            }
        }

        // ====== INSTALLER CHECK ======
        // Inspects a DOWNLOADED (not installed) APK before it reaches the
        // package installer: package name, versionCode/versionName and the
        // signing-cert digests of the archive, plus whether any of those
        // digests matches the currently installed app's signer. The Dart
        // side refuses to invoke installApk unless the package is Noctra's
        // AND the signer matches (Android also enforces signature
        // continuity on update; this makes the refusal explicit and early).
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, INSTALLER_CHECK_CHANNEL).setMethodCallHandler { call, result ->
            if (call.method != "inspectDownloadedApk") {
                result.notImplemented()
                return@setMethodCallHandler
            }
            try {
                val path = call.argument<String>("filePath")
                if (path.isNullOrEmpty()) {
                    result.error("INSTALLER_CHECK_ERROR", "missing filePath", null)
                    return@setMethodCallHandler
                }
                val archive = packageManager.getPackageArchiveInfo(
                    path,
                    if (android.os.Build.VERSION.SDK_INT >= android.os.Build.VERSION_CODES.P) {
                        android.content.pm.PackageManager.GET_SIGNING_CERTIFICATES
                    } else {
                        @Suppress("DEPRECATION")
                        android.content.pm.PackageManager.GET_SIGNATURES
                    }
                )
                if (archive == null) {
                    result.error("INSTALLER_CHECK_ERROR", "unparsable APK", null)
                    return@setMethodCallHandler
                }
                // Several fields are only populated when sourceDir points at
                // the archive itself.
                archive.applicationInfo?.sourceDir = path
                val pkgName = archive.packageName ?: ""
                val versionName = archive.versionName ?: ""
                val versionCode: Long =
                    if (android.os.Build.VERSION.SDK_INT >= android.os.Build.VERSION_CODES.P) {
                        archive.longVersionCode
                    } else {
                        @Suppress("DEPRECATION")
                        archive.versionCode.toLong()
                    }
                val signerDigests = signerDigestsOf(archive)
                val matchesInstalled =
                    signerDigests.isNotEmpty() &&
                        signerDigests.any {
                            installedSignerDigests(packageManager, packageName)
                                .contains(it)
                        }
                val payload = mapOf(
                    "packageName" to pkgName,
                    "versionCode" to versionCode,
                    "versionName" to versionName,
                    "signerDigests" to signerDigests,
                    "matchesInstalledSigner" to matchesInstalled
                )
                result.success(payload)
            } catch (e: Throwable) {
                Log.e(TAG, "installer check failed", e)
                result.error("INSTALLER_CHECK_ERROR", e.message, null)
            }
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
                    } else {
                        // Activity is gone — the Dart side may still be
                        // awaiting the Future. Hand it back an explicit
                        // error so callers can fall back to cached state
                        // instead of being left pending forever.
                        try {
                            result.error(
                                "ACTIVITY_DESTROYED",
                                "Activity was destroyed before result was sent",
                                data
                            )
                        } catch (e2: Throwable) {
                            Log.e(TAG, "Failed to send ACTIVITY_DESTROYED error", e2)
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
                    } else {
                        try {
                            result.error("ACTIVITY_DESTROYED", e.message, null)
                        } catch (e2: Throwable) {
                            Log.e(TAG, "Failed to send ACTIVITY_DESTROYED error", e2)
                        }
                    }
                }
            }
        }
    }
}

/**
 * Compute the SHA-256 of a Signature's underlying X.509 certificate
 * (lower-case hex). PackageManager.signingInfo gives us Signature
 * objects whose `toCharsString()` is the cert encoded via the
 * platform's CertificateFactory pipeline, which is the right
 * primitive for stable pinning across rebuilds that re-sign with
 * the same key.
 */
private fun certSha256(
    sig: android.content.pm.Signature
): String {
    // Signature.toByteArray() returns the DER-encoded X.509 certificate —
    // the same bytes Android's own PackageManager hashes for
    // PackageInfo.signingInfo / signatures, so the digest is directly
    // comparable to the platform's.
    val raw = sig.toByteArray()
    val md = java.security.MessageDigest.getInstance("SHA-256")
    val digest = md.digest(raw)
    return digest.joinToString("") { "%02x".format(it) }
}

/**
 * SHA-256 digests of the signing certificates of the INSTALLED package.
 * API 28+ uses signingInfo (signingCertificateHistory for the common
 * single-signer case, so certificates from past key rotations remain
 * accepted); API 27 and below uses the legacy signatures field.
 */
private fun installedSignerDigests(
    pm: android.content.pm.PackageManager,
    pkgName: String
): List<String> {
    return if (android.os.Build.VERSION.SDK_INT >= android.os.Build.VERSION_CODES.P) {
        val info = pm.getPackageInfo(
            pkgName,
            android.content.pm.PackageManager.GET_SIGNING_CERTIFICATES
        )
        val signingInfo = info.signingInfo
        val sigs = if (signingInfo == null) {
            emptyArray<android.content.pm.Signature>()
        } else if (signingInfo.hasMultipleSigners()) {
            signingInfo.apkContentsSigners
        } else {
            signingInfo.signingCertificateHistory
        }
        sigs.map { sig -> certSha256(sig) }
    } else {
        @Suppress("DEPRECATION")
        val info = pm.getPackageInfo(pkgName, android.content.pm.PackageManager.GET_SIGNATURES)
        @Suppress("DEPRECATION")
        val sigs = info.signatures ?: emptyArray<android.content.pm.Signature>()
        sigs.map { sig -> certSha256(sig) }
    }
}

/**
 * SHA-256 digests of the signing certificates embedded in a parsed APK
 * archive ([PackageInfo] obtained via getPackageArchiveInfo). Mirrors the
 * installed-package extraction rules.
 */
private fun signerDigestsOf(archive: android.content.pm.PackageInfo): List<String> {
    return if (android.os.Build.VERSION.SDK_INT >= android.os.Build.VERSION_CODES.P) {
        val signingInfo = archive.signingInfo
        val sigs = if (signingInfo == null) {
            emptyArray<android.content.pm.Signature>()
        } else if (signingInfo.hasMultipleSigners()) {
            signingInfo.apkContentsSigners
        } else {
            signingInfo.signingCertificateHistory
        }
        sigs.map { sig -> certSha256(sig) }
    } else {
        @Suppress("DEPRECATION")
        val sigs = archive.signatures ?: emptyArray<android.content.pm.Signature>()
        sigs.map { sig -> certSha256(sig) }
    }
}
