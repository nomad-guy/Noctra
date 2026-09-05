package com.nomadguy.noctra

import android.media.audiofx.BassBoost
import android.media.audiofx.Equalizer
import android.media.audiofx.PresetReverb
import android.media.audiofx.Virtualizer
import android.util.Log

/**
 * Legacy NXP audio effects engine using Equalizer, BassBoost,
 * Virtualizer, and PresetReverb. Compatible with all Android
 * releases from API 9 upwards.
 */
class NoctraLegacyEffects {
    companion object {
        private const val TAG = "NoctraLegacyEffects"
        private const val MAX_SUPPORTED_BANDS = 10
    }

    private var equalizer: Equalizer? = null
    private var bassBoost: BassBoost? = null
    private var virtualizer: Virtualizer? = null
    private var presetReverb: PresetReverb? = null
    private var attachedSessionId: Int = 0

    val isAttached: Boolean
        get() = equalizer != null || bassBoost != null ||
            virtualizer != null || presetReverb != null

    fun attach(sessionId: Int): Boolean {
        if (sessionId <= 0) return false
        if (sessionId == attachedSessionId && isAttached) return true
        release()
        attachedSessionId = sessionId
        try {
            equalizer = Equalizer(0, sessionId).apply { enabled = true }
            bassBoost = BassBoost(0, sessionId).apply { enabled = true }
            virtualizer = Virtualizer(0, sessionId).apply { enabled = true }
            presetReverb = PresetReverb(0, sessionId).apply { enabled = true }
            Log.i(TAG, "Legacy NXP effects attached for session $sessionId")
            return true
        } catch (e: Throwable) {
            Log.w(TAG, "Legacy NXP effects attach failed for session $sessionId", e)
            release()
            return false
        }
    }

    fun applyBands(
        bands: List<Double>,
        bassStrength: Double,
        virtualizerStrength: Double,
    ): Boolean {
        try {
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
            return true
        } catch (e: Throwable) {
            Log.w(TAG, "applyBands failed on legacy engine", e)
            return false
        }
    }

    fun applyPresetMode(mode: String): Boolean {
        try {
            if (!isAttached) return false
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
            return true
        } catch (e: Throwable) {
            Log.w(TAG, "applyPresetMode failed on legacy engine", e)
            return false
        }
    }

    fun release() {
        try { equalizer?.release() } catch (e: Throwable) { Log.w(TAG, "equalizer release failed", e) }
        try { bassBoost?.release() } catch (e: Throwable) { Log.w(TAG, "bassBoost release failed", e) }
        try { virtualizer?.release() } catch (e: Throwable) { Log.w(TAG, "virtualizer release failed", e) }
        try { presetReverb?.release() } catch (e: Throwable) { Log.w(TAG, "presetReverb release failed", e) }
        equalizer = null
        bassBoost = null
        virtualizer = null
        presetReverb = null
        attachedSessionId = 0
    }
}
