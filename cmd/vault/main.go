package main

import (
	"bufio"
	"bytes"
	"crypto/aes"
	"crypto/cipher"
	"crypto/hmac"
	"crypto/rand"
	"crypto/sha256"
	"crypto/subtle"
	"encoding/binary"
	"fmt"
	"io"
	"os"
	"path/filepath"
	"strings"
	"time"
)

const (
	Version = "5.5.2"

	MagicV5 = "VAULTV05"
	MagicV4 = "VAULTV04"
	MagicV3 = "VAULTV03"
	MagicV2 = "VAULTV02"
	MagicV1 = "HDRLOK01"

	FooterLenV5Resumable = 104
	FooterLenV5Base      = 96
	FooterLenV4          = 80
	FooterLenV3          = 80
	FooterLenV2          = 76

	ChunkSizeV5 = 64 * 1024 // 64 KB
	KdfItersV5  = 600000    // OWASP 2026 Gold Standard

	StateNormalLocked      = 0
	StateLockInProgress    = 1
	StateUnlockInProgress  = 2
)

var excludedExts = map[string]bool{
	".bat": true, ".cmd": true, ".ps1": true, ".py": true,
	".html": true, ".sh": true, ".git": true, ".gitignore": true,
	".env": true, ".log": true, ".exe": true,
}

var excludedDirs = map[string]bool{
	"tools": true, ".vault": true, ".git": true, "__pycache__": true,
	"node_modules": true, ".vscode": true, ".idea": true, "cmd": true,
	"bin": true, "installers": true, "releases_v5.5.1": true, "releases_v5.5.2": true, "android": true,
}

func pbkdf2SHA256(password []byte, salt []byte, iter int, keyLen int) []byte {
	prf := hmac.New(sha256.New, password)
	hashLen := prf.Size()
	numBlocks := (keyLen + hashLen - 1) / hashLen
	var dk []byte
	for block := 1; block <= numBlocks; block++ {
		prf.Reset()
		prf.Write(salt)
		var buf [4]byte
		binary.BigEndian.PutUint32(buf[:], uint32(block))
		prf.Write(buf[:])
		u := prf.Sum(nil)

		t := make([]byte, len(u))
		copy(t, u)

		for i := 2; i <= iter; i++ {
			prf.Reset()
			prf.Write(u)
			u = prf.Sum(nil)
			for j := 0; j < len(t); j++ {
				t[j] ^= u[j]
			}
		}
		dk = append(dk, t...)
	}
	return dk[:keyLen]
}

func deriveKeysV5(password string, salt []byte) (encKey []byte, macKey []byte, authTag []byte) {
	dk := pbkdf2SHA256([]byte(password), salt, KdfItersV5, 64)
	encKey = dk[:32]
	macKey = dk[32:64]

	h := hmac.New(sha256.New, macKey)
	h.Write([]byte("VAULT_AUTH_V5"))
	h.Write(salt)
	fullTag := h.Sum(nil)
	authTag = fullTag[:16]
	return
}

func deriveLegacyKey(password string, salt []byte, version int) (key []byte, authHash []byte) {
	iters := 10000
	if version >= 3 {
		iters = 100000
	}
	key = pbkdf2SHA256([]byte(password), salt, iters, 32)
	var tag []byte
	switch version {
	case 4:
		tag = []byte("VAULT_AUTH_V4")
	case 3:
		tag = []byte("VAULT_AUTH_V3")
	case 2:
		tag = []byte("VAULT_AUTH_V2")
	default:
		tag = []byte("AUTH_CHECK_V1")
	}
	h := sha256.New()
	h.Write(key)
	h.Write(tag)
	h.Write(salt)
	authHash = h.Sum(nil)
	return
}

func makeCounter(nonce []byte, blockOffset uint64) []byte {
	ctr := make([]byte, 16)
	copy(ctr, nonce)
	low := binary.BigEndian.Uint64(ctr[8:16])
	low += blockOffset
	binary.BigEndian.PutUint64(ctr[8:16], low)
	return ctr
}

