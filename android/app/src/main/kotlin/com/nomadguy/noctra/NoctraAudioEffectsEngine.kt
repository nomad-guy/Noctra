package com.nomadguy.noctra

import android.media.audiofx.BassBoost
import android.media.audiofx.Equalizer
import android.media.audiofx.LoudnessEnhancer
import android.media.audiofx.PresetReverb
import android.media.audiofx.Virtualizer
import android.os.Build
import android.util.Log
import java.util.concurrent.locks.ReentrantLock
import kotlin.concurrent.withLock

/**
 * Thread-safe wrapper around Android's audio effect primitives.
 *
 * `MainActivity.nativeExecutor` is a 4-thread pool and every
 * `MethodChannel` invocation (attachSession, applyBands,
 * applyPresetMode) lands on one of those workers. Without external
 * synchronization a fast [attachSession] → [release] → [attachSession]
 * sequence can race a concurrent [applyBands] and observe a
 * half-released effect graph. All public methods now take a single
 * [ReentrantLock] so the effect graph is replaced and reconfigured
 * atomically.
 */
class NoctraAudioEffectsEngine {
    companion object {
        private const val TAG = "NoctraAudioEffects"
        // Maximum Equalizer band index that applyBands will ever address.
        // The Dart side sends 10 bands; clamp so an over-sized list
        // cannot IndexOutOfBounds on a device that exposes more bands.
        private const val MAX_SUPPORTED_BANDS = 10
    }

    private val lock = ReentrantLock()
    private var dynamicsProcessor: NoctraDynamicsProcessor? = null
    private var equalizer: Equalizer? = null
    private var bassBoost: BassBoost? = null
    private var virtualizer: Virtualizer? = null
    private var presetReverb: PresetReverb? = null
    private var loudnessEnhancer: LoudnessEnhancer? = null
    private var currentSessionId: Int = 0

