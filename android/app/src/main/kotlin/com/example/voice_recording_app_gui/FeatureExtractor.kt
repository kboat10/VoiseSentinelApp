package com.example.voice_recording_app_gui

import kotlin.math.*

/**
 * Extracts 68 DSP features from a 16kHz mono float waveform.
 * Matches training pipeline: frame=1024, hop=512.
 *
 * Output order (EnsembleFeatureOrder):
 * - centroid_mean, log_energy (2)
 * - mfcc_1..mfcc_13 (13)
 * - mfcc_std_1..mfcc_std_13 (13)
 * - mel_1..mel_40 (40)
 */
object FeatureExtractor {

    const val SAMPLE_RATE = 16000
    const val FRAME_LENGTH = 1024
    const val HOP_LENGTH = 512
    const val N_MELS = 40
    const val N_MFCC = 13
    const val FFT_LENGTH = 1024

    private const val FMIN = 0.0
    private const val FMAX = 8000.0  // Nyquist for 16kHz

    /**
     * Extracts 68 acoustic features from waveform.
     * @param waveform 16kHz mono float array, values in [-1, 1]
     * @return FloatArray of 68 features in ensemble order
     */
    fun extract(waveform: FloatArray): FloatArray {
        val features = FloatArray(68)

        // 1. Log energy: log(sum(waveform^2))
        var energySum = 0.0
        for (s in waveform) {
            energySum += s * s
        }
        features[0] = ln(max(1.0, energySum)).toFloat()  // centroid_mean slot - we'll overwrite
        features[1] = ln(max(1.0, energySum)).toFloat()  // log_energy

        // 2. Frame the signal
        val nFrames = max(1, (waveform.size - FRAME_LENGTH) / HOP_LENGTH + 1)
        val centroidPerFrame = FloatArray(nFrames)
        val mfccPerFrame = Array(nFrames) { FloatArray(N_MFCC) }
        val melPerFrame = Array(nFrames) { FloatArray(N_MELS) }

        val window = FloatArray(FRAME_LENGTH) { i ->
            (0.5 * (1 - cos(2 * PI * i / (FRAME_LENGTH - 1)))).toFloat()  // Hann
        }

        val melFilterBank = createMelFilterBank()

        for (f in 0 until nFrames) {
            val start = f * HOP_LENGTH
            if (start + FRAME_LENGTH > waveform.size) break

            val frame = FloatArray(FFT_LENGTH)
            for (i in 0 until FRAME_LENGTH) {
                frame[i] = waveform[start + i] * window[i]
            }

            val magnitude = fftMagnitude(frame)

            // Spectral centroid: sum(freq * mag) / sum(mag)
            var centroidNum = 0.0
            var centroidDen = 0.0
            for (k in 1 until magnitude.size) {
                val freq = k * SAMPLE_RATE.toDouble() / FFT_LENGTH
                val mag = magnitude[k].toDouble()
                centroidNum += freq * mag
                centroidDen += mag
            }
            centroidPerFrame[f] = if (centroidDen > 1e-10) {
                (centroidNum / centroidDen).toFloat()
            } else 0f

            // Power spectrum for mel
            val powerSpectrum = FloatArray(magnitude.size) { magnitude[it] * magnitude[it] }

            // Mel spectrogram (40 bands)
            for (m in 0 until N_MELS) {
                var sum = 0.0
                for (k in 0 until melFilterBank[m].size) {
                    sum += powerSpectrum[k] * melFilterBank[m][k]
                }
                melPerFrame[f][m] = ln(max(1e-10, sum)).toFloat()
            }

            // MFCC: DCT of log mel (take first 13)
            val logMel = melPerFrame[f]
            for (c in 0 until N_MFCC) {
                var sum = 0.0
                for (m in 0 until N_MELS) {
                    sum += logMel[m] * cos(PI * c * (m + 0.5) / N_MELS)
                }
                mfccPerFrame[f][c] = (sum * sqrt(2.0 / N_MELS)).toFloat()
            }
        }

        // 3. Centroid mean
        features[0] = centroidPerFrame.average().toFloat()

        // 4. MFCC mean and std
        for (c in 0 until N_MFCC) {
            val values = FloatArray(nFrames) { mfccPerFrame[it][c] }
            features[2 + c] = values.average()
            features[15 + c] = std(values)
        }

        // 5. Mel mean (across time)
        for (m in 0 until N_MELS) {
            val values = FloatArray(nFrames) { melPerFrame[it][m] }
            features[28 + m] = values.average()
        }

        return features
    }