func formatETA(seconds float64) string {
	if seconds < 0 || seconds > 86400 {
		return "--:--"
	}
	sec := int(seconds)
	m := sec / 60
	s := sec % 60
	h := m / 60
	m = m % 60
	if h > 0 {
		return fmt.Sprintf("%02d:%02d:%02d", h, m, s)
	}
	return fmt.Sprintf("%02d:%02d", m, s)
}

func renderPhaseNotice(phase, filename, message string) {
	nameDisplay := filename
	if len(nameDisplay) > 16 {
		nameDisplay = nameDisplay[:13] + "..."
	}
	line := fmt.Sprintf("  [%-12s] [%-16s] %s", phase, nameDisplay, message)
	if len(line) < 85 {
		line += strings.Repeat(" ", 85-len(line))
	}
	fmt.Printf("\r%s", line)
}

func renderProgress(phase, filename string, currentBytes, totalBytes int64, startTime time.Time) {
	if totalBytes < 512*1024 {
		return
	}
	elapsed := time.Since(startTime).Seconds()
	if elapsed < 0.001 {
		elapsed = 0.001
	}
	speed := float64(currentBytes) / elapsed
	speedMB := speed / (1024 * 1024)
	percent := float64(currentBytes) / float64(totalBytes) * 100.0
	if percent > 100.0 {
		percent = 100.0
	}

	remBytes := totalBytes - currentBytes
	var etaSec float64
	if speed > 0 {
		etaSec = float64(remBytes) / speed
	}
	etaStr := formatETA(etaSec)

	barWidth := 20
	filled := int(float64(barWidth) * (percent / 100.0))
	if filled > barWidth {
		filled = barWidth
	}
	bar := strings.Repeat("=", filled) + strings.Repeat("-", barWidth-filled)

	currMB := float64(currentBytes) / (1024 * 1024)
	totMB := float64(totalBytes) / (1024 * 1024)

	nameDisplay := filename
	if len(nameDisplay) > 16 {
		nameDisplay = nameDisplay[:13] + "..."
	}

	line := fmt.Sprintf("  [%-12s] [%-16s] [%s] %5.1f%% | %6.1f/%6.1f MB | %5.1f MB/s | ETA: %s",
		phase, nameDisplay, bar, percent, currMB, totMB, speedMB, etaStr)

	if len(line) < 85 {
		line += strings.Repeat(" ", 85-len(line))
	}
	fmt.Printf("\r%s", line)
}

func clearProgressLine() {
	fmt.Printf("\r%s\r", strings.Repeat(" ", 85))
}

type FooterInfo struct {
	Version        int
	Footer         []byte
	Length         int64
	Checkpoint     uint64
	FailedAttempts uint16
	StateFlags     uint16
}

