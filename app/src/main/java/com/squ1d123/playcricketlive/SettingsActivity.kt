package com.squ1d123.playcricketlive

import android.app.Activity
import android.os.Bundle
import androidx.activity.ComponentActivity
import androidx.activity.compose.rememberLauncherForActivityResult
import androidx.activity.compose.setContent
import androidx.activity.result.contract.ActivityResultContracts
import androidx.compose.foundation.layout.*
import androidx.compose.foundation.rememberScrollState
import androidx.compose.foundation.verticalScroll
import androidx.compose.material3.*
import androidx.compose.runtime.*
import androidx.compose.ui.Modifier
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.platform.LocalContext
import androidx.compose.ui.unit.dp
import kotlinx.coroutines.launch

class SettingsActivity : ComponentActivity() {
    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        setContent {
            MaterialTheme(colorScheme = darkColorScheme().copy(primary = Color.Red)) {
                SettingsScreen(onBack = { finish() })
            }
        }
    }
}

@OptIn(ExperimentalMaterial3Api::class)
@Composable
fun SettingsScreen(onBack: () -> Unit) {
    val context = LocalContext.current
    val settings = remember { StreamSettingsRepository(context) }
    val ytService = remember { YouTubeLiveService(context) }
    val scope = rememberCoroutineScope()

    var scorecardUrl by remember { mutableStateOf(settings.getScorecardUrl()) }
    var selectedBitrateIndex by remember {
        val current = settings.getBitrate()
        val idx = StreamSettingsRepository.bitratePresets.indexOfFirst { it.bitrate == current }
        mutableIntStateOf(if (idx >= 0) idx else StreamSettingsRepository.DEFAULT_BITRATE_INDEX)
    }
    var selectedResolutionIndex by remember { mutableIntStateOf(settings.getResolutionIndex()) }
    var selectedEncoder by remember { mutableStateOf(settings.getVideoEncoder()) }
    var selectedPrivacy by remember { mutableStateOf(settings.getPrivacy()) }
    var ytEmail by remember { mutableStateOf(ytService.currentEmail) }
    var snackMessage by remember { mutableStateOf<String?>(null) }

    val snackbarHostState = remember { SnackbarHostState() }
    LaunchedEffect(snackMessage) {
        snackMessage?.let {
            snackbarHostState.showSnackbar(it)
            snackMessage = null
        }
    }

    val signInLauncher = rememberLauncherForActivityResult(ActivityResultContracts.StartActivityForResult()) { result ->
        if (result.resultCode == Activity.RESULT_OK) {
            val success = ytService.handleSignInResult(result.data)
            ytEmail = ytService.currentEmail
            snackMessage = if (success) "Signed in as ${ytEmail}" else "Sign-in failed"
        }
    }

    Scaffold(
        snackbarHost = { SnackbarHost(snackbarHostState) },
        topBar = {
            TopAppBar(
                title = { Text("Stream Settings") },
                colors = TopAppBarDefaults.topAppBarColors(containerColor = Color.Red, titleContentColor = Color.White)
            )
        }
    ) { padding ->
        Column(
            modifier = Modifier.fillMaxSize().padding(padding).padding(16.dp).verticalScroll(rememberScrollState()),
            verticalArrangement = Arrangement.spacedBy(16.dp)
        ) {
            // YouTube Account
            Text("YouTube Account", style = MaterialTheme.typography.titleMedium)
            if (ytEmail != null) {
                Text("Signed in as: $ytEmail", color = Color.Green)
                Row(horizontalArrangement = Arrangement.spacedBy(8.dp)) {
                    Button(onClick = { ytService.signOutForSwitch(); ytEmail = null; signInLauncher.launch(ytService.getSignInIntent()) }) { Text("Switch") }
                    Button(onClick = { scope.launch { ytService.signOut(); ytEmail = null; snackMessage = "Signed out" } },
                        colors = ButtonDefaults.buttonColors(containerColor = Color.Gray)) { Text("Sign Out") }
                }
            } else {
                Text("Not signed in", color = Color.Gray)
                Button(onClick = { signInLauncher.launch(ytService.getSignInIntent()) }) { Text("Sign In with Google") }
            }

            HorizontalDivider()

            // Scorecard URL
            Text("Scorecard URL", style = MaterialTheme.typography.titleMedium)
            OutlinedTextField(
                value = scorecardUrl,
                onValueChange = { scorecardUrl = it },
                label = { Text("Play-Cricket Match URL") },
                placeholder = { Text("https://yourclub.play-cricket.com/website/results/1234567") },
                modifier = Modifier.fillMaxWidth(),
                singleLine = true
            )

            HorizontalDivider()

            // Bitrate
            var bitrateExpanded by remember { mutableStateOf(false) }
            ExposedDropdownMenuBox(expanded = bitrateExpanded, onExpandedChange = { bitrateExpanded = it }) {
                OutlinedTextField(
                    value = StreamSettingsRepository.bitratePresets[selectedBitrateIndex].name,
                    onValueChange = {},
                    readOnly = true,
                    label = { Text("Bitrate") },
                    trailingIcon = { ExposedDropdownMenuDefaults.TrailingIcon(bitrateExpanded) },
                    modifier = Modifier.fillMaxWidth().menuAnchor()
                )
                ExposedDropdownMenu(expanded = bitrateExpanded, onDismissRequest = { bitrateExpanded = false }) {
                    StreamSettingsRepository.bitratePresets.forEachIndexed { i, preset ->
                        DropdownMenuItem(text = { Text(preset.name) }, onClick = { selectedBitrateIndex = i; bitrateExpanded = false })
                    }
                }
            }

            // Resolution
            var resExpanded by remember { mutableStateOf(false) }
            ExposedDropdownMenuBox(expanded = resExpanded, onExpandedChange = { resExpanded = it }) {
                OutlinedTextField(
                    value = StreamSettingsRepository.resolutionPresets[selectedResolutionIndex].name,
                    onValueChange = {},
                    readOnly = true,
                    label = { Text("Resolution") },
                    trailingIcon = { ExposedDropdownMenuDefaults.TrailingIcon(resExpanded) },
                    modifier = Modifier.fillMaxWidth().menuAnchor()
                )
                ExposedDropdownMenu(expanded = resExpanded, onDismissRequest = { resExpanded = false }) {
                    StreamSettingsRepository.resolutionPresets.forEachIndexed { i, preset ->
                        DropdownMenuItem(text = { Text(preset.name) }, onClick = { selectedResolutionIndex = i; resExpanded = false })
                    }
                }
            }

            // Encoder
            val encoders = listOf("h264" to "H264 (compatible)", "h265" to "H265 / HEVC", "av1" to "AV1 (best compression)")
            var encExpanded by remember { mutableStateOf(false) }
            ExposedDropdownMenuBox(expanded = encExpanded, onExpandedChange = { encExpanded = it }) {
                OutlinedTextField(
                    value = encoders.first { it.first == selectedEncoder }.second,
                    onValueChange = {},
                    readOnly = true,
                    label = { Text("Video Encoder") },
                    trailingIcon = { ExposedDropdownMenuDefaults.TrailingIcon(encExpanded) },
                    modifier = Modifier.fillMaxWidth().menuAnchor()
                )
                ExposedDropdownMenu(expanded = encExpanded, onDismissRequest = { encExpanded = false }) {
                    encoders.forEach { (key, label) ->
                        DropdownMenuItem(text = { Text(label) }, onClick = { selectedEncoder = key; encExpanded = false })
                    }
                }
            }

            // Stream privacy
            var privacyExpanded by remember { mutableStateOf(false) }
            ExposedDropdownMenuBox(expanded = privacyExpanded, onExpandedChange = { privacyExpanded = it }) {
                OutlinedTextField(
                    value = StreamSettingsRepository.privacyOptions.first { it.first == selectedPrivacy }.second,
                    onValueChange = {},
                    readOnly = true,
                    label = { Text("Stream Privacy") },
                    trailingIcon = { ExposedDropdownMenuDefaults.TrailingIcon(privacyExpanded) },
                    modifier = Modifier.fillMaxWidth().menuAnchor()
                )
                ExposedDropdownMenu(expanded = privacyExpanded, onDismissRequest = { privacyExpanded = false }) {
                    StreamSettingsRepository.privacyOptions.forEach { (key, label) ->
                        DropdownMenuItem(text = { Text(label) }, onClick = { selectedPrivacy = key; privacyExpanded = false })
                    }
                }
            }

            Spacer(Modifier.height(16.dp))

            // Save button
            Button(
                onClick = {
                    settings.saveScorecardUrl(scorecardUrl.trim())
                    settings.saveBitrate(StreamSettingsRepository.bitratePresets[selectedBitrateIndex].bitrate)
                    settings.saveResolutionIndex(selectedResolutionIndex)
                    settings.saveVideoEncoder(selectedEncoder)
                    settings.savePrivacy(selectedPrivacy)
                    snackMessage = "Settings saved!"
                },
                modifier = Modifier.fillMaxWidth(),
                colors = ButtonDefaults.buttonColors(containerColor = Color.Red)
            ) {
                Text("Save Settings", modifier = Modifier.padding(8.dp))
            }
        }
    }
}