    fun attachSession(sessionId: Int): Boolean = lock.withLock {
        if (sessionId <= 0) return@withLock false
        if (sessionId == currentSessionId && (dynamicsProcessor != null || equalizer != null)) return@withLock true
        releaseLocked()
        currentSessionId = sessionId
        try {
            // Android 9+ (API 28+): Prioritize studio DynamicsProcessing (linear phase PreEQ + peak limiter)
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.P) {
                val dp = NoctraDynamicsProcessor(sessionId)
                if (dp.isAvailable) {
                    dynamicsProcessor = dp
                }
            }
            // Fallback to legacy android.media.audiofx.Equalizer if DynamicsProcessing unavailable
            if (dynamicsProcessor == null) {
                equalizer = Equalizer(0, sessionId).apply { enabled = true }
            }

            bassBoost = BassBoost(0, sessionId).apply { enabled = true }
            virtualizer = Virtualizer(0, sessionId).apply { enabled = true }
            presetReverb = PresetReverb(0, sessionId).apply { enabled = true }
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.KITKAT) {
                loudnessEnhancer = LoudnessEnhancer(sessionId).apply {
                    // Set target gain to 0 mB (neutral) by default to prevent digital clipping/compression
                    setTargetGain(0)
                    enabled = false
                }
            }
        } catch (e: Throwable) {
            Log.w(TAG, "Effect attach failed for session $sessionId; releasing", e)
            releaseLocked()
        }
        return@withLock dynamicsProcessor != null ||
            equalizer != null ||
            bassBoost != null ||
            virtualizer != null ||
            presetReverb != null
    }

    fun applyBands(
        bands: List<Double>,
        bassStrength: Double,
        virtualizerStrength: Double,
    ): Boolean = lock.withLock {
        try {
            if (dynamicsProcessor == null && equalizer == null && currentSessionId != 0) {
                attachSession(currentSessionId)
            }
            // 1. Try modern DynamicsProcessing linear-phase PreEQ
            val handledByDynamics = dynamicsProcessor?.applyBands(bands) ?: false
            if (!handledByDynamics) {
                // 2. Fall back to legacy Equalizer
                equalizer?.let { eq ->
                    val numBands = eq.numberOfBands.toInt()
                    val minLevel = eq.bandLevelRange[0]
                    val maxLevel = eq.bandLevelRange[1]
                    val limit = minOf(numBands, bands.size, MAX_SUPPORTED_BANDS)
                    for (i in 0 until limit) {
                        val rawDb = bands[i]
                        val mB = (rawDb * 100).toInt()
                            .coerceIn(minLevel.toInt(), maxLevel.toInt())
                            .toShort()
                        eq.setBandLevel(i.toShort(), mB)
                    }
                }
            }
            bassBoost?.let { bb ->
                if (bb.strengthSupported) {
                    val strength = ((bassStrength / 12.0).coerceIn(0.0, 1.0) * 1000)
                        .toInt().toShort()
                    bb.setStrength(strength)
                }
            }
            virtualizer?.let { v ->
                if (v.strengthSupported) {
                    val strength = ((virtualizerStrength / 12.0).coerceIn(0.0, 1.0) * 1000)
                        .toInt().toShort()
                    v.setStrength(strength)
                }
            }
            true
        } catch (e: Throwable) {
            Log.w(TAG, "applyBands failed", e)
            false
        }
    }

    fun applyPresetMode(mode: String): Boolean = lock.withLock {
        try {
            if (currentSessionId <= 0 ||
                (dynamicsProcessor == null && equalizer == null &&
                    bassBoost == null && virtualizer == null && presetReverb == null)
            ) {
                return@withLock false
            }
            when (mode.lowercase()) {
                "spatial3d" -> {
                    virtualizer?.setStrength(1000.toShort())
                    bassBoost?.setStrength(300.toShort())
                    presetReverb?.preset = PresetReverb.PRESET_SMALLROOM
                }
                "concertreverb" -> {
                    virtualizer?.setStrength(600.toShort())
                    bassBoost?.setStrength(400.toShort())
                    presetReverb?.preset = PresetReverb.PRESET_LARGEHALL
                }
                "studiomaster" -> {
                    virtualizer?.setStrength(200.toShort())
                    bassBoost?.setStrength(250.toShort())
                    presetReverb?.preset = PresetReverb.PRESET_NONE
                }
                "lossless320" -> {
                    virtualizer?.setStrength(0.toShort())
                    bassBoost?.setStrength(0.toShort())
                    presetReverb?.preset = PresetReverb.PRESET_NONE
                }
                "bassultra" -> {
                    bassBoost?.setStrength(1000.toShort())
                    virtualizer?.setStrength(100.toShort())
                    presetReverb?.preset = PresetReverb.PRESET_NONE
                }
                else -> {
                    bassBoost?.setStrength(0.toShort())
                    virtualizer?.setStrength(0.toShort())
                    presetReverb?.preset = PresetReverb.PRESET_NONE
                }
            }
            true
        } catch (e: Throwable) {
            Log.w(TAG, "applyPresetMode('$mode') failed", e)
            false
        }
    }

    fun release() {
        lock.withLock { releaseLocked() }
    }

    /** Caller must already hold [lock]. */
    private fun releaseLocked() {
        try { dynamicsProcessor?.release() } catch (e: Throwable) {
            Log.w(TAG, "dynamicsProcessor.release() failed", e)
        }
        try { equalizer?.release() } catch (e: Throwable) {
            Log.w(TAG, "equalizer.release() failed", e)
        }
        try { bassBoost?.release() } catch (e: Throwable) {
            Log.w(TAG, "bassBoost.release() failed", e)
        }
        try { virtualizer?.release() } catch (e: Throwable) {
            Log.w(TAG, "virtualizer.release() failed", e)
        }
        try { presetReverb?.release() } catch (e: Throwable) {
            Log.w(TAG, "presetReverb.release() failed", e)
        }
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.KITKAT) {
            try { loudnessEnhancer?.release() } catch (e: Throwable) {
                Log.w(TAG, "loudnessEnhancer.release() failed", e)
            }
        }
        dynamicsProcessor = null
        equalizer = null
        bassBoost = null
        virtualizer = null
        presetReverb = null
        loudnessEnhancer = null
    }
}
