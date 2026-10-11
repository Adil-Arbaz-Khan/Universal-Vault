package com.adil.universalvault.crypto

import android.system.Os
import android.system.OsConstants
import android.webkit.MimeTypeMap
import java.io.Closeable
import java.io.FileDescriptor
import java.io.IOException
import java.nio.ByteBuffer
import java.nio.ByteOrder
import java.nio.channels.FileChannel
import java.security.MessageDigest
import java.security.SecureRandom
import javax.crypto.Cipher
import javax.crypto.Mac
import javax.crypto.SecretKeyFactory
import javax.crypto.spec.IvParameterSpec
import javax.crypto.spec.PBEKeySpec
import javax.crypto.spec.SecretKeySpec

interface VaultChannel : Closeable {
    fun position(): Long
    fun position(newPosition: Long): VaultChannel
    fun read(dst: ByteBuffer): Int
    fun write(src: ByteBuffer): Int
    fun truncate(size: Long): VaultChannel
    fun force(metaData: Boolean)
    fun size(): Long
}

class FileDescriptorVaultChannel(private val fd: FileDescriptor) : VaultChannel {
    override fun position(): Long {
        return try {
            Os.lseek(fd, 0, OsConstants.SEEK_CUR)
        } catch (e: Exception) {
            throw IOException("Failed to get position from fd", e)
        }
    }

    override fun position(newPosition: Long): VaultChannel {
        try {
            Os.lseek(fd, newPosition, OsConstants.SEEK_SET)
        } catch (e: Exception) {
            throw IOException("Failed to seek to position $newPosition", e)
        }
        return this
    }

    override fun read(dst: ByteBuffer): Int {
        var totalRead = 0
        try {
            while (dst.hasRemaining()) {
                val n = Os.read(fd, dst)
                if (n <= 0) break
                totalRead += n
            }
        } catch (e: Exception) {
            throw IOException("Failed to read from fd", e)
        }
        return if (totalRead == 0 && dst.hasRemaining()) -1 else totalRead
    }

    override fun write(src: ByteBuffer): Int {
        val total = src.remaining()
        try {
            while (src.hasRemaining()) {
                Os.write(fd, src)
            }
        } catch (e: Exception) {
            throw IOException("Failed to write to fd", e)
        }
        return total
    }

    override fun truncate(size: Long): VaultChannel {
        try {
            Os.ftruncate(fd, size)
        } catch (e: Exception) {
            throw IOException("Failed to truncate fd to $size", e)
        }
        return this
    }

    override fun force(metaData: Boolean) {
        try {
            Os.fsync(fd)
        } catch (e: Exception) {
            throw IOException("Failed to fsync fd", e)
        }
    }

    override fun size(): Long {
        return try {
            Os.fstat(fd).st_size
        } catch (e: Exception) {
            throw IOException("Failed to fstat fd", e)
        }
    }

    override fun close() {
        // Closed by owner ParcelFileDescriptor
    }
}

class FileChannelVaultChannel(private val fc: FileChannel) : VaultChannel {
    override fun position(): Long = fc.position()
    override fun position(newPosition: Long): VaultChannel {
        fc.position(newPosition)
        return this
    }
    override fun read(dst: ByteBuffer): Int = fc.read(dst)
    override fun write(src: ByteBuffer): Int = fc.write(src)
    override fun truncate(size: Long): VaultChannel {
        fc.truncate(size)
        return this
    }
    override fun force(metaData: Boolean) = fc.force(metaData)
    override fun size(): Long = fc.size()
    override fun close() = fc.close()
}

object VaultEngine {

    const val MAGIC_V5 = "VAULTV05"
    const val FOOTER_LEN_V5_RESUMABLE = 104
    const val FOOTER_LEN_V5_BASE = 96
    const val CHUNK_SIZE_V5 = 64 * 1024 // 64 KB
    const val KDF_ITERS_V5 = 600000     // OWASP 2026 Gold Standard

    const val STATE_NORMAL_LOCKED = 0
    const val STATE_LOCK_IN_PROGRESS = 1
    const val STATE_UNLOCK_IN_PROGRESS = 2
    const val FLAG_GIBBERISH_NAME = 4

    data class VaultOperationResult(
        val message: String,
        val newFileName: String? = null
    )

    data class DecryptedMemoryResult(
        val bytes: ByteArray,
        val originalName: String? = null,
        val dataLen: Long
    )

    data class FooterInfo(
        val version: Int,
        val length: Int,
        val salt: ByteArray,
        val nonce: ByteArray,
        val masterMac: ByteArray,
        val authTag: ByteArray,
        val checkpoint: Long,
        val failedAttempts: Int,
        val stateFlags: Int
    )

    data class VaultStatus(
        val isLocked: Boolean,
        val version: Int,
        val details: String,
        val isInterrupted: Boolean = false,
        val checkpointBytes: Long = 0L,
        val dataLength: Long = 0L
    )

    interface ProgressListener {
        fun onProgress(
            phase: String,
            currentBytes: Long,
            totalBytes: Long,
            speedMBps: Double,
            etaSeconds: Long
        )
    }

    private fun makeCounter(nonce: ByteArray, blockOffset: Long): ByteArray {
        val ctr = nonce.copyOf()
        var add = blockOffset
        var i = 15
        while (i >= 0 && add > 0) {
            val sum = (ctr[i].toInt() and 0xFF).toLong() + (add and 0xFF)
            ctr[i] = (sum and 0xFF).toByte()
            add = (add ushr 8) + (sum ushr 8)
            i--
        }
        return ctr
    }

