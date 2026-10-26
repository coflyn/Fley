// ignore_for_file: deprecated_member_use
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../providers/settings_provider.dart';
import 'dart:io';
import 'dart:ui';
import 'dart:convert';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:on_audio_query/on_audio_query.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:image_picker/image_picker.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:path_provider/path_provider.dart';
import '../main.dart';
import '../utils/globals.dart';
import '../utils/image_cropper_util.dart';

import '../widgets/settings/settings_ui_components.dart';
import 'package:fley/l10n/app_localizations.dart';
part 'settings_sleep_timer.dart';
part 'settings_backup_restore.dart';
part 'settings_hidden_tracks.dart';
part 'settings_threshold_ui.dart';
part 'settings_typography_ui.dart';
part 'settings_theme_accent_ui.dart';
part 'settings_theme_mode_ui.dart';
part 'settings_language_density_ui.dart';

class SettingsScreen extends ConsumerStatefulWidget {
  final VoidCallback onRescanLibrary;
  final VoidCallback onSettingsChanged;
  final Function(int) onSetSleepTimer;
  final VoidCallback onResetData;
  final ValueNotifier<int> sleepTimerNotifier;
  final VoidCallback onManageFolders;
  final Function(bool) onSetSkipSilence;

  const SettingsScreen({
    super.key,
    required this.onRescanLibrary,
    required this.onSettingsChanged,
    required this.onSetSleepTimer,
    required this.onResetData,
    required this.sleepTimerNotifier,
    required this.onManageFolders,
    required this.onSetSkipSilence,
  });