func readFileFooter(f *os.File, size int64) (*FooterInfo, error) {
	if size >= FooterLenV5Resumable {
		f.Seek(size-FooterLenV5Resumable, io.SeekStart)
		buf := make([]byte, FooterLenV5Resumable)
		if _, err := io.ReadFull(f, buf); err == nil {
			if string(buf[:8]) == MagicV5 {
				chk := binary.LittleEndian.Uint64(buf[92:100])
				fails := binary.LittleEndian.Uint16(buf[100:102])
				state := binary.LittleEndian.Uint16(buf[102:104])
				return &FooterInfo{
					Version:        5,
					Footer:         buf,
					Length:         FooterLenV5Resumable,
					Checkpoint:     chk,
					FailedAttempts: fails,
					StateFlags:     state,
				}, nil
			}
		}
	}
	if size >= FooterLenV5Base {
		f.Seek(size-FooterLenV5Base, io.SeekStart)
		buf := make([]byte, FooterLenV5Base)
		if _, err := io.ReadFull(f, buf); err == nil {
			if string(buf[:8]) == MagicV5 {
				fails := binary.LittleEndian.Uint16(buf[92:94])
				return &FooterInfo{
					Version:        5,
					Footer:         buf,
					Length:         FooterLenV5Base,
					Checkpoint:     0,
					FailedAttempts: fails,
					StateFlags:     StateNormalLocked,
				}, nil
			}
		}
	}
	if size >= FooterLenV4 {
		f.Seek(size-FooterLenV4, io.SeekStart)
		buf := make([]byte, FooterLenV4)
		if _, err := io.ReadFull(f, buf); err == nil {
			m := string(buf[:8])
			if m == MagicV4 || m == MagicV3 {
				v := 4
				if m == MagicV3 {
					v = 3
				}
				fails := binary.LittleEndian.Uint16(buf[76:78])
				return &FooterInfo{
					Version:        v,
					Footer:         buf,
					Length:         FooterLenV4,
					FailedAttempts: fails,
				}, nil
			}
		}
	}
	if size >= FooterLenV2 {
		f.Seek(size-FooterLenV2, io.SeekStart)
		buf := make([]byte, FooterLenV2)
		if _, err := io.ReadFull(f, buf); err == nil {
			m := string(buf[:8])
			if m == MagicV2 || m == MagicV1 {
				v := 2
				if m == MagicV1 {
					v = 1
				}
				return &FooterInfo{
					Version: v,
					Footer:  buf,
					Length:  FooterLenV2,
				}, nil
			}
		}
	}

	// Partial footer check
	if size >= 16 {
		scanLen := int64(256)
		if size < scanLen {
			scanLen = size
		}
		f.Seek(size-scanLen, io.SeekStart)
		tail := make([]byte, scanLen)
		if _, err := io.ReadFull(f, tail); err == nil {
			idx := bytes.LastIndex(tail, []byte(MagicV5))
			if idx >= 0 {
				damagedOffset := size - scanLen + int64(idx)
				return &FooterInfo{
					Version: -1, // Damaged marker
					Length:  damagedOffset,
				}, nil
			}
		}
	}

	return nil, nil
}

func checkFileStatus(filepath string) string {
	fi, err := os.Lstat(filepath)
	if err != nil {
		return "invalid"
	}
	if fi.Mode()&os.ModeSymlink != 0 {
		return "symlink (skipped)"
	}
	size := fi.Size()
	if size < FooterLenV2 {
		return "unlocked"
	}

	f, err := os.Open(filepath)
	if err != nil {
		return "unlocked"
	}
	defer f.Close()

	info, _ := readFileFooter(f, size)
	if info == nil {
		return "unlocked"
	}
	if info.Version == -1 {
		return "unlocked (partial initial header detected - self-heals on lock)"
	}
	if info.Version == 5 {
		if info.Length == FooterLenV5Resumable {
			if info.StateFlags == StateUnlockInProgress {
				return fmt.Sprintf("locked (V5 RESUMABLE UNLOCK INTERRUPTED at %.2f MB)", float64(info.Checkpoint)/(1024*1024))
			} else if info.StateFlags == StateLockInProgress {
				return fmt.Sprintf("locked (V5 RESUMABLE LOCK INTERRUPTED at %.2f MB)", float64(info.Checkpoint)/(1024*1024))
			}
		}
		lbl := "V5 Authenticated AEAD (100% Full-File)"
		if info.FailedAttempts >= 5 {
			return fmt.Sprintf("locked (%s - LOCKOUT: %d fails)", lbl, info.FailedAttempts)
		}
		return fmt.Sprintf("locked (%s)", lbl)
	}
	if info.Version == 4 {
		chunkSize := binary.LittleEndian.Uint32(info.Footer[8:12])
		mode := "V4 Full Armor"
		if chunkSize != 0 {
			mode = "V4 Header Armor"
		}
		if info.FailedAttempts >= 5 {
			return fmt.Sprintf("locked (%s - LOCKOUT: %d fails)", mode, info.FailedAttempts)
		}
		return fmt.Sprintf("locked (%s)", mode)
	}
	return fmt.Sprintf("locked (Legacy V%d)", info.Version)
}