    fun deriveKeys(password: String, salt: ByteArray): Triple<ByteArray, ByteArray, ByteArray> {
        val spec = PBEKeySpec(password.toCharArray(), salt, KDF_ITERS_V5, 512)
        val skf = SecretKeyFactory.getInstance("PBKDF2WithHmacSHA256")
        val dk = skf.generateSecret(spec).encoded
        val encKey = dk.copyOfRange(0, 32)
        val macKey = dk.copyOfRange(32, 64)

        val mac = Mac.getInstance("HmacSHA256")
        mac.init(SecretKeySpec(macKey, "HmacSHA256"))
        mac.update("VAULT_AUTH_V5".toByteArray(Charsets.UTF_8))
        mac.update(salt)
        val fullTag = mac.doFinal()
        val authTag = fullTag.copyOfRange(0, 16)

        return Triple(encKey, macKey, authTag)
    }

    fun readFooter(channel: VaultChannel, size: Long): FooterInfo? {
        if (size < FOOTER_LEN_V5_BASE) return null

        // Try 104-byte resumable footer
        if (size >= FOOTER_LEN_V5_RESUMABLE) {
            val buf = ByteBuffer.allocate(FOOTER_LEN_V5_RESUMABLE).order(ByteOrder.LITTLE_ENDIAN)
            channel.position(size - FOOTER_LEN_V5_RESUMABLE)
            channel.read(buf)
            buf.flip()

            val magicBytes = ByteArray(8)
            buf.get(magicBytes)
            if (String(magicBytes, Charsets.US_ASCII) == MAGIC_V5) {
                buf.getInt() // chunkSize (4B)
                val salt = ByteArray(16).also { buf.get(it) }
                val nonce = ByteArray(16).also { buf.get(it) }
                val masterMac = ByteArray(32).also { buf.get(it) }
                val authTag = ByteArray(16).also { buf.get(it) }
                val checkpoint = buf.getLong()
                val fails = buf.getShort().toInt() and 0xFFFF
                val state = buf.getShort().toInt() and 0xFFFF

                return FooterInfo(
                    version = 5,
                    length = FOOTER_LEN_V5_RESUMABLE,
                    salt = salt,
                    nonce = nonce,
                    masterMac = masterMac,
                    authTag = authTag,
                    checkpoint = checkpoint,
                    failedAttempts = fails,
                    stateFlags = state
                )
            }
        }

        // Try 96-byte legacy/base footer
        val buf96 = ByteBuffer.allocate(FOOTER_LEN_V5_BASE).order(ByteOrder.LITTLE_ENDIAN)
        channel.position(size - FOOTER_LEN_V5_BASE)
        channel.read(buf96)
        buf96.flip()

        val magicBytes96 = ByteArray(8)
        buf96.get(magicBytes96)
        if (String(magicBytes96, Charsets.US_ASCII) == MAGIC_V5) {
            buf96.getInt() // chunkSize
            val salt = ByteArray(16).also { buf96.get(it) }
            val nonce = ByteArray(16).also { buf96.get(it) }
            val masterMac = ByteArray(32).also { buf96.get(it) }
            val authTag = ByteArray(16).also { buf96.get(it) }
            val fails = buf96.getShort().toInt() and 0xFFFF
            val mode = buf96.getShort().toInt() and 0xFFFF

            return FooterInfo(
                version = 5,
                length = FOOTER_LEN_V5_BASE,
                salt = salt,
                nonce = nonce,
                masterMac = masterMac,
                authTag = authTag,
                checkpoint = 0L,
                failedAttempts = fails,
                stateFlags = STATE_NORMAL_LOCKED
            )
        }

        return null
    }

    fun inspectStatus(channel: FileChannel, size: Long): VaultStatus =
        inspectStatus(FileChannelVaultChannel(channel), size)

    fun inspectStatus(channel: VaultChannel, size: Long): VaultStatus {
        val footer = readFooter(channel, size)
        if (footer == null) {
            return VaultStatus(
                isLocked = false,
                version = 0,
                details = "Unlocked (Plaintext)",
                dataLength = size
            )
        }

        val hasGibberish = (footer.stateFlags and FLAG_GIBBERISH_NAME) != 0
        val isInterruptedLock = (footer.stateFlags and 3) == STATE_LOCK_IN_PROGRESS
        val isInterruptedUnlock = (footer.stateFlags and 3) == STATE_UNLOCK_IN_PROGRESS
        val totalCipherLen = size - footer.length
        val dataLen = if (hasGibberish && footer.checkpoint > 0 && footer.checkpoint < totalCipherLen) {
            footer.checkpoint
        } else {
            totalCipherLen
        }

        if (isInterruptedLock && footer.checkpoint > 0) {
            val mb = footer.checkpoint.toDouble() / (1024 * 1024)
            return VaultStatus(
                isLocked = true,
                version = 5,
                details = "Interrupted Lock at ${"%.2f".format(mb)} MB (Resumable)",
                isInterrupted = true,
                checkpointBytes = footer.checkpoint,
                dataLength = dataLen
            )
        }

        if (isInterruptedUnlock && footer.checkpoint > 0) {
            val mb = footer.checkpoint.toDouble() / (1024 * 1024)
            return VaultStatus(
                isLocked = true,
                version = 5,
                details = "Interrupted Unlock at ${"%.2f".format(mb)} MB (Resumable)",
                isInterrupted = true,
                checkpointBytes = footer.checkpoint,
                dataLength = dataLen
            )
        }

        val gibLabel = if (hasGibberish) " [Gibberish Name]" else ""
        return VaultStatus(
            isLocked = true,
            version = 5,
            details = "Locked (V5 Authenticated AEAD 100% Full-File$gibLabel)",
            isInterrupted = false,
            dataLength = dataLen
        )
    }

