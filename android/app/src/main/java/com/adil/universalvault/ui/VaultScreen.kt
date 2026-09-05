package com.adil.universalvault.ui

import android.net.Uri
import androidx.activity.compose.rememberLauncherForActivityResult
import androidx.activity.result.contract.ActivityResultContracts
import androidx.compose.animation.*
import androidx.compose.foundation.background
import androidx.compose.foundation.border
import androidx.compose.foundation.clickable
import androidx.compose.foundation.layout.*
import androidx.compose.foundation.rememberScrollState
import androidx.compose.foundation.shape.CircleShape
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.foundation.text.KeyboardActions
import androidx.compose.foundation.text.KeyboardOptions
import androidx.compose.foundation.verticalScroll
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.filled.*
import androidx.compose.material.icons.outlined.*
import androidx.compose.material3.*
import androidx.compose.runtime.*
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.graphics.Brush
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.platform.LocalFocusManager
import androidx.compose.ui.text.font.FontFamily
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.text.input.ImeAction
import androidx.compose.ui.text.input.PasswordVisualTransformation
import androidx.compose.ui.text.input.VisualTransformation
import androidx.compose.ui.text.style.TextAlign
import androidx.compose.ui.text.style.TextOverflow
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import com.adil.universalvault.crypto.VaultEngine
import com.adil.universalvault.ui.theme.*

data class SelectedFileInfo(
    val uri: Uri,
    val name: String,
    val size: Long,
    val status: VaultEngine.VaultStatus
)

data class ProgressState(
    val isRunning: Boolean = false,
    val phase: String = "",
    val currentBytes: Long = 0L,
    val totalBytes: Long = 0L,
    val speedMBps: Double = 0.0,
    val etaSeconds: Long = 0L
)