func lockFileV5(filePath string, password string) (bool, string) {
	fi, err := os.Lstat(filePath)
	if err != nil {
		return false, err.Error()
	}
	if fi.Mode()&os.ModeSymlink != 0 {
		return false, "Symlink skipped"
	}
	size := fi.Size()
	if size < 1 {
		return false, "File is empty (0 bytes)"
	}

	fname := filepath.Base(filePath)

	f, err := os.OpenFile(filePath, os.O_RDWR, 0666)
	if err != nil {
		return false, err.Error()
	}
	defer f.Close()

	info, _ := readFileFooter(f, size)

	// Clean up any damaged partial footer
	if info != nil && info.Version == -1 {
		f.Truncate(info.Length)
		f.Sync()
		size = info.Length
		info = nil
	}

	// Resume interrupted lock
	if info != nil && info.Version == 5 && info.Length == FooterLenV5Resumable && info.StateFlags == StateLockInProgress {
		salt := info.Footer[12:28]
		nonce := info.Footer[28:44]
		encKey, macKey, authTag := deriveKeysV5(password, salt)
		if subtle.ConstantTimeCompare(info.Footer[76:92], authTag) != 1 {
			return false, "INCORRECT PASSWORD during resume"
		}

		block, _ := aes.NewCipher(encKey)
		dataLen := size - FooterLenV5Resumable
		pos := int64(info.Checkpoint)
		blockIdx := pos / ChunkSizeV5
		lastSyncPos := pos

		buf := make([]byte, ChunkSizeV5)
		resumeEncT := time.Now()

		for pos < dataLen {
			take := int64(ChunkSizeV5)
			if dataLen-pos < take {
				take = dataLen - pos
			}
			f.Seek(pos, io.SeekStart)
			io.ReadFull(f, buf[:take])

			ctr := makeCounter(nonce, uint64(blockIdx*(ChunkSizeV5/16)))
			stream := cipher.NewCTR(block, ctr)
			stream.XORKeyStream(buf[:take], buf[:take])

			f.Seek(pos, io.SeekStart)
			f.Write(buf[:take])

			pos += take
			blockIdx++

			if pos-lastSyncPos >= 1024*1024 || pos == dataLen {
				f.Sync()
				f.Seek(dataLen+92, io.SeekStart)
				var chkBuf [8]byte
				binary.LittleEndian.PutUint64(chkBuf[:], uint64(pos))
				f.Write(chkBuf[:])
				f.Sync()
				lastSyncPos = pos
			}
			renderProgress("Encrypting", fname, pos, dataLen, resumeEncT)
		}

		// Compute final master MAC
		f.Seek(0, io.SeekStart)
		h := hmac.New(sha256.New, macKey)
		p := int64(0)
		sealT := time.Now()
		for p < dataLen {
			t := int64(ChunkSizeV5)
			if dataLen-p < t {
				t = dataLen - p
			}
			io.ReadFull(f, buf[:t])
			h.Write(buf[:t])
			p += t
			renderProgress("Sealing HMAC", fname, p, dataLen, sealT)
		}
		masterMac := h.Sum(nil)

		f.Seek(dataLen+44, io.SeekStart)
		f.Write(masterMac)
		f.Seek(dataLen+92, io.SeekStart)
		var finalTail [12]byte
		binary.LittleEndian.PutUint64(finalTail[0:8], uint64(dataLen))
		binary.LittleEndian.PutUint16(finalTail[8:10], 0)
		binary.LittleEndian.PutUint16(finalTail[10:12], StateNormalLocked)
		f.Write(finalTail[:])
		f.Sync()

		clearProgressLine()
		return true, fmt.Sprintf("Resumed & Finalized 100%% Full-File AEAD (%d bytes)", dataLen)
	}

	if info != nil {
		return false, "Already locked"
	}

	salt := make([]byte, 16)
	nonce := make([]byte, 16)
	rand.Read(salt)
	rand.Read(nonce)

	renderPhaseNotice("Key Deriv", fname, "Computing 600,000 PBKDF2 rounds...")
	encKey, macKey, authTag := deriveKeysV5(password, salt)
	dataLen := size

	// Write initial 104-byte header at EOF with StateLockInProgress
	f.Seek(0, io.SeekEnd)
	var initialFooter [FooterLenV5Resumable]byte
	copy(initialFooter[0:8], []byte(MagicV5))
	binary.LittleEndian.PutUint32(initialFooter[8:12], ChunkSizeV5)
	copy(initialFooter[12:28], salt)
	copy(initialFooter[28:44], nonce)
	// 44..76 MasterMAC temp 0s
	copy(initialFooter[76:92], authTag)
	binary.LittleEndian.PutUint64(initialFooter[92:100], 0)
	binary.LittleEndian.PutUint16(initialFooter[100:102], 0)
	binary.LittleEndian.PutUint16(initialFooter[102:104], StateLockInProgress)
	f.Write(initialFooter[:])
	f.Sync()

	block, _ := aes.NewCipher(encKey)
	h := hmac.New(sha256.New, macKey)
	pos := int64(0)
	blockIdx := int64(0)
	lastSyncPos := int64(0)
	buf := make([]byte, ChunkSizeV5)
	encT := time.Now()

	for pos < dataLen {
		take := int64(ChunkSizeV5)
		if dataLen-pos < take {
			take = dataLen - pos
		}
		f.Seek(pos, io.SeekStart)
		io.ReadFull(f, buf[:take])

		ctr := makeCounter(nonce, uint64(blockIdx*(ChunkSizeV5/16)))
		stream := cipher.NewCTR(block, ctr)
		stream.XORKeyStream(buf[:take], buf[:take])

		h.Write(buf[:take])

		f.Seek(pos, io.SeekStart)
		f.Write(buf[:take])

		pos += take
		blockIdx++

		if pos-lastSyncPos >= 1024*1024 || pos == dataLen {
			f.Sync()
			f.Seek(dataLen+92, io.SeekStart)
			var chkBuf [8]byte
			binary.LittleEndian.PutUint64(chkBuf[:], uint64(pos))
			f.Write(chkBuf[:])
			f.Sync()
			lastSyncPos = pos
		}
		renderProgress("Encrypting", fname, pos, dataLen, encT)
	}

	masterMac := h.Sum(nil)
	f.Seek(dataLen+44, io.SeekStart)
	f.Write(masterMac)
	f.Seek(dataLen+92, io.SeekStart)
	var finalTail [12]byte
	binary.LittleEndian.PutUint64(finalTail[0:8], uint64(dataLen))
	binary.LittleEndian.PutUint16(finalTail[8:10], 0)
	binary.LittleEndian.PutUint16(finalTail[10:12], StateNormalLocked)
	f.Write(finalTail[:])
	f.Sync()

	clearProgressLine()
	return true, fmt.Sprintf("100%% Full-File AEAD Resumable Armor (%d bytes, 600k PBKDF2)", dataLen)
}