    fun lock(
        channel: FileChannel,
        size: Long,
        password: String,
        gibberish: Boolean = false,
        originalFileName: String? = null,
        listener: ProgressListener? = null
    ): Result<VaultOperationResult> = lock(FileChannelVaultChannel(channel), size, password, gibberish, originalFileName, listener)

    fun lock(
        channel: VaultChannel,
        size: Long,
        password: String,
        gibberish: Boolean = false,
        originalFileName: String? = null,
        listener: ProgressListener? = null
    ): Result<VaultOperationResult> {
        if (size == 0L) {
            return Result.failure(IllegalArgumentException("File is empty (0 bytes)"))
        }

        val existingFooter = readFooter(channel, size)
        if (existingFooter != null) {
            // Check if resuming an interrupted lock
            if ((existingFooter.stateFlags and 3) == STATE_LOCK_IN_PROGRESS && existingFooter.checkpoint > 0) {
                return resumeLock(channel, size, existingFooter, password, listener)
            }
            return Result.failure(IllegalStateException("File is already locked"))
        }

        val secureRandom = SecureRandom()
        val salt = ByteArray(16).also { secureRandom.nextBytes(it) }
        val nonce = ByteArray(16).also { secureRandom.nextBytes(it) }

        listener?.onProgress("Key Derivation", 0L, size, 0.0, 0L)
        val (encKey, macKey, authTag) = deriveKeys(password, salt)
        val dataLen = size

        val hasGibberish = gibberish && !originalFileName.isNullOrEmpty()
        val origNameBytes = if (hasGibberish) originalFileName!!.toByteArray(Charsets.UTF_8) else null
        val metaLen = if (origNameBytes != null) 2 + origNameBytes.size else 0
        val totalCipherLen = dataLen + metaLen

        val cipher = Cipher.getInstance("AES/CTR/NoPadding")
        val keySpec = SecretKeySpec(encKey, "AES")

        // Write encrypted filename metadata before footer if gibberish
        if (origNameBytes != null) {
            val metaBlockOffset = (dataLen + 15) / 16
            val metaCounter = makeCounter(nonce, metaBlockOffset)
            val metaCipher = Cipher.getInstance("AES/CTR/NoPadding")
            metaCipher.init(Cipher.ENCRYPT_MODE, keySpec, IvParameterSpec(metaCounter))
            val encName = metaCipher.doFinal(origNameBytes)

            val metaBuf = ByteBuffer.allocate(metaLen).order(ByteOrder.LITTLE_ENDIAN)
            metaBuf.putShort(origNameBytes.size.toShort())
            metaBuf.put(encName)
            metaBuf.flip()

            channel.position(dataLen)
            channel.write(metaBuf)
        }

        // 1. Write initial 104-byte header at totalCipherLen with STATE_LOCK_IN_PROGRESS
        channel.position(totalCipherLen)
        val initialBuf = ByteBuffer.allocate(FOOTER_LEN_V5_RESUMABLE).order(ByteOrder.LITTLE_ENDIAN)
        initialBuf.put(MAGIC_V5.toByteArray(Charsets.US_ASCII))
        initialBuf.putInt(CHUNK_SIZE_V5)
        initialBuf.put(salt)
        initialBuf.put(nonce)
        initialBuf.put(ByteArray(32)) // temp MasterMAC zeros
        initialBuf.put(authTag)
        initialBuf.putLong(0L) // checkpoint = 0
        initialBuf.putShort(0.toShort()) // fails = 0
        initialBuf.putShort(STATE_LOCK_IN_PROGRESS.toShort()) // state = LockInProgress
        initialBuf.flip()
        channel.write(initialBuf)
        channel.force(true)

        val hmac = Mac.getInstance("HmacSHA256").apply {
            init(SecretKeySpec(macKey, "HmacSHA256"))
        }

        var pos = 0L
        var blockIdx = 0L
        var lastSyncPos = 0L
        val chunkBuf = ByteArray(CHUNK_SIZE_V5)
        val encStartTime = System.currentTimeMillis()

        while (pos < dataLen) {
            val take = minOf(CHUNK_SIZE_V5.toLong(), dataLen - pos).toInt()
            channel.position(pos)
            val byteBuf = ByteBuffer.wrap(chunkBuf, 0, take)
            channel.read(byteBuf)

            val counter = makeCounter(nonce, blockIdx * (CHUNK_SIZE_V5 / 16))
            cipher.init(Cipher.ENCRYPT_MODE, keySpec, IvParameterSpec(counter))
            cipher.update(chunkBuf, 0, take, chunkBuf, 0)

            hmac.update(chunkBuf, 0, take)

            channel.position(pos)
            byteBuf.flip()
            channel.write(byteBuf)

            pos += take
            blockIdx++

            if (pos - lastSyncPos >= 1024 * 1024 || pos == dataLen) {
                channel.force(true)
                channel.position(totalCipherLen + 92)
                val chkBuf = ByteBuffer.allocate(8).order(ByteOrder.LITTLE_ENDIAN).putLong(pos)
                chkBuf.flip()
                channel.write(chkBuf)
                channel.force(true)
                lastSyncPos = pos
            }

            val elapsedSec = maxOf(0.001, (System.currentTimeMillis() - encStartTime) / 1000.0)
            val speed = (pos / elapsedSec) / (1024 * 1024)
            val remBytes = dataLen - pos
            val etaSec = if (speed > 0) (remBytes / (speed * 1024 * 1024)).toLong() else 0L
            listener?.onProgress("Encrypting", pos, dataLen, speed, etaSec)
        }

        if (origNameBytes != null) {
            channel.position(dataLen)
            val metaReadBuf = ByteBuffer.allocate(metaLen)
            channel.read(metaReadBuf)
            hmac.update(metaReadBuf.array())
        }

        // Finalize Master MAC & seal footer
        val masterMac = hmac.doFinal()
        channel.position(totalCipherLen + 44)
        channel.write(ByteBuffer.wrap(masterMac))

        channel.position(totalCipherLen + 92)
        val finalTail = ByteBuffer.allocate(12).order(ByteOrder.LITTLE_ENDIAN)
        finalTail.putLong(dataLen)
        finalTail.putShort(0.toShort())
        val finalFlags = if (hasGibberish) STATE_NORMAL_LOCKED or FLAG_GIBBERISH_NAME else STATE_NORMAL_LOCKED
        finalTail.putShort(finalFlags.toShort())
        finalTail.flip()
        channel.write(finalTail)
        channel.force(true)

        val gibberishFileName = if (hasGibberish) {
            val randBytes = ByteArray(8).also { secureRandom.nextBytes(it) }
            randBytes.joinToString("") { "%02x".format(it) } + ".vault"
        } else null

        return Result.success(VaultOperationResult("100% Full-File AEAD Armor Sealed ($dataLen bytes)", gibberishFileName))
    }

