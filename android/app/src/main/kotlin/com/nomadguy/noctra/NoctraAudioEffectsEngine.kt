package com.nomadguy.noctra

import android.media.audiofx.BassBoost
import android.media.audiofx.Equalizer
import android.media.audiofx.LoudnessEnhancer
import android.media.audiofx.PresetReverb
import android.media.audiofx.Virtualizer
import android.os.Build

class NoctraAudioEffectsEngine {
    private var equalizer: Equalizer? = null
    private var bassBoost: BassBoost? = null
    private var virtualizer: Virtualizer? = null
    private var presetReverb: PresetReverb? = null
    private var loudnessEnhancer: LoudnessEnhancer? = null
    private var currentSessionId: Int = 0

    fun attachSession(sessionId: Int) {
        if (sessionId == currentSessionId && equalizer != null) return
        release()
        currentSessionId = sessionId
        try {
            equalizer = Equalizer(0, sessionId).apply { enabled = true }
            bassBoost = BassBoost(0, sessionId).apply { enabled = true }
            virtualizer = Virtualizer(0, sessionId).apply { enabled = true }
            presetReverb = PresetReverb(0, sessionId).apply { enabled = true }
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.KITKAT) {
                loudnessEnhancer = LoudnessEnhancer(sessionId).apply {
                    setTargetGain(100)
                    enabled = true
                }
            }
        } catch (_: Throwable) {}
    }

    fun applyBands(bands: List<Double>, bassStrength: Double, virtualizerStrength: Double): Boolean {
        return try {
            if (equalizer == null && currentSessionId != 0) attachSession(currentSessionId)
            equalizer?.let { eq ->
                val numBands = eq.numberOfBands.toInt()
                val minLevel = eq.bandLevelRange[0]
                val maxLevel = eq.bandLevelRange[1]
                for (i in 0 until minOf(numBands, bands.size)) {
                    val rawDb = bands[i]
                    val mB = (rawDb * 100).toInt().coerceIn(minLevel.toInt(), maxLevel.toInt()).toShort()
                    eq.setBandLevel(i.toShort(), mB)
                }
            }
            bassBoost?.let { bb ->
                if (bb.strengthSupported) {
                    val strength = ((bassStrength / 12.0).coerceIn(0.0, 1.0) * 1000).toInt().toShort()
                    bb.setStrength(strength)
                }
            }
            virtualizer?.let { v ->
                if (v.strengthSupported) {
                    val strength = ((virtualizerStrength / 12.0).coerceIn(0.0, 1.0) * 1000).toInt().toShort()
                    v.setStrength(strength)
                }
            }
            true
        } catch (_: Throwable) { false }
    }

    fun applyPresetMode(mode: String): Boolean {
        return try {
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
        } catch (_: Throwable) { false }
    }

    fun release() {
        try { equalizer?.release() } catch (_: Throwable) {}
        try { bassBoost?.release() } catch (_: Throwable) {}
        try { virtualizer?.release() } catch (_: Throwable) {}
        try { presetReverb?.release() } catch (_: Throwable) {}
        try { if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.KITKAT) loudnessEnhancer?.release() } catch (_: Throwable) {}
        equalizer = null
        bassBoost = null
        virtualizer = null
        presetReverb = null
        loudnessEnhancer = null
    }
}
