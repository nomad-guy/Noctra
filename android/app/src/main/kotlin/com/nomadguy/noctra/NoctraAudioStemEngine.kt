package com.nomadguy.noctra

import android.media.MediaCodec
import android.media.MediaExtractor
import android.media.MediaFormat
import java.io.File
import java.io.FileOutputStream
import java.nio.ByteBuffer
import java.nio.ByteOrder
import kotlin.math.abs
import kotlin.math.cos
import kotlin.math.min
import kotlin.math.pow
import kotlin.math.sin
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
                writeWav(outFile, data, sampleRate, channels)
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
            null
        } finally {
            try { codec?.stop() } catch (_: Throwable) {}
            try { codec?.release() } catch (_: Throwable) {}
            try { extractor?.release() } catch (_: Throwable) {}
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

            fft(fftBuffer, frameSize)

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

            applyMaskAndWrite(fftBuffer, vocalMask, vocals, startSample, channels, frameSize)
            applyMaskAndWrite(fftBuffer, bassMask, bass, startSample, channels, frameSize)
            applyMaskAndWrite(fftBuffer, drumMask, drums, startSample, channels, frameSize)

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

    private fun fft(buffer: DoubleArray, n: Int) {
        if (n <= 1) return
        var j = 0
        for (i in 1 until n) {
            var bit = n shr 1
            while (j and bit != 0) { j = j xor bit; bit = bit shr 1 }
            j = j xor bit
            if (i < j) {
                var tmp = buffer[i * 2]; buffer[i * 2] = buffer[j * 2]; buffer[j * 2] = tmp
                tmp = buffer[i * 2 + 1]; buffer[i * 2 + 1] = buffer[j * 2 + 1]; buffer[j * 2 + 1] = tmp
            }
        }
        var len = 2
        while (len <= n) {
            val halfLen = len / 2
            val angle = -2.0 * Math.PI / len
            val wRe = cos(angle)
            val wIm = sin(angle)
            var i = 0
            while (i < n) {
                var curRe = 1.0; var curIm = 0.0
                for (k in 0 until halfLen) {
                    val tRe = curRe * buffer[(i + k + halfLen) * 2] - curIm * buffer[(i + k + halfLen) * 2 + 1]
                    val tIm = curRe * buffer[(i + k + halfLen) * 2 + 1] + curIm * buffer[(i + k + halfLen) * 2]
                    val evenRe = buffer[(i + k) * 2]; val evenIm = buffer[(i + k) * 2 + 1]
                    buffer[(i + k) * 2] = evenRe + tRe; buffer[(i + k) * 2 + 1] = evenIm + tIm
                    buffer[(i + k + halfLen) * 2] = evenRe - tRe; buffer[(i + k + halfLen) * 2 + 1] = evenIm - tIm
                    val newCurRe = curRe * wRe - curIm * wIm; curIm = curRe * wIm + curIm * wRe; curRe = newCurRe
                }
                i += len
            }
            len = len shl 1
        }
    }

    /**
     * Inverse FFT. The forward transform above uses angle = -2π/N,
     * so the inverse uses +2π/N and divides by N on output. Without
     * this routine the masker was calling `fft()` on a masked
     * spectrum and writing the *forward* transform of the masked
     * spectrum back into the time domain — which is not a valid
     * reconstruction and produced garbage audio.
     */
    private fun ifft(buffer: DoubleArray, n: Int) {
        if (n <= 1) return
        var j = 0
        for (i in 1 until n) {
            var bit = n shr 1
            while (j and bit != 0) { j = j xor bit; bit = bit shr 1 }
            j = j xor bit
            if (i < j) {
                var tmp = buffer[i * 2]; buffer[i * 2] = buffer[j * 2]; buffer[j * 2] = tmp
                tmp = buffer[i * 2 + 1]; buffer[i * 2 + 1] = buffer[j * 2 + 1]; buffer[j * 2 + 1] = tmp
            }
        }
        var len = 2
        while (len <= n) {
            val halfLen = len / 2
            val angle = 2.0 * Math.PI / len // conjugate of forward angle
            val wRe = cos(angle)
            val wIm = sin(angle)
            var i = 0
            while (i < n) {
                var curRe = 1.0; var curIm = 0.0
                for (k in 0 until halfLen) {
                    val tRe = curRe * buffer[(i + k + halfLen) * 2] - curIm * buffer[(i + k + halfLen) * 2 + 1]
                    val tIm = curRe * buffer[(i + k + halfLen) * 2 + 1] + curIm * buffer[(i + k + halfLen) * 2]
                    val evenRe = buffer[(i + k) * 2]; val evenIm = buffer[(i + k) * 2 + 1]
                    buffer[(i + k) * 2] = evenRe + tRe; buffer[(i + k) * 2 + 1] = evenIm + tIm
                    buffer[(i + k + halfLen) * 2] = evenRe - tRe; buffer[(i + k + halfLen) * 2 + 1] = evenIm - tIm
                    val newCurRe = curRe * wRe - curIm * wIm; curIm = curRe * wIm + curIm * wRe; curRe = newCurRe
                }
                i += len
            }
            len = len shl 1
        }
        // Normalise by 1/N for the inverse.
        for (i in 0 until n) {
            buffer[i * 2] /= n
            buffer[i * 2 + 1] /= n
        }
    }

    private fun applyMaskAndWrite(fftBuffer: DoubleArray, mask: BooleanArray, output: ShortArray, startSample: Int, channels: Int, frameSize: Int) {
        // Build the masked spectrum, then transform it BACK to the
        // time domain with the real inverse. The previous version
        // called the forward FFT here, which produced the DFT of a
        // zero-padded masked spectrum — not a meaningful audio
        // signal. With a proper IFFT and a 1/N normaliser (inside
        // ifft), the sum of all masks on the original buffer
        // reconstructs the input on the unmasked band.
        val masked = DoubleArray(frameSize * 2)
        for (k in 0 until frameSize) {
            if (mask[k]) { masked[k * 2] = fftBuffer[k * 2]; masked[k * 2 + 1] = fftBuffer[k * 2 + 1] }
        }
        ifft(masked, frameSize)
        for (i in 0 until frameSize) {
            val sample = (masked[i * 2] * Short.MAX_VALUE).coerceIn(Short.MIN_VALUE.toDouble(), Short.MAX_VALUE.toDouble()).toInt().toShort()
            for (ch in 0 until channels) {
                val idx = (startSample + i * channels + ch).coerceIn(0, output.size - 1)
                output[idx] = sample
            }
        }
    }

    private fun writeWav(file: File, data: ShortArray, sampleRate: Int, channels: Int) {
        val bitsPerSample = 16
        val byteRate = sampleRate * channels * bitsPerSample / 8
        val blockAlign = channels * bitsPerSample / 8
        val dataSize = data.size * 2
        val fileSize = 36 + dataSize

        FileOutputStream(file).use { fos ->
            val header = ByteArray(44)
            header[0] = 'R'.code.toByte(); header[1] = 'I'.code.toByte(); header[2] = 'F'.code.toByte(); header[3] = 'F'.code.toByte()
            writeInt(header, 4, fileSize)
            header[8] = 'W'.code.toByte(); header[9] = 'A'.code.toByte(); header[10] = 'V'.code.toByte(); header[11] = 'E'.code.toByte()
            header[12] = 'f'.code.toByte(); header[13] = 'm'.code.toByte(); header[14] = 't'.code.toByte(); header[15] = ' '.code.toByte()
            writeInt(header, 16, 16); writeShort(header, 20, 1); writeShort(header, 22, channels)
            writeInt(header, 24, sampleRate); writeInt(header, 28, byteRate)
            writeShort(header, 32, blockAlign); writeShort(header, 34, bitsPerSample)
            header[36] = 'd'.code.toByte(); header[37] = 'a'.code.toByte(); header[38] = 't'.code.toByte(); header[39] = 'a'.code.toByte()
            writeInt(header, 40, dataSize)
            fos.write(header)
            val byteBuffer = ByteBuffer.allocate(dataSize).order(ByteOrder.LITTLE_ENDIAN)
            for (sample in data) byteBuffer.putShort(sample)
            fos.write(byteBuffer.array())
        }
    }

    private fun writeInt(buffer: ByteArray, offset: Int, value: Int) {
        buffer[offset] = (value and 0xFF).toByte(); buffer[offset + 1] = ((value shr 8) and 0xFF).toByte()
        buffer[offset + 2] = ((value shr 16) and 0xFF).toByte(); buffer[offset + 3] = ((value shr 24) and 0xFF).toByte()
    }

    private fun writeShort(buffer: ByteArray, offset: Int, value: Int) {
        buffer[offset] = (value and 0xFF).toByte(); buffer[offset + 1] = ((value shr 8) and 0xFF).toByte()
    }
}