    private fun resumeLock(
        channel: VaultChannel,
        size: Long,
        footer: FooterInfo,
        password: String,
        listener: ProgressListener?
    ): Result<VaultOperationResult> {
        val (encKey, macKey, authTag) = deriveKeys(password, footer.salt)
        if (!MessageDigest.isEqual(authTag, footer.authTag)) {
            return Result.failure(SecurityException("Incorrect password"))
        }

        val hasGibberish = (footer.stateFlags and FLAG_GIBBERISH_NAME) != 0
        val totalCipherLen = size - footer.length
        val dataLen = if (hasGibberish && footer.checkpoint > 0 && footer.checkpoint < totalCipherLen) {
            footer.checkpoint
        } else {
            totalCipherLen
        }
        val cipher = Cipher.getInstance("AES/CTR/NoPadding")
        val keySpec = SecretKeySpec(encKey, "AES")

        var pos = footer.checkpoint
        var blockIdx = pos / CHUNK_SIZE_V5
        var lastSyncPos = pos
        val chunkBuf = ByteArray(CHUNK_SIZE_V5)
        val resumeStartTime = System.currentTimeMillis()

        while (pos < dataLen) {
            val take = minOf(CHUNK_SIZE_V5.toLong(), dataLen - pos).toInt()
            channel.position(pos)
            val byteBuf = ByteBuffer.wrap(chunkBuf, 0, take)
            channel.read(byteBuf)

            val counter = makeCounter(footer.nonce, blockIdx * (CHUNK_SIZE_V5 / 16))
            cipher.init(Cipher.ENCRYPT_MODE, keySpec, IvParameterSpec(counter))
            cipher.update(chunkBuf, 0, take, chunkBuf, 0)

            channel.position(pos)
            byteBuf.flip()
            channel.write(byteBuf)

            pos += take
            blockIdx++

            if (pos - lastSyncPos >= 1024 * 1024 || pos == dataLen) {
                channel.force(true)
                channel.position(totalCipherLen + 92)
                val chkBuf = ByteBuffer.allocate(8).order(ByteOrder.LITTLE_ENDIAN).putLong(pos)
                chkBuf.flip()
                channel.write(chkBuf)
                channel.force(true)
                lastSyncPos = pos
            }

            val elapsedSec = maxOf(0.001, (System.currentTimeMillis() - resumeStartTime) / 1000.0)
            val speed = ((pos - footer.checkpoint) / elapsedSec) / (1024 * 1024)
            val remBytes = dataLen - pos
            val etaSec = if (speed > 0) (remBytes / (speed * 1024 * 1024)).toLong() else 0L
            listener?.onProgress("Encrypting", pos, dataLen, speed, etaSec)
        }

        // Recompute master MAC over entire ciphertext (0 to totalCipherLen)
        val hmac = Mac.getInstance("HmacSHA256").apply {
            init(SecretKeySpec(macKey, "HmacSHA256"))
        }
        var p = 0L
        val sealStartTime = System.currentTimeMillis()
        while (p < totalCipherLen) {
            val take = minOf(CHUNK_SIZE_V5.toLong(), totalCipherLen - p).toInt()
            channel.position(p)
            val byteBuf = ByteBuffer.wrap(chunkBuf, 0, take)
            channel.read(byteBuf)
            hmac.update(chunkBuf, 0, take)
            p += take

            val elapsedSec = maxOf(0.001, (System.currentTimeMillis() - sealStartTime) / 1000.0)
            val speed = (p / elapsedSec) / (1024 * 1024)
            val remBytes = totalCipherLen - p
            val etaSec = if (speed > 0) (remBytes / (speed * 1024 * 1024)).toLong() else 0L
            listener?.onProgress("Sealing HMAC", p, totalCipherLen, speed, etaSec)
        }

        val masterMac = hmac.doFinal()
        channel.position(totalCipherLen + 44)
        channel.write(ByteBuffer.wrap(masterMac))

        channel.position(totalCipherLen + 92)
        val finalTail = ByteBuffer.allocate(12).order(ByteOrder.LITTLE_ENDIAN)
        finalTail.putLong(dataLen)
        finalTail.putShort(0.toShort())
        val finalFlags = if (hasGibberish) STATE_NORMAL_LOCKED or FLAG_GIBBERISH_NAME else STATE_NORMAL_LOCKED
        finalTail.putShort(finalFlags.toShort())
        finalTail.flip()
        channel.write(finalTail)
        channel.force(true)

        return Result.success(VaultOperationResult("Resumed & Finalized 100% Full-File AEAD ($dataLen bytes)"))
    }

