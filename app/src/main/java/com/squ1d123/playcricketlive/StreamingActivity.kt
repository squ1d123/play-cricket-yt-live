package com.squ1d123.playcricketlive

import android.Manifest
import android.app.Activity
import android.content.pm.PackageManager
import android.os.Bundle
import android.view.SurfaceHolder
import android.view.WindowManager
import android.widget.Toast
import androidx.activity.ComponentActivity
import androidx.activity.compose.rememberLauncherForActivityResult
import androidx.activity.compose.setContent
import androidx.activity.result.contract.ActivityResultContracts
import androidx.compose.foundation.background
import androidx.compose.foundation.clickable
import androidx.compose.foundation.layout.*
import androidx.compose.foundation.shape.CircleShape
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.filled.*
import androidx.compose.material3.*
import androidx.compose.runtime.*
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.graphics.graphicsLayer
import androidx.compose.ui.platform.LocalContext
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import androidx.compose.ui.viewinterop.AndroidView
import androidx.core.content.ContextCompat
import com.pedro.common.ConnectChecker
import com.pedro.encoder.input.gl.render.filters.`object`.ImageObjectFilterRender
import com.pedro.encoder.utils.gl.TranslateTo
import com.pedro.library.rtmp.RtmpCamera2
import com.pedro.library.view.OpenGlView
import kotlinx.coroutines.delay
import kotlinx.coroutines.launch

class StreamingActivity : ComponentActivity(), ConnectChecker {

    private var rtmpCamera: RtmpCamera2? = null
    private var openGlView: OpenGlView? = null

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        window.addFlags(WindowManager.LayoutParams.FLAG_KEEP_SCREEN_ON)

        setContent {
            MaterialTheme(colorScheme = darkColorScheme().copy(primary = Color.Red)) {
                StreamingScreen(
                    activity = this,
                    getRtmpCamera = { rtmpCamera },
                    setRtmpCamera = { rtmpCamera = it },
                    getOpenGlView = { openGlView },
                    setOpenGlView = { openGlView = it },
                )
            }
        }
    }

    override fun onDestroy() {
        super.onDestroy()
        rtmpCamera?.let {
            if (it.isStreaming) it.stopStream()
            if (it.isOnPreview) it.stopPreview()
        }
    }

    // ConnectChecker callbacks
    override fun onConnectionStarted(url: String) {}
    override fun onConnectionSuccess() { runOnUiThread { Toast.makeText(this, "Connected", Toast.LENGTH_SHORT).show() } }
    override fun onConnectionFailed(reason: String) { runOnUiThread { Toast.makeText(this, "Connection failed: $reason", Toast.LENGTH_SHORT).show(); rtmpCamera?.stopStream() } }
    override fun onNewBitrate(bitrate: Long) {}
    override fun onDisconnect() { runOnUiThread { Toast.makeText(this, "Disconnected", Toast.LENGTH_SHORT).show() } }
    override fun onAuthError() { runOnUiThread { Toast.makeText(this, "Auth error", Toast.LENGTH_SHORT).show() } }
    override fun onAuthSuccess() {}
}

