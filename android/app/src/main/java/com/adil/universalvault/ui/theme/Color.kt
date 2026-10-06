package com.adil.universalvault.ui.theme

import androidx.compose.runtime.staticCompositionLocalOf
import androidx.compose.ui.graphics.Color

// Dark Palette
val BgMidnight = Color(0xFF06090F)
val SurfaceObsidian = Color(0xFF0D131F)
val SurfaceBorder = Color(0xFF1E293B)
val SurfaceElevated = Color(0xFF151E2E)

// Light Palette (Matching HTML Web Workstation)
val BgLight = Color(0xFFFAFAFA)
val SurfaceLight = Color(0xFFFFFFFF)
val SurfaceBorderLight = Color(0xFFE2E8F0)
val SurfaceElevatedLight = Color(0xFFF1F5F9)

val AccentCyan = Color(0xFF38BDF8)
val AccentCyanDark = Color(0xFF0284C7)
val AccentIndigo = Color(0xFF818CF8)
val EmeraldSuccess = Color(0xFF10B981)
val RoseProtected = Color(0xFFF43F5E)
val AmberWarning = Color(0xFFF59E0B)

// Dark Text
val TextPrimary = Color(0xFFF8FAFC)
val TextSecondary = Color(0xFF94A3B8)
val TextMuted = Color(0xFF64748B)

// Light Text
val TextPrimaryLight = Color(0xFF0F172A)
val TextSecondaryLight = Color(0xFF475569)
val TextMutedLight = Color(0xFF64748B)

data class VaultColors(
    val background: Color,
    val surface: Color,
    val surfaceBorder: Color,
    val surfaceElevated: Color,
    val textPrimary: Color,
    val textSecondary: Color,
    val textMuted: Color,
    val accentCyan: Color,
    val emeraldSuccess: Color,
    val roseProtected: Color,
    val isDark: Boolean
)

val DarkVaultColors = VaultColors(
    background = BgMidnight,
    surface = SurfaceObsidian,
    surfaceBorder = SurfaceBorder,
    surfaceElevated = SurfaceElevated,
    textPrimary = TextPrimary,
    textSecondary = TextSecondary,
    textMuted = TextMuted,
    accentCyan = AccentCyan,
    emeraldSuccess = EmeraldSuccess,
    roseProtected = RoseProtected,
    isDark = true
)

val LightVaultColors = VaultColors(
    background = BgLight,
    surface = SurfaceLight,
    surfaceBorder = SurfaceBorderLight,
    surfaceElevated = SurfaceElevatedLight,
    textPrimary = TextPrimaryLight,
    textSecondary = TextSecondaryLight,
    textMuted = TextMutedLight,
    accentCyan = AccentCyanDark,
    emeraldSuccess = EmeraldSuccess,
    roseProtected = RoseProtected,
    isDark = false
)

val LocalVaultColors = staticCompositionLocalOf { DarkVaultColors }
