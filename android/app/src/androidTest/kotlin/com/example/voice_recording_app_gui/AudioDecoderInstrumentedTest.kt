package com.example.voice_recording_app_gui

import androidx.test.ext.junit.runners.AndroidJUnit4
import androidx.test.platform.app.InstrumentationRegistry
import org.junit.Assert.*
import org.junit.Test
import org.junit.runner.RunWith
import java.io.File
import java.io.RandomAccessFile
import java.nio.ByteBuffer
import java.nio.ByteOrder
import kotlin.math.*

/**
 * Instrumented tests for AudioDecoder.
 * Requires a connected device or emulator.
 * Run with: ./gradlew :app:connectedAndroidTest
 *
 * These tests generate synthetic WAV files on-device and verify the full
 * decode → resample → normalise pipeline without any network calls.
 */
@RunWith(AndroidJUnit4::class)
class AudioDecoderInstrumentedTest {

    private val ctx = InstrumentationRegistry.getInstrumentation().targetContext

    // ── WAV generation helpers ────────────────────────────────────────────────

    /**
     * Writes a 16-bit PCM WAV file to [file].
     * Defaults: 16 kHz mono sine at [freqHz] for [durationSec] seconds.
     */
    private fun writeSineWav(
        file: File,
        freqHz: Double = 440.0,
        sampleRate: Int = 16000,
        channels: Int = 1,
        durationSec: Double = 1.0,
    ) {
        val numSamples = (sampleRate * durationSec * channels).toInt()
        val pcm = ShortArray(numSamples) { i ->
            val t = i.toDouble() / (sampleRate * channels)
            (sin(2 * PI * freqHz * t) * 32767).toInt().toShort()
        }

        val dataSize = numSamples * 2
        val raf = RandomAccessFile(file, "rw")
        raf.use {
            // RIFF header
            it.write("RIFF".toByteArray())
            it.write(intToLe(36 + dataSize))
            it.write("WAVE".toByteArray())
            // fmt chunk
            it.write("fmt ".toByteArray())
            it.write(intToLe(16))           // chunk size
            it.write(shortToLe(1))          // PCM
            it.write(shortToLe(channels.toShort()))
            it.write(intToLe(sampleRate))
            it.write(intToLe(sampleRate * channels * 2))  // byte rate
            it.write(shortToLe((channels * 2).toShort())) // block align
            it.write(shortToLe(16))         // bits per sample
            // data chunk
            it.write("data".toByteArray())
            it.write(intToLe(dataSize))
            val buf = ByteBuffer.allocate(dataSize).order(ByteOrder.LITTLE_ENDIAN)
            pcm.forEach { s -> buf.putShort(s) }
            it.write(buf.array())
        }
    }

    private fun intToLe(v: Int): ByteArray =
        ByteBuffer.allocate(4).order(ByteOrder.LITTLE_ENDIAN).putInt(v).array()

    private fun shortToLe(v: Short): ByteArray =
        ByteBuffer.allocate(2).order(ByteOrder.LITTLE_ENDIAN).putShort(v).array()

    private fun tempWav(name: String) = File(ctx.cacheDir, name)

    // ── Tests ─────────────────────────────────────────────────────────────────

    @Test
    fun decodeWav_16kHz_mono_returns_non_null_float_array() {
        val f = tempWav("test_16k_mono.wav")
        writeSineWav(f, sampleRate = 16000, channels = 1)
        val result = AudioDecoder.decodeTo16kMonoFloat(f.path)
        assertNotNull("Expected non-null FloatArray for a valid WAV", result)
    }

    @Test
    fun decodeWav_16kHz_mono_correct_sample_count() {
        val f = tempWav("test_16k_1s.wav")
        writeSineWav(f, sampleRate = 16000, channels = 1, durationSec = 1.0)
        val result = AudioDecoder.decodeTo16kMonoFloat(f.path)!!
        // Allow ±5% tolerance for encoder overhead
        val expected = 16000
        assertTrue("Sample count should be ~16000, got ${result.size}", result.size in (expected * 95 / 100)..(expected * 105 / 100))
    }

    @Test
    fun decodeWav_44kHz_resampled_to_16kHz() {
        val f = tempWav("test_44k_mono.wav")
        writeSineWav(f, sampleRate = 44100, channels = 1, durationSec = 1.0)
        val result = AudioDecoder.decodeTo16kMonoFloat(f.path)!!
        // After resampling 44100 → 16000, expect ~16000 samples
        val expected = 16000
        assertTrue("Resampled count should be ~16000, got ${result.size}", result.size in (expected * 90 / 100)..(expected * 110 / 100))
    }

    @Test
    fun decodeWav_stereo_converted_to_mono() {
        val f = tempWav("test_stereo.wav")
        writeSineWav(f, sampleRate = 16000, channels = 2, durationSec = 1.0)
        val result = AudioDecoder.decodeTo16kMonoFloat(f.path)!!
        // Stereo → mono: samples should be halved, ≈ 16000
        assertTrue("Stereo→mono should produce ~16000 samples, got ${result.size}", result.size in 14000..18000)
    }

    @Test
    fun decodeWav_all_samples_in_normalised_range() {
        val f = tempWav("test_normalised.wav")
        writeSineWav(f, freqHz = 440.0, sampleRate = 16000, channels = 1)
        val result = AudioDecoder.decodeTo16kMonoFloat(f.path)!!
        val max = result.max()
        val min = result.min()
        assertTrue("All samples must be in [-1.0, 1.0], got max=$max min=$min", max <= 1.0f && min >= -1.0f)
    }

    @Test
    fun decodeWav_no_nan_or_inf_in_output() {
        val f = tempWav("test_no_nan.wav")
        writeSineWav(f, sampleRate = 16000, channels = 1, durationSec = 2.0)
        val result = AudioDecoder.decodeTo16kMonoFloat(f.path)!!
        for (i in result.indices) {
            assertFalse("Sample[$i] is NaN", result[i].isNaN())
            assertFalse("Sample[$i] is Inf", result[i].isInfinite())
        }
    }

    @Test
    fun decodeWav_missing_file_returns_null() {
        val result = AudioDecoder.decodeTo16kMonoFloat("/no/such/file.wav")
        assertNull("Missing file should return null", result)
    }

    @Test
    fun decodeWav_feeds_into_feature_extractor_producing_68_features() {
        val f = tempWav("test_feature_pipeline.wav")
        writeSineWav(f, freqHz = 440.0, sampleRate = 16000, channels = 1, durationSec = 1.0)
        val waveform = AudioDecoder.decodeTo16kMonoFloat(f.path)!!
        val features = FeatureExtractor.extract(waveform)
        assertEquals("Full pipeline must produce 68 DSP features", 68, features.size)
        features.forEachIndexed { i, v ->
            assertFalse("Feature[$i] is NaN", v.isNaN())
            assertFalse("Feature[$i] is Inf", v.isInfinite())
        }
    }
}
