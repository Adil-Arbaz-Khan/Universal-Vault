package com.adil.universalvault

import android.content.Intent
import android.net.Uri
import android.os.Bundle
import android.provider.OpenableColumns
import androidx.activity.ComponentActivity
import androidx.activity.compose.setContent
import androidx.compose.runtime.*
import androidx.lifecycle.lifecycleScope
import com.adil.universalvault.crypto.FileDescriptorVaultChannel
import com.adil.universalvault.crypto.VaultEngine
import com.adil.universalvault.ui.*
import com.adil.universalvault.ui.theme.UniversalVaultTheme
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.launch
import kotlinx.coroutines.withContext

class MainActivity : ComponentActivity() {

    private var selectedFileState by mutableStateOf<SelectedFileInfo?>(null)
    private var progressState by mutableStateOf(ProgressState())
    private var resultMessageState by mutableStateOf<String?>(null)
    private var isErrorState by mutableStateOf(false)

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)

        handleIntent(intent)

        setContent {
            UniversalVaultTheme {
                VaultScreen(
                    selectedFile = selectedFileState,
                    progress = progressState,
                    resultMessage = resultMessageState,
                    isError = isErrorState,
                    onFileSelected = { uri -> loadFile(uri) },
                    onLockClicked = { password -> executeLock(password) },
                    onUnlockClicked = { password -> executeUnlock(password) },
                    onClearResult = { resultMessageState = null }
                )
            }
        }
    }

    override fun onNewIntent(intent: Intent) {
        super.onNewIntent(intent)
        handleIntent(intent)
    }

    private fun handleIntent(intent: Intent?) {
        if (intent == null) return
        val uri: Uri? = when (intent.action) {
            Intent.ACTION_SEND -> {
                intent.getParcelableExtra(Intent.EXTRA_STREAM)
            }
            Intent.ACTION_VIEW -> {
                intent.data
            }
            else -> null
        }
        uri?.let { loadFile(it) }
    }

    private fun loadFile(uri: Uri) {
        lifecycleScope.launch(Dispatchers.IO) {
            try {
                var fileName = "Selected_File"
                var fileSize = 0L

                contentResolver.query(uri, null, null, null, null)?.use { cursor ->
                    val nameIdx = cursor.getColumnIndex(OpenableColumns.DISPLAY_NAME)
                    val sizeIdx = cursor.getColumnIndex(OpenableColumns.SIZE)
                    if (cursor.moveToFirst()) {
                        if (nameIdx >= 0) fileName = cursor.getString(nameIdx)
                        if (sizeIdx >= 0) fileSize = cursor.getLong(sizeIdx)
                    }
                }

                val pfd = contentResolver.openFileDescriptor(uri, "r")
                if (pfd != null) {
                    if (fileSize <= 0) fileSize = pfd.statSize
                    val channel = FileDescriptorVaultChannel(pfd.fileDescriptor)
                    val status = VaultEngine.inspectStatus(channel, fileSize)
                    pfd.close()

                    withContext(Dispatchers.Main) {
                        selectedFileState = SelectedFileInfo(
                            uri = uri,
                            name = fileName,
                            size = fileSize,
                            status = status
                        )
                        resultMessageState = null
                        isErrorState = false
                    }
                }
            } catch (e: Exception) {
                withContext(Dispatchers.Main) {
                    resultMessageState = "Error reading file: ${e.localizedMessage}"
                    isErrorState = true
                }
            }
        }
    }

    private fun executeLock(password: String) {
        val fileInfo = selectedFileState ?: return
        progressState = ProgressState(isRunning = true, phase = "Initializing...")
        resultMessageState = null
        isErrorState = false

        lifecycleScope.launch(Dispatchers.IO) {
            try {
                val pfd = contentResolver.openFileDescriptor(fileInfo.uri, "rw")
                    ?: throw IllegalStateException("Cannot open file descriptor with write access")

                val channel = FileDescriptorVaultChannel(pfd.fileDescriptor)
                val result = VaultEngine.lock(
                    channel = channel,
                    size = fileInfo.size,
                    password = password,
                    listener = object : VaultEngine.ProgressListener {
                        override fun onProgress(
                            phase: String,
                            currentBytes: Long,
                            totalBytes: Long,
                            speedMBps: Double,
                            etaSeconds: Long
                        ) {
                            lifecycleScope.launch(Dispatchers.Main) {
                                progressState = ProgressState(
                                    isRunning = true,
                                    phase = phase,
                                    currentBytes = currentBytes,
                                    totalBytes = totalBytes,
                                    speedMBps = speedMBps,
                                    etaSeconds = etaSeconds
                                )
                            }
                        }
                    }
                )

                // Refresh status
                val newStatus = VaultEngine.inspectStatus(channel, channel.size())
                val newSize = channel.size()
                pfd.close()

                withContext(Dispatchers.Main) {
                    progressState = ProgressState(isRunning = false)
                    if (result.isSuccess) {
                        resultMessageState = result.getOrNull()
                        isErrorState = false
                        selectedFileState = fileInfo.copy(
                            size = newSize,
                            status = newStatus
                        )
                    } else {
                        resultMessageState = result.exceptionOrNull()?.message ?: "Lock failed"
                        isErrorState = true
                    }
                }
            } catch (e: Exception) {
                withContext(Dispatchers.Main) {
                    progressState = ProgressState(isRunning = false)
                    resultMessageState = e.localizedMessage ?: "Operation failed"
                    isErrorState = true
                }
            }
        }
    }

    private fun executeUnlock(password: String) {
        val fileInfo = selectedFileState ?: return
        progressState = ProgressState(isRunning = true, phase = "Initializing...")
        resultMessageState = null
        isErrorState = false

        lifecycleScope.launch(Dispatchers.IO) {
            try {
                val pfd = contentResolver.openFileDescriptor(fileInfo.uri, "rw")
                    ?: throw IllegalStateException("Cannot open file descriptor with write access")

                val channel = FileDescriptorVaultChannel(pfd.fileDescriptor)
                val result = VaultEngine.unlock(
                    channel = channel,
                    size = fileInfo.size,
                    password = password,
                    listener = object : VaultEngine.ProgressListener {
                        override fun onProgress(
                            phase: String,
                            currentBytes: Long,
                            totalBytes: Long,
                            speedMBps: Double,
                            etaSeconds: Long
                        ) {
                            lifecycleScope.launch(Dispatchers.Main) {
                                progressState = ProgressState(
                                    isRunning = true,
                                    phase = phase,
                                    currentBytes = currentBytes,
                                    totalBytes = totalBytes,
                                    speedMBps = speedMBps,
                                    etaSeconds = etaSeconds
                                )
                            }
                        }
                    }
                )

                // Refresh status
                val newStatus = VaultEngine.inspectStatus(channel, channel.size())
                val newSize = channel.size()
                pfd.close()

                withContext(Dispatchers.Main) {
                    progressState = ProgressState(isRunning = false)
                    if (result.isSuccess) {
                        resultMessageState = result.getOrNull()
                        isErrorState = false
                        selectedFileState = fileInfo.copy(
                            size = newSize,
                            status = newStatus
                        )
                    } else {
                        resultMessageState = result.exceptionOrNull()?.message ?: "Unlock failed"
                        isErrorState = true
                    }
                }
            } catch (e: Exception) {
                withContext(Dispatchers.Main) {
                    progressState = ProgressState(isRunning = false)
                    resultMessageState = e.localizedMessage ?: "Operation failed"
                    isErrorState = true
                }
            }
        }
    }
}
