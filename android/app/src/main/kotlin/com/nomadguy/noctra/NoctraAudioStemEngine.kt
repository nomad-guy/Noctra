package com.nomadguy.noctra

import android.media.MediaCodec
import android.media.MediaExtractor
import android.media.MediaFormat
import java.io.File
import java.nio.ByteOrder
import kotlin.math.abs
import kotlin.math.pow
import kotlin.math.sqrt

/**
 * On-device audio stem separation engine.
 * Uses frequency-domain analysis to split audio into vocals, drums, bass, and other.
 */
object NoctraAudioStemEngine {

    fun separateStems(
        inputPath: String,
        outputDir: String,
        model: String
    ): Map<String, Any>? {
        val inputFile = File(inputPath)
        if (!inputFile.exists() || inputFile.length() < 1024) return null

        val outDir = File(outputDir)
        if (!outDir.exists()) outDir.mkdirs()

        return try {
            val pcmData = decodeToPcm(inputPath) ?: return null
            val sampleRate = pcmData.sampleRate
            val channels = pcmData.channels
            val pcm = pcmData.pcm

            val separated = when (model) {
                "hq" -> separateHighQuality(pcm, sampleRate, channels)
                "karaoke" -> separateKaraoke(pcm, sampleRate, channels)
                else -> separateLight(pcm, sampleRate, channels)
            }

            val stems = mutableMapOf<String, Any>()
            val durationSec = pcm.size.toFloat() / (sampleRate * channels * 2)

            for ((name, data) in separated) {
                val outFile = File(outDir, "$name.wav")
                WavFileWriter.writeWav(outFile, data, sampleRate, channels)
                stems[name] = mapOf("path" to outFile.absolutePath, "size" to outFile.length())
            }

            stems["duration"] = durationSec.toDouble()
            stems["model"] = model
            stems["sampleRate"] = sampleRate
            stems["status"] = "success"
            stems
        } catch (e: Exception) {
            null
        }
    }

    private data class PcmData(val pcm: ShortArray, val sampleRate: Int, val channels: Int)

    private fun decodeToPcm(path: String): PcmData? {
        var extractor: MediaExtractor? = null
        var codec: MediaCodec? = null
        return try {
            val ext = MediaExtractor()
            extractor = ext
            ext.setDataSource(path)

            var audioTrackIndex = -1
            var format: MediaFormat? = null
            for (i in 0 until ext.trackCount) {
                val f = ext.getTrackFormat(i)
                val mime = f.getString(MediaFormat.KEY_MIME) ?: continue
                if (mime.startsWith("audio/")) {
                    audioTrackIndex = i
                    format = f
                    break
                }
            }
            if (audioTrackIndex < 0 || format == null) return null

            ext.selectTrack(audioTrackIndex)
            val sampleRate = format.getInteger(MediaFormat.KEY_SAMPLE_RATE)
            val channels = format.getInteger(MediaFormat.KEY_CHANNEL_COUNT)
            val mime = format.getString(MediaFormat.KEY_MIME) ?: return null

            val c = MediaCodec.createDecoderByType(mime)
            codec = c
            c.configure(format, null, null, 0)
            c.start()

            val pcmChunks = mutableListOf<ShortArray>()
            val info = MediaCodec.BufferInfo()
            var inputDone = false
            var outputDone = false

            while (!outputDone) {
                if (!inputDone) {
                    val inputIndex = c.dequeueInputBuffer(10_000)
                    if (inputIndex >= 0) {
                        val inputBuffer = c.getInputBuffer(inputIndex) ?: continue
                        val sampleSize = ext.readSampleData(inputBuffer, 0)
                        if (sampleSize < 0) {
                            c.queueInputBuffer(inputIndex, 0, 0, 0, MediaCodec.BUFFER_FLAG_END_OF_STREAM)
                            inputDone = true
                        } else {
                            c.queueInputBuffer(inputIndex, 0, sampleSize, ext.sampleTime, 0)
                            ext.advance()
                        }
                    }
                }
                val outputIndex = c.dequeueOutputBuffer(info, 10_000)
                if (outputIndex >= 0) {
                    if (info.flags and MediaCodec.BUFFER_FLAG_END_OF_STREAM != 0) outputDone = true
                    val outputBuffer = c.getOutputBuffer(outputIndex) ?: continue
                    val shortBuffer = outputBuffer.order(ByteOrder.LITTLE_ENDIAN).asShortBuffer()
                    val shorts = ShortArray(shortBuffer.remaining())
                    shortBuffer.get(shorts)
                    pcmChunks.add(shorts)
                    c.releaseOutputBuffer(outputIndex, false)
                }
            }

            val totalSize = pcmChunks.sumOf { it.size }
            val pcm = ShortArray(totalSize)
            var offset = 0
            for (chunk in pcmChunks) {
                System.arraycopy(chunk, 0, pcm, offset, chunk.size)
                offset += chunk.size
            }
            PcmData(pcm, sampleRate, channels)
        } catch (e: Exception) {
            android.util.Log.w("NoctraAudioStem", "decodeToPcm failed for $path", e)
            null
        } finally {
            try { codec?.stop() } catch (e: Throwable) {
                android.util.Log.w("NoctraAudioStem", "codec.stop() failed", e)
            }
            try { codec?.release() } catch (e: Throwable) {
                android.util.Log.w("NoctraAudioStem", "codec.release() failed", e)
            }
            try { extractor?.release() } catch (e: Throwable) {
                android.util.Log.w("NoctraAudioStem", "extractor.release() failed", e)
            }
        }
    }

