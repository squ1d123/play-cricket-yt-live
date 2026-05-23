package com.squ1d123.playcricketlive

import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.withContext
import okhttp3.MediaType.Companion.toMediaType
import okhttp3.OkHttpClient
import okhttp3.Request
import okhttp3.RequestBody
import okio.BufferedSink
import java.util.concurrent.TimeUnit

data class SpeedTestResult(val uploadMbps: Double, val recommendedBitrateIndex: Int, val recommendedResolutionIndex: Int)

object UploadSpeedTest {
    private const val TEST_URL = "https://speed.cloudflare.com/__up"
    private const val TEST_SIZE_BYTES = 2 * 1024 * 1024L

    suspend fun run(onProgress: (String) -> Unit): SpeedTestResult = withContext(Dispatchers.IO) {
        onProgress("Preparing upload speed test...")

        val client = OkHttpClient.Builder()
            .connectTimeout(30, TimeUnit.SECONDS)
            .writeTimeout(30, TimeUnit.SECONDS)
            .readTimeout(30, TimeUnit.SECONDS)
            .build()

        val body = object : RequestBody() {
            override fun contentType() = "application/octet-stream".toMediaType()
            override fun contentLength() = TEST_SIZE_BYTES
            override fun writeTo(sink: BufferedSink) {
                val chunk = ByteArray(16384)
                var written = 0L
                while (written < TEST_SIZE_BYTES) {
                    val toWrite = minOf(chunk.size.toLong(), TEST_SIZE_BYTES - written).toInt()
                    sink.write(chunk, 0, toWrite)
                    written += toWrite
                }
            }
        }

        onProgress("Uploading test data (2 MB)...")

        val startTime = System.nanoTime()
        client.newCall(Request.Builder().url(TEST_URL).post(body).build()).execute().use { }
        val elapsed = (System.nanoTime() - startTime) / 1_000_000_000.0

        val mbps = (TEST_SIZE_BYTES * 8.0) / (elapsed * 1_000_000.0)
        onProgress("Upload speed: %.1f Mbps".format(mbps))

        val (bitrateIdx, resIdx) = recommend(mbps)
        SpeedTestResult(mbps, bitrateIdx, resIdx)
    }

    private fun recommend(mbps: Double): Pair<Int, Int> {
        // Use 70% of measured speed for streaming headroom
        val usable = mbps * 0.7
        val usableBps = (usable * 1_000_000).toInt()

        val bitrateIdx = StreamSettingsRepository.bitratePresets
            .indexOfLast { it.bitrate <= usableBps }
            .coerceAtLeast(0)

        val resIdx = when {
            usable >= 15 -> 3 // 4K
            usable >= 10 -> 2 // 1440p
            usable >= 6 -> 1  // 1080p
            else -> 0         // 720p
        }

        return bitrateIdx to resIdx
    }
}
