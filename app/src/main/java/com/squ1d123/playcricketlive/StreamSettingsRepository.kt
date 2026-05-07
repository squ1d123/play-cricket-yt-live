package com.squ1d123.playcricketlive

import android.content.Context
import android.content.SharedPreferences

data class BitratePreset(val name: String, val bitrate: Int)
data class ResolutionPreset(val name: String, val width: Int, val height: Int, val youtubeResolution: String)

class StreamSettingsRepository(context: Context) {
    private val prefs: SharedPreferences = context.getSharedPreferences("stream_settings", Context.MODE_PRIVATE)

    companion object {
        val bitratePresets = listOf(
            BitratePreset("Good (6 Mbps)", 6 * 1024 * 1024),
            BitratePreset("High (8 Mbps)", 8 * 1024 * 1024),
            BitratePreset("Very High (12 Mbps)", 12 * 1024 * 1024),
            BitratePreset("Excellent (15 Mbps)", 15 * 1024 * 1024),
            BitratePreset("Ultra (20 Mbps)", 20 * 1024 * 1024),
        )

        val resolutionPresets = listOf(
            ResolutionPreset("720p (HD)", 1280, 720, "720p"),
            ResolutionPreset("1080p (Full HD)", 1920, 1080, "1080p"),
            ResolutionPreset("1440p (2K)", 2560, 1440, "1440p"),
            ResolutionPreset("4K", 3840, 2160, "2160p"),
        )

        val privacyOptions = listOf("public" to "Public", "unlisted" to "Unlisted", "private" to "Private")

        const val DEFAULT_BITRATE_INDEX = 1
        const val DEFAULT_RESOLUTION_INDEX = 1
        const val DEFAULT_ENCODER = "h264"
        const val DEFAULT_PRIVACY = "public"
    }

    fun getScorecardUrl(): String = prefs.getString("scorecard_url", "") ?: ""
    fun saveScorecardUrl(url: String) = prefs.edit().putString("scorecard_url", url).apply()

    fun getBitrate(): Int = prefs.getInt("bitrate", bitratePresets[DEFAULT_BITRATE_INDEX].bitrate)
    fun saveBitrate(bitrate: Int) = prefs.edit().putInt("bitrate", bitrate).apply()

    fun getResolutionIndex(): Int = prefs.getInt("resolution", DEFAULT_RESOLUTION_INDEX)
    fun saveResolutionIndex(index: Int) = prefs.edit().putInt("resolution", index).apply()

    fun getResolution(): ResolutionPreset = resolutionPresets[getResolutionIndex().coerceIn(0, resolutionPresets.lastIndex)]
    fun getYoutubeResolution(): String = getResolution().youtubeResolution

    fun getVideoEncoder(): String = prefs.getString("video_encoder", DEFAULT_ENCODER) ?: DEFAULT_ENCODER
    fun saveVideoEncoder(encoder: String) = prefs.edit().putString("video_encoder", encoder).apply()

    fun getYtAccountEmail(): String = prefs.getString("yt_account_email", "") ?: ""
    fun saveYtAccountEmail(email: String) = prefs.edit().putString("yt_account_email", email).apply()
    fun clearYtAccountEmail() = prefs.edit().remove("yt_account_email").apply()

    fun getPrivacy(): String = prefs.getString("stream_privacy", DEFAULT_PRIVACY) ?: DEFAULT_PRIVACY
    fun savePrivacy(privacy: String) = prefs.edit().putString("stream_privacy", privacy).apply()
}
