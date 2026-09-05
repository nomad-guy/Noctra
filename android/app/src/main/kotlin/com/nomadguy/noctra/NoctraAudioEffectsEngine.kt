package com.nomadguy.noctra

import android.util.Log
import java.util.concurrent.locks.ReentrantLock
import kotlin.concurrent.withLock

/**
 * Adaptive Audio Effects Coordinator.
 *
 * Orchestrates between [NoctraDynamicsProcessor] (API 28+ zero-latency
 * time-domain dynamics processing) and [NoctraLegacyEffects] (universal
 * NXP Equalizer/BassBoost/Virtualizer/Reverb).
 *
 * Ensures mutual exclusivity: only one engine is attached to the audio
 * session at any time to prevent AudioFlinger effect chain overload
 * and OEM Dolby/Dirac muting on Realme, Oppo, Xiaomi, and Samsung devices.
 */
class NoctraAudioEffectsEngine {
    companion object {
        private const val TAG = "NoctraEffectsEngine"
        const val ENGINE_NONE = "none"
        const val ENGINE_DYNAMICS = "dynamics_processing"
        const val ENGINE_LEGACY = "legacy_nxp"
    }

    private val lock = ReentrantLock()
    private val dynamicsEngine = NoctraDynamicsProcessor()
    private val legacyEngine = NoctraLegacyEffects()
    private var activeEngine = ENGINE_NONE
    private var currentSessionId = 0

    fun getActiveEngineName(): String = lock.withLock { activeEngine }

    fun attachSession(sessionId: Int): Boolean = lock.withLock {
        if (sessionId <= 0) return@withLock false
        if (sessionId == currentSessionId && activeEngine != ENGINE_NONE) {
            return@withLock true
        }

        releaseLocked()
        currentSessionId = sessionId

        // Strategy: Attempt DynamicsProcessing first (API 28+ time-domain IIR)
        if (dynamicsEngine.isSupported) {
            val dynAttached = try {
                dynamicsEngine.attach(sessionId)
            } catch (e: Throwable) {
                Log.w(TAG, "DynamicsProcessing threw during attach", e)
                false
            }
            if (dynAttached) {
                activeEngine = ENGINE_DYNAMICS
                Log.i(TAG, "Attached DynamicsProcessing engine for session $sessionId")
                return@withLock true
            }
        }

        // Fallback: Legacy NXP Equalizer + BassBoost + Virtualizer + Reverb
        Log.i(TAG, "Falling back to legacy NXP effects engine for session $sessionId")
        val legacyAttached = try {
            legacyEngine.attach(sessionId)
        } catch (e: Throwable) {
            Log.w(TAG, "Legacy effects threw during attach", e)
            false
        }

        if (legacyAttached) {
            activeEngine = ENGINE_LEGACY
            Log.i(TAG, "Attached legacy NXP effects engine for session $sessionId")
            return@withLock true
        }

        activeEngine = ENGINE_NONE
        Log.w(TAG, "Both audio engines failed to attach for session $sessionId")
        return@withLock false
    }

    fun applyBands(
        bands: List<Double>,
        bassStrength: Double,
        virtualizerStrength: Double,
    ): Boolean = lock.withLock {
        if (activeEngine == ENGINE_NONE && currentSessionId != 0) {
            attachSession(currentSessionId)
        }
        return@withLock when (activeEngine) {
            ENGINE_DYNAMICS -> dynamicsEngine.applyBands(bands, bassStrength, virtualizerStrength)
            ENGINE_LEGACY -> legacyEngine.applyBands(bands, bassStrength, virtualizerStrength)
            else -> false
        }
    }

    fun applyPresetMode(mode: String): Boolean = lock.withLock {
        if (activeEngine == ENGINE_NONE && currentSessionId != 0) {
            attachSession(currentSessionId)
        }
        return@withLock when (activeEngine) {
            ENGINE_DYNAMICS -> dynamicsEngine.applyPresetMode(mode)
            ENGINE_LEGACY -> legacyEngine.applyPresetMode(mode)
            else -> false
        }
    }

    fun release() {
        lock.withLock { releaseLocked() }
    }

    /** Caller must already hold [lock]. */
    private fun releaseLocked() {
        try {
            dynamicsEngine.release()
        } catch (e: Throwable) {
            Log.w(TAG, "dynamicsEngine release failed", e)
        }
        try {
            legacyEngine.release()
        } catch (e: Throwable) {
            Log.w(TAG, "legacyEngine release failed", e)
        }
        activeEngine = ENGINE_NONE
        currentSessionId = 0
    }
}
