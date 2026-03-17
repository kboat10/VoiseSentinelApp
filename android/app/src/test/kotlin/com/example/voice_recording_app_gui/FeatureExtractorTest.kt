package com.example.voice_recording_app_gui

import org.junit.Assert.*
import org.junit.Test
import kotlin.math.*

/**
 * JVM unit tests for FeatureExtractor.
 * No Android framework needed – pure Kotlin math.
 * Run with: ./gradlew :app:test
 */
class FeatureExtractorTest {

    companion object {
        const val SR = 16000

        /** Generates a sine wave at [freqHz] for [durationSec] seconds. */
        fun sine(freqHz: Double, durationSec: Double = 1.0): FloatArray {
            val n = (SR * durationSec).toInt()
            return FloatArray(n) { i -> sin(2 * PI * freqHz * i / SR).toFloat() }
        }

        /** Generates white noise of given length. */
        fun noise(n: Int = SR): FloatArray {
            val rng = java.util.Random(42)
            return FloatArray(n) { (rng.nextFloat() * 2f - 1f) }
        }
    }

    // ── Dimension tests ──────────────────────────────────────────────────────

    @Test
    fun `extract returns exactly 68 features for a 1-second sine wave`() {
        val features = FeatureExtractor.extract(sine(440.0))
        assertEquals("Feature vector must be 68-dimensional", 68, features.size)
    }

    @Test
    fun `extract returns exactly 68 features for white noise`() {
        val features = FeatureExtractor.extract(noise())
        assertEquals(68, features.size)
    }

    @Test
    fun `extract returns exactly 68 features for 3-second signal`() {
        val features = FeatureExtractor.extract(sine(440.0, 3.0))
        assertEquals(68, features.size)
    }

    @Test
    fun `extract returns 68 zero features for empty waveform`() {
        val features = FeatureExtractor.extract(FloatArray(0))
        assertEquals(68, features.size)
        features.forEach { assertEquals(0f, it, 0f) }
    }

    @Test
    fun `extract returns 68 features for a very short waveform less than one frame`() {
        val features = FeatureExtractor.extract(FloatArray(512) { 0.1f })
        assertEquals(68, features.size)
    }

    // ── Feature order tests ───────────────────────────────────────────────────

    @Test
    fun `index 0 is centroid_mean and is finite`() {
        val f = FeatureExtractor.extract(sine(440.0))
        assertTrue("centroid_mean should be finite", f[0].isFinite())
        assertTrue("centroid_mean should be > 0 for a 440Hz tone", f[0] > 0f)
    }

    @Test
    fun `index 1 is log_energy and is finite`() {
        val f = FeatureExtractor.extract(sine(440.0))
        assertTrue("log_energy should be finite", f[1].isFinite())
        assertTrue("log_energy should be > 0 for non-silent audio", f[1] > 0f)
    }

    @Test
    fun `indices 2-14 are mfcc means`() {
        val f = FeatureExtractor.extract(sine(440.0))
        for (i in 2..14) {
            assertTrue("mfcc_mean[$i] should be finite", f[i].isFinite())
        }
    }

    @Test
    fun `indices 15-27 are mfcc stds`() {
        val f = FeatureExtractor.extract(sine(440.0))
        for (i in 15..27) {
            assertTrue("mfcc_std[$i] should be finite", f[i].isFinite())
            assertTrue("mfcc_std[$i] should be >= 0 for noise", f[i] >= 0f)
        }
    }

    @Test
    fun `indices 28-67 are mel means`() {
        val f = FeatureExtractor.extract(sine(440.0))
        for (i in 28..67) {
            assertTrue("mel_mean[$i] should be finite", f[i].isFinite())
        }
    }

    // ── Sanity / value tests ──────────────────────────────────────────────────

    @Test
    fun `log_energy is zero for silent audio`() {
        // All zeros → energySum = 0, log(max(1, 0)) = log(1) = 0
        val f = FeatureExtractor.extract(FloatArray(SR) { 0f })
        assertEquals("log_energy of silence should be 0", 0f, f[1], 1e-5f)
    }

    @Test
    fun `spectral centroid is higher for high-frequency tone than low`() {
        val low = FeatureExtractor.extract(sine(200.0))
        val high = FeatureExtractor.extract(sine(4000.0))
        assertTrue(
            "4kHz centroid (${high[0]}) should be > 200Hz centroid (${low[0]})",
            high[0] > low[0]
        )
    }

    @Test
    fun `different signals produce different feature vectors`() {
        val f1 = FeatureExtractor.extract(sine(440.0))
        val f2 = FeatureExtractor.extract(sine(880.0))
        val diffs = f1.zip(f2.toList()).count { (a, b) -> abs(a - b) > 1e-6f }
        assertTrue("440Hz and 880Hz signals should differ in at least some features", diffs > 0)
    }

    @Test
    fun `no NaN or Inf in features for typical speech-like noise`() {
        val f = FeatureExtractor.extract(noise(SR * 3))
        for (i in f.indices) {
            assertFalse("Feature[$i] should not be NaN", f[i].isNaN())
            assertFalse("Feature[$i] should not be Inf", f[i].isInfinite())
        }
    }

    // ── Feature dimension matches OnnxEnsemble.FEATURE_DIM ───────────────────

    @Test
    fun `DSP features plus wav2vec embedding equals FEATURE_DIM`() {
        val dspDim = 68
        val sslDim = 1024
        assertEquals(
            "68 DSP + 1024 SSL must equal FEATURE_DIM (${OnnxEnsemble.FEATURE_DIM})",
            OnnxEnsemble.FEATURE_DIM,
            dspDim + sslDim
        )
    }

    // ── OnnxEnsemble verdict thresholds ──────────────────────────────────────

    @Test
    fun `verdict thresholds match specification`() {
        assertEquals("real",                 OnnxEnsemble.verdict(0.10))
        assertEquals("real",                 OnnxEnsemble.verdict(0.14))
        assertEquals("suspicious",           OnnxEnsemble.verdict(0.15))
        assertEquals("suspicious",           OnnxEnsemble.verdict(0.44))
        assertEquals("synthetic_probable",   OnnxEnsemble.verdict(0.45))
        assertEquals("synthetic_probable",   OnnxEnsemble.verdict(0.84))
        assertEquals("synthetic_definitive", OnnxEnsemble.verdict(0.86))
        assertEquals("synthetic_definitive", OnnxEnsemble.verdict(1.00))
    }
}