func unlockFileV5(filePath string, password string) (bool, string) {
	fi, err := os.Lstat(filePath)
	if err != nil {
		return false, err.Error()
	}
	if fi.Mode()&os.ModeSymlink != 0 {
		return false, "Symlink skipped"
	}
	size := fi.Size()
	fname := filepath.Base(filePath)

	f, err := os.OpenFile(filePath, os.O_RDWR, 0666)
	if err != nil {
		return false, err.Error()
	}
	defer f.Close()

	info, _ := readFileFooter(f, size)
	if info == nil || info.Version == -1 {
		return false, "Not locked"
	}

	dataLen := size - info.Length

	if info.Version == 5 {
		salt := info.Footer[12:28]
		nonce := info.Footer[28:44]
		storedMac := info.Footer[44:76]
		storedAuthTag := info.Footer[76:92]

		if info.FailedAttempts >= 10 {
			return false, fmt.Sprintf("BRUTE-FORCE LOCKOUT ACTIVE (%d failed attempts). Cooldown required.", info.FailedAttempts)
		}

		renderPhaseNotice("Key Deriv", fname, "Computing 600,000 PBKDF2 rounds...")
		encKey, macKey, computedAuthTag := deriveKeysV5(password, salt)
		if subtle.ConstantTimeCompare(storedAuthTag, computedAuthTag) != 1 {
			clearProgressLine()
			info.FailedAttempts++
			f.Seek(size-4, io.SeekStart)
			var failBuf [2]byte
			binary.LittleEndian.PutUint16(failBuf[:], info.FailedAttempts)
			f.Write(failBuf[:])
			f.Sync()
			rem := 10 - int(info.FailedAttempts)
			if rem < 0 {
				rem = 0
			}
			return false, fmt.Sprintf("INCORRECT PASSWORD (%d failed attempts, %d left before lockout)", info.FailedAttempts, rem)
		}

		block, _ := aes.NewCipher(encKey)
		buf := make([]byte, ChunkSizeV5)

		// CASE 1: Rollback an interrupted lock operation
		if info.StateFlags == StateLockInProgress && info.Checkpoint > 0 {
			rollbackLen := int64(info.Checkpoint)
			if rollbackLen > dataLen {
				rollbackLen = dataLen
			}
			pos := int64(0)
			blockIdx := int64(0)
			rollbackT := time.Now()

			for pos < rollbackLen {
				take := int64(ChunkSizeV5)
				if rollbackLen-pos < take {
					take = rollbackLen - pos
				}
				f.Seek(pos, io.SeekStart)
				io.ReadFull(f, buf[:take])

				ctr := makeCounter(nonce, uint64(blockIdx*(ChunkSizeV5/16)))
				stream := cipher.NewCTR(block, ctr)
				stream.XORKeyStream(buf[:take], buf[:take])

				f.Seek(pos, io.SeekStart)
				f.Write(buf[:take])

				pos += take
				blockIdx++
				renderProgress("Rolling Back", fname, pos, rollbackLen, rollbackT)
			}
			f.Sync()
			f.Truncate(dataLen)
			f.Sync()
			clearProgressLine()
			return true, fmt.Sprintf("Rolled Back Interrupted Lock & Fully Restored Original (%d bytes)", dataLen)
		}

		// CASE 2: Resume interrupted unlock or fresh unlock
		startPos := int64(0)
		if info.StateFlags == StateUnlockInProgress && info.Checkpoint > 0 {
			startPos = int64(info.Checkpoint)
		} else {
			// Verify Master HMAC
			f.Seek(0, io.SeekStart)
			h := hmac.New(sha256.New, macKey)
			p := int64(0)
			verifyT := time.Now()
			for p < dataLen {
				t := int64(ChunkSizeV5)
				if dataLen-p < t {
					t = dataLen - p
				}
				io.ReadFull(f, buf[:t])
				h.Write(buf[:t])
				p += t
				renderProgress("Verifying", fname, p, dataLen, verifyT)
			}
			computedMac := h.Sum(nil)
			if subtle.ConstantTimeCompare(storedMac, computedMac) != 1 {
				clearProgressLine()
				return false, "INTEGRITY ERROR: Ciphertext has been modified or corrupted! Decryption halted."
			}

			if info.Length == FooterLenV5Resumable {
				f.Seek(dataLen+92, io.SeekStart)
				var stateBuf [12]byte
				binary.LittleEndian.PutUint64(stateBuf[0:8], 0)
				binary.LittleEndian.PutUint16(stateBuf[8:10], info.FailedAttempts)
				binary.LittleEndian.PutUint16(stateBuf[10:12], StateUnlockInProgress)
				f.Write(stateBuf[:])
				f.Sync()
			}
		}

		pos := startPos
		blockIdx := pos / ChunkSizeV5
		lastSyncPos := pos
		decryptT := time.Now()

		for pos < dataLen {
			take := int64(ChunkSizeV5)
			if dataLen-pos < take {
				take = dataLen - pos
			}
			f.Seek(pos, io.SeekStart)
			io.ReadFull(f, buf[:take])

			ctr := makeCounter(nonce, uint64(blockIdx*(ChunkSizeV5/16)))
			stream := cipher.NewCTR(block, ctr)
			stream.XORKeyStream(buf[:take], buf[:take])

			f.Seek(pos, io.SeekStart)
			f.Write(buf[:take])

			pos += take
			blockIdx++

			if info.Length == FooterLenV5Resumable {
				if pos-lastSyncPos >= 1024*1024 || pos == dataLen {
					f.Sync()
					f.Seek(dataLen+92, io.SeekStart)
					var chkBuf [8]byte
					binary.LittleEndian.PutUint64(chkBuf[:], uint64(pos))
					f.Write(chkBuf[:])
					f.Sync()
					lastSyncPos = pos
				}
			}
			renderProgress("Decrypting", fname, pos, dataLen, decryptT)
		}

		f.Sync()
		f.Truncate(dataLen)
		f.Sync()

		clearProgressLine()

		if startPos > 0 {
			return true, fmt.Sprintf("Resumed & Fully Restored (%d bytes, resumed from %.2f MB)", dataLen, float64(startPos)/(1024*1024))
		}
		return true, fmt.Sprintf("Verified & Restored 100%% full file (%d bytes)", dataLen)
	}

	return false, "Legacy format detected. Please unlock with python tools/vault.py unlock."
}