    private fun separateLight(pcm: ShortArray, sampleRate: Int, channels: Int): Map<String, ShortArray> {
        val frameSize = 2048
        val hopSize = 512
        val totalFrames = (pcm.size / channels) / hopSize

        val vocals = ShortArray(pcm.size)
        val drums = ShortArray(pcm.size)
        val bass = ShortArray(pcm.size)
        val other = ShortArray(pcm.size)

        val fftBuffer = DoubleArray(frameSize * 2)
        val binWidth = sampleRate.toDouble() / frameSize

        for (frame in 0 until totalFrames) {
            val startSample = frame * hopSize * channels

            for (i in 0 until frameSize) {
                val idx = (startSample + i * channels).coerceIn(0, pcm.size - 1)
                fftBuffer[i * 2] = pcm[idx].toDouble() / Short.MAX_VALUE
                fftBuffer[i * 2 + 1] = 0.0
            }

            StemDspHelper.fft(fftBuffer, frameSize)

            val vocalMask = BooleanArray(frameSize)
            val bassMask = BooleanArray(frameSize)
            val drumMask = BooleanArray(frameSize)

            for (k in 0 until frameSize / 2) {
                val freq = k * binWidth
                val mag = sqrt(fftBuffer[k * 2].pow(2) + fftBuffer[k * 2 + 1].pow(2))
                vocalMask[k] = freq in 300.0..3000.0 && mag > 0.01
                vocalMask[frameSize - 1 - k] = vocalMask[k]
                bassMask[k] = freq < 200.0 && mag > 0.01
                bassMask[frameSize - 1 - k] = bassMask[k]
                drumMask[k] = (freq > 6000.0 || (freq > 100.0 && freq < 500.0)) && mag > 0.02
                drumMask[frameSize - 1 - k] = drumMask[k]
            }

            StemDspHelper.applyMaskAndWrite(fftBuffer, vocalMask, vocals, startSample, channels, frameSize)
            StemDspHelper.applyMaskAndWrite(fftBuffer, bassMask, bass, startSample, channels, frameSize)
            StemDspHelper.applyMaskAndWrite(fftBuffer, drumMask, drums, startSample, channels, frameSize)

            for (i in 0 until frameSize) {
                val idx = (startSample + i * channels).coerceIn(0, pcm.size - 1)
                val orig = pcm[idx].toInt()
                val v = vocals[idx].toInt()
                val b = bass[idx].toInt()
                val d = drums[idx].toInt()
                other[idx] = (orig - v - b - d).coerceIn(Short.MIN_VALUE.toInt(), Short.MAX_VALUE.toInt()).toShort()
            }
        }
        return mapOf("vocals" to vocals, "drums" to drums, "bass" to bass, "other" to other)
    }

    private fun separateHighQuality(pcm: ShortArray, sampleRate: Int, channels: Int): Map<String, ShortArray> {
        val result = separateLight(pcm, sampleRate, channels)
        val vocals = result["vocals"]!!
        val threshold = Short.MAX_VALUE * 0.02
        for (i in vocals.indices) {
            if (abs(vocals[i].toDouble()) < threshold) vocals[i] = 0
        }
        return result
    }

    private fun separateKaraoke(pcm: ShortArray, sampleRate: Int, channels: Int): Map<String, ShortArray> {
        val result = separateLight(pcm, sampleRate, channels)
        val vocals = result["vocals"]!!
        val karaoke = ShortArray(pcm.size)
        for (i in pcm.indices) {
            val inverted = (-vocals[i].toInt()).coerceIn(Short.MIN_VALUE.toInt(), Short.MAX_VALUE.toInt())
            karaoke[i] = (pcm[i].toInt() + inverted).coerceIn(Short.MIN_VALUE.toInt(), Short.MAX_VALUE.toInt()).toShort()
        }
        return mapOf("vocals" to vocals, "accompaniment" to karaoke, "drums" to result["drums"]!!, "bass" to result["bass"]!!)
    }
}
