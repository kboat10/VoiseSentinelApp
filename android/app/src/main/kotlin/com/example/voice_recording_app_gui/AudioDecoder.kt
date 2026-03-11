package com.example.voice_recording_app_gui

import android.media.MediaCodec
import android.media.MediaExtractor
import android.media.MediaFormat
import java.io.File
import java.nio.ByteBuffer
import java.nio.ByteOrder
import kotlin.math.min

/**
 * Decodes M4A/AAC audio files to 16kHz mono PCM float array for feature extraction.
 * Uses MediaExtractor + MediaCodec for decoding, then resamples to 16kHz and converts to mono.
 */
object AudioDecoder {

    const val TARGET_SAMPLE_RATE = 16000

    /**
     * Decodes an audio file (m4a, mp3, etc.) to 16kHz mono PCM as FloatArray.
     * Values are normalized to approximately [-1, 1] range for Wav2Vec2.
     *
     * @param audioPath Path to the audio file
     * @return FloatArray of 16kHz mono PCM, or null on failure
     */
    fun decodeTo16kMonoFloat(audioPath: String): FloatArray? {
        val file = File(audioPath)
        if (!file.exists()) return null

        return try {
            val extractor = MediaExtractor()
            extractor.setDataSource(audioPath)

            var trackIndex = -1
            for (i in 0 until extractor.trackCount) {
                val format = extractor.getTrackFormat(i)
                val mime = format.getString(MediaFormat.KEY_MIME) ?: ""
                if (mime.startsWith("audio/")) {
                    trackIndex = i
                    break
                }
            }
            if (trackIndex < 0) return null

            extractor.selectTrack(trackIndex)
            val format = extractor.getTrackFormat(trackIndex)
            val mime = format.getString(MediaFormat.KEY_MIME) ?: return null

            val codec = MediaCodec.createDecoderByType(mime)
            codec.configure(format, null, null, 0)
            codec.start()

            val pcmSamples = mutableListOf<Short>()
            val bufferInfo = MediaCodec.BufferInfo()
            var inputDone = false
            var outputDone = false

            while (!outputDone) {
                if (!inputDone) {
                    val inputBufferIndex = codec.dequeueInputBuffer(10000)
                    if (inputBufferIndex >= 0) {
                        val inputBuffer = codec.getInputBuffer(inputBufferIndex)
                            ?: continue
                        val sampleSize = extractor.readSampleData(inputBuffer, 0)
                        if (sampleSize < 0) {
                            codec.queueInputBuffer(
                                inputBufferIndex, 0, 0, 0,
                                MediaCodec.BUFFER_FLAG_END_OF_STREAM
                            )
                            inputDone = true
                        } else {
                            val presentationTimeUs = extractor.sampleTime
                            codec.queueInputBuffer(
                                inputBufferIndex, 0, sampleSize, presentationTimeUs, 0
                            )
                            extractor.advance()
                        }
                    }
                }

                val outputBufferIndex = codec.dequeueOutputBuffer(bufferInfo, 10000)
                when {
                    outputBufferIndex >= 0 -> {
                        if (bufferInfo.flags and MediaCodec.BUFFER_FLAG_END_OF_STREAM != 0) {
                            outputDone = true
                        }
                        val outputBuffer = codec.getOutputBuffer(outputBufferIndex) ?: run {
                            codec.releaseOutputBuffer(outputBufferIndex, false)
                            continue
                        }
                        outputBuffer.position(bufferInfo.offset)
                        outputBuffer.limit(bufferInfo.offset + bufferInfo.size)
                        val chunk = ByteArray(bufferInfo.size)
                        outputBuffer.get(chunk)
                        val shorts = ByteBuffer.wrap(chunk).order(ByteOrder.nativeOrder()).asShortBuffer()
                        while (shorts.hasRemaining()) {
                            pcmSamples.add(shorts.get())
                        }
                        codec.releaseOutputBuffer(outputBufferIndex, false)
                    }
                    outputBufferIndex == MediaCodec.INFO_OUTPUT_FORMAT_CHANGED -> {
                        // Format changed, continue
                    }
                    outputBufferIndex == MediaCodec.INFO_TRY_AGAIN_LATER -> {
                        if (inputDone) outputDone = true
                    }
                    else -> {
                        if (inputDone) outputDone = true
                    }
                }
            }

            codec.stop()
            codec.release()
            extractor.release()

            val sourceSampleRate = format.getInteger(MediaFormat.KEY_SAMPLE_RATE).takeIf { it > 0 } ?: 44100
            val channelCount = format.getInteger(MediaFormat.KEY_CHANNEL_COUNT).takeIf { it > 0 } ?: 1
            val sourceSamples = pcmSamples.toShortArray()

            val mono = if (channelCount > 1) {
                toMono(sourceSamples, channelCount)
            } else {
                sourceSamples
            }

            val resampled = if (sourceSampleRate != TARGET_SAMPLE_RATE) {
                resample(mono, sourceSampleRate, TARGET_SAMPLE_RATE)
            } else {
                mono
            }

            val floats = FloatArray(resampled.size) { resampled[it] / 32768f }
            floats
        } catch (e: Exception) {
            e.printStackTrace()
            null
        }
    }

    private fun toMono(samples: ShortArray, channels: Int): ShortArray {
        val monoSize = samples.size / channels
        val mono = ShortArray(monoSize)
        for (i in 0 until monoSize) {
            var sum = 0
            for (c in 0 until channels) {
                sum += samples[i * channels + c].toInt()
            }
            mono[i] = (sum / channels).toShort()
        }
        return mono
    }

    private fun resample(samples: ShortArray, fromRate: Int, toRate: Int): ShortArray {
        if (fromRate == toRate) return samples
        val ratio = fromRate.toDouble() / toRate
        val outSize = (samples.size / ratio).toInt()
        val out = ShortArray(outSize)
        for (i in 0 until outSize) {
            val srcIdx = i * ratio
            val idx0 = srcIdx.toInt().coerceIn(0, samples.size - 1)
            val idx1 = (idx0 + 1).coerceIn(0, samples.size - 1)
            val frac = srcIdx - idx0
            val v0 = samples[idx0].toInt()
            val v1 = samples[idx1].toInt()
            out[i] = (v0 + (v1 - v0) * frac).toInt().coerceIn(-32768, 32767).toShort()
        }
        return out
    }
}
