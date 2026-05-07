package com.squ1d123.playcricketlive

import android.app.Activity
import android.content.Context
import android.content.Intent
import androidx.activity.result.ActivityResultLauncher
import com.google.android.gms.auth.api.signin.GoogleSignIn
import com.google.android.gms.auth.api.signin.GoogleSignInAccount
import com.google.android.gms.auth.api.signin.GoogleSignInClient
import com.google.android.gms.auth.api.signin.GoogleSignInOptions
import com.google.android.gms.common.api.Scope
import com.google.api.client.googleapis.extensions.android.gms.auth.GoogleAccountCredential
import com.google.api.client.http.javanet.NetHttpTransport
import com.google.api.client.json.gson.GsonFactory
import com.google.api.services.youtube.YouTube
import com.google.api.services.youtube.model.*
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.withContext
import java.util.Collections

class YouTubeLiveService(private val context: Context) {

    companion object {
        private const val YOUTUBE_SCOPE = "https://www.googleapis.com/auth/youtube"
        private const val YOUTUBE_FORCE_SSL_SCOPE = "https://www.googleapis.com/auth/youtube.force-ssl"
    }

    private val settings = StreamSettingsRepository(context)
    private var googleSignInClient: GoogleSignInClient
    private var account: GoogleSignInAccount? = null
    private var youtubeApi: YouTube? = null

    val isSignedIn: Boolean get() = account != null
    val currentEmail: String? get() = account?.email

    init {
        val gso = GoogleSignInOptions.Builder(GoogleSignInOptions.DEFAULT_SIGN_IN)
            .requestEmail()
            .requestScopes(Scope(YOUTUBE_SCOPE), Scope(YOUTUBE_FORCE_SSL_SCOPE))
            .build()
        googleSignInClient = GoogleSignIn.getClient(context, gso)

        // Restore existing sign-in
        val lastAccount = GoogleSignIn.getLastSignedInAccount(context)
        if (lastAccount != null && GoogleSignIn.hasPermissions(lastAccount, Scope(YOUTUBE_SCOPE))) {
            account = lastAccount
            buildYouTubeApi()
        }
    }

    fun getSignInIntent(): Intent = googleSignInClient.signInIntent

    fun handleSignInResult(data: Intent?): Boolean {
        val task = GoogleSignIn.getSignedInAccountFromIntent(data)
        return try {
            account = task.getResult(Exception::class.java)
            buildYouTubeApi()
            settings.saveYtAccountEmail(account?.email ?: "")
            true
        } catch (e: Exception) {
            false
        }
    }

    suspend fun signOut() {
        withContext(Dispatchers.IO) {
            googleSignInClient.signOut().addOnCompleteListener {}
        }
        account = null
        youtubeApi = null
        settings.clearYtAccountEmail()
    }

    private fun buildYouTubeApi() {
        val credential = GoogleAccountCredential.usingOAuth2(
            context, listOf(YOUTUBE_SCOPE, YOUTUBE_FORCE_SSL_SCOPE)
        )
        credential.selectedAccount = account?.account
        youtubeApi = YouTube.Builder(NetHttpTransport(), GsonFactory.getDefaultInstance(), credential)
            .setApplicationName("PlayCricketLive")
            .build()
    }

    suspend fun createAndBindStream(title: String, privacy: String = "public"): String? = withContext(Dispatchers.IO) {
        val api = youtubeApi ?: return@withContext null

        try {
            // 1. Create broadcast
            val broadcast = api.liveBroadcasts().insert(
                listOf("snippet", "contentDetails", "status"),
                LiveBroadcast()
                    .setSnippet(LiveBroadcastSnippet().setTitle(title).setScheduledStartTime(com.google.api.client.util.DateTime(System.currentTimeMillis())))
                    .setContentDetails(LiveBroadcastContentDetails().setEnableAutoStart(true).setEnableAutoStop(true).setLatencyPreference("normal"))
                    .setStatus(LiveBroadcastStatus().setPrivacyStatus(privacy).setSelfDeclaredMadeForKids(false))
            ).execute()

            val broadcastId = broadcast.id

            // 2. Create stream
            val resolution = settings.getYoutubeResolution()
            val stream = api.liveStreams().insert(
                listOf("snippet", "cdn"),
                LiveStream()
                    .setSnippet(LiveStreamSnippet().setTitle("$title - Stream"))
                    .setCdn(CdnSettings().setFrameRate("60fps").setIngestionType("rtmp").setResolution(resolution))
            ).execute()

            val streamId = stream.id
            val ingestionUrl = stream.cdn.ingestionInfo.ingestionAddress
            val streamName = stream.cdn.ingestionInfo.streamName

            // 3. Bind stream to broadcast
            api.liveBroadcasts().bind(broadcastId, listOf("id", "contentDetails"))
                .setStreamId(streamId)
                .execute()

            "$ingestionUrl/$streamName"
        } catch (e: Exception) {
            e.printStackTrace()
            null
        }
    }
}