    private fun createMelFilterBank(): Array<FloatArray> {
        val lowMel = hzToMel(FMIN)
        val highMel = hzToMel(FMAX)
        val melPoints = FloatArray(N_MELS + 2)
        for (i in 0 until N_MELS + 2) {
            melPoints[i] = lowMel + (highMel - lowMel) * i / (N_MELS + 1)
        }
        val hzPoints = melPoints.map { melToHz(it) }

        val fftFreqs = FloatArray(FFT_LENGTH / 2 + 1) { i ->
            i * SAMPLE_RATE.toFloat() / FFT_LENGTH
        }

        val filterBank = Array(N_MELS) { FloatArray(FFT_LENGTH / 2 + 1) }
        for (i in 0 until N_MELS) {
            val left = hzPoints[i]
            val center = hzPoints[i + 1]
            val right = hzPoints[i + 2]
            for (k in fftFreqs.indices) {
                val freq = fftFreqs[k]
                filterBank[i][k] = when {
                    freq < left || freq > right -> 0f
                    freq < center -> ((freq - left) / (center - left)).toFloat()
                    else -> ((right - freq) / (right - center)).toFloat()
                }
            }
        }
        return filterBank
    }

    private fun hzToMel(hz: Double): Float =
        (2595 * log10(1 + hz / 700)).toFloat()

    private fun melToHz(mel: Float): Double =
        700 * (10.0.pow((mel / 2595).toDouble()) - 1)

    private fun fftMagnitude(signal: FloatArray): FloatArray {
        val n = signal.size
        val real = DoubleArray(n) { signal[it].toDouble() }
        val imag = DoubleArray(n) { 0.0 }
        fft(real, imag, n)
        return FloatArray(n / 2 + 1) { i ->
            sqrt(real[i] * real[i] + imag[i] * imag[i]).toFloat()
        }
    }

    private fun fft(real: DoubleArray, imag: DoubleArray, n: Int) {
        var j = 0
        for (i in 0 until n - 1) {
            if (i < j) {
                var t = real[i]; real[i] = real[j]; real[j] = t
                t = imag[i]; imag[i] = imag[j]; imag[j] = t
            }
            var m = n / 2
            while (m >= 1 && j >= m) {
                j -= m
                m /= 2
            }
            j += m
        }
        var mmax = 1
        while (n > mmax) {
            val istep = mmax * 2
            val theta = -PI / mmax
            var wtemp = sin(0.5 * theta)
            val wpr = -2 * wtemp * wtemp
            val wpi = sin(theta)
            var wr = 1.0
            var wi = 0.0
            for (m in 0 until mmax) {
                for (i in m until n step istep) {
                    val j = i + mmax
                    val tempr = wr * real[j] - wi * imag[j]
                    val tempi = wr * imag[j] + wi * real[j]
                    real[j] = real[i] - tempr
                    imag[j] = imag[i] - tempi
                    real[i] += tempr
                    imag[i] += tempi
                }
                wtemp = wr
                wr += wr * wpr - wi * wpi
                wi += wi * wpr + wtemp * wpi
            }
            mmax = istep
        }
    }

    private fun FloatArray.average(): Float {
        if (isEmpty()) return 0f
        var s = 0.0
        for (v in this) s += v
        return (s / size).toFloat()
    }

    private fun std(arr: FloatArray): Float {
        if (arr.size < 2) return 0f
        val mean = arr.average()
        var sumSq = 0.0
        for (v in arr) {
            val d = v - mean
            sumSq += d * d
        }
        return sqrt(sumSq / (arr.size - 1)).toFloat()
    }
}