@Composable
fun StreamingScreen(
    activity: StreamingActivity,
    getRtmpCamera: () -> RtmpCamera2?,
    setRtmpCamera: (RtmpCamera2) -> Unit,
    getOpenGlView: () -> OpenGlView?,
    setOpenGlView: (OpenGlView) -> Unit,
) {
    val context = LocalContext.current
    val settings = remember { StreamSettingsRepository(context) }
    val ytService = remember { YouTubeLiveService(context) }
    val scope = rememberCoroutineScope()

    var isStreaming by remember { mutableStateOf(false) }
    var hasPermissions by remember { mutableStateOf(false) }
    var cameraReady by remember { mutableStateOf(false) }
    var showOverlay by remember { mutableStateOf(true) }
    val scraper = remember { PlayCricketScraper() }
    val overlayFilterRef = remember { mutableStateOf<ImageObjectFilterRender?>(null) }

    val permissionLauncher = rememberLauncherForActivityResult(ActivityResultContracts.RequestMultiplePermissions()) { perms ->
        hasPermissions = perms.values.all { it }
    }

    LaunchedEffect(Unit) {
        val cam = ContextCompat.checkSelfPermission(context, Manifest.permission.CAMERA) == PackageManager.PERMISSION_GRANTED
        val mic = ContextCompat.checkSelfPermission(context, Manifest.permission.RECORD_AUDIO) == PackageManager.PERMISSION_GRANTED
        if (cam && mic) {
            hasPermissions = true
        } else {
            permissionLauncher.launch(arrayOf(Manifest.permission.CAMERA, Manifest.permission.RECORD_AUDIO))
        }
    }

    // Periodic score scraping + overlay update
    LaunchedEffect(cameraReady, showOverlay) {
        if (!cameraReady) return@LaunchedEffect
        val scorecardUrl = settings.getScorecardUrl()
        if (scorecardUrl.isEmpty()) return@LaunchedEffect
        val resolution = settings.getResolution()
        val renderer = ScoreOverlayRenderer(resolution.width, resolution.height)

        while (true) {
            try {
                val matchData = scraper.fetchMatchData(scorecardUrl)
                if (matchData != null) {
                    val bowler = scraper.fetchCurrentBowler(matchData)
                    val bitmap = renderer.render(
                        batsman1Name = matchData.batsmen.getOrNull(0)?.name ?: "",
                        batsman1Runs = matchData.batsmen.getOrNull(0)?.runs ?: 0,
                        batsman1Balls = matchData.batsmen.getOrNull(0)?.balls ?: 0,
                        batsman2Name = matchData.batsmen.getOrNull(1)?.name ?: "",
                        batsman2Runs = matchData.batsmen.getOrNull(1)?.runs ?: 0,
                        batsman2Balls = matchData.batsmen.getOrNull(1)?.balls ?: 0,
                        score = matchData.battingScore.ifEmpty { matchData.homeScore },
                        overs = matchData.battingOvers.ifEmpty { matchData.homeOvers },
                        bowlerName = bowler?.name ?: "",
                        bowlerWickets = bowler?.wickets ?: 0,
                        bowlerRuns = bowler?.runs ?: 0,
                        bowlerOvers = bowler?.overs ?: 0,
                    )

                    val camera = getRtmpCamera()
                    if (camera != null && showOverlay) {
                        if (overlayFilterRef.value == null) {
                            val filter = ImageObjectFilterRender()
                            camera.glInterface.addFilter(filter)
                            filter.setScale(100f, renderer.getScaleY())
                            filter.setPosition(TranslateTo.BOTTOM)
                            filter.setImage(bitmap)
                            overlayFilterRef.value = filter
                        } else {
                            overlayFilterRef.value?.setImage(bitmap)
                        }
                    } else if (!showOverlay && overlayFilterRef.value != null) {
                        camera?.glInterface?.removeFilter(overlayFilterRef.value!!)
                        overlayFilterRef.value = null
                    }
                }
            } catch (_: Exception) {}
            delay(30_000)
        }
    }

    val signInLauncher = rememberLauncherForActivityResult(ActivityResultContracts.StartActivityForResult()) { result ->
        if (result.resultCode == Activity.RESULT_OK) {
            ytService.handleSignInResult(result.data)
        }
    }

    Box(modifier = Modifier.fillMaxSize().background(Color.Black)) {
        if (hasPermissions) {
            // Camera preview
            AndroidView(
                factory = { ctx ->
                    val glView = OpenGlView(ctx)
                    setOpenGlView(glView)
                    glView.holder.addCallback(object : SurfaceHolder.Callback {
                        override fun surfaceCreated(holder: SurfaceHolder) {
                            val resolution = settings.getResolution()
                            val camera = RtmpCamera2(glView, activity)
                            setRtmpCamera(camera)
                            camera.prepareVideo(resolution.width, resolution.height, 60, settings.getBitrate(), 0)
                            camera.prepareAudio(128000, 44100, true)

                            // Log detailed camera info
                            val camManager = context.getSystemService(android.content.Context.CAMERA_SERVICE) as android.hardware.camera2.CameraManager
                            for (id in camManager.cameraIdList) {
                                try {
                                    val chars = camManager.getCameraCharacteristics(id)
                                    val facing = chars.get(android.hardware.camera2.CameraCharacteristics.LENS_FACING)
                                    val facingStr = when (facing) { 0 -> "FRONT"; 1 -> "BACK"; 2 -> "EXTERNAL"; else -> "?" }
                                    val focalLengths = chars.get(android.hardware.camera2.CameraCharacteristics.LENS_INFO_AVAILABLE_FOCAL_LENGTHS)
                                    val sensorSize = chars.get(android.hardware.camera2.CameraCharacteristics.SENSOR_INFO_PIXEL_ARRAY_SIZE)
                                    val physicalSize = chars.get(android.hardware.camera2.CameraCharacteristics.SENSOR_INFO_PHYSICAL_SIZE)
                                    val capabilities = chars.get(android.hardware.camera2.CameraCharacteristics.REQUEST_AVAILABLE_CAPABILITIES)
                                    val isLogical = capabilities?.contains(android.hardware.camera2.CameraCharacteristics.REQUEST_AVAILABLE_CAPABILITIES_LOGICAL_MULTI_CAMERA) == true
                                    val physicalCamIds = if (android.os.Build.VERSION.SDK_INT >= 28) chars.physicalCameraIds else emptySet()
                                    val zoomRange = if (android.os.Build.VERSION.SDK_INT >= 30) chars.get(android.hardware.camera2.CameraCharacteristics.CONTROL_ZOOM_RATIO_RANGE) else null
                                    val outputSizes = chars.get(android.hardware.camera2.CameraCharacteristics.SCALER_STREAM_CONFIGURATION_MAP)
                                        ?.getOutputSizes(android.graphics.ImageFormat.JPEG)
                                        ?.take(3)?.joinToString { "${it.width}x${it.height}" }

                                    android.util.Log.d("CameraInfo", "=== Camera ID: $id ===")
                                    android.util.Log.d("CameraInfo", "  Facing: $facingStr")
                                    android.util.Log.d("CameraInfo", "  Focal lengths: ${focalLengths?.joinToString()}")
                                    android.util.Log.d("CameraInfo", "  Sensor pixels: ${sensorSize?.width}x${sensorSize?.height}")
                                    android.util.Log.d("CameraInfo", "  Sensor physical: ${physicalSize?.width}mm x ${physicalSize?.height}mm")
                                    android.util.Log.d("CameraInfo", "  Logical multi-cam: $isLogical")
                                    android.util.Log.d("CameraInfo", "  Physical sub-cameras: $physicalCamIds")
                                    android.util.Log.d("CameraInfo", "  Zoom range: $zoomRange")
                                    android.util.Log.d("CameraInfo", "  Top output sizes: $outputSizes")
                                } catch (e: Exception) {
                                    android.util.Log.d("CameraInfo", "Camera $id: error ${e.message}")
                                }
                            }

                            // Start on logical camera "0" to enable multi-camera zoom switching
                            camera.startPreview("5")
                            // Log available optical zoom levels
                            val opticalZooms = camera.opticalZooms
                            if (opticalZooms != null && opticalZooms.isNotEmpty()) {
                                android.util.Log.d("StreamingActivity", "Optical zooms: ${opticalZooms.joinToString()}")
                            }
                            android.util.Log.d("StreamingActivity", "Zoom range: ${camera.zoomRange}")
                            android.util.Log.d("StreamingActivity", "Current camera ID: ${camera.currentCameraId}")
                            android.util.Log.d("StreamingActivity", "Physical cameras available: ${camera.physicalCamerasAvailable()}")
                            // Try to find hidden physical cameras (4, 5, 6...)
                            for (physId in 4..10) {
                                try {
                                    val chars = camManager.getCameraCharacteristics(physId.toString())
                                    val fl = chars.get(android.hardware.camera2.CameraCharacteristics.LENS_INFO_AVAILABLE_FOCAL_LENGTHS)
                                    val pixels = chars.get(android.hardware.camera2.CameraCharacteristics.SENSOR_INFO_PIXEL_ARRAY_SIZE)
                                    android.util.Log.d("CameraInfo", "=== Hidden Camera ID: $physId === FL: ${fl?.joinToString()}, Pixels: ${pixels?.width}x${pixels?.height}")
                                } catch (_: Exception) {}
                            }
                            cameraReady = true
                        }
                        override fun surfaceChanged(holder: SurfaceHolder, format: Int, width: Int, height: Int) {}
                        override fun surfaceDestroyed(holder: SurfaceHolder) {
                            getRtmpCamera()?.let {
                                if (it.isStreaming) it.stopStream()
                                if (it.isOnPreview) it.stopPreview()
                            }
                            cameraReady = false
                        }
                    })
                    glView
                },
                modifier = Modifier.fillMaxSize()
            )

            // Top bar - status
            Row(
                modifier = Modifier.fillMaxWidth().padding(16.dp).align(Alignment.TopStart),
                horizontalArrangement = Arrangement.SpaceBetween
            ) {
                // LIVE indicator
                Surface(
                    color = if (isStreaming) Color.Red else Color.Gray,
                    shape = MaterialTheme.shapes.small
                ) {
                    Text(
                        if (isStreaming) " ● LIVE " else " OFFLINE ",
                        color = Color.White,
                        fontSize = 14.sp,
                        modifier = Modifier.padding(horizontal = 12.dp, vertical = 4.dp)
                    )
                }

                Row(horizontalArrangement = Arrangement.spacedBy(8.dp)) {
                    if (!ytService.isSignedIn) {
                        IconButton(onClick = { signInLauncher.launch(ytService.getSignInIntent()) }) {
                            Icon(Icons.Default.Person, "Sign in", tint = Color.White)
                        }
                    } else {
                        Icon(Icons.Default.CheckCircle, "Signed in", tint = Color.Green, modifier = Modifier.size(24.dp).align(Alignment.CenterVertically))
                    }
                    // Toggle overlay
                    IconButton(onClick = { showOverlay = !showOverlay }) {
                        Icon(
                            if (showOverlay) Icons.Default.Clear else Icons.Default.Star,
                            "Toggle overlay", tint = Color.White
                        )
                    }
                    // Camera picker
                    var showCameraPicker by remember { mutableStateOf(false) }
                    Box {
                        IconButton(onClick = { showCameraPicker = true }) {
                            Icon(Icons.Default.Refresh, "Switch camera", tint = Color.White)
                        }
                        DropdownMenu(expanded = showCameraPicker, onDismissRequest = { showCameraPicker = false }) {
                            val camera = getRtmpCamera()
                            val cameras = camera?.camerasAvailable ?: emptyArray()
                            val currentId = camera?.currentCameraId ?: ""
                            val cameraManager = remember {
                                context.getSystemService(android.content.Context.CAMERA_SERVICE) as android.hardware.camera2.CameraManager
                            }
                            // List all cameras from CameraManager (includes physical cameras)
                            val allCameraIds = remember {
                                try { cameraManager.cameraIdList.toList() } catch (_: Exception) { cameras.toList() }
                            }
                            allCameraIds.forEach { id ->
                                val label = remember(id) {
                                    try {
                                        val chars = cameraManager.getCameraCharacteristics(id)
                                        val facing = chars.get(android.hardware.camera2.CameraCharacteristics.LENS_FACING)
                                        val focalLengths = chars.get(android.hardware.camera2.CameraCharacteristics.LENS_INFO_AVAILABLE_FOCAL_LENGTHS)
                                        val fl = focalLengths?.firstOrNull() ?: 0f
                                        val sensorSize = chars.get(android.hardware.camera2.CameraCharacteristics.SENSOR_INFO_PIXEL_ARRAY_SIZE)
                                        val mp = if (sensorSize != null) "${(sensorSize.width.toLong() * sensorSize.height / 1_000_000)}MP" else ""
                                        val facingStr = when (facing) {
                                            android.hardware.camera2.CameraCharacteristics.LENS_FACING_FRONT -> "Front"
                                            android.hardware.camera2.CameraCharacteristics.LENS_FACING_BACK -> when {
                                                fl > 7f -> "Tele"
                                                fl < 3.5f -> "Ultra-wide"
                                                else -> "Wide"
                                            }
                                            else -> "External"
                                        }
                                        "$facingStr ${String.format("%.1f", fl)}mm $mp [id:$id]"
                                    } catch (_: Exception) { "Camera $id" }
                                }
                                DropdownMenuItem(
                                    text = { Text(if (id == currentId) "✓ $label" else label) },
                                    onClick = {
                                        try { camera?.switchCamera(id) } catch (_: Exception) {}
                                        showCameraPicker = false
                                    }
                                )
                            }
                        }
                    }
                }
            }

            // Stream button
            Box(
                modifier = Modifier.align(Alignment.BottomCenter).padding(bottom = 24.dp)
            ) {
                Box(
                    modifier = Modifier
                        .size(48.dp)
                        .clip(CircleShape)
                        .background(if (isStreaming) Color.Red else Color.White)
                        .clickable {
                            val camera = getRtmpCamera() ?: return@clickable
                            if (isStreaming) {
                                camera.stopStream()
                                isStreaming = false
                            } else {
                                if (!ytService.isSignedIn) {
                                    Toast.makeText(context, "Sign in to YouTube first", Toast.LENGTH_SHORT).show()
                                    return@clickable
                                }
                                scope.launch {
                                    Toast.makeText(context, "Creating broadcast...", Toast.LENGTH_SHORT).show()
                                    val url = ytService.createAndBindStream(
                                        title = "De Beauvoir Dugongs Live - ${java.time.LocalDate.now()}",
                                        privacy = settings.getPrivacy()
                                    )
                                    if (url != null) {
                                        camera.startStream(url)
                                        isStreaming = true
                                    } else {
                                        Toast.makeText(context, "Failed to create broadcast", Toast.LENGTH_SHORT).show()
                                    }
                                }
                            }
                        },
                    contentAlignment = Alignment.Center
                ) {
                    Icon(
                        if (isStreaming) Icons.Default.Close else Icons.Default.PlayArrow,
                        contentDescription = null,
                        tint = if (isStreaming) Color.White else Color.Red,
                        modifier = Modifier.size(24.dp)
                    )
                }
            }

            // Zoom slider (right edge, vertical)
            if (cameraReady) {
                var zoomLevel by remember { mutableFloatStateOf(1f) }
                val zoomRange = remember(cameraReady) { getRtmpCamera()?.zoomRange }
                val minZoom = zoomRange?.lower ?: 1f
                val maxZoom = zoomRange?.upper ?: 1f
                val camFocalLengths = remember(cameraReady) {
                    try {
                        val mgr = context.getSystemService(android.content.Context.CAMERA_SERVICE) as android.hardware.camera2.CameraManager
                        val chars = mgr.getCameraCharacteristics("5")
                        if (android.os.Build.VERSION.SDK_INT >= 28) {
                            chars.physicalCameraIds.mapNotNull { id ->
                                try {
                                    val pc = mgr.getCameraCharacteristics(id)
                                    val fl = pc.get(android.hardware.camera2.CameraCharacteristics.LENS_INFO_AVAILABLE_FOCAL_LENGTHS)?.firstOrNull() ?: return@mapNotNull null
                                    id to fl
                                } catch (_: Exception) { null }
                            }
                        } else emptyList()
                    } catch (_: Exception) { emptyList() }
                }

                if (maxZoom > minZoom) {
                    Box(
                        modifier = Modifier
                            .align(Alignment.CenterEnd)
                            .padding(end = 8.dp)
                            .width(200.dp)
                            .fillMaxHeight(),
                        contentAlignment = Alignment.Center
                    ) {
                        Slider(
                            value = zoomLevel,
                            onValueChange = { value ->
                                zoomLevel = value
                                val camera = getRtmpCamera() ?: return@Slider
                                val wideFl = 6.06f
                                val fl = when {
                                    value <= 0.6f -> 2.62f
                                    value >= 2.0f -> 13.3f
                                    else -> wideFl
                                }
                                if (kotlin.math.abs(fl - wideFl) > 0.01f) {
                                    camera.setOpticalZoom(fl)
                                }
                                camera.setZoom(value)
                            },
                            valueRange = minZoom..maxZoom,
                            modifier = Modifier
                                .fillMaxHeight()
                                .graphicsLayer { rotationZ = -90f },
                            colors = SliderDefaults.colors(thumbColor = Color.Red, activeTrackColor = Color.Red)
                        )
                        Text(
                            buildString {
                                append(String.format("%.1f", zoomLevel))
                                append("x")
                            },
                            color = Color.White,
                            fontSize = 12.sp,
                            modifier = Modifier.align(Alignment.CenterEnd).padding(end = 4.dp)
                        )
                    }
                }
            }
        } else {
            // No permissions
            Column(modifier = Modifier.align(Alignment.Center), horizontalAlignment = Alignment.CenterHorizontally) {
                Text("Camera & microphone permissions required", color = Color.White)
                Spacer(Modifier.height(16.dp))
                Button(onClick = { permissionLauncher.launch(arrayOf(Manifest.permission.CAMERA, Manifest.permission.RECORD_AUDIO)) }) {
                    Text("Grant Permissions")
                }
            }
        }
    }
}
