package com.nomadguy.noctra

import kotlin.math.cos
import kotlin.math.sin

object StemDspHelper {

    fun fft(buffer: DoubleArray, n: Int) {
        if (n <= 1) return
        var j = 0
        for (i in 1 until n) {
            var bit = n shr 1
            while (j and bit != 0) {
                j = j xor bit
                bit = bit shr 1
            }
            j = j xor bit
            if (i < j) {
                var tmp = buffer[i * 2]
                buffer[i * 2] = buffer[j * 2]
                buffer[j * 2] = tmp
                tmp = buffer[i * 2 + 1]
                buffer[i * 2 + 1] = buffer[j * 2 + 1]
                buffer[j * 2 + 1] = tmp
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
                var curRe = 1.0
                var curIm = 0.0
                for (k in 0 until halfLen) {
                    val tRe = curRe * buffer[(i + k + halfLen) * 2] - curIm * buffer[(i + k + halfLen) * 2 + 1]
                    val tIm = curRe * buffer[(i + k + halfLen) * 2 + 1] + curIm * buffer[(i + k + halfLen) * 2]
                    val evenRe = buffer[(i + k) * 2]
                    val evenIm = buffer[(i + k) * 2 + 1]
                    buffer[(i + k) * 2] = evenRe + tRe
                    buffer[(i + k) * 2 + 1] = evenIm + tIm
                    buffer[(i + k + halfLen) * 2] = evenRe - tRe
                    buffer[(i + k + halfLen) * 2 + 1] = evenIm - tIm
                    val newCurRe = curRe * wRe - curIm * wIm
                    curIm = curRe * wIm + curIm * wRe
                    curRe = newCurRe
                }
                i += len
            }
            len = len shl 1
        }
    }

    fun ifft(buffer: DoubleArray, n: Int) {
        if (n <= 1) return
        var j = 0
        for (i in 1 until n) {
            var bit = n shr 1
            while (j and bit != 0) {
                j = j xor bit
                bit = bit shr 1
            }
            j = j xor bit
            if (i < j) {
                var tmp = buffer[i * 2]
                buffer[i * 2] = buffer[j * 2]
                buffer[j * 2] = tmp
                tmp = buffer[i * 2 + 1]
                buffer[i * 2 + 1] = buffer[j * 2 + 1]
                buffer[j * 2 + 1] = tmp
            }
        }
        var len = 2
        while (len <= n) {
            val halfLen = len / 2
            val angle = 2.0 * Math.PI / len
            val wRe = cos(angle)
            val wIm = sin(angle)
            var i = 0
            while (i < n) {
                var curRe = 1.0
                var curIm = 0.0
                for (k in 0 until halfLen) {
                    val tRe = curRe * buffer[(i + k + halfLen) * 2] - curIm * buffer[(i + k + halfLen) * 2 + 1]
                    val tIm = curRe * buffer[(i + k + halfLen) * 2 + 1] + curIm * buffer[(i + k + halfLen) * 2]
                    val evenRe = buffer[(i + k) * 2]
                    val evenIm = buffer[(i + k) * 2 + 1]
                    buffer[(i + k) * 2] = evenRe + tRe
                    buffer[(i + k) * 2 + 1] = evenIm + tIm
                    buffer[(i + k + halfLen) * 2] = evenRe - tRe
                    buffer[(i + k + halfLen) * 2 + 1] = evenIm - tIm
                    val newCurRe = curRe * wRe - curIm * wIm
                    curIm = curRe * wIm + curIm * wRe
                    curRe = newCurRe
                }
                i += len
            }
            len = len shl 1
        }
        for (i in 0 until n) {
            buffer[i * 2] /= n
            buffer[i * 2 + 1] /= n
        }
    }

    fun applyMaskAndWrite(
        fftBuffer: DoubleArray,
        mask: BooleanArray,
        output: ShortArray,
        startSample: Int,
        channels: Int,
        frameSize: Int
    ) {
        val masked = DoubleArray(frameSize * 2)
        for (k in 0 until frameSize) {
            if (mask[k]) {
                masked[k * 2] = fftBuffer[k * 2]
                masked[k * 2 + 1] = fftBuffer[k * 2 + 1]
            }
        }
        ifft(masked, frameSize)
        for (i in 0 until frameSize) {
            val sample = (masked[i * 2] * Short.MAX_VALUE)
                .coerceIn(Short.MIN_VALUE.toDouble(), Short.MAX_VALUE.toDouble())
                .toInt().toShort()
            for (ch in 0 until channels) {
                val idx = (startSample + i * channels + ch).coerceIn(0, output.size - 1)
                output[idx] = sample
            }
        }
    }
}