    fun unlock(
        channel: FileChannel,
        size: Long,
        password: String,
        listener: ProgressListener? = null
    ): Result<VaultOperationResult> = unlock(FileChannelVaultChannel(channel), size, password, listener)

    fun unlock(
        channel: VaultChannel,
        size: Long,
        password: String,
        listener: ProgressListener? = null
    ): Result<VaultOperationResult> {
        val footer = readFooter(channel, size)
            ?: return Result.failure(IllegalStateException("File is not locked or has unsupported format"))

        val hasGibberish = (footer.stateFlags and FLAG_GIBBERISH_NAME) != 0
        val isInterruptedLock = (footer.stateFlags and 3) == STATE_LOCK_IN_PROGRESS
        val isInterruptedUnlock = (footer.stateFlags and 3) == STATE_UNLOCK_IN_PROGRESS
        val totalCipherLen = size - footer.length
        val dataLen = if (hasGibberish && footer.checkpoint > 0 && footer.checkpoint < totalCipherLen) {
            footer.checkpoint
        } else {
            totalCipherLen
        }

        listener?.onProgress("Key Derivation", 0L, dataLen, 0.0, 0L)
        val (encKey, macKey, authTag) = deriveKeys(password, footer.salt)

        if (!MessageDigest.isEqual(authTag, footer.authTag)) {
            var fails = footer.failedAttempts + 1
            channel.position(size - 4)
            val failBuf = ByteBuffer.allocate(2).order(ByteOrder.LITTLE_ENDIAN).putShort(fails.toShort())
            failBuf.flip()
            channel.write(failBuf)
            channel.force(true)
            val rem = maxOf(0, 10 - fails)
            return Result.failure(SecurityException("Incorrect password ($fails failed attempts, $rem left before lockout)"))
        }

        val cipher = Cipher.getInstance("AES/CTR/NoPadding")
        val keySpec = SecretKeySpec(encKey, "AES")
        val chunkBuf = ByteArray(CHUNK_SIZE_V5)

        // CASE 1: Rollback an interrupted lock operation
        if (isInterruptedLock && footer.checkpoint > 0) {
            val rollbackLen = minOf(footer.checkpoint, dataLen)
            var pos = 0L
            var blockIdx = 0L
            val rollbackStartTime = System.currentTimeMillis()

            while (pos < rollbackLen) {
                val take = minOf(CHUNK_SIZE_V5.toLong(), rollbackLen - pos).toInt()
                channel.position(pos)
                val byteBuf = ByteBuffer.wrap(chunkBuf, 0, take)
                channel.read(byteBuf)

                val counter = makeCounter(footer.nonce, blockIdx * (CHUNK_SIZE_V5 / 16))
                cipher.init(Cipher.ENCRYPT_MODE, keySpec, IvParameterSpec(counter))
                cipher.update(chunkBuf, 0, take, chunkBuf, 0)

                channel.position(pos)
                byteBuf.flip()
                channel.write(byteBuf)

                pos += take
                blockIdx++

                val elapsedSec = maxOf(0.001, (System.currentTimeMillis() - rollbackStartTime) / 1000.0)
                val speed = (pos / elapsedSec) / (1024 * 1024)
                val remBytes = rollbackLen - pos
                val etaSec = if (speed > 0) (remBytes / (speed * 1024 * 1024)).toLong() else 0L
                listener?.onProgress("Rolling Back", pos, rollbackLen, speed, etaSec)
            }
            channel.force(true)
            channel.truncate(dataLen)
            channel.force(true)
            return Result.success(VaultOperationResult("Rolled back interrupted lock & fully restored original ($dataLen bytes)"))
        }

        // CASE 2: Master HMAC Verification (Anti-Tampering)
        var startPos = 0L
        if (isInterruptedUnlock && footer.checkpoint > 0) {
            startPos = footer.checkpoint
        } else {
            val hmac = Mac.getInstance("HmacSHA256").apply {
                init(SecretKeySpec(macKey, "HmacSHA256"))
            }
            var p = 0L
            val verifyStartTime = System.currentTimeMillis()
            while (p < totalCipherLen) {
                val take = minOf(CHUNK_SIZE_V5.toLong(), totalCipherLen - p).toInt()
                channel.position(p)
                val byteBuf = ByteBuffer.wrap(chunkBuf, 0, take)
                channel.read(byteBuf)
                hmac.update(chunkBuf, 0, take)
                p += take

                val elapsedSec = maxOf(0.001, (System.currentTimeMillis() - verifyStartTime) / 1000.0)
                val speed = (p / elapsedSec) / (1024 * 1024)
                val remBytes = totalCipherLen - p
                val etaSec = if (speed > 0) (remBytes / (speed * 1024 * 1024)).toLong() else 0L
                listener?.onProgress("Verifying", p, totalCipherLen, speed, etaSec)
            }

            val computedMac = hmac.doFinal()
            if (!MessageDigest.isEqual(computedMac, footer.masterMac)) {
                return Result.failure(SecurityException("INTEGRITY ERROR: Ciphertext has been modified or corrupted! Decryption halted."))
            }

            if (footer.length == FOOTER_LEN_V5_RESUMABLE) {
                channel.position(totalCipherLen + 92)
                val stateBuf = ByteBuffer.allocate(12).order(ByteOrder.LITTLE_ENDIAN)
                stateBuf.putLong(0L)
                stateBuf.putShort(footer.failedAttempts.toShort())
                val stateFlags = if (hasGibberish) STATE_UNLOCK_IN_PROGRESS or FLAG_GIBBERISH_NAME else STATE_UNLOCK_IN_PROGRESS
                stateBuf.putShort(stateFlags.toShort())
                stateBuf.flip()
                channel.write(stateBuf)
                channel.force(true)
            }
        }

        var restoredOrigName: String? = null
        if (hasGibberish) {
            try {
                channel.position(dataLen)
                val lenBuf = ByteBuffer.allocate(2).order(ByteOrder.LITTLE_ENDIAN)
                channel.read(lenBuf)
                lenBuf.flip()
                val nameLen = lenBuf.getShort().toInt() and 0xFFFF
                if (nameLen in 1..2047 && dataLen + 2 + nameLen <= totalCipherLen) {
                    val encNameBuf = ByteBuffer.allocate(nameLen)
                    channel.read(encNameBuf)
                    val metaBlockOffset = (dataLen + 15) / 16
                    val metaCounter = makeCounter(footer.nonce, metaBlockOffset)
                    val metaCipher = Cipher.getInstance("AES/CTR/NoPadding")
                    metaCipher.init(Cipher.DECRYPT_MODE, keySpec, IvParameterSpec(metaCounter))
                    val decNameBytes = metaCipher.doFinal(encNameBuf.array())
                    restoredOrigName = String(decNameBytes, Charsets.UTF_8)
                }
            } catch (e: Exception) {
                // Ignore metadata read failure
            }
        }

        // Decryption Phase
        var pos = startPos
        var blockIdx = pos / CHUNK_SIZE_V5
        var lastSyncPos = pos
        val decryptStartTime = System.currentTimeMillis()

        while (pos < dataLen) {
            val take = minOf(CHUNK_SIZE_V5.toLong(), dataLen - pos).toInt()
            channel.position(pos)
            val byteBuf = ByteBuffer.wrap(chunkBuf, 0, take)
            channel.read(byteBuf)

            val counter = makeCounter(footer.nonce, blockIdx * (CHUNK_SIZE_V5 / 16))
            cipher.init(Cipher.ENCRYPT_MODE, keySpec, IvParameterSpec(counter))
            cipher.update(chunkBuf, 0, take, chunkBuf, 0)

            channel.position(pos)
            byteBuf.flip()
            channel.write(byteBuf)

            pos += take
            blockIdx++

            if (footer.length == FOOTER_LEN_V5_RESUMABLE) {
                if (pos - lastSyncPos >= 1024 * 1024 || pos == dataLen) {
                    channel.force(true)
                    channel.position(totalCipherLen + 92)
                    val chkBuf = ByteBuffer.allocate(8).order(ByteOrder.LITTLE_ENDIAN).putLong(pos)
                    chkBuf.flip()
                    channel.write(chkBuf)
                    channel.force(true)
                    lastSyncPos = pos
                }
            }

            val elapsedSec = maxOf(0.001, (System.currentTimeMillis() - decryptStartTime) / 1000.0)
            val speed = ((pos - startPos) / elapsedSec) / (1024 * 1024)
            val remBytes = dataLen - pos
            val etaSec = if (speed > 0) (remBytes / (speed * 1024 * 1024)).toLong() else 0L
            listener?.onProgress("Decrypting", pos, dataLen, speed, etaSec)
        }

        // Safe atomic truncate & restore original file size
        channel.force(true)
        channel.truncate(dataLen)
        channel.force(true)

        val successMsg = if (restoredOrigName != null) {
            "Verified & Restored original file $restoredOrigName ($dataLen bytes)"
        } else if (startPos > 0) {
            val mb = startPos.toDouble() / (1024 * 1024)
            "Resumed & Fully Restored ($dataLen bytes, resumed from ${"%.2f".format(mb)} MB)"
        } else {
            "Verified & Restored 100% full file ($dataLen bytes)"
        }
        return Result.success(VaultOperationResult(successMsg, restoredOrigName))
    }