func resolveTargets(targetPath string) []string {
	cleanPath := strings.Trim(targetPath, "\"' ")
	absPath, err := filepath.Abs(cleanPath)
	if err != nil {
		return nil
	}

	fi, err := os.Lstat(absPath)
	if err != nil {
		return nil
	}
	if fi.Mode()&os.ModeSymlink != 0 {
		return nil
	}

	if !fi.IsDir() {
		ext := strings.ToLower(filepath.Ext(absPath))
		if excludedExts[ext] {
			return nil
		}
		return []string{absPath}
	}

	var results []string
	stack := []string{absPath}

	for len(stack) > 0 {
		curr := stack[len(stack)-1]
		stack = stack[:len(stack)-1]

		entries, err := os.ReadDir(curr)
		if err != nil {
			continue
		}

		for _, e := range entries {
			name := e.Name()
			if strings.HasPrefix(name, ".") {
				continue
			}
			full := filepath.Join(curr, name)
			info, err := os.Lstat(full)
			if err != nil || info.Mode()&os.ModeSymlink != 0 {
				continue
			}

			if info.IsDir() {
				low := strings.ToLower(name)
				if excludedDirs[low] {
					continue
				}
				stack = append(stack, full)
			} else {
				ext := strings.ToLower(filepath.Ext(name))
				if excludedExts[ext] {
					continue
				}
				results = append(results, full)
			}
		}
	}
	return results
}

