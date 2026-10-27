import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../utils/globals.dart';

class SettingsState {
  final int playCountThreshold;
  final String activeFont;
  final double fontScale;
  final String themeAccentPreset;
  final String playerBackgroundStyle;
  final String detailViewBackgroundStyle;
  final String? homeBannerPath;
  final bool showHomeBanner;
  final String? playerCustomBgPath;
  final double playerCustomBgBlur;
  final double playerCustomBgDim;
  final double playerCustomBgScale;
  final String themeMode;
  final String customThemeBg;
  final String? customThemeBgPath;
  final double customThemeBgBlur;
  final double customThemeBgDim;
  final double customThemeBgScale;
  final String customThemeStyle;

  SettingsState({
    this.playCountThreshold = 10,
    this.activeFont = 'Plus Jakarta Sans',
    this.fontScale = 1.0,
    this.themeAccentPreset = 'spotify',
    this.playerBackgroundStyle = 'gradient',
    this.detailViewBackgroundStyle = 'gradient',
    this.homeBannerPath,
    this.showHomeBanner = true,
    this.playerCustomBgPath,
    this.playerCustomBgBlur = 0.0,
    this.playerCustomBgDim = 0.4,
    this.playerCustomBgScale = 1.0,
    this.themeMode = 'dark',
    this.customThemeBg = 'dynamic',
    this.customThemeBgPath,
    this.customThemeBgBlur = 25.0,
    this.customThemeBgDim = 0.65,
    this.customThemeBgScale = 1.0,
    this.customThemeStyle = 'dark',
  });

  SettingsState copyWith({
    int? playCountThreshold,
    String? activeFont,
    double? fontScale,
    String? themeAccentPreset,
    String? playerBackgroundStyle,
    String? detailViewBackgroundStyle,
    String? homeBannerPath,
    bool? showHomeBanner,
    String? playerCustomBgPath,
    double? playerCustomBgBlur,
    double? playerCustomBgDim,
    double? playerCustomBgScale,
    String? themeMode,
    String? customThemeBg,
    String? customThemeBgPath,
    double? customThemeBgBlur,
    double? customThemeBgDim,
    double? customThemeBgScale,
    String? customThemeStyle,
  }) {
    return SettingsState(
      playCountThreshold: playCountThreshold ?? this.playCountThreshold,
      activeFont: activeFont ?? this.activeFont,
      fontScale: fontScale ?? this.fontScale,
      themeAccentPreset: themeAccentPreset ?? this.themeAccentPreset,
      playerBackgroundStyle:
          playerBackgroundStyle ?? this.playerBackgroundStyle,
      detailViewBackgroundStyle:
          detailViewBackgroundStyle ?? this.detailViewBackgroundStyle,
      homeBannerPath: homeBannerPath != null
          ? (homeBannerPath.isEmpty ? null : homeBannerPath)
          : this.homeBannerPath,
      showHomeBanner: showHomeBanner ?? this.showHomeBanner,
      playerCustomBgPath: playerCustomBgPath != null
          ? (playerCustomBgPath.isEmpty ? null : playerCustomBgPath)
          : this.playerCustomBgPath,
      playerCustomBgBlur: playerCustomBgBlur ?? this.playerCustomBgBlur,
      playerCustomBgDim: playerCustomBgDim ?? this.playerCustomBgDim,
      playerCustomBgScale: playerCustomBgScale ?? this.playerCustomBgScale,
      themeMode: themeMode ?? this.themeMode,
      customThemeBg: customThemeBg ?? this.customThemeBg,
      customThemeBgPath: customThemeBgPath != null
          ? (customThemeBgPath.isEmpty ? null : customThemeBgPath)
          : this.customThemeBgPath,
      customThemeBgBlur: customThemeBgBlur ?? this.customThemeBgBlur,
      customThemeBgDim: customThemeBgDim ?? this.customThemeBgDim,
      customThemeBgScale: customThemeBgScale ?? this.customThemeBgScale,
      customThemeStyle: customThemeStyle ?? this.customThemeStyle,
    );
  }
}

class SettingsNotifier extends Notifier<SettingsState> {
  @override
  SettingsState build() {
    _loadSettings();
    return SettingsState();
  }