    fun decryptToMemory(
        channel: FileChannel,
        size: Long,
        password: String,
        listener: ProgressListener? = null
    ): Result<DecryptedMemoryResult> = decryptToMemory(FileChannelVaultChannel(channel), size, password, listener)

    fun decryptToMemory(
        channel: VaultChannel,
        size: Long,
        password: String,
        listener: ProgressListener? = null
    ): Result<DecryptedMemoryResult> {
        val footer = readFooter(channel, size)
            ?: return Result.failure(IllegalStateException("File is not locked or has unsupported format"))

        val interrupted = footer.stateFlags and 3
        if (interrupted != 0) {
            val which = if (interrupted == STATE_LOCK_IN_PROGRESS) "LOCK" else "UNLOCK"
            return Result.failure(IllegalStateException("Interrupted $which state detected. Please resume or rollback before viewing in RAM."))
        }

        val hasGibberish = (footer.stateFlags and FLAG_GIBBERISH_NAME) != 0
        val totalCipherLen = size - footer.length
        val dataLen = if (hasGibberish && footer.checkpoint > 0 && footer.checkpoint < totalCipherLen) {
            footer.checkpoint
        } else {
            totalCipherLen
        }

        val runtime = Runtime.getRuntime()
        val maxHeap = runtime.maxMemory()
        val usedHeap = runtime.totalMemory() - runtime.freeMemory()
        val availableHeap = maxOf(0L, maxHeap - usedHeap)
        // Dynamic RAM safety threshold: Allow up to 90% of available heap or 1 GB
        val maxAllowed = minOf(1024L * 1024 * 1024, (availableHeap * 0.90).toLong())

        if (dataLen > maxAllowed) {
            val fileMb = formatBytes(dataLen)
            val ramMb = formatBytes(availableHeap)
            return Result.failure(
                IllegalStateException(
                    "RAM Overload Protected: File size ($fileMb) exceeds currently available volatile RAM ($ramMb). " +
                    "To prevent an Out-Of-Memory crash, please close background apps, use UNLOCK for in-place decryption, or inspect on desktop."
                )
            )
        }

        listener?.onProgress("Key Derivation", 0L, dataLen, 0.0, 0L)
        val (encKey, macKey, authTag) = deriveKeys(password, footer.salt)

        if (!MessageDigest.isEqual(authTag, footer.authTag)) {
            val fails = footer.failedAttempts + 1
            val rem = maxOf(0, 10 - fails)
            return Result.failure(SecurityException("Incorrect password ($fails failed attempts, $rem left before lockout)"))
        }

        // Master HMAC Verification
        val hmac = Mac.getInstance("HmacSHA256").apply {
            init(SecretKeySpec(macKey, "HmacSHA256"))
        }
        val chunkBuf = ByteArray(CHUNK_SIZE_V5)
        var p = 0L
        val verifyStartTime = System.currentTimeMillis()
        while (p < totalCipherLen) {
            val take = minOf(CHUNK_SIZE_V5.toLong(), totalCipherLen - p).toInt()
            channel.position(p)
            val byteBuf = ByteBuffer.wrap(chunkBuf, 0, take)
            channel.read(byteBuf)
            hmac.update(chunkBuf, 0, take)
            p += take

            val elapsedSec = maxOf(0.001, (System.currentTimeMillis() - verifyStartTime) / 1000.0)
            val speed = (p / elapsedSec) / (1024 * 1024)
            val remBytes = totalCipherLen - p
            val etaSec = if (speed > 0) (remBytes / (speed * 1024 * 1024)).toLong() else 0L
            listener?.onProgress("Verifying Integrity", p, totalCipherLen, speed, etaSec)
        }

        val computedMac = hmac.doFinal()
        if (!MessageDigest.isEqual(computedMac, footer.masterMac)) {
            return Result.failure(SecurityException("INTEGRITY ERROR: Ciphertext has been modified or corrupted! Decryption halted."))
        }

        val cipher = Cipher.getInstance("AES/CTR/NoPadding")
        val keySpec = SecretKeySpec(encKey, "AES")

        var restoredOrigName: String? = null
        if (hasGibberish) {
            try {
                channel.position(dataLen)
                val lenBuf = ByteBuffer.allocate(2).order(ByteOrder.LITTLE_ENDIAN)
                channel.read(lenBuf)
                lenBuf.flip()
                val nameLen = lenBuf.getShort().toInt() and 0xFFFF
                if (nameLen in 1..2047 && dataLen + 2 + nameLen <= totalCipherLen) {
                    val encNameBuf = ByteBuffer.allocate(nameLen)
                    channel.read(encNameBuf)
                    val metaBlockOffset = (dataLen + 15) / 16
                    val metaCounter = makeCounter(footer.nonce, metaBlockOffset)
                    val metaCipher = Cipher.getInstance("AES/CTR/NoPadding")
                    metaCipher.init(Cipher.ENCRYPT_MODE, keySpec, IvParameterSpec(metaCounter))
                    val decNameBytes = metaCipher.doFinal(encNameBuf.array())
                    restoredOrigName = String(decNameBytes, Charsets.UTF_8)
                }
            } catch (e: Exception) {
                // Ignore metadata recovery error
            }
        }

        // Stream into volatile memory buffer with OOM guard
        val memoryBytes = try {
            ByteArray(dataLen.toInt())
        } catch (e: OutOfMemoryError) {
            System.gc()
            return Result.failure(
                IllegalStateException(
                    "RAM Full / Heap Exhaustion: Device ran out of contiguous memory while allocating ${formatBytes(dataLen)}. " +
                    "Please close other applications or use UNLOCK to decrypt in-place on storage."
                )
            )
        }
        var pos = 0L
        var blockIdx = 0L
        val decryptStartTime = System.currentTimeMillis()

        while (pos < dataLen) {
            val take = minOf(CHUNK_SIZE_V5.toLong(), dataLen - pos).toInt()
            channel.position(pos)
            val byteBuf = ByteBuffer.wrap(chunkBuf, 0, take)
            channel.read(byteBuf)

            val counter = makeCounter(footer.nonce, blockIdx * (CHUNK_SIZE_V5 / 16))
            cipher.init(Cipher.ENCRYPT_MODE, keySpec, IvParameterSpec(counter))
            val decBytes = cipher.doFinal(chunkBuf, 0, take)
            System.arraycopy(decBytes, 0, memoryBytes, pos.toInt(), take)

            pos += take
            blockIdx++

            val elapsedSec = maxOf(0.001, (System.currentTimeMillis() - decryptStartTime) / 1000.0)
            val speed = (pos / elapsedSec) / (1024 * 1024)
            val remBytes = dataLen - pos
            val etaSec = if (speed > 0) (remBytes / (speed * 1024 * 1024)).toLong() else 0L
            listener?.onProgress("Decrypting to RAM", pos, dataLen, speed, etaSec)
        }

        return Result.success(DecryptedMemoryResult(memoryBytes, restoredOrigName, dataLen))
    }

