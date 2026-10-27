import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:fluttertoast/fluttertoast.dart';
import 'package:audio_service/audio_service.dart';

import 'package:google_fonts/google_fonts.dart';

import 'package:fley/l10n/app_localizations.dart';
export 'strings.dart';

String getFontFamily([String? fontName]) {
  final font = fontName ?? activeFontNotifier.value;
  if (font == 'Spotify Style') {
    return GoogleFonts.figtree().fontFamily!;
  } else if (font == 'Apple Music Style') {
    return GoogleFonts.inter().fontFamily!;
  } else {
    return GoogleFonts.plusJakartaSans().fontFamily!;
  }
}

bool isBackgroundInitialized = false;
String? backgroundInitError;
late AudioHandler audioHandler;
final ValueNotifier<String> activeFontNotifier = ValueNotifier<String>(
  'Plus Jakarta Sans',
);
final ValueNotifier<double> fontScaleNotifier = ValueNotifier<double>(1.0);
final ValueNotifier<String> themeModeNotifier = ValueNotifier<String>('dark');
final ValueNotifier<String> customThemeBgNotifier = ValueNotifier<String>(
  'dynamic',
);
final ValueNotifier<Color?> dominantColorNotifier = ValueNotifier<Color?>(null);
final ValueNotifier<String?> customThemeBgPathNotifier = ValueNotifier<String?>(
  null,
);
final ValueNotifier<double> customThemeBgBlurNotifier = ValueNotifier<double>(
  25.0,
);
final ValueNotifier<double> customThemeBgDimNotifier = ValueNotifier<double>(
  0.65,
);
final ValueNotifier<double> customThemeBgScaleNotifier = ValueNotifier<double>(
  1.0,
);
final ValueNotifier<String> customThemeStyleNotifier = ValueNotifier<String>(
  'dark',
);
final ValueNotifier<double> customThemeBgOffsetXNotifier =
    ValueNotifier<double>(0.0);
final ValueNotifier<double> customThemeBgOffsetYNotifier =
    ValueNotifier<double>(0.0);
final ValueNotifier<double> playerCustomBgOffsetXNotifier =
    ValueNotifier<double>(0.0);
final ValueNotifier<double> playerCustomBgOffsetYNotifier =
    ValueNotifier<double>(0.0);

// Player Background Settings
final ValueNotifier<String> playerBackgroundStyleNotifier =
    ValueNotifier<String>('gradient');
final ValueNotifier<String> detailViewBackgroundStyleNotifier =
    ValueNotifier<String>('gradient');
final ValueNotifier<String?> homeBannerPathNotifier =
    ValueNotifier<String?>(null);
final ValueNotifier<bool> showHomeBannerNotifier = ValueNotifier<bool>(true);
final ValueNotifier<String?> playerCustomBgPathNotifier =
    ValueNotifier<String?>(null);
final ValueNotifier<double> playerCustomBgBlurNotifier = ValueNotifier<double>(
  0.0,
);
final ValueNotifier<double> playerCustomBgDimNotifier = ValueNotifier<double>(
  0.4,
);
final ValueNotifier<double> playerCustomBgScaleNotifier = ValueNotifier<double>(
  1.0,
);
final ValueNotifier<String> themeAccentPresetNotifier = ValueNotifier<String>(
  'spotify',
);

Color resolveThemeAccentColor(String preset, Color? dominantColor) {
  if (preset == 'dynamic') {
    final baseColor = dominantColor ?? const Color(0xFF8E8E93);
    final hsl = HSLColor.fromColor(baseColor);
    if (hsl.lightness < 0.55) {
      if (hsl.saturation < 0.12) {
        return const Color(0xFFB3B3B3);
      }
      return hsl.withLightness(0.6).toColor();
    }
    return baseColor;
  }
  switch (preset) {
    case 'spotify':
      return const Color(0xFF1DB954);
    case 'apple':
      return const Color(0xFFFC3C44);
    case 'purple':
      return const Color(0xFF8E2DE2);
    case 'tidal':
      return const Color(0xFF00F2FE);
    case 'orange':
      return const Color(0xFFFF9233);
    case 'sakura':
      return const Color(0xFFFF2A6D);
    case 'gold':
      return const Color(0xFFDFBA59);
    case 'blue':
      return const Color(0xFF007AFF);
    case 'lime':
      return const Color(0xFFCCFF00);
    default:
      return const Color(0xFF1DB954);
  }
}