  Future<void> _loadSettings() async {
    final prefs = await SharedPreferences.getInstance();
    state = SettingsState(
      playCountThreshold: prefs.getInt('playCountThreshold') ?? 10,
      activeFont: prefs.getString('activeFont') ?? 'Plus Jakarta Sans',
      fontScale: prefs.getDouble('fontScale') ?? 1.0,
      themeAccentPreset: prefs.getString('themeAccentPreset') ?? 'spotify',
      playerBackgroundStyle:
          prefs.getString('playerBackgroundStyle') ?? 'gradient',
      detailViewBackgroundStyle:
          prefs.getString('detailViewBackgroundStyle') ?? 'gradient',
      homeBannerPath: prefs.getString('homeBannerPath'),
      showHomeBanner: prefs.getBool('showHomeBanner') ?? true,
      playerCustomBgPath: prefs.getString('playerCustomBgPath'),
      playerCustomBgBlur: prefs.getDouble('playerCustomBgBlur') ?? 0.0,
      playerCustomBgDim: prefs.getDouble('playerCustomBgDim') ?? 0.4,
      playerCustomBgScale: prefs.getDouble('playerCustomBgScale') ?? 1.0,
      themeMode: prefs.getString('themeMode') ?? 'dark',
      customThemeBg: prefs.getString('customThemeBg') ?? 'dynamic',
      customThemeBgPath: prefs.getString('customThemeBgPath'),
      customThemeBgBlur: prefs.getDouble('customThemeBgBlur') ?? 25.0,
      customThemeBgDim: prefs.getDouble('customThemeBgDim') ?? 0.65,
      customThemeBgScale: prefs.getDouble('customThemeBgScale') ?? 1.0,
      customThemeStyle: prefs.getString('customThemeStyle') ?? 'dark',
    );

    // Sync to globals for backward compatibility during refactor phase
    activeFontNotifier.value = state.activeFont;
    fontScaleNotifier.value = state.fontScale;
    themeModeNotifier.value = state.themeMode;
    customThemeBgNotifier.value = state.customThemeBg;
    customThemeBgPathNotifier.value = state.customThemeBgPath;
    customThemeBgBlurNotifier.value = state.customThemeBgBlur;
    customThemeBgDimNotifier.value = state.customThemeBgDim;
    customThemeBgScaleNotifier.value = state.customThemeBgScale;
    customThemeStyleNotifier.value = state.customThemeStyle;
    playerBackgroundStyleNotifier.value = state.playerBackgroundStyle;
    detailViewBackgroundStyleNotifier.value = state.detailViewBackgroundStyle;
    homeBannerPathNotifier.value = state.homeBannerPath;
    showHomeBannerNotifier.value = state.showHomeBanner;
    playerCustomBgPathNotifier.value = state.playerCustomBgPath;
    playerCustomBgBlurNotifier.value = state.playerCustomBgBlur;
    playerCustomBgDimNotifier.value = state.playerCustomBgDim;
    playerCustomBgScaleNotifier.value = state.playerCustomBgScale;
    themeAccentPresetNotifier.value = state.themeAccentPreset;
  }