func readPasswordMasked(prompt string) string {
	fmt.Print(prompt)
	defer fmt.Println()

	cleanup, err := disableEcho()
	if err == nil && cleanup != nil {
		defer cleanup()
	}

	reader := bufio.NewReader(os.Stdin)
	pass, err := reader.ReadString('\n')
	if err != nil && len(pass) == 0 {
		return ""
	}
	return strings.TrimRight(pass, "\r\n")
}

func printBanner(action, targetPath string, targetsCount int) {
	fmt.Println(strings.Repeat("=", 70))
	fmt.Printf("  Universal Vault v%s (CLI Native): %s Operation\n", Version, strings.ToUpper(action))
	fmt.Printf("  Target Scope   : %s\n", targetPath)
	fmt.Printf("  Files Located  : %d\n", targetsCount)
	if action == "lock" {
		fmt.Println("  Armor Mode     : 100% Full-File Resumable AEAD (Stream Encrypt-then-MAC)")
		fmt.Println("  Security       : 600,000 PBKDF2-SHA256 Rounds | Anti-Tampering HMAC-SHA256")
		fmt.Println("  Fault Tolerance: Checkpointed In-Place Streaming (Crash-Safe Resumable)")
	}
	fmt.Println(strings.Repeat("=", 70))
}

func main() {
	if len(os.Args) < 2 {
		fmt.Printf("Universal Vault v%s - High Performance In-Place Cryptographic CLI\n\n", Version)
		fmt.Println("Usage:")
		fmt.Println("  vault lock   <path> [-p password]   Encrypt file or directory tree in-place")
		fmt.Println("  vault unlock <path> [-p password]   Verify HMAC & decrypt file or directory")
		fmt.Println("  vault status <path>                 Inspect lock status and checkpoints")
		fmt.Println("  vault version                       Display CLI build version")
		return
	}

	action := strings.ToLower(os.Args[1])

	if action == "version" || action == "-v" || action == "--version" {
		fmt.Printf("Universal Vault CLI v%s (Go Native Architecture)\n", Version)
		return
	}

	if action != "lock" && action != "unlock" && action != "status" {
		fmt.Printf("Unknown command '%s'. Valid commands: lock, unlock, status, version\n", action)
		os.Exit(1)
	}

	targetPath := "."
	var password string

	for i := 2; i < len(os.Args); i++ {
		arg := os.Args[i]
		if arg == "-p" || arg == "--password" {
			if i+1 < len(os.Args) {
				password = os.Args[i+1]
				i++
			}
		} else if !strings.HasPrefix(arg, "-") {
			targetPath = arg
		}
	}

	targets := resolveTargets(targetPath)
	absPath, _ := filepath.Abs(targetPath)
	printBanner(action, absPath, len(targets))

	if len(targets) == 0 {
		fmt.Println("No eligible files found to process.\n")
		return
	}

	if action == "status" {
		locked := 0
		unlocked := 0
		for _, p := range targets {
			st := checkFileStatus(p)
			rel, err := filepath.Rel(absPath, p)
			if err != nil || rel == "." {
				rel = filepath.Base(p)
			}
			if strings.HasPrefix(st, "locked") {
				fmt.Printf("  [LOCKED]   %s (%s)\n", rel, st)
				locked++
			} else {
				fmt.Printf("  [UNLOCKED] %s\n", rel)
				unlocked++
			}
		}
		fmt.Println(strings.Repeat("-", 70))
		fmt.Printf("Status Summary: %d Locked | %d Unlocked\n\n", locked, unlocked)
		return
	}

	if password == "" {
		password = readPasswordMasked(fmt.Sprintf("Enter Master Password to %s: ", strings.ToUpper(action)))
		if password == "" {
			fmt.Println("Error: Password cannot be empty.")
			os.Exit(1)
		}
	}

	succeeded := 0
	skipped := 0
	failed := 0

	for _, p := range targets {
		rel, err := filepath.Rel(absPath, p)
		if err != nil || rel == "." {
			rel = filepath.Base(p)
		}
		var ok bool
		var msg string
		if action == "lock" {
			ok, msg = lockFileV5(p, password)
		} else {
			ok, msg = unlockFileV5(p, password)
		}

		clearProgressLine()
		fmt.Printf("Processing: %s... ", rel)

		if ok {
			fmt.Printf("[SUCCESS: %s]\n", msg)
			succeeded++
		} else if strings.Contains(msg, "Already locked") || strings.Contains(msg, "Not locked") || strings.Contains(msg, "empty") {
			fmt.Printf("[SKIPPED: %s]\n", msg)
			skipped++
		} else {
			fmt.Printf("[FAILED: %s]\n", msg)
			failed++
		}
	}

	fmt.Println(strings.Repeat("-", 70))
	fmt.Printf("Summary: %d Succeeded | %d Skipped | %d Failed\n\n", succeeded, skipped, failed)
}