@Composable
fun VaultScreen(
    selectedFile: SelectedFileInfo?,
    progress: ProgressState,
    resultMessage: String?,
    isError: Boolean,
    onFileSelected: (Uri) -> Unit,
    onLockClicked: (String) -> Unit,
    onUnlockClicked: (String) -> Unit,
    onClearResult: () -> Unit
) {
    var password by remember { mutableStateOf("") }
    var passwordVisible by remember { mutableStateOf(false) }
    val focusManager = LocalFocusManager.current

    val filePicker = rememberLauncherForActivityResult(
        contract = ActivityResultContracts.OpenDocument()
    ) { uri ->
        uri?.let { onFileSelected(it) }
    }

    Scaffold(
        containerColor = BgMidnight
    ) { padding ->
        Column(
            modifier = Modifier
                .fillMaxSize()
                .padding(padding)
                .verticalScroll(rememberScrollState())
                .padding(horizontal = 20.dp, vertical = 24.dp),
            horizontalAlignment = Alignment.CenterHorizontally
        ) {
            // 1. Sleek Brand Header
            Row(
                modifier = Modifier
                    .fillMaxWidth()
                    .padding(bottom = 24.dp),
                verticalAlignment = Alignment.CenterVertically,
                horizontalArrangement = Arrangement.SpaceBetween
            ) {
                Row(verticalAlignment = Alignment.CenterVertically) {
                    Box(
                        modifier = Modifier
                            .size(42.dp)
                            .clip(RoundedCornerShape(12.dp))
                            .background(
                                Brush.linearGradient(
                                    listOf(AccentCyan.copy(alpha = 0.25f), AccentIndigo.copy(alpha = 0.25f))
                                )
                            )
                            .border(1.dp, AccentCyan.copy(alpha = 0.4f), RoundedCornerShape(12.dp)),
                        contentAlignment = Alignment.Center
                    ) {
                        Icon(
                            imageVector = Icons.Default.Shield,
                            contentDescription = null,
                            tint = AccentCyan,
                            modifier = Modifier.size(24.dp)
                        )
                    }
                    Spacer(modifier = Modifier.width(12.dp))
                    Column {
                        Text(
                            text = "UNIVERSAL VAULT",
                            color = TextPrimary,
                            fontSize = 17.sp,
                            fontWeight = FontWeight.Bold,
                            letterSpacing = 1.sp
                        )
                        Text(
                            text = "Sovereign In-Place AEAD",
                            color = TextSecondary,
                            fontSize = 12.sp,
                            fontWeight = FontWeight.Medium
                        )
                    }
                }

                Surface(
                    shape = RoundedCornerShape(20.dp),
                    color = SurfaceElevated,
                    border = androidx.compose.foundation.BorderStroke(1.dp, SurfaceBorder)
                ) {
                    Text(
                        text = "v5.5.2",
                        color = AccentCyan,
                        fontSize = 11.sp,
                        fontWeight = FontWeight.SemiBold,
                        modifier = Modifier.padding(horizontal = 10.dp, vertical = 4.dp)
                    )
                }
            }

            // 2. File Selection Card
            Card(
                modifier = Modifier
                    .fillMaxWidth()
                    .clip(RoundedCornerShape(20.dp))
                    .border(1.dp, if (selectedFile != null) AccentCyan.copy(alpha = 0.3f) else SurfaceBorder, RoundedCornerShape(20.dp))
                    .clickable(enabled = !progress.isRunning) {
                        filePicker.launch(arrayOf("*/*"))
                    },
                colors = CardDefaults.cardColors(containerColor = SurfaceObsidian)
            ) {
                if (selectedFile == null) {
                    Column(
                        modifier = Modifier
                            .fillMaxWidth()
                            .padding(vertical = 36.dp, horizontal = 20.dp),
                        horizontalAlignment = Alignment.CenterHorizontally
                    ) {
                        Box(
                            modifier = Modifier
                                .size(56.dp)
                                .clip(CircleShape)
                                .background(SurfaceElevated),
                            contentAlignment = Alignment.Center
                        ) {
                            Icon(
                                imageVector = Icons.Outlined.FilePresent,
                                contentDescription = null,
                                tint = AccentCyan,
                                modifier = Modifier.size(28.dp)
                            )
                        }
                        Spacer(modifier = Modifier.height(16.dp))
                        Text(
                            text = "Tap to Select File",
                            color = TextPrimary,
                            fontSize = 16.sp,
                            fontWeight = FontWeight.SemiBold
                        )
                        Spacer(modifier = Modifier.height(4.dp))
                        Text(
                            text = "SAF Supported • Zero Temporary Storage Overhead",
                            color = TextMuted,
                            fontSize = 12.sp
                        )
                    }
                } else {
                    Column(
                        modifier = Modifier
                            .fillMaxWidth()
                            .padding(20.dp)
                    ) {
                        Row(
                            modifier = Modifier.fillMaxWidth(),
                            verticalAlignment = Alignment.CenterVertically
                        ) {
                            Box(
                                modifier = Modifier
                                    .size(46.dp)
                                    .clip(RoundedCornerShape(12.dp))
                                    .background(
                                        if (selectedFile.status.isLocked) RoseProtected.copy(alpha = 0.15f)
                                        else EmeraldSuccess.copy(alpha = 0.15f)
                                    ),
                                contentAlignment = Alignment.Center
                            ) {
                                Icon(
                                    imageVector = if (selectedFile.status.isLocked) Icons.Default.Lock else Icons.Default.LockOpen,
                                    contentDescription = null,
                                    tint = if (selectedFile.status.isLocked) RoseProtected else EmeraldSuccess,
                                    modifier = Modifier.size(24.dp)
                                )
                            }
                            Spacer(modifier = Modifier.width(14.dp))
                            Column(modifier = Modifier.weight(1f)) {
                                Text(
                                    text = selectedFile.name,
                                    color = TextPrimary,
                                    fontSize = 15.sp,
                                    fontWeight = FontWeight.Bold,
                                    maxLines = 1,
                                    overflow = TextOverflow.Ellipsis
                                )
                                Spacer(modifier = Modifier.height(2.dp))
                                Text(
                                    text = formatBytes(selectedFile.size),
                                    color = TextSecondary,
                                    fontSize = 12.sp,
                                    fontFamily = FontFamily.Monospace
                                )
                            }
                        }

                        Spacer(modifier = Modifier.height(16.dp))

                        // Status Badge
                        Surface(
                            shape = RoundedCornerShape(10.dp),
                            color = SurfaceElevated,
                            border = androidx.compose.foundation.BorderStroke(
                                1.dp,
                                if (selectedFile.status.isLocked) RoseProtected.copy(alpha = 0.3f)
                                else EmeraldSuccess.copy(alpha = 0.3f)
                            ),
                            modifier = Modifier.fillMaxWidth()
                        ) {
                            Row(
                                modifier = Modifier.padding(horizontal = 12.dp, vertical = 8.dp),
                                verticalAlignment = Alignment.CenterVertically
                            ) {
                                Box(
                                    modifier = Modifier
                                        .size(8.dp)
                                        .clip(CircleShape)
                                        .background(if (selectedFile.status.isLocked) RoseProtected else EmeraldSuccess)
                                )
                                Spacer(modifier = Modifier.width(8.dp))
                                Text(
                                    text = selectedFile.status.details,
                                    color = if (selectedFile.status.isLocked) RoseProtected else EmeraldSuccess,
                                    fontSize = 12.sp,
                                    fontWeight = FontWeight.Medium
                                )
                            }
                        }
                    }
                }
            }

            Spacer(modifier = Modifier.height(20.dp))

            // 3. Password Input Card
            Card(
                modifier = Modifier
                    .fillMaxWidth()
                    .clip(RoundedCornerShape(20.dp))
                    .border(1.dp, SurfaceBorder, RoundedCornerShape(20.dp)),
                colors = CardDefaults.cardColors(containerColor = SurfaceObsidian)
            ) {
                Column(modifier = Modifier.padding(18.dp)) {
                    Text(
                        text = "MASTER PASSWORD",
                        color = TextMuted,
                        fontSize = 11.sp,
                        fontWeight = FontWeight.Bold,
                        letterSpacing = 1.sp
                    )
                    Spacer(modifier = Modifier.height(10.dp))
                    OutlinedTextField(
                        value = password,
                        onValueChange = {
                            password = it
                            onClearResult()
                        },
                        placeholder = {
                            Text(
                                text = "Enter password to lock/unlock",
                                color = TextMuted,
                                fontSize = 14.sp
                            )
                        },
                        leadingIcon = {
                            Icon(
                                imageVector = Icons.Outlined.Key,
                                contentDescription = null,
                                tint = AccentCyan,
                                modifier = Modifier.size(20.dp)
                            )
                        },
                        trailingIcon = {
                            IconButton(onClick = { passwordVisible = !passwordVisible }) {
                                Icon(
                                    imageVector = if (passwordVisible) Icons.Default.Visibility else Icons.Default.VisibilityOff,
                                    contentDescription = null,
                                    tint = TextSecondary,
                                    modifier = Modifier.size(20.dp)
                                )
                            }
                        },
                        visualTransformation = if (passwordVisible) VisualTransformation.None else PasswordVisualTransformation(),
                        singleLine = true,
                        keyboardOptions = KeyboardOptions(imeAction = ImeAction.Done),
                        keyboardActions = KeyboardActions(onDone = { focusManager.clearFocus() }),
                        enabled = !progress.isRunning,
                        colors = OutlinedTextFieldDefaults.colors(
                            focusedBorderColor = AccentCyan,
                            unfocusedBorderColor = SurfaceBorder,
                            focusedContainerColor = SurfaceElevated,
                            unfocusedContainerColor = SurfaceElevated,
                            focusedTextColor = TextPrimary,
                            unfocusedTextColor = TextPrimary
                        ),
                        shape = RoundedCornerShape(14.dp),
                        modifier = Modifier.fillMaxWidth()
                    )
                    Spacer(modifier = Modifier.height(8.dp))
                    Text(
                        text = "🔒 Secured by 600,000 PBKDF2-SHA256 rounds (OWASP Gold Standard)",
                        color = TextMuted,
                        fontSize = 11.sp
                    )
                }
            }

            Spacer(modifier = Modifier.height(24.dp))

            // 4. Action Buttons
            Row(
                modifier = Modifier.fillMaxWidth(),
                horizontalArrangement = Arrangement.spacedBy(14.dp)
            ) {
                // LOCK Button
                Button(
                    onClick = {
                        focusManager.clearFocus()
                        onLockClicked(password)
                    },
                    enabled = selectedFile != null && password.isNotEmpty() && !progress.isRunning,
                    shape = RoundedCornerShape(16.dp),
                    colors = ButtonDefaults.buttonColors(containerColor = Color.Transparent),
                    contentPadding = PaddingValues(),
                    modifier = Modifier
                        .weight(1f)
                        .height(52.dp)
                ) {
                    Box(
                        modifier = Modifier
                            .fillMaxSize()
                            .background(
                                Brush.horizontalGradient(
                                    listOf(RoseProtected, Color(0xFFE11D48))
                                )
                            ),
                        contentAlignment = Alignment.Center
                    ) {
                        Row(verticalAlignment = Alignment.CenterVertically) {
                            Icon(
                                imageVector = Icons.Default.Lock,
                                contentDescription = null,
                                tint = Color.White,
                                modifier = Modifier.size(18.dp)
                            )
                            Spacer(modifier = Modifier.width(8.dp))
                            Text(
                                text = "LOCK",
                                color = Color.White,
                                fontWeight = FontWeight.Bold,
                                fontSize = 14.sp,
                                letterSpacing = 1.sp
                            )
                        }
                    }
                }

                // UNLOCK Button
                Button(
                    onClick = {
                        focusManager.clearFocus()
                        onUnlockClicked(password)
                    },
                    enabled = selectedFile != null && password.isNotEmpty() && !progress.isRunning,
                    shape = RoundedCornerShape(16.dp),
                    colors = ButtonDefaults.buttonColors(containerColor = Color.Transparent),
                    contentPadding = PaddingValues(),
                    modifier = Modifier
                        .weight(1f)
                        .height(52.dp)
                ) {
                    Box(
                        modifier = Modifier
                            .fillMaxSize()
                            .background(
                                Brush.horizontalGradient(
                                    listOf(EmeraldSuccess, Color(0xFF0D9488))
                                )
                            ),
                        contentAlignment = Alignment.Center
                    ) {
                        Row(verticalAlignment = Alignment.CenterVertically) {
                            Icon(
                                imageVector = Icons.Default.LockOpen,
                                contentDescription = null,
                                tint = Color.White,
                                modifier = Modifier.size(18.dp)
                            )
                            Spacer(modifier = Modifier.width(8.dp))
                            Text(
                                text = "UNLOCK",
                                color = Color.White,
                                fontWeight = FontWeight.Bold,
                                fontSize = 14.sp,
                                letterSpacing = 1.sp
                            )
                        }
                    }
                }
            }

            // 5. Live Progress Card
            AnimatedVisibility(
                visible = progress.isRunning,
                enter = fadeIn() + expandVertically(),
                exit = fadeOut() + shrinkVertically()
            ) {
                Card(
                    modifier = Modifier
                        .fillMaxWidth()
                        .padding(top = 20.dp)
                        .clip(RoundedCornerShape(20.dp))
                        .border(1.dp, AccentCyan.copy(alpha = 0.4f), RoundedCornerShape(20.dp)),
                    colors = CardDefaults.cardColors(containerColor = SurfaceObsidian)
                ) {
                    Column(modifier = Modifier.padding(18.dp)) {
                        Row(
                            modifier = Modifier.fillMaxWidth(),
                            horizontalArrangement = Arrangement.SpaceBetween,
                            verticalAlignment = Alignment.CenterVertically
                        ) {
                            Row(verticalAlignment = Alignment.CenterVertically) {
                                CircularProgressIndicator(
                                    modifier = Modifier.size(16.dp),
                                    color = AccentCyan,
                                    strokeWidth = 2.dp
                                )
                                Spacer(modifier = Modifier.width(10.dp))
                                Text(
                                    text = progress.phase,
                                    color = AccentCyan,
                                    fontSize = 13.sp,
                                    fontWeight = FontWeight.Bold
                                )
                            }

                            val percent = if (progress.totalBytes > 0) {
                                (progress.currentBytes.toDouble() / progress.totalBytes * 100).coerceIn(0.0, 100.0)
                            } else 0.0

                            Text(
                                text = "${"%.1f".format(percent)}%",
                                color = TextPrimary,
                                fontSize = 14.sp,
                                fontWeight = FontWeight.Bold,
                                fontFamily = FontFamily.Monospace
                            )
                        }

                        Spacer(modifier = Modifier.height(12.dp))

                        val progressFraction = if (progress.totalBytes > 0) {
                            (progress.currentBytes.toFloat() / progress.totalBytes).coerceIn(0f, 1f)
                        } else 0f

                        LinearProgressIndicator(
                            progress = { progressFraction },
                            modifier = Modifier
                                .fillMaxWidth()
                                .height(8.dp)
                                .clip(RoundedCornerShape(4.dp)),
                            color = AccentCyan,
                            trackColor = SurfaceElevated
                        )

                        Spacer(modifier = Modifier.height(12.dp))

                        Row(
                            modifier = Modifier.fillMaxWidth(),
                            horizontalArrangement = Arrangement.SpaceBetween
                        ) {
                            Text(
                                text = "${formatBytes(progress.currentBytes)} / ${formatBytes(progress.totalBytes)}",
                                color = TextSecondary,
                                fontSize = 11.sp,
                                fontFamily = FontFamily.Monospace
                            )
                            Text(
                                text = "${"%.1f".format(progress.speedMBps)} MB/s | ETA: ${formatEta(progress.etaSeconds)}",
                                color = TextSecondary,
                                fontSize = 11.sp,
                                fontFamily = FontFamily.Monospace
                            )
                        }
                    }
                }
            }

            // 6. Result Notification Banner
            AnimatedVisibility(
                visible = !progress.isRunning && resultMessage != null,
                enter = fadeIn() + expandVertically(),
                exit = fadeOut() + shrinkVertically()
            ) {
                Card(
                    modifier = Modifier
                        .fillMaxWidth()
                        .padding(top = 20.dp)
                        .clip(RoundedCornerShape(16.dp))
                        .border(
                            1.dp,
                            if (isError) RoseProtected.copy(alpha = 0.5f) else EmeraldSuccess.copy(alpha = 0.5f),
                            RoundedCornerShape(16.dp)
                        ),
                    colors = CardDefaults.cardColors(containerColor = SurfaceObsidian)
                ) {
                    Row(
                        modifier = Modifier.padding(16.dp),
                        verticalAlignment = Alignment.CenterVertically
                    ) {
                        Icon(
                            imageVector = if (isError) Icons.Default.ErrorOutline else Icons.Default.CheckCircle,
                            contentDescription = null,
                            tint = if (isError) RoseProtected else EmeraldSuccess,
                            modifier = Modifier.size(24.dp)
                        )
                        Spacer(modifier = Modifier.width(12.dp))
                        Text(
                            text = resultMessage ?: "",
                            color = TextPrimary,
                            fontSize = 13.sp,
                            fontWeight = FontWeight.Medium
                        )
                    }
                }
            }

            Spacer(modifier = Modifier.weight(1f, fill = false))
            Spacer(modifier = Modifier.height(40.dp))

            // 7. Subtle Footer
            Text(
                text = "Universal Vault • 100% In-Place Authenticated Encryption",
                color = TextMuted,
                fontSize = 11.sp,
                textAlign = TextAlign.Center
            )
        }
    }
}

fun formatBytes(bytes: Long): String {
    if (bytes < 1024) return "$bytes B"
    val kb = bytes / 1024.0
    if (kb < 1024) return "${"%.1f".format(kb)} KB"
    val mb = kb / 1024.0
    if (mb < 1024) return "${"%.1f".format(mb)} MB"
    val gb = mb / 1024.0
    return "${"%.2f".format(gb)} GB"
}

fun formatEta(seconds: Long): String {
    if (seconds <= 0 || seconds > 86400) return "--:--"
    val m = seconds / 60
    val s = seconds % 60
    return "%02d:%02d".format(m, s)
}
