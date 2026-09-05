package com.nomadguy.noctra

import android.media.audiofx.DynamicsProcessing
import android.os.Build
import android.util.Log

/**
 * DynamicsProcessing engine using Android 9+ (API 28) time-domain
 * IIR filters (VARIANT_FAVOR_TIME_RESOLUTION).
 *
 * Configured as a 10-band PreEq + output Limiter.
 * Attached exclusively to prevent AudioFlinger effect chain overload
 * and OEM Dolby/Dirac muting on Realme, Oppo, Xiaomi, and Samsung devices.
 */
class NoctraDynamicsProcessor {
    companion object {
        private const val TAG = "NoctraDynProc"
        private const val NUM_BANDS = 10
        private val BAND_FREQUENCIES = floatArrayOf(
            31.0f, 62.0f, 125.0f, 250.0f, 500.0f,
            1000.0f, 2000.0f, 4000.0f, 8000.0f, 16000.0f
        )
    }

    private var dp: DynamicsProcessing? = null
    private var attachedSessionId: Int = 0

    val isSupported: Boolean
        get() = Build.VERSION.SDK_INT >= Build.VERSION_CODES.P

    val isAttached: Boolean
        get() = dp != null

    fun attach(sessionId: Int): Boolean {
        if (!isSupported || sessionId <= 0) return false
        if (sessionId == attachedSessionId && isAttached) return true
        release()
        attachedSessionId = sessionId
        try {
            val builder = DynamicsProcessing.Config.Builder(
                DynamicsProcessing.VARIANT_FAVOR_TIME_RESOLUTION,
                2, // stereo
                true, // pre-eq
                NUM_BANDS,
                false, // mbc
                0,
                false, // post-eq
                0,
                true // limiter
            )

            // Setup default 10-band PreEq
            val preEq = DynamicsProcessing.Eq(true, true, NUM_BANDS)
            for (i in 0 until NUM_BANDS) {
                val band = DynamicsProcessing.EqBand(true, BAND_FREQUENCIES[i], 0.0f)
                preEq.setBand(i, band)
            }
            builder.setPreferredFrameDuration(10.0f)
            builder.setPreEqAllChannelsTo(preEq)

            // Limiter: 1ms attack, 50ms release, 10:1 ratio, -0.5dB threshold, 0dB postGain
            val limiter = DynamicsProcessing.Limiter(
                true, true, 0, 1.0f, 50.0f, 10.0f, -0.5f, 0.0f
            )
            builder.setLimiterAllChannelsTo(limiter)

            val config = builder.build()
            dp = DynamicsProcessing(0, sessionId, config).apply {
                enabled = true
            }
            Log.i(TAG, "DynamicsProcessing attached successfully for session $sessionId")
            return true
        } catch (e: Throwable) {
            Log.w(TAG, "DynamicsProcessing attach failed for session $sessionId", e)
            release()
            return false
        }
    }

    fun applyBands(
        bands: List<Double>,
        bassStrength: Double,
        virtualizerStrength: Double,
    ): Boolean {
        val proc = dp ?: return false
        try {
            val limit = minOf(NUM_BANDS, bands.size)
            val bassAdd = (bassStrength / 12.0).coerceIn(0.0, 1.0) * 4.0
            val trebleAdd = (virtualizerStrength / 12.0).coerceIn(0.0, 1.0) * 2.0

            for (ch in 0 until 2) {
                for (i in 0 until limit) {
                    var gain = bands[i].toFloat()
                    if (i < 2) gain += bassAdd.toFloat()
                    if (i >= 8) gain += trebleAdd.toFloat()
                    val band = DynamicsProcessing.EqBand(true, BAND_FREQUENCIES[i], gain)
                    proc.setPreEqBandByChannelIndex(ch, i, band)
                }
            }
            return true
        } catch (e: Throwable) {
            Log.w(TAG, "applyBands failed on DynamicsProcessing", e)
            return false
        }
    }

    fun applyPresetMode(mode: String): Boolean {
        val proc = dp ?: return false
        try {
            when (mode.lowercase()) {
                "spatial3d" -> {
                    proc.setInputGainAllChannelsTo(1.5f)
                    setBandGainOffset(proc, 0, 2.0f)
                    setBandGainOffset(proc, 8, 3.5f)
                    setBandGainOffset(proc, 9, 4.0f)
                }
                "concertreverb" -> {
                    proc.setInputGainAllChannelsTo(1.0f)
                    setBandGainOffset(proc, 1, 2.5f)
                    setBandGainOffset(proc, 4, 1.5f)
                    setBandGainOffset(proc, 7, 2.0f)
                }
                "studiomaster" -> {
                    proc.setInputGainAllChannelsTo(1.2f)
                    setBandGainOffset(proc, 0, 1.5f)
                    setBandGainOffset(proc, 4, 0.5f)
                    setBandGainOffset(proc, 9, 2.0f)
                }
                "bassultra" -> {
                    proc.setInputGainAllChannelsTo(1.0f)
                    setBandGainOffset(proc, 0, 6.0f)
                    setBandGainOffset(proc, 1, 4.5f)
                    setBandGainOffset(proc, 2, 2.0f)
                }
                else -> {
                    proc.setInputGainAllChannelsTo(0.0f)
                }
            }
            return true
        } catch (e: Throwable) {
            Log.w(TAG, "applyPresetMode failed on DynamicsProcessing", e)
            return false
        }
    }

    private fun setBandGainOffset(proc: DynamicsProcessing, bandIdx: Int, gainDb: Float) {
        if (bandIdx in 0 until NUM_BANDS) {
            val band = DynamicsProcessing.EqBand(true, BAND_FREQUENCIES[bandIdx], gainDb)
            proc.setPreEqBandByChannelIndex(0, bandIdx, band)
            proc.setPreEqBandByChannelIndex(1, bandIdx, band)
        }
    }

    fun release() {
        try {
            dp?.release()
        } catch (e: Throwable) {
            Log.w(TAG, "DynamicsProcessing release failed", e)
        }
        dp = null
        attachedSessionId = 0
    }
}