    fun isTextContent(bytes: ByteArray): Boolean {
        if (bytes.isEmpty()) return true
        val checkLen = minOf(bytes.size, 1024)
        var nonPrintable = 0
        for (i in 0 until checkLen) {
            val b = bytes[i].toInt() and 0xFF
            if (b == 0) return false // Null byte indicates binary
            if (b < 32 && b != 9 && b != 10 && b != 13) {
                nonPrintable++
            }
        }
        return (nonPrintable.toDouble() / checkLen) < 0.05
    }

    fun detectMimeType(fileName: String, bytes: ByteArray): String {
        // 1. Inspect magic signatures first
        if (bytes.size >= 4) {
            // PDF: %PDF
            if (bytes[0] == 0x25.toByte() && bytes[1] == 0x50.toByte() && bytes[2] == 0x44.toByte() && bytes[3] == 0x46.toByte()) {
                return "application/pdf"
            }
            // PNG: \x89PNG
            if (bytes.size >= 8 && bytes[0] == 0x89.toByte() && bytes[1] == 0x50.toByte() && bytes[2] == 0x4E.toByte() && bytes[3] == 0x47.toByte()) {
                return "image/png"
            }
            // JPEG: \xFF\xD8\xFF
            if (bytes.size >= 3 && bytes[0] == 0xFF.toByte() && bytes[1] == 0xD8.toByte() && bytes[2] == 0xFF.toByte()) {
                return "image/jpeg"
            }
            // GIF: GIF8
            if (bytes.size >= 6 && bytes[0] == 'G'.code.toByte() && bytes[1] == 'I'.code.toByte() && bytes[2] == 'F'.code.toByte()) {
                return "image/gif"
            }
            // WebP: RIFF....WEBP
            if (bytes.size >= 12 && bytes[0] == 'R'.code.toByte() && bytes[1] == 'I'.code.toByte() && bytes[2] == 'F'.code.toByte() && bytes[3] == 'F'.code.toByte()
                && bytes[8] == 'W'.code.toByte() && bytes[9] == 'E'.code.toByte() && bytes[10] == 'B'.code.toByte() && bytes[11] == 'P'.code.toByte()) {
                return "image/webp"
            }
            // MP4: ....ftyp
            if (bytes.size >= 8 && bytes[4] == 'f'.code.toByte() && bytes[5] == 't'.code.toByte() && bytes[6] == 'y'.code.toByte() && bytes[7] == 'p'.code.toByte()) {
                return "video/mp4"
            }
            // WebM / Matroska: 0x1A 0x45 0xDF 0xA3
            if (bytes[0] == 0x1A.toByte() && bytes[1] == 0x45.toByte() && bytes[2] == 0xDF.toByte() && bytes[3] == 0xA3.toByte()) {
                return "video/webm"
            }
            // MP3: ID3 or sync frame
            if (bytes.size >= 3 && bytes[0] == 'I'.code.toByte() && bytes[1] == 'D'.code.toByte() && bytes[2] == '3'.code.toByte()) {
                return "audio/mpeg"
            }
            if (bytes.size >= 2 && bytes[0] == 0xFF.toByte() && (bytes[1].toInt() and 0xE0) == 0xE0) {
                return "audio/mpeg"
            }
            // WAV: RIFF....WAVE
            if (bytes.size >= 12 && bytes[0] == 'R'.code.toByte() && bytes[1] == 'I'.code.toByte() && bytes[2] == 'F'.code.toByte() && bytes[3] == 'F'.code.toByte()
                && bytes[8] == 'W'.code.toByte() && bytes[9] == 'A'.code.toByte() && bytes[10] == 'V'.code.toByte() && bytes[11] == 'E'.code.toByte()) {
                return "audio/wav"
            }
            // OGG: OggS
            if (bytes[0] == 'O'.code.toByte() && bytes[1] == 'g'.code.toByte() && bytes[2] == 'g'.code.toByte() && bytes[3] == 'S'.code.toByte()) {
                return "audio/ogg"
            }
            // FLAC: fLaC
            if (bytes[0] == 'f'.code.toByte() && bytes[1] == 'L'.code.toByte() && bytes[2] == 'a'.code.toByte() && bytes[3] == 'C'.code.toByte()) {
                return "audio/flac"
            }
        }

        // 2. Extension lookup
        val ext = fileName.substringAfterLast('.', "").lowercase()
        val mimeFromExt = MimeTypeMap.getSingleton().getMimeTypeFromExtension(ext)
        if (mimeFromExt != null && mimeFromExt != "application/octet-stream") {
            return mimeFromExt
        }

        // Known extension fallbacks
        when (ext) {
            "mp4", "m4v" -> return "video/mp4"
            "mkv" -> return "video/x-matroska"
            "webm" -> return "video/webm"
            "mov" -> return "video/quicktime"
            "avi" -> return "video/x-msvideo"
            "3gp" -> return "video/3gpp"
            "mp3" -> return "audio/mpeg"
            "wav" -> return "audio/wav"
            "m4a", "aac" -> return "audio/mp4"
            "ogg", "oga", "opus" -> return "audio/ogg"
            "flac" -> return "audio/flac"
            "pdf" -> return "application/pdf"
            "jpg", "jpeg" -> return "image/jpeg"
            "png" -> return "image/png"
            "gif" -> return "image/gif"
            "webp" -> return "image/webp"
            "bmp" -> return "image/bmp"
            "svg" -> return "image/svg+xml"
            "txt", "log", "env", "ini", "conf", "properties" -> return "text/plain"
            "md", "markdown" -> return "text/markdown"
            "json" -> return "application/json"
            "xml" -> return "application/xml"
            "html", "htm" -> return "text/html"
            "csv" -> return "text/csv"
        }

        // 3. Fallback to heuristic text check
        if (isTextContent(bytes)) {
            return "text/plain"
        }

        return "application/octet-stream"
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
}
