package com.nomadguy.noctra

import android.media.audiofx.DynamicsProcessing
import android.media.audiofx.DynamicsProcessing.Config
import android.media.audiofx.DynamicsProcessing.EqBand
import android.media.audiofx.DynamicsProcessing.Limiter
import android.os.Build
import android.util.Log
import androidx.annotation.RequiresApi

/**
 * Hardware-accelerated 5-band audio dynamics processor for Android 9+ (API 28+).
 *
 * Uses [DynamicsProcessing] to deliver zero-latency linear phase PreEQ
 * matching Noctra's 5 acoustic center frequencies (60Hz, 230Hz, 910Hz, 3.6kHz, 14kHz)
 * with an integrated studio-grade soft-knee peak limiter to prevent digital clipping.
 */
@RequiresApi(Build.VERSION_CODES.P)
class NoctraDynamicsProcessor(private val sessionId: Int) {
    companion object {
        private const val TAG = "NoctraDynamics"
        val BAND_FREQUENCIES = floatArrayOf(60f, 230f, 910f, 3600f, 14000f)
        private const val CHANNEL_COUNT = 2 // Stereo
    }

    private var processor: DynamicsProcessing? = null

    init {
        try {
            val bandCount = BAND_FREQUENCIES.size
            val builder = Config.Builder(
                DynamicsProcessing.VARIANT_FAVOR_FREQUENCY_RESOLUTION,
                CHANNEL_COUNT,
                true, // preEqInUse
                bandCount, // preEqBandCount
                false, // mbcInUse
                0, // mbcBandCount
                false, // postEqInUse
                0, // postEqBandCount
                true // limiterInUse
            )

            val config = builder.build()
            processor = DynamicsProcessing(0, sessionId, config).apply {
                enabled = true
                for (b in 0 until bandCount) {
                    val band = EqBand(true, BAND_FREQUENCIES[b], 0f)
                    setPreEqBandAllChannelsTo(b, band)
                }
                // Studio peak limiter: linkGroup=0, attack=1ms, release=100ms, ratio=10:1, threshold=-0.2dBFS, postGain=0dB
                val limiter = Limiter(true, true, 0, 1.0f, 100.0f, 10.0f, -0.2f, 0.0f)
                setLimiterAllChannelsTo(limiter)
            }
            Log.i(TAG, "DynamicsProcessing attached successfully for session $sessionId")
        } catch (e: Throwable) {
            Log.w(TAG, "DynamicsProcessing initialization failed for session $sessionId", e)
            processor = null
        }
    }

    val isAvailable: Boolean
        get() = processor != null

    fun applyBands(bands: List<Double>): Boolean {
        val dp = processor ?: return false
        return try {
            val limit = minOf(bands.size, BAND_FREQUENCIES.size)
            for (i in 0 until limit) {
                val gainDb = bands[i].toFloat().coerceIn(-15f, 15f)
                val band = EqBand(true, BAND_FREQUENCIES[i], gainDb)
                dp.setPreEqBandAllChannelsTo(i, band)
            }
            true
        } catch (e: Throwable) {
            Log.w(TAG, "applyBands on DynamicsProcessing failed", e)
            false
        }
    }

    fun release() {
        try {
            processor?.release()
        } catch (e: Throwable) {
            Log.w(TAG, "DynamicsProcessing release failed", e)
        }
        processor = null
    }
}