  Future<void> updateSetting({
    int? playCountThreshold,
    String? activeFont,
    double? fontScale,
    String? themeAccentPreset,
    String? playerBackgroundStyle,
    String? detailViewBackgroundStyle,
    String? homeBannerPath,
    bool? showHomeBanner,
    String? playerCustomBgPath,
    double? playerCustomBgBlur,
    double? playerCustomBgDim,
    double? playerCustomBgScale,
    String? themeMode,
    String? customThemeBg,
    String? customThemeBgPath,
    double? customThemeBgBlur,
    double? customThemeBgDim,
    double? customThemeBgScale,
    String? customThemeStyle,
  }) async {
    final prefs = await SharedPreferences.getInstance();

    if (playCountThreshold != null) {
      await prefs.setInt('playCountThreshold', playCountThreshold);
    }
    if (activeFont != null) {
      await prefs.setString('activeFont', activeFont);
    }
    if (fontScale != null) {
      await prefs.setDouble('fontScale', fontScale);
    }
    if (themeAccentPreset != null) {
      await prefs.setString('themeAccentPreset', themeAccentPreset);
    }
    if (playerBackgroundStyle != null) {
      await prefs.setString('playerBackgroundStyle', playerBackgroundStyle);
    }
    if (detailViewBackgroundStyle != null) {
      await prefs.setString(
        'detailViewBackgroundStyle',
        detailViewBackgroundStyle,
      );
    }
    if (homeBannerPath != null) {
      await prefs.setString('homeBannerPath', homeBannerPath);
    }
    if (showHomeBanner != null) {
      await prefs.setBool('showHomeBanner', showHomeBanner);
    }
    if (playerCustomBgPath != null) {
      await prefs.setString('playerCustomBgPath', playerCustomBgPath);
    }
    if (playerCustomBgBlur != null) {
      await prefs.setDouble('playerCustomBgBlur', playerCustomBgBlur);
    }
    if (playerCustomBgDim != null) {
      await prefs.setDouble('playerCustomBgDim', playerCustomBgDim);
    }
    if (playerCustomBgScale != null) {
      await prefs.setDouble('playerCustomBgScale', playerCustomBgScale);
    }
    if (themeMode != null) {
      await prefs.setString('themeMode', themeMode);
    }
    if (customThemeBg != null) {
      await prefs.setString('customThemeBg', customThemeBg);
    }
    if (customThemeBgPath != null) {
      await prefs.setString('customThemeBgPath', customThemeBgPath);
    }
    if (customThemeBgBlur != null) {
      await prefs.setDouble('customThemeBgBlur', customThemeBgBlur);
    }
    if (customThemeBgDim != null) {
      await prefs.setDouble('customThemeBgDim', customThemeBgDim);
    }
    if (customThemeBgScale != null) {
      await prefs.setDouble('customThemeBgScale', customThemeBgScale);
    }
    if (customThemeStyle != null) {
      await prefs.setString('customThemeStyle', customThemeStyle);
    }

    state = state.copyWith(
      playCountThreshold: playCountThreshold,
      activeFont: activeFont,
      fontScale: fontScale,
      themeAccentPreset: themeAccentPreset,
      playerBackgroundStyle: playerBackgroundStyle,
      detailViewBackgroundStyle: detailViewBackgroundStyle,
      homeBannerPath: homeBannerPath,
      showHomeBanner: showHomeBanner,
      playerCustomBgPath: playerCustomBgPath,
      playerCustomBgBlur: playerCustomBgBlur,
      playerCustomBgDim: playerCustomBgDim,
      playerCustomBgScale: playerCustomBgScale,
      themeMode: themeMode,
      customThemeBg: customThemeBg,
      customThemeBgPath: customThemeBgPath,
      customThemeBgBlur: customThemeBgBlur,
      customThemeBgDim: customThemeBgDim,
      customThemeBgScale: customThemeBgScale,
      customThemeStyle: customThemeStyle,
    );

    // Sync to globals
    if (activeFont != null) {
      activeFontNotifier.value = activeFont;
    }
    if (fontScale != null) {
      fontScaleNotifier.value = fontScale;
    }
    if (themeMode != null) {
      themeModeNotifier.value = themeMode;
    }
    if (customThemeBg != null) {
      customThemeBgNotifier.value = customThemeBg;
    }
    if (customThemeBgPath != null) {
      customThemeBgPathNotifier.value = customThemeBgPath;
    }
    if (customThemeBgBlur != null) {
      customThemeBgBlurNotifier.value = customThemeBgBlur;
    }
    if (customThemeBgDim != null) {
      customThemeBgDimNotifier.value = customThemeBgDim;
    }
    if (customThemeBgScale != null) {
      customThemeBgScaleNotifier.value = customThemeBgScale;
    }
    if (customThemeStyle != null) {
      customThemeStyleNotifier.value = customThemeStyle;
    }
    if (playerBackgroundStyle != null) {
      playerBackgroundStyleNotifier.value = playerBackgroundStyle;
    }
    if (detailViewBackgroundStyle != null) {
      detailViewBackgroundStyleNotifier.value = detailViewBackgroundStyle;
    }
    if (homeBannerPath != null) {
      homeBannerPathNotifier.value = homeBannerPath;
    }
    if (showHomeBanner != null) {
      showHomeBannerNotifier.value = showHomeBanner;
    }
    if (playerCustomBgPath != null) {
      playerCustomBgPathNotifier.value = playerCustomBgPath;
    }
    if (playerCustomBgBlur != null) {
      playerCustomBgBlurNotifier.value = playerCustomBgBlur;
    }
    if (playerCustomBgDim != null) {
      playerCustomBgDimNotifier.value = playerCustomBgDim;
    }
    if (playerCustomBgScale != null) {
      playerCustomBgScaleNotifier.value = playerCustomBgScale;
    }
    if (themeAccentPreset != null) {
      themeAccentPresetNotifier.value = themeAccentPreset;
    }
  }
}

final settingsProvider = NotifierProvider<SettingsNotifier, SettingsState>(() {
  return SettingsNotifier();
});
