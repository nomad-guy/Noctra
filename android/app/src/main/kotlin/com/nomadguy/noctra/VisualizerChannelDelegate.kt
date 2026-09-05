package com.nomadguy.noctra

import android.media.audiofx.Visualizer
import android.os.Handler
import android.os.Looper
import android.util.Log
import io.flutter.embedding.engine.dart.DartExecutor
import io.flutter.plugin.common.EventChannel

class VisualizerChannelDelegate(private val effectsEngine: NoctraAudioEffectsEngine) {
    companion object {
        private const val TAG = "VisualizerChannelDelegate"
        private const val VISUALIZER_CHANNEL = "com.nomadguy.noctra/audio_visualizer"
    }

    private var visualizer: Visualizer? = null
    private val visualizerHandler = Handler(Looper.getMainLooper())
    @Volatile private var visualizerWaveform: DoubleArray? = null
    @Volatile private var visualizerFft: DoubleArray? = null
    @Volatile private var visualizerTickQueued = false
    @Volatile private var visualizerSink: EventChannel.EventSink? = null

    private fun dispatchVisualizerFrame() {
        visualizerTickQueued = false
        val sink = visualizerSink ?: return
        val wf = visualizerWaveform
        val fft = visualizerFft
        if (wf != null) {
            visualizerWaveform = null
            try {
                sink.success(mapOf("type" to "waveform", "data" to wf.toList()))
            } catch (_: Throwable) {}
        }
        if (fft != null) {
            visualizerFft = null
            try {
                sink.success(mapOf("type" to "fft", "data" to fft.toList()))
            } catch (_: Throwable) {}
        }
    }

    private fun scheduleVisualizerFlush() {
        if (visualizerTickQueued) return
        visualizerTickQueued = true
        visualizerHandler.postDelayed({ dispatchVisualizerFrame() }, 33L) // ~30 Hz
    }

    fun register(messenger: DartExecutor) {
        EventChannel(messenger, VISUALIZER_CHANNEL).setStreamHandler(object : EventChannel.StreamHandler {
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
                } catch (e: Throwable) {
                    Log.e(TAG, "Visualizer setup failed", e)
                }
            }

            override fun onCancel(arguments: Any?) {
                release()
            }
        })
    }

    fun release() {
        try {
            visualizerHandler.removeCallbacksAndMessages(null)
            visualizerTickQueued = false
            visualizerWaveform = null
            visualizerFft = null
            visualizerSink = null
            visualizer?.enabled = false
            visualizer?.release()
            visualizer = null
        } catch (e: Throwable) {
            Log.e(TAG, "Visualizer cleanup failed", e)
        }
    }
}