// User Profile Notifiers
final ValueNotifier<String> userProfileNameNotifier =
    ValueNotifier<String>('User');
final ValueNotifier<String?> userProfileImageNotifier =
    ValueNotifier<String?>(null);
final ValueNotifier<String> userProfileBioNotifier =
    ValueNotifier<String>('Music enthusiast');

// Lyrics viewer behavior
final ValueNotifier<bool> lyricsHidePastNotifier = ValueNotifier<bool>(true);
final ValueNotifier<bool> lyricsAutoFollowNotifier = ValueNotifier<bool>(true);

void showFleyToast(String msg, {bool isLong = false}) {
  Fluttertoast.showToast(
    msg: msg,
    toastLength: isLong ? Toast.LENGTH_LONG : Toast.LENGTH_SHORT,
    gravity: ToastGravity.BOTTOM,
    backgroundColor: const Color(0xFF1E1E1E),
    textColor: Colors.white,
    fontSize: 14.0,
  );
}

Future<bool?> showConfirmationDialog(
  BuildContext context, {
  required String title,
  required String content,
  String? confirmText,
  String? cancelText,
  Color confirmColor = Colors.redAccent,
}) {
  final isLight = isAppLight;
  return showDialog<bool>(
    context: context,
    builder: (context) {
      return AlertDialog(
        backgroundColor: isLight
            ? const Color(0xFFF0F0F3)
            : const Color(0xFF1E1E1E),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        title: Row(
          children: [
            Icon(Icons.warning_amber_rounded, color: confirmColor),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                title,
                style: TextStyle(
                  color: isLight ? const Color(0xFF1A1A1A) : Colors.white,
                  fontSize: 18,
                ),
              ),
            ),
          ],
        ),
        content: Text(
          content,
          style: TextStyle(
            color: isLight ? Colors.black87 : Colors.white70,
            height: 1.5,
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text(
              cancelText ?? AppLocalizations.of(context).cancel,
              style: TextStyle(
                color: isLight ? Colors.black54 : Colors.white54,
              ),
            ),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: Text(
              confirmText ?? AppLocalizations.of(context).confirm,
              style: TextStyle(
                color: confirmColor,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ],
      );
    },
  );
}

bool get isAppLight {
  final mode = themeModeNotifier.value;
  if (mode == 'light') return true;
  if (mode == 'custom') {
    final style = customThemeStyleNotifier.value;
    if (style == 'light') return true;
    if (style == 'dynamic') {
      final activeCol = dominantColorNotifier.value ?? const Color(0xFF8E8E93);
      return activeCol.computeLuminance() > 0.45;
    }
  }
  return false;
}

Color getAppBackgroundColor({
  required String themeMode,
  required String customBg,
  required Color? artworkColor,
}) {
  if (themeMode == 'light') return const Color(0xFFF6F8FA);
  if (themeMode == 'dark') return const Color(0xFF0A0A0A);
  switch (customBg) {
    case 'custom_image':
      return Colors.transparent;
    case 'navy':
      return const Color(0xFF0B132B);
    case 'forest':
      return const Color(0xFF0D1F1D);
    case 'wine':
      return const Color(0xFF1A0F1A);
    case 'terracotta':
      return const Color(0xFF211510);
    case 'slate':
      return const Color(0xFF1C2541);
    case 'dynamic':
    default:
      if (artworkColor == null) return const Color(0xFF0F0F15);
      final hsl = HSLColor.fromColor(artworkColor);
      return hsl
          .withSaturation(clampDouble(hsl.saturation * 0.35, 0.1, 0.25))
          .withLightness(clampDouble(hsl.lightness * 0.12, 0.04, 0.08))
          .toColor();
  }
}

Color getAppCardColor({required String themeMode, required Color appBgColor}) {
  if (themeMode == 'light') return Colors.white;
  if (themeMode == 'dark') return const Color(0xFF161616);
  final hsl = HSLColor.fromColor(appBgColor);
  return hsl
      .withLightness(clampDouble(hsl.lightness + 0.04, 0.06, 0.16))
      .toColor();
}