  @override
  ConsumerState<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends ConsumerState<SettingsScreen> {
  bool _filterShortAudio = false;
  bool _autoRegexClean = false;
  int _crossfadeDuration = 200;
  bool _pauseOnDisconnect = true;
  bool _autoPlayAfterCall = true;
  bool _playTogether = false;
  int _playCountThreshold = 10;
  String _activeFont = activeFontNotifier.value;
  double _fontScale = 1.0;
  String _language = 'en';
  bool _skipSilence = false;
  bool _stopOnLowBattery = false;
  bool _monoAudio = false;
  List<String> _hiddenTrackIds = [];
  String _selectedThemeAccent = 'spotify';
  String _selectedThemeMode = 'dark';
  String _customThemeBg = 'dynamic';
  String? _customThemeBgPath;
  double _customThemeBgBlur = 25.0;
  double _customThemeBgDim = 0.65;
  String _customThemeStyle = 'dark';
  String _playerBackgroundStyle = 'gradient';
  String? _playerCustomBgPath;
  double _playerCustomBgBlur = 0.0;
  double _playerCustomBgDim = 0.4;
  bool _autoCheckUpdates = true;
  String _libraryDensity = 'standard';
  bool _autoPlayOnConnect = false;
  double _playbackSpeed = 1.0;
  bool _pitchLock = true;
  double _lyricFontSize = 22.0;
  bool _lyricsHidePast = true;
  bool _lyricsAutoFollow = true;
  String _appVersion = 'Loading...';
  Future<List<SongModel>>? _songsFuture;

  Color get _activeAccentColor {
    if (_selectedThemeAccent == 'dynamic') {
      return dominantColorNotifier.value ?? const Color(0xFF8E8E93);
    }
    switch (_selectedThemeAccent) {
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

  @override
  void initState() {
    super.initState();
    _loadSettings();
    dominantColorNotifier.addListener(_onDominantColorChanged);
  }

  @override
  void dispose() {
    dominantColorNotifier.removeListener(_onDominantColorChanged);
    super.dispose();
  }

  void _onDominantColorChanged() {
    if (mounted && _selectedThemeAccent == 'dynamic') {
      setState(() {});
    }
  }

  Future<void> _checkForUpdates() async {
    showFleyToast(AppLocalizations.of(context).checkingUpdates);
    try {
      final client = HttpClient();
      client.userAgent = 'Fley-App';
      final request = await client.getUrl(
        Uri.parse('https://api.github.com/repos/coflyn/Fley/releases/latest'),
      );
      final response = await request.close();
      if (response.statusCode == 200) {
        final responseBody = await response.transform(utf8.decoder).join();
        final json = jsonDecode(responseBody) as Map<String, dynamic>;
        final String latestVersionTag = json['tag_name'] ?? 'v1.0.0';
        final String htmlUrl =
            json['html_url'] ?? 'https://github.com/coflyn/Fley/releases';

        final latestVersion = latestVersionTag.replaceAll('v', '').trim();

        final packageInfo = await PackageInfo.fromPlatform();
        final currentVersion = packageInfo.version;

        bool isNewer(String latest, String current) {
          try {
            final l = latest
                .split('.')
                .map((e) => int.tryParse(e) ?? 0)
                .toList();
            final c = current
                .split('.')
                .map((e) => int.tryParse(e) ?? 0)
                .toList();
            for (int i = 0; i < 3; i++) {
              final lp = i < l.length ? l[i] : 0;
              final cp = i < c.length ? c[i] : 0;
              if (lp > cp) return true;
              if (lp < cp) return false;
            }
          } catch (_) {}
          return false;
        }

        if (isNewer(latestVersion, currentVersion)) {
          if (!mounted) return;
          final isLight = isAppLight;
          showDialog(
            context: context,
            builder: (context) {
              return AlertDialog(
                backgroundColor: isLight
                    ? const Color(0xFFF0F0F3)
                    : const Color(0xFF161616),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
                title: Row(
                  children: [
                    Icon(
                      Icons.system_update_rounded,
                      color: _activeAccentColor,
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        AppLocalizations.of(context).updateAvailable,
                        style: TextStyle(
                          color: isLight
                              ? const Color(0xFF1A1A1A)
                              : Colors.white,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ],
                ),
                content: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      AppLocalizations.of(context).newVersionAvailable,
                      style: TextStyle(
                        color: isLight ? Colors.black87 : Colors.white70,
                      ),
                    ),
                    const SizedBox(height: 12),
                    Text(
                      '${AppLocalizations.of(context).currentVersion}: v$currentVersion\n${AppLocalizations.of(context).latestVersion}: $latestVersionTag',
                      style: TextStyle(
                        color: isLight ? Colors.black54 : Colors.white54,
                        fontFamily: 'monospace',
                      ),
                    ),
                  ],
                ),
                actions: [
                  TextButton(
                    onPressed: () => Navigator.pop(context),
                    child: Text(
                      AppLocalizations.of(context).later,
                      style: TextStyle(
                        color: isLight ? Colors.black54 : Colors.white54,
                      ),
                    ),
                  ),
                  TextButton(
                    onPressed: () async {
                      Navigator.pop(context);
                      final url = Uri.parse(htmlUrl);
                      try {
                        await launchUrl(
                          url,
                          mode: LaunchMode.externalApplication,
                        );
                      } catch (_) {
                        showFleyToast(
                          lookupAppLocalizations(
                            Locale(FleyStrings.currentLang),
                          ).couldNotOpenUpdate,
                        );
                      }
                    },
                    child: Text(
                      AppLocalizations.of(context).download,
                      style: TextStyle(
                        color: _activeAccentColor,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ],
              );
            },
          );
        } else {
          showFleyToast(
            '${lookupAppLocalizations(Locale(FleyStrings.currentLang)).fleyUpToDate} (v$currentVersion)',
          );
        }
      } else {
        showFleyToast(
          lookupAppLocalizations(
            Locale(FleyStrings.currentLang),
          ).unableCheckUpdates,
        );
      }
    } catch (_) {
      showFleyToast(
        lookupAppLocalizations(Locale(FleyStrings.currentLang)).networkError,
      );
    }
  }

  Future<void> _loadSettings() async {
    final prefs = await SharedPreferences.getInstance();
    bool monoAudio = prefs.getBool('monoAudio') ?? false;

    setState(() {
      _filterShortAudio = prefs.getBool('filterShortAudio') ?? false;
      _autoRegexClean = prefs.getBool('autoRegexClean') ?? false;
      _crossfadeDuration = prefs.getInt('crossfadeDuration') ?? 200;
      _pauseOnDisconnect = prefs.getBool('pauseOnDisconnect') ?? true;
      _autoPlayAfterCall = prefs.getBool('autoPlayAfterCall') ?? true;
      _playTogether = prefs.getBool('playTogether') ?? false;
      _playCountThreshold = prefs.getInt('playCountThreshold') ?? 10;
      _activeFont = prefs.getString('activeFont') ?? 'Plus Jakarta Sans';
      _fontScale = prefs.getDouble('fontScale') ?? 1.0;
      _language = prefs.getString('language') ?? 'en';
      _skipSilence = prefs.getBool('skipSilence') ?? false;
      _stopOnLowBattery = prefs.getBool('stopOnLowBattery') ?? false;
      _monoAudio = monoAudio;
      _hiddenTrackIds = prefs.getStringList('hidden_track_ids') ?? [];
      _selectedThemeAccent = prefs.getString('themeAccentPreset') ?? 'spotify';
      _selectedThemeMode = prefs.getString('themeMode') ?? 'dark';
      _customThemeBg = prefs.getString('customThemeBg') ?? 'dynamic';
      _customThemeBgPath = prefs.getString('customThemeBgPath');
      _customThemeBgBlur = prefs.getDouble('customThemeBgBlur') ?? 25.0;
      _customThemeBgDim = prefs.getDouble('customThemeBgDim') ?? 0.65;
      _customThemeStyle = prefs.getString('customThemeStyle') ?? 'dark';
      _playerBackgroundStyle =
          prefs.getString('playerBackgroundStyle') ?? 'gradient';
      _playerCustomBgPath = prefs.getString('playerCustomBgPath');
      _playerCustomBgBlur = prefs.getDouble('playerCustomBgBlur') ?? 0.0;
      _playerCustomBgDim = prefs.getDouble('playerCustomBgDim') ?? 0.4;
      _autoCheckUpdates = prefs.getBool('auto_check_updates') ?? true;
      _libraryDensity = prefs.getString('libraryDensity') ?? 'standard';
      _autoPlayOnConnect = prefs.getBool('autoPlayOnConnect') ?? false;
      _playbackSpeed = prefs.getDouble('playbackSpeed') ?? 1.0;
      _pitchLock = prefs.getBool('pitchLock') ?? true;
      _lyricFontSize = prefs.getDouble('lyricFontSize') ?? 18.0;
      _lyricsHidePast = prefs.getBool('lyricsHidePast') ?? true;
      _lyricsAutoFollow = prefs.getBool('lyricsAutoFollow') ?? true;
    });

    final packageInfo = await PackageInfo.fromPlatform();
    if (mounted) {
      setState(() {
        _appVersion = packageInfo.version;
      });
    }
  }

  Future<void> _saveBool(String key, bool value) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(key, value);
    widget
        .onSettingsChanged(); // Trigger reload of settings without full library rescan
  }

  Future<void> _saveInt(String key, int value) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(key, value);
    widget
        .onSettingsChanged(); // Trigger reload of settings without full library rescan
  }

  Future<void> _pickAndSaveImage({
    required String prefKey,
    required Function(String) onSave,
    required Function(String) onSetStatePath,
  }) async {
    final ImagePicker picker = ImagePicker();
    final XFile? image = await picker.pickImage(source: ImageSource.gallery);
    if (image != null) {
      if (!mounted) return;
      final croppedPath = await ImageCropperUtil.cropImage(
        context: context,
        sourcePath: image.path,
      );
      if (croppedPath != null) {
        final prefs = await SharedPreferences.getInstance();
        await prefs.setString(prefKey, croppedPath);
        onSetStatePath(croppedPath);
        onSave(croppedPath);
        showFleyToast(
          lookupAppLocalizations(
            Locale(FleyStrings.currentLang),
          ).wallpaperUpdated,
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final isLight = _selectedThemeMode == 'light';
    return Scaffold(
      backgroundColor: isLight
          ? const Color(0xFFF6F8FA)
          : const Color(0xFF0A0A0A),
      appBar: AppBar(
        backgroundColor: isLight
            ? const Color(0xFFF6F8FA)
            : const Color(0xFF0A0A0A),
        elevation: 0,
        scrolledUnderElevation: 0,
        surfaceTintColor: Colors.transparent,
        centerTitle: true,
        leading: IconButton(
          icon: Icon(
            Icons.arrow_back,
            color: isLight ? const Color(0xFF1A1A1A) : Colors.white,
          ),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(
          AppLocalizations.of(context).settings,
          style: TextStyle(
            fontWeight: FontWeight.w700,
            fontSize: 18,
            color: isLight ? const Color(0xFF1A1A1A) : Colors.white,
          ),
        ),
      ),
      body: ListView(
        physics: const BouncingScrollPhysics(),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        children: [
          SettingsSectionHeader(
            title: AppLocalizations.of(context).appearance,
            activeAccentColor: _activeAccentColor,
          ),
          SettingsPremiumCard(
            isLight: _selectedThemeMode == 'light',
            children: [
              SettingsPremiumListTile(
                isLight: _selectedThemeMode == 'light',
                activeAccentColor: _activeAccentColor,
                icon: Icons.language_rounded,
                title: AppLocalizations.of(context).language,
                subtitle: _language == 'id'
                    ? AppLocalizations.of(context).languageId
                    : _language == 'ja'
                    ? AppLocalizations.of(context).languageJa
                    : AppLocalizations.of(context).languageEn,
                onTap: () => _showLanguageSelectionDialog(),
              ),
              const Divider(color: Colors.white10, height: 1),
              SettingsPremiumListTile(
                isLight: _selectedThemeMode == 'light',
                activeAccentColor: _activeAccentColor,
                icon: Icons.font_download_outlined,
                title: AppLocalizations.of(context).typographyFontSize,
                subtitle:
                    '${_activeFont == 'Spotify Style'
                        ? 'Figtree'
                        : _activeFont == 'Apple Music Style'
                        ? 'Inter'
                        : 'Plus Jakarta Sans'} • ${_getFontSizeLabel(_fontScale)}',
                onTap: () => _showTypographyPreviewDialog(),
              ),
              const Divider(color: Colors.white10, height: 1),
              SettingsPremiumListTile(
                isLight: _selectedThemeMode == 'light',
                activeAccentColor: _activeAccentColor,
                icon: Icons.palette_outlined,
                title: AppLocalizations.of(context).themeAccentColor,
                subtitle: _getThemeAccentLabel(_selectedThemeAccent),
                onTap: () => _showThemeAccentSelectionDialog(),
              ),
              const Divider(color: Colors.white10, height: 1),
              SettingsPremiumListTile(
                isLight: _selectedThemeMode == 'light',
                activeAccentColor: _activeAccentColor,
                icon: Icons.density_medium_rounded,
                title: AppLocalizations.of(context).libraryDensity,
                subtitle: _libraryDensity == 'compact'
                    ? AppLocalizations.of(context).densityCompact
                    : AppLocalizations.of(context).densityStandard,
                onTap: () => _showLibraryDensityDialog(),
              ),
              const Divider(color: Colors.white10, height: 1),
              SettingsPremiumListTile(
                isLight: _selectedThemeMode == 'light',
                activeAccentColor: _activeAccentColor,
                icon: Icons.format_size_rounded,
                title: AppLocalizations.of(context).lyricFontSize,
                subtitle: '${_lyricFontSize.toInt()} sp',
                onTap: () => _showLyricFontSizeDialog(),
              ),
              const Divider(color: Colors.white10, height: 1),
              SettingsPremiumSwitchTile(
                isLight: _selectedThemeMode == 'light',
                activeAccentColor: _activeAccentColor,
                icon: Icons.compare_arrows_rounded,
                title: AppLocalizations.of(context).lyricsAutoFollow,
                subtitle: AppLocalizations.of(context).lyricsAutoFollowSubtitle,
                value: _lyricsAutoFollow,
                onChanged: (val) {
                  setState(() => _lyricsAutoFollow = val);
                  _saveBool('lyricsAutoFollow', val);
                },
              ),
              const Divider(color: Colors.white10, height: 1),
              SettingsPremiumSwitchTile(
                isLight: _selectedThemeMode == 'light',
                activeAccentColor: _activeAccentColor,
                icon: Icons.visibility_off_rounded,
                title: AppLocalizations.of(context).lyricsHidePast,
                subtitle: AppLocalizations.of(context).lyricsHidePastSubtitle,
                value: _lyricsHidePast,
                onChanged: (val) {
                  setState(() => _lyricsHidePast = val);
                  _saveBool('lyricsHidePast', val);
                },
              ),
              const Divider(color: Colors.white10, height: 1),
              SettingsPremiumListTile(
                isLight: _selectedThemeMode == 'light',
                activeAccentColor: _activeAccentColor,
                icon: _selectedThemeMode == 'light'
                    ? Icons.light_mode_outlined
                    : _selectedThemeMode == 'custom'
                    ? Icons.color_lens_outlined
                    : Icons.dark_mode_outlined,
                title: AppLocalizations.of(context).themeMode,
                subtitle: _getThemeModeLabel(_selectedThemeMode),
                onTap: () => _showThemeModeSelectionDialog(),
              ),
              if (_selectedThemeMode == 'custom') ...[
                const Divider(color: Colors.white10, height: 1),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 20,
                    vertical: 16,
                  ),
                  color: isLight
                      ? Colors.black.withValues(alpha: 0.01)
                      : Colors.white.withValues(alpha: 0.02),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        AppLocalizations.of(
                          context,
                        ).customThemeBg.toUpperCase(),
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w800,
                          color: isLight ? Colors.black54 : Colors.white54,
                          letterSpacing: 1.5,
                        ),
                      ),
                      const SizedBox(height: 12),
                      SizedBox(
                        height: 38,
                        child: ListView(
                          scrollDirection: Axis.horizontal,
                          physics: const BouncingScrollPhysics(),
                          children: [
                            _buildCustomBgOption(
                              id: 'dynamic',
                              name: 'Dynamic (Artwork)',
                              color:
                                  dominantColorNotifier.value ??
                                  const Color(0xFF8E8E93),
                            ),
                            const SizedBox(width: 10),
                            _buildCustomBgOption(
                              id: 'custom_image',
                              name: AppLocalizations.of(context).bgCustomImage,
                              color: const Color(0xFF8E8E93),
                            ),
                            const SizedBox(width: 10),
                            _buildCustomBgOption(
                              id: 'navy',
                              name: AppLocalizations.of(context).bgDeepNavy,
                              color: const Color(0xFF0B132B),
                            ),
                            const SizedBox(width: 10),
                            _buildCustomBgOption(
                              id: 'forest',
                              name: AppLocalizations.of(context).bgForestGreen,
                              color: const Color(0xFF0D1F1D),
                            ),
                            const SizedBox(width: 10),
                            _buildCustomBgOption(
                              id: 'wine',
                              name: AppLocalizations.of(context).bgMidnightWine,
                              color: const Color(0xFF1A0F1A),
                            ),
                            const SizedBox(width: 10),
                            _buildCustomBgOption(
                              id: 'terracotta',
                              name: AppLocalizations.of(
                                context,
                              ).bgSunsetTerracotta,
                              color: const Color(0xFF211510),
                            ),
                            const SizedBox(width: 10),
                            _buildCustomBgOption(
                              id: 'slate',
                              name: AppLocalizations.of(
                                context,
                              ).bgSlateGrayBlue,
                              color: const Color(0xFF1C2541),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ],
              if (_selectedThemeMode == 'custom' &&
                  _customThemeBg == 'custom_image') ...[
                const Divider(color: Colors.white10, height: 1),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 20,
                    vertical: 16,
                  ),
                  color: isLight
                      ? Colors.black.withValues(alpha: 0.01)
                      : Colors.white.withValues(alpha: 0.02),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            AppLocalizations.of(context).themeWallpaperSettings,
                            style: TextStyle(
                              color: _activeAccentColor,
                              fontWeight: FontWeight.bold,
                              fontSize: 13,
                              fontFamily: getFontFamily(_activeFont),
                            ),
                          ),
                          TextButton.icon(
                            style: TextButton.styleFrom(
                              padding: EdgeInsets.zero,
                              minimumSize: Size.zero,
                              tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                              foregroundColor: isLight
                                  ? Colors.black54
                                  : Colors.white70,
                            ),
                            icon: const Icon(
                              Icons.photo_library_outlined,
                              size: 14,
                            ),
                            label: Text(
                              AppLocalizations.of(context).changePhoto,
                              style: TextStyle(
                                fontSize: 12,
                                fontFamily: getFontFamily(_activeFont),
                              ),
                            ),
                            onPressed: () => _pickAndSaveImage(
                              prefKey: 'customThemeBgPath',
                              onSave: (path) => ref
                                  .read(settingsProvider.notifier)
                                  .updateSetting(customThemeBgPath: path),
                              onSetStatePath: (path) =>
                                  setState(() => _customThemeBgPath = path),
                            ),
                          ),
                        ],
                      ),
                      if (_customThemeBgPath != null &&
                          File(_customThemeBgPath!).existsSync()) ...[
                        const SizedBox(height: 12),
                        Builder(
                          builder: (context) {
                            bool isMockLight = false;
                            if (_customThemeStyle == 'light') {
                              isMockLight = true;
                            } else if (_customThemeStyle == 'dynamic') {
                              final activeCol =
                                  dominantColorNotifier.value ??
                                  const Color(0xFF8E8E93);
                              isMockLight = activeCol.computeLuminance() > 0.45;
                            }
                            return Center(
                              child: Container(
                                width: 144,
                                height: 256,
                                decoration: BoxDecoration(
                                  color: isMockLight
                                      ? Colors.white
                                      : const Color(0xFF0A0A0A),
                                  borderRadius: BorderRadius.circular(16),
                                  border: Border.all(
                                    color: isMockLight
                                        ? Colors.black12
                                        : Colors.white10,
                                    width: 1.5,
                                  ),
                                  boxShadow: [
                                    BoxShadow(
                                      color: Colors.black.withValues(
                                        alpha: 0.3,
                                      ),
                                      blurRadius: 10,
                                      offset: const Offset(0, 4),
                                    ),
                                  ],
                                ),
                                child: ClipRRect(
                                  borderRadius: BorderRadius.circular(14),
                                  child: Stack(
                                    children: [
                                      // Live blurred custom background image preview
                                      Positioned.fill(
                                        child: ClipRect(
                                          child: ImageFiltered(
                                            imageFilter: ImageFilter.blur(
                                              sigmaX: _customThemeBgBlur / 2.0,
                                              sigmaY: _customThemeBgBlur / 2.0,
                                            ),
                                            child: Image.file(
                                              File(_customThemeBgPath!),
                                              fit: BoxFit.cover,
                                            ),
                                          ),
                                        ),
                                      ),
                                      // Theme dimming overlay
                                      Positioned.fill(
                                        child: Container(
                                          color: isMockLight
                                              ? Colors.white.withValues(
                                                  alpha: 0.15,
                                                )
                                              : Colors.black.withValues(
                                                  alpha: _customThemeBgDim,
                                                ),
                                        ),
                                      ),
                                      Padding(
                                        padding: const EdgeInsets.all(10),
                                        child: Column(
                                          crossAxisAlignment:
                                              CrossAxisAlignment.start,
                                          children: [
                                            const SizedBox(height: 4),
                                            Container(
                                              width: 45,
                                              height: 8,
                                              decoration: BoxDecoration(
                                                color: isMockLight
                                                    ? const Color(0xFF1A1A1A)
                                                    : Colors.white,
                                                borderRadius:
                                                    BorderRadius.circular(2),
                                              ),
                                            ),
                                            const SizedBox(height: 12),
                                            Container(
                                              height: 14,
                                              decoration: BoxDecoration(
                                                color: isMockLight
                                                    ? Colors.black.withValues(
                                                        alpha: 0.06,
                                                      )
                                                    : Colors.white10,
                                                borderRadius:
                                                    BorderRadius.circular(4),
                                              ),
                                              child: Row(
                                                children: [
                                                  const SizedBox(width: 4),
                                                  Icon(
                                                    Icons.search,
                                                    size: 8,
                                                    color: isMockLight
                                                        ? Colors.black38
                                                        : Colors.white38,
                                                  ),
                                                  const SizedBox(width: 4),
                                                  Container(
                                                    width: 50,
                                                    height: 4,
                                                    decoration: BoxDecoration(
                                                      color: isMockLight
                                                          ? Colors.black26
                                                          : Colors.white24,
                                                      borderRadius:
                                                          BorderRadius.circular(
                                                            1,
                                                          ),
                                                    ),
                                                  ),
                                                ],
                                              ),
                                            ),
                                            const SizedBox(height: 16),
                                            for (int i = 0; i < 3; i++) ...[
                                              Row(
                                                children: [
                                                  Container(
                                                    width: 16,
                                                    height: 16,
                                                    decoration: BoxDecoration(
                                                      color: _activeAccentColor
                                                          .withValues(
                                                            alpha: 0.2,
                                                          ),
                                                      borderRadius:
                                                          BorderRadius.circular(
                                                            3,
                                                          ),
                                                    ),
                                                    child: Icon(
                                                      Icons.music_note,
                                                      size: 9,
                                                      color: _activeAccentColor,
                                                    ),
                                                  ),
                                                  const SizedBox(width: 6),
                                                  Column(
                                                    crossAxisAlignment:
                                                        CrossAxisAlignment
                                                            .start,
                                                    children: [
                                                      Container(
                                                        width: 38,
                                                        height: 4,
                                                        decoration: BoxDecoration(
                                                          color: isMockLight
                                                              ? const Color(
                                                                  0xFF1A1A1A,
                                                                )
                                                              : Colors.white,
                                                          borderRadius:
                                                              BorderRadius.circular(
                                                                1,
                                                              ),
                                                        ),
                                                      ),
                                                      const SizedBox(height: 3),
                                                      Container(
                                                        width: 25,
                                                        height: 3,
                                                        decoration: BoxDecoration(
                                                          color: isMockLight
                                                              ? Colors.black45
                                                              : Colors.white38,
                                                          borderRadius:
                                                              BorderRadius.circular(
                                                                1,
                                                              ),
                                                        ),
                                                      ),
                                                    ],
                                                  ),
                                                ],
                                              ),
                                              const SizedBox(height: 10),
                                            ],
                                          ],
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            );
                          },
                        ),
                        const SizedBox(height: 16),

                        Row(
                          children: [
                            Expanded(child: _buildStylePill('dark', 'Dark')),
                            const SizedBox(width: 8),
                            Expanded(child: _buildStylePill('light', 'Light')),
                            const SizedBox(width: 8),
                            Expanded(
                              child: _buildStylePill('dynamic', 'Dynamic'),
                            ),
                          ],
                        ),
                        const SizedBox(height: 16),
                        // Blur Slider
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              AppLocalizations.of(context).blurLevel,
                              style: TextStyle(
                                color: isLight
                                    ? Colors.black54
                                    : Colors.white70,
                                fontSize: 13,
                                fontFamily: getFontFamily(_activeFont),
                              ),
                            ),
                            Text(
                              '${_customThemeBgBlur.round()}',
                              style: TextStyle(
                                color: isLight
                                    ? Colors.black38
                                    : Colors.white38,
                                fontSize: 13,
                                fontFamily: getFontFamily(_activeFont),
                              ),
                            ),
                          ],
                        ),
                        Slider(
                          value: _customThemeBgBlur,
                          min: 0.0,
                          max: 60.0,
                          activeColor: _activeAccentColor,
                          inactiveColor: isLight
                              ? Colors.black.withValues(alpha: 0.08)
                              : Colors.white10,
                          onChanged: (val) {
                            setState(() {
                              _customThemeBgBlur = val;
                            });
                            ref
                                .read(settingsProvider.notifier)
                                .updateSetting(customThemeBgBlur: val);
                          },
                        ),
                        // Dim Level (Opacity)
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              AppLocalizations.of(context).dimLevel,
                              style: TextStyle(
                                color: isLight
                                    ? Colors.black54
                                    : Colors.white70,
                                fontSize: 13,
                                fontFamily: getFontFamily(_activeFont),
                              ),
                            ),
                            Text(
                              '${(_customThemeBgDim * 100).round()}%',
                              style: TextStyle(
                                color: isLight
                                    ? Colors.black38
                                    : Colors.white38,
                                fontSize: 13,
                                fontFamily: getFontFamily(_activeFont),
                              ),
                            ),
                          ],
                        ),
                        Slider(
                          value: _customThemeBgDim,
                          min: 0.0,
                          max: 0.90,
                          activeColor: _activeAccentColor,
                          inactiveColor: isLight
                              ? Colors.black.withValues(alpha: 0.08)
                              : Colors.white10,
                          onChanged: (val) {
                            setState(() {
                              _customThemeBgDim = val;
                            });
                            ref
                                .read(settingsProvider.notifier)
                                .updateSetting(customThemeBgDim: val);
                          },
                        ),
                      ] else ...[
                        const SizedBox(height: 12),
                        Center(
                          child: Text(
                            AppLocalizations.of(context).noWallpaper,
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              color: isLight ? Colors.black54 : Colors.white54,
                              fontSize: 12,
                              fontFamily: getFontFamily(_activeFont),
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              ],
              const Divider(color: Colors.white10, height: 1),
              SettingsPremiumListTile(
                isLight: _selectedThemeMode == 'light',
                activeAccentColor: _activeAccentColor,
                icon: Icons.wallpaper_outlined,
                title: AppLocalizations.of(context).playerBackground,
                subtitle: _getPlayerBackgroundStyleLabel(
                  _playerBackgroundStyle,
                ),
                onTap: () => _showPlayerBackgroundStyleDialog(),
              ),
              if (_playerBackgroundStyle == 'custom') ...[
                const Divider(color: Colors.white10, height: 1),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 20,
                    vertical: 16,
                  ),
                  color: isLight
                      ? Colors.black.withValues(alpha: 0.01)
                      : Colors.white.withValues(alpha: 0.02),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            AppLocalizations.of(context).wallpaperSettings,
                            style: TextStyle(
                              color: _activeAccentColor,
                              fontWeight: FontWeight.bold,
                              fontSize: 13,
                              fontFamily: getFontFamily(_activeFont),
                            ),
                          ),
                          TextButton.icon(
                            style: TextButton.styleFrom(
                              padding: EdgeInsets.zero,
                              minimumSize: Size.zero,
                              tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                              foregroundColor: isLight
                                  ? Colors.black54
                                  : Colors.white70,
                            ),
                            icon: const Icon(
                              Icons.photo_library_outlined,
                              size: 14,
                            ),
                            label: Text(
                              AppLocalizations.of(context).changePhoto,
                              style: TextStyle(
                                fontSize: 12,
                                fontFamily: getFontFamily(_activeFont),
                              ),
                            ),
                            onPressed: () => _pickAndSaveImage(
                              prefKey: 'playerCustomBgPath',
                              onSave: (path) => ref
                                  .read(settingsProvider.notifier)
                                  .updateSetting(playerCustomBgPath: path),
                              onSetStatePath: (path) =>
                                  setState(() => _playerCustomBgPath = path),
                            ),
                          ),
                        ],
                      ),
                      if (_playerCustomBgPath != null &&
                          File(_playerCustomBgPath!).existsSync()) ...[
                        const SizedBox(height: 12),
                        Center(
                          child: Container(
                            width: 144,
                            height: 256,
                            decoration: BoxDecoration(
                              color: const Color(0xFF0A0A0A),
                              borderRadius: BorderRadius.circular(16),
                              border: Border.all(
                                color: Colors.white10,
                                width: 1.5,
                              ),
                              boxShadow: [
                                BoxShadow(
                                  color: Colors.black.withValues(alpha: 0.5),
                                  blurRadius: 10,
                                  offset: const Offset(0, 4),
                                ),
                              ],
                            ),
                            child: ClipRRect(
                              borderRadius: BorderRadius.circular(14),
                              child: Stack(
                                children: [
                                  // Live blurred, scaled custom background image preview
                                  Positioned.fill(
                                    child: ClipRect(
                                      child: ImageFiltered(
                                        imageFilter: ImageFilter.blur(
                                          sigmaX: _playerCustomBgBlur,
                                          sigmaY: _playerCustomBgBlur,
                                        ),
                                        child: Image.file(
                                          File(_playerCustomBgPath!),
                                          fit: BoxFit.cover,
                                        ),
                                      ),
                                    ),
                                  ),
                                  // Real-time custom dimming overlay
                                  Positioned.fill(
                                    child: Container(
                                      color: Colors.black.withValues(
                                        alpha: _playerCustomBgDim,
                                      ),
                                    ),
                                  ),
                                  Padding(
                                    padding: const EdgeInsets.symmetric(
                                      vertical: 24,
                                      horizontal: 16,
                                    ),
                                    child: Column(
                                      mainAxisAlignment: MainAxisAlignment.end,
                                      children: [
                                        Container(
                                          width: 90,
                                          height: 90,
                                          decoration: BoxDecoration(
                                            color: Colors.white10,
                                            borderRadius: BorderRadius.circular(
                                              8,
                                            ),
                                            border: Border.all(
                                              color: Colors.white24,
                                              width: 0.5,
                                            ),
                                            boxShadow: [
                                              BoxShadow(
                                                color: Colors.black.withValues(
                                                  alpha: 0.2,
                                                ),
                                                blurRadius: 10,
                                                offset: const Offset(0, 4),
                                              ),
                                            ],
                                          ),
                                          child: const Icon(
                                            Icons.music_note,
                                            color: Colors.white54,
                                            size: 24,
                                          ),
                                        ),
                                        const Spacer(),
                                        Container(
                                          width: 80,
                                          height: 6,
                                          decoration: BoxDecoration(
                                            color: Colors.white,
                                            borderRadius: BorderRadius.circular(
                                              3,
                                            ),
                                          ),
                                        ),
                                        const SizedBox(height: 6),
                                        Container(
                                          width: 50,
                                          height: 4,
                                          decoration: BoxDecoration(
                                            color: Colors.white54,
                                            borderRadius: BorderRadius.circular(
                                              2,
                                            ),
                                          ),
                                        ),
                                        const SizedBox(height: 16),
                                        Container(
                                          width: double.infinity,
                                          height: 2,
                                          color: Colors.white30,
                                          child: Align(
                                            alignment: Alignment.centerLeft,
                                            child: Container(
                                              width: 40,
                                              color: Colors.white,
                                            ),
                                          ),
                                        ),
                                        const SizedBox(height: 16),
                                        const Row(
                                          mainAxisAlignment:
                                              MainAxisAlignment.spaceEvenly,
                                          children: [
                                            Icon(
                                              Icons.skip_previous,
                                              color: Colors.white70,
                                              size: 16,
                                              shadows: [
                                                Shadow(
                                                  color: Colors.black54,
                                                  blurRadius: 4,
                                                ),
                                              ],
                                            ),
                                            Icon(
                                              Icons.play_circle_fill,
                                              color: Colors.white,
                                              size: 32,
                                              shadows: [
                                                Shadow(
                                                  color: Colors.black54,
                                                  blurRadius: 4,
                                                ),
                                              ],
                                            ),
                                            Icon(
                                              Icons.skip_next,
                                              color: Colors.white70,
                                              size: 16,
                                              shadows: [
                                                Shadow(
                                                  color: Colors.black54,
                                                  blurRadius: 4,
                                                ),
                                              ],
                                            ),
                                          ],
                                        ),
                                      ],
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                      ],
                      const SizedBox(height: 16),
                      // Blur Slider
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            AppLocalizations.of(context).blurLevel,
                            style: TextStyle(
                              color: isLight ? Colors.black54 : Colors.white70,
                              fontSize: 13,
                            ),
                          ),
                          Text(
                            '${_playerCustomBgBlur.round()}',
                            style: TextStyle(
                              color: isLight ? Colors.black38 : Colors.white38,
                              fontSize: 13,
                            ),
                          ),
                        ],
                      ),
                      Slider(
                        value: _playerCustomBgBlur,
                        min: 0.0,
                        max: 60.0,
                        activeColor: _activeAccentColor,
                        inactiveColor: isLight
                            ? Colors.black.withValues(alpha: 0.08)
                            : Colors.white10,
                        onChanged: (val) {
                          setState(() {
                            _playerCustomBgBlur = val;
                          });
                          ref
                              .read(settingsProvider.notifier)
                              .updateSetting(playerCustomBgBlur: val);
                        },
                      ),
                      // Dim Level (Opacity)
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            AppLocalizations.of(context).dimLevel,
                            style: TextStyle(
                              color: isLight ? Colors.black54 : Colors.white70,
                              fontSize: 13,
                            ),
                          ),
                          Text(
                            '${(_playerCustomBgDim * 100).round()}%',
                            style: TextStyle(
                              color: isLight ? Colors.black38 : Colors.white38,
                              fontSize: 13,
                            ),
                          ),
                        ],
                      ),
                      Slider(
                        value: _playerCustomBgDim,
                        min: 0.0,
                        max: 0.90,
                        activeColor: _activeAccentColor,
                        inactiveColor: isLight
                            ? Colors.black.withValues(alpha: 0.08)
                            : Colors.white10,
                        onChanged: (val) {
                          setState(() {
                            _playerCustomBgDim = val;
                          });
                          ref
                              .read(settingsProvider.notifier)
                              .updateSetting(playerCustomBgDim: val);
                        },
                      ),
                    ],
                  ),
                ),
              ],
            ],
          ),
          SettingsSectionHeader(
            title: AppLocalizations.of(context).audioPlayback,
            activeAccentColor: _activeAccentColor,
          ),
          SettingsPremiumCard(
            isLight: _selectedThemeMode == 'light',
            children: [
              ValueListenableBuilder<int>(
                valueListenable: widget.sleepTimerNotifier,
                builder: (context, remaining, child) {
                  final isActive = remaining > 0;
                  final mins = (remaining / 60).floor().toString().padLeft(
                    2,
                    '0',
                  );
                  final secs = (remaining % 60).toString().padLeft(2, '0');
                  return SettingsPremiumListTile(
                    isLight: _selectedThemeMode == 'light',
                    activeAccentColor: _activeAccentColor,
                    icon: Icons.timer_outlined,
                    title: AppLocalizations.of(context).sleepTimer,
                    subtitle: isActive
                        ? '${AppLocalizations.of(context).stopsIn} $mins:$secs'
                        : AppLocalizations.of(context).sleepTimerSubtitle,
                    isActive: isActive,
                    trailing: isActive
                        ? IconButton(
                            icon: const Icon(
                              Icons.close,
                              color: Colors.white54,
                            ),
                            onPressed: () => widget.onSetSleepTimer(0),
                          )
                        : const Icon(
                            Icons.chevron_right,
                            color: Colors.white24,
                          ),
                    onTap: () => _showSleepTimerDialog(),
                  );
                },
              ),
              SettingsPremiumListTile(
                isLight: _selectedThemeMode == 'light',
                activeAccentColor: _activeAccentColor,
                icon: Icons.compare_arrows_rounded,
                title: AppLocalizations.of(context).audioCrossfade,
                subtitle: '${_crossfadeDuration}ms',
                trailing: SizedBox(
                  width: 140,
                  child: SliderTheme(
                    data: SliderTheme.of(context).copyWith(
                      trackHeight: 4,
                      thumbShape: const RoundSliderThumbShape(
                        enabledThumbRadius: 6,
                      ),
                      overlayShape: const RoundSliderOverlayShape(
                        overlayRadius: 14,
                      ),
                    ),
                    child: Slider(
                      value: _crossfadeDuration.toDouble().clamp(200.0, 3000.0),
                      min: 200,
                      max: 3000,
                      divisions: 28,
                      activeColor: _activeAccentColor,
                      inactiveColor: Colors.white10,
                      onChanged: (val) {
                        setState(() {
                          _crossfadeDuration = val.toInt();
                        });
                      },
                      onChangeEnd: (val) {
                        _saveInt('crossfadeDuration', val.toInt());
                      },
                    ),
                  ),
                ),
              ),
              SettingsPremiumSwitchTile(
                isLight: _selectedThemeMode == 'light',
                activeAccentColor: _activeAccentColor,
                icon: Icons.headset_off_outlined,
                title: AppLocalizations.of(context).pauseOnDisconnect,
                subtitle: AppLocalizations.of(
                  context,
                ).pauseOnDisconnectSubtitle,
                value: _pauseOnDisconnect,
                onChanged: (val) {
                  setState(() => _pauseOnDisconnect = val);
                  _saveBool('pauseOnDisconnect', val);
                },
              ),
              SettingsPremiumSwitchTile(
                isLight: _selectedThemeMode == 'light',
                activeAccentColor: _activeAccentColor,
                icon: Icons.headset_mic_outlined,
                title: AppLocalizations.of(context).autoPlayOnConnect,
                subtitle: AppLocalizations.of(
                  context,
                ).autoPlayOnConnectSubtitle,
                value: _autoPlayOnConnect,
                onChanged: (val) {
                  setState(() => _autoPlayOnConnect = val);
                  _saveBool('autoPlayOnConnect', val);
                },
              ),
              SettingsPremiumListTile(
                isLight: _selectedThemeMode == 'light',
                activeAccentColor: _activeAccentColor,
                icon: Icons.speed_rounded,
                title: AppLocalizations.of(context).playbackSpeed,
                subtitle:
                    '${_playbackSpeed}x${_pitchLock ? ' • ${AppLocalizations.of(context).pitchLock}' : ''}',
                onTap: () => _showPlaybackSpeedDialog(),
              ),
              SettingsPremiumSwitchTile(
                isLight: _selectedThemeMode == 'light',
                activeAccentColor: _activeAccentColor,
                icon: Icons.call_missed_outgoing_rounded,
                title: AppLocalizations.of(context).resumeAfterCall,
                subtitle: AppLocalizations.of(context).resumeAfterCallSubtitle,
                value: _autoPlayAfterCall,
                onChanged: (val) {
                  setState(() => _autoPlayAfterCall = val);
                  _saveBool('autoPlayAfterCall', val);
                },
              ),
              SettingsPremiumSwitchTile(
                isLight: _selectedThemeMode == 'light',
                activeAccentColor: _activeAccentColor,
                icon: Icons.layers_rounded,
                title: AppLocalizations.of(context).playTogether,
                subtitle: AppLocalizations.of(context).playTogetherSubtitle,
                value: _playTogether,
                onChanged: (val) {
                  setState(() => _playTogether = val);
                  _saveBool('playTogether', val);
                  configureAudioSession(val); // Reconfigure dynamically
                },
              ),
              SettingsPremiumSwitchTile(
                isLight: _selectedThemeMode == 'light',
                activeAccentColor: _activeAccentColor,
                icon: Icons.content_cut_rounded,
                title: AppLocalizations.of(context).silenceTrimmer,
                subtitle: AppLocalizations.of(context).silenceTrimmerSubtitle,
                value: _skipSilence,
                onChanged: (val) {
                  setState(() => _skipSilence = val);
                  _saveBool('skipSilence', val);
                  widget.onSetSkipSilence(val);
                  showFleyToast(
                    val
                        ? AppLocalizations.of(context).silenceEnabledToast
                        : AppLocalizations.of(context).silenceDisabledToast,
                  );
                },
              ),
              SettingsPremiumSwitchTile(
                isLight: _selectedThemeMode == 'light',
                activeAccentColor: _activeAccentColor,
                icon: Icons.battery_saver_rounded,
                title: AppLocalizations.of(context).stopOnLowBattery,
                subtitle: AppLocalizations.of(context).stopOnLowBatterySubtitle,
                value: _stopOnLowBattery,
                onChanged: (val) {
                  setState(() => _stopOnLowBattery = val);
                  _saveBool('stopOnLowBattery', val);
                },
              ),
              SettingsPremiumSwitchTile(
                isLight: _selectedThemeMode == 'light',
                activeAccentColor: _activeAccentColor,
                icon: Icons.hearing_rounded,
                title: AppLocalizations.of(context).monoAudio,
                subtitle: AppLocalizations.of(context).monoAudioSubtitle,
                value: _monoAudio,
                onChanged: (val) async {
                  setState(() => _monoAudio = val);
                  await _saveBool('monoAudio', val);
                  try {
                    const channel = MethodChannel('com.fley.audio/equalizer');
                    await channel.invokeMethod('toggleMonoAudio', {
                      'enable': val,
                    });
                  } catch (e) {
                    if (e is PlatformException &&
                        e.code == 'PERMISSION_DENIED') {
                      showFleyToast(
                        lookupAppLocalizations(
                          Locale(FleyStrings.currentLang),
                        ).monoAudioPermission,
                        isLong: true,
                      );
                    }
                  }
                },
              ),
              SettingsPremiumListTile(
                isLight: _selectedThemeMode == 'light',
                activeAccentColor: _activeAccentColor,
                icon: Icons.equalizer_rounded,
                title: AppLocalizations.of(context).equalizer,
                subtitle: AppLocalizations.of(context).equalizerSubtitle,
                onTap: () {
                  MainScreen.showEqualizer(context);
                },
              ),
              SettingsPremiumListTile(
                isLight: _selectedThemeMode == 'light',
                activeAccentColor: _activeAccentColor,
                icon: Icons.bar_chart_rounded,
                title: AppLocalizations.of(context).mostPlayedThreshold,
                subtitle: _getThresholdLabel(_playCountThreshold),
                onTap: () => _showThresholdDialog(),
              ),
            ],
          ),
          SettingsSectionHeader(
            title: AppLocalizations.of(context).libraryStorage,
            activeAccentColor: _activeAccentColor,
          ),
          SettingsPremiumCard(
            isLight: _selectedThemeMode == 'light',
            children: [
              SettingsPremiumSwitchTile(
                isLight: _selectedThemeMode == 'light',
                activeAccentColor: _activeAccentColor,
                icon: Icons.auto_fix_high,
                title: AppLocalizations.of(context).autoRegexCleaner,
                subtitle: AppLocalizations.of(context).autoRegexSubtitle,
                value: _autoRegexClean,
                onChanged: (val) {
                  setState(() => _autoRegexClean = val);
                  _saveBool('autoRegexClean', val);
                  if (val) {
                    showFleyToast(
                      AppLocalizations.of(context).rescanToApply,
                      isLong: true,
                    );
                  }
                },
              ),
              SettingsPremiumSwitchTile(
                isLight: _selectedThemeMode == 'light',
                activeAccentColor: _activeAccentColor,
                icon: Icons.filter_alt_outlined,
                title: AppLocalizations.of(context).filterShortAudio,
                subtitle: AppLocalizations.of(context).filterShortSubtitle,
                value: _filterShortAudio,
                onChanged: (val) {
                  setState(() => _filterShortAudio = val);
                  _saveBool('filterShortAudio', val);
                  widget.onRescanLibrary(); // Needs immediate rescan to filter
                },
              ),
              SettingsPremiumListTile(
                isLight: _selectedThemeMode == 'light',
                activeAccentColor: _activeAccentColor,
                icon: Icons.folder_outlined,
                title: AppLocalizations.of(context).specificFolderScan,
                subtitle: AppLocalizations.of(context).specificFolderSubtitle,
                onTap: () {
                  widget.onManageFolders();
                },
              ),
              SettingsPremiumListTile(
                isLight: _selectedThemeMode == 'light',
                activeAccentColor: _activeAccentColor,
                icon: Icons.visibility_off_outlined,
                title: AppLocalizations.of(context).hiddenTracks,
                subtitle: AppLocalizations.of(context).hiddenTracksSubtitle,
                onTap: () async {
                  _songsFuture = OnAudioQuery().querySongs(
                    sortType: SongSortType.TITLE,
                    orderType: OrderType.ASC_OR_SMALLER,
                    uriType: UriType.EXTERNAL,
                    ignoreCase: true,
                  );
                  await _showHiddenTracksSheet(context);
                  _songsFuture = null;
                },
              ),
              SettingsPremiumListTile(
                isLight: _selectedThemeMode == 'light',
                activeAccentColor: _activeAccentColor,
                icon: Icons.sync_rounded,
                title: AppLocalizations.of(context).rescanLibrary,
                subtitle: AppLocalizations.of(context).rescanSubtitle,
                onTap: () {
                  Navigator.pop(context);
                  widget.onRescanLibrary();
                },
              ),
              SettingsPremiumListTile(
                isLight: _selectedThemeMode == 'light',
                activeAccentColor: _activeAccentColor,
                icon: Icons.cleaning_services_outlined,
                title: AppLocalizations.of(context).clearImageCache,
                subtitle: AppLocalizations.of(context).clearCacheSubtitle,
                onTap: () {
                  PaintingBinding.instance.imageCache.clear();
                  PaintingBinding.instance.imageCache.clearLiveImages();
                  showFleyToast(AppLocalizations.of(context).imageCacheCleared);
                },
              ),
              SettingsPremiumListTile(
                isLight: _selectedThemeMode == 'light',
                activeAccentColor: _activeAccentColor,
                icon: Icons.backup_outlined,
                title: AppLocalizations.of(context).backupData,
                subtitle: AppLocalizations.of(context).backupDataSubtitle,
                onTap: () => _handleBackup(),
              ),
              SettingsPremiumListTile(
                isLight: _selectedThemeMode == 'light',
                activeAccentColor: _activeAccentColor,
                icon: Icons.restore_outlined,
                title: AppLocalizations.of(context).restoreData,
                subtitle: AppLocalizations.of(context).restoreDataSubtitle,
                onTap: () => _handleRestore(),
              ),
              SettingsPremiumListTile(
                isLight: _selectedThemeMode == 'light',
                activeAccentColor: _activeAccentColor,
                icon: Icons.delete_forever_outlined,
                title: AppLocalizations.of(context).resetAppData,
                subtitle: AppLocalizations.of(context).resetDataSubtitle,
                titleColor: Colors.redAccent,
                iconColor: Colors.redAccent,
                onTap: () => _showResetConfirmation(),
              ),
            ],
          ),
          SettingsSectionHeader(
            title: AppLocalizations.of(context).aboutFley,
            activeAccentColor: _activeAccentColor,
          ),
          SettingsPremiumCard(
            isLight: _selectedThemeMode == 'light',
            children: [
              SettingsPremiumListTile(
                isLight: _selectedThemeMode == 'light',
                activeAccentColor: _activeAccentColor,
                icon: Icons.update_rounded,
                title: AppLocalizations.of(context).checkUpdates,
                subtitle: 'Version $_appVersion',
                onTap: () => _checkForUpdates(),
              ),
              SettingsPremiumSwitchTile(
                isLight: _selectedThemeMode == 'light',
                activeAccentColor: _activeAccentColor,
                icon: Icons.autorenew_rounded,
                title: AppLocalizations.of(context).autoCheckUpdates,
                subtitle: AppLocalizations.of(context).autoCheckUpdatesSubtitle,
                value: _autoCheckUpdates,
                onChanged: (value) async {
                  setState(() => _autoCheckUpdates = value);
                  final prefs = await SharedPreferences.getInstance();
                  await prefs.setBool('auto_check_updates', value);
                },
              ),
              SettingsPremiumListTile(
                isLight: _selectedThemeMode == 'light',
                activeAccentColor: _activeAccentColor,
                icon: Icons.code_rounded,
                title: AppLocalizations.of(context).sourceCode,
                subtitle: AppLocalizations.of(context).githubRepo,
                trailing: const Icon(
                  Icons.open_in_new,
                  color: Colors.white24,
                  size: 18,
                ),
                onTap: () async {
                  final url = Uri.parse('https://github.com/coflyn/Fley');
                  try {
                    final launched = await launchUrl(
                      url,
                      mode: LaunchMode.externalApplication,
                    );
                    if (!launched) {
                      showFleyToast(
                        lookupAppLocalizations(
                          Locale(FleyStrings.currentLang),
                        ).couldNotOpenLink,
                      );
                    }
                  } catch (e) {
                    showFleyToast(
                      lookupAppLocalizations(
                        Locale(FleyStrings.currentLang),
                      ).couldNotOpenLink,
                    );
                  }
                },
              ),
              SettingsPremiumListTile(
                isLight: _selectedThemeMode == 'light',
                activeAccentColor: _activeAccentColor,
                icon: Icons.favorite_rounded,
                iconColor: const Color(0xFFE91E63),
                title: AppLocalizations.of(context).supportDeveloper,
                subtitle: AppLocalizations.of(context).donateSociabuzz,
                trailing: const Icon(
                  Icons.open_in_new,
                  color: Colors.white24,
                  size: 18,
                ),
                onTap: () async {
                  final url = Uri.parse('https://sociabuzz.com/coflyn');
                  try {
                    final launched = await launchUrl(
                      url,
                      mode: LaunchMode.externalApplication,
                    );
                    if (!launched) {
                      showFleyToast(
                        lookupAppLocalizations(
                          Locale(FleyStrings.currentLang),
                        ).couldNotOpenLink,
                      );
                    }
                  } catch (e) {
                    showFleyToast(
                      lookupAppLocalizations(
                        Locale(FleyStrings.currentLang),
                      ).couldNotOpenLink,
                    );
                  }
                },
              ),
            ],
          ),
          const SizedBox(height: 20),
        ],
      ),
    );
  }
}
