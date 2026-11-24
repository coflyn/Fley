// ignore_for_file: depend_on_referenced_packages, deprecated_member_use, unused_field
import 'dart:ui';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'dart:async';
import 'package:flutter/services.dart';
import 'package:just_audio/just_audio.dart';
import 'package:audio_session/audio_session.dart';
import 'package:audio_service/audio_service.dart';
import 'package:on_audio_query/on_audio_query.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:mini_music_visualizer/mini_music_visualizer.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:convert';
import 'dart:io';
import 'package:palette_generator/palette_generator.dart';
import 'package:image_picker/image_picker.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:path_provider/path_provider.dart';
import 'package:file_selector/file_selector.dart';

import 'models/track.dart';
import 'models/lyrics_line.dart';
import 'widgets/custom_track_shape.dart';

import 'package:window_manager/window_manager.dart';
import 'services/desktop_audio_scanner.dart';
import 'ui/desktop/desktop_layout_shell.dart';
import 'screens/settings_screen.dart';
import 'screens/profile_screen.dart';
import 'ui/animated_splash_screen.dart';
import 'utils/globals.dart';
import 'utils/artwork_cache.dart';
import 'utils/image_cropper_util.dart';
import 'services/ytmusic_service.dart';
import 'services/yt_player_service.dart';
import 'services/download_service.dart';
import 'services/playlist_import_service.dart';
import 'screens/ytmusic_auth_screen.dart';
import 'package:fley/l10n/app_localizations.dart';
part 'ui/player_ui.dart';
part 'ui/detail_views_ui.dart';
part 'ui/tabs_ui.dart';
part 'ui/track_options_ui.dart';
part 'ui/edit_metadata_ui.dart';
part 'ui/sort_ui.dart';
part 'ui/sort_modal_ui.dart';
part 'ui/detail_sort_ui.dart';
part 'ui/song_info_ui.dart';
part 'ui/cover_picker_ui.dart';
part 'ui/song_cover_picker_ui.dart';
part 'ui/ringtone_cutter_ui.dart';
part 'ui/playlist_edit_songs_ui.dart';
part 'ui/playlist_manage_ui.dart';
part 'ui/sleep_timer_ui.dart';
part 'ui/folder_scan_ui.dart';
part 'ui/downloads_sheet_ui.dart';
part 'ui/modals_utility_ui.dart';
part 'ui/equalizer_sheet_ui.dart';
part 'services/audio_handler.dart';
part 'ui/main_ui_components.dart';
part 'ui/bottom_nav_ui.dart';
part 'ui/home_ui.dart';
part 'logic/audio_settings_logic.dart';
part 'logic/audio_streams_logic.dart';
part 'logic/audio_equalizer_logic.dart';
part 'logic/audio_library_scan_logic.dart';
part 'logic/audio_playback_logic.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  final isDesktop = Platform.isMacOS || Platform.isWindows || Platform.isLinux;
  if (isDesktop) {
    try {
      await windowManager.ensureInitialized();
      const windowOptions = WindowOptions(
        size: Size(1100, 720),
        minimumSize: Size(850, 600),
        center: true,
        backgroundColor: Colors.transparent,
        skipTaskbar: false,
        titleBarStyle: TitleBarStyle.hidden,
        title: 'Fley',
      );
      await windowManager.waitUntilReadyToShow(windowOptions, () async {
        await windowManager.show();
        await windowManager.focus();
      });
    } catch (e) {
      debugPrint('WindowManager init error: $e');
    }
  } else {
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
  }

  final prefs = await SharedPreferences.getInstance();
  final playTogether = prefs.getBool('playTogether') ?? false;
  await configureAudioSession(playTogether);
  await ytmInitFromPrefs();
  await ArtworkCacheManager.init();

  if (Platform.isAndroid || Platform.isIOS) {
    try {
      audioHandler = await AudioService.init(
        builder: () => MyAudioHandler(),
        config: const AudioServiceConfig(
          androidNotificationChannelId: 'com.fley.music.channel.audio.v1',
          androidNotificationChannelName: 'Fley Audio Player',
          androidNotificationOngoing: false,
          androidStopForegroundOnPause: true,
          androidShowNotificationBadge: true,
          androidNotificationIcon: 'drawable/ic_notification',
        ),
      );
      isBackgroundInitialized = true;
    } catch (e, stackTrace) {
      debugPrint('AudioService init error: $e');
      debugPrint('StackTrace: $stackTrace');
      backgroundInitError = '$e\n$stackTrace';
      audioHandler = MyAudioHandler();
      isBackgroundInitialized = false;
    }
  } else {
    audioHandler = MyAudioHandler();
    isBackgroundInitialized = true;
  }

  // Initialize ValueNotifiers directly from prefs BEFORE runApp so first frame renders with correct settings
  final savedFont = prefs.getString('activeFont') ?? 'Plus Jakarta Sans';
  activeFontNotifier.value = savedFont;
  themeModeNotifier.value = prefs.getString('themeMode') ?? 'dark';
  playlistAddSongPositionNotifier.value =
      prefs.getString('playlist_add_song_position') ?? 'top';
  customThemeBgNotifier.value = prefs.getString('customThemeBg') ?? 'dynamic';
  languageNotifier.value = prefs.getString('language') ?? 'en';
  fontScaleNotifier.value = prefs.getDouble('fontScale') ?? 1.0;
  userProfileNameNotifier.value =
      prefs.getString('userProfileName') ?? 'User';
  final savedProfileImg = prefs.getString('userProfileImage');
  if (savedProfileImg != null && savedProfileImg.isNotEmpty) {
    try {
      if (File(savedProfileImg).existsSync()) {
        userProfileImageNotifier.value = savedProfileImg;
      } else {
        userProfileImageNotifier.value = null;
      }
    } catch (_) {
      userProfileImageNotifier.value = null;
    }
  } else {
    userProfileImageNotifier.value = null;
  }
  userProfileBioNotifier.value =
      prefs.getString('userProfileBio') ?? 'Music enthusiast';

  // Preload selected Google font to avoid default-font flash on first frame.
  try {
    if (savedFont == 'Spotify Style') {
      await GoogleFonts.pendingFonts([
        GoogleFonts.figtree(),
        GoogleFonts.figtree(fontWeight: FontWeight.bold),
        GoogleFonts.figtree(fontWeight: FontWeight.w600),
      ]);
    } else if (savedFont == 'Apple Music Style') {
      await GoogleFonts.pendingFonts([
        GoogleFonts.inter(),
        GoogleFonts.inter(fontWeight: FontWeight.bold),
        GoogleFonts.inter(fontWeight: FontWeight.w600),
      ]);
    } else {
      await GoogleFonts.pendingFonts([
        GoogleFonts.plusJakartaSans(),
        GoogleFonts.plusJakartaSans(fontWeight: FontWeight.bold),
        GoogleFonts.plusJakartaSans(fontWeight: FontWeight.w600),
      ]);
    }
  } catch (e) {
    debugPrint('Font preload error: $e');
  }

  runApp(const ProviderScope(child: FleyApp()));
}

class FleyApp extends StatelessWidget {
  const FleyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<String>(
      valueListenable: themeModeNotifier,
      builder: (context, themeMode, child) {
        return ValueListenableBuilder<String>(
          valueListenable: customThemeBgNotifier,
          builder: (context, customThemeBg, child) {
            return ValueListenableBuilder<Color?>(
              valueListenable: dominantColorNotifier,
              builder: (context, dominantColor, child) {
                return ValueListenableBuilder<String>(
                  valueListenable: customThemeStyleNotifier,
                  builder: (context, customThemeStyle, child) {
                    final appBgColor = getAppBackgroundColor(
                      themeMode: themeMode,
                      customBg: customThemeBg,
                      artworkColor: dominantColor,
                    );
                    final appCardColor = getAppCardColor(
                      themeMode: themeMode,
                      appBgColor: appBgColor,
                    );

                    bool isLight = themeMode == 'light';
                    if (themeMode == 'custom') {
                      if (customThemeStyle == 'light') {
                        isLight = true;
                      } else if (customThemeStyle == 'dynamic') {
                        final activeCol =
                            dominantColor ?? const Color(0xFF8E8E93);
                        isLight = activeCol.computeLuminance() > 0.45;
                      }
                    }

                    return ValueListenableBuilder<String>(
                      valueListenable: activeFontNotifier,
                      builder: (context, fontName, child) {
                        final baseTheme = isLight
                            ? ThemeData.light()
                            : ThemeData.dark();
                        TextTheme textTheme;
                        if (fontName == 'Spotify Style') {
                          textTheme = GoogleFonts.figtreeTextTheme(
                            baseTheme.textTheme,
                          );
                        } else if (fontName == 'Apple Music Style') {
                          textTheme = GoogleFonts.interTextTheme(
                            baseTheme.textTheme,
                          );
                        } else {
                          textTheme = GoogleFonts.plusJakartaSansTextTheme(
                            baseTheme.textTheme,
                          );
                        }

                        return ValueListenableBuilder<double>(
                          valueListenable: fontScaleNotifier,
                          builder: (context, scale, child) {
                            return ValueListenableBuilder<String>(
                              valueListenable: languageNotifier,
                              builder: (context, lang, child) {
                                return ValueListenableBuilder<String>(
                                  valueListenable: themeAccentPresetNotifier,
                                  builder: (context, accentPreset, child) {
                                    final activeAccent = resolveThemeAccentColor(
                                      accentPreset,
                                      dominantColor,
                                    );
                                    return MaterialApp(
                                      title: 'Fley',
                                      debugShowCheckedModeBanner: false,
                                      localizationsDelegates:
                                          AppLocalizations.localizationsDelegates,
                                      supportedLocales:
                                          AppLocalizations.supportedLocales,
                                      locale: Locale(lang),
                                      builder: (context, child) {
                                        return MediaQuery(
                                          data: MediaQuery.of(context).copyWith(
                                            textScaler: TextScaler.linear(scale),
                                          ),
                                          child: child!,
                                        );
                                      },
                                      theme: ThemeData(
                                        useMaterial3: true,
                                        fontFamily: getFontFamily(fontName),
                                        brightness: isLight
                                            ? Brightness.light
                                            : Brightness.dark,
                                        scaffoldBackgroundColor: appBgColor,
                                        textTheme: textTheme.apply(
                                          bodyColor: isLight
                                              ? const Color(0xFF1A1A1A)
                                              : Colors.white,
                                          displayColor: isLight
                                              ? const Color(0xFF1A1A1A)
                                              : Colors.white,
                                        ),
                                        colorScheme: ColorScheme(
                                          brightness: isLight
                                              ? Brightness.light
                                              : Brightness.dark,
                                          primary: activeAccent,
                                          onPrimary: Colors.black,
                                          secondary: activeAccent,
                                          onSecondary: Colors.black,
                                          error: Colors.red,
                                          onError: Colors.white,
                                          surface: appCardColor,
                                          onSurface: isLight
                                              ? const Color(0xFF1A1A1A)
                                              : Colors.white,
                                          outline: isLight
                                              ? Colors.black12
                                              : Colors.white10,
                                        ),
                                        listTileTheme: ListTileThemeData(
                                          shape: RoundedRectangleBorder(
                                            borderRadius: BorderRadius.circular(12),
                                          ),
                                        ),
                                        bottomSheetTheme: BottomSheetThemeData(
                                          constraints: (Platform.isMacOS ||
                                                  Platform.isWindows ||
                                                  Platform.isLinux)
                                              ? const BoxConstraints(maxWidth: 580)
                                              : null,
                                        ),
                                      ),
                                      home: const MainScreen(),
                                    );
                                  },
                                );
                              },
                            );
                          },
                        );
                      },
                    );
                  },
                );
              },
            );
          },
        );
      },
    );
  }
}

class OnlineDetailTarget {
  final String title;
  final String subtitle;
  final String type; // 'Artist' or 'Album'
  final String thumbnailUrl;
  final String? browseId;

  const OnlineDetailTarget({
    required this.title,
    required this.subtitle,
    required this.type,
    required this.thumbnailUrl,
    this.browseId,
  });
}

class MainScreen extends StatefulWidget {
  const MainScreen({super.key});

  // ignore: library_private_types_in_public_api
  static _MainScreenState? get mainScreenState =>
      _MainScreenState.mainScreenState;

  static void showEqualizer(BuildContext context) {
    if (mainScreenState != null) {
      if (!Platform.isAndroid) {
        showFleyToast(
          lookupAppLocalizations(Locale(FleyStrings.currentLang))
              .eqErrorUnsupported,
        );
        return;
      }
      final sessionId = mainScreenState!.player.androidAudioSessionId ?? 0;
      if (sessionId == 0) {
        showFleyToast(
          lookupAppLocalizations(Locale(FleyStrings.currentLang))
              .playFirstToUseEqualizer,
        );
      } else {
        mainScreenState!._showEqualizerSheet(context);
      }
    }
  }

  @override
  State<MainScreen> createState() => _MainScreenState();
}

class _MainScreenState extends State<MainScreen> with WidgetsBindingObserver {
  static _MainScreenState? mainScreenState;
  AudioPlayer get player => _audioPlayer;
  final AudioPlayer _audioPlayer = (audioHandler as MyAudioHandler).player;
  final OnAudioQuery _audioQuery = OnAudioQuery();
  final ScrollController _lyricsScrollController = ScrollController();
  final ScrollController _detailScrollController = ScrollController();
  final ScrollController _playerScrollController = ScrollController();
  double _playerDismissStartY = 0.0;
  bool _isPlayerPullDismissing = false;
  final Map<String, List<Track>> _cachedArtistExploreTracks = {};
  final Map<String, bool> _loadingArtistExplore = {};
  final ValueNotifier<int> _sleepTimerNotifier = ValueNotifier<int>(0);
  Timer? _sleepTimer;
  bool _sleepAtEndOfTrack = false;
  bool _isNaturalFadingOut = false;
  String? _lastCrossfadedTrackId;
  bool _filterShortAudio = false;
  bool _autoRegexClean = false;
  int _crossfadeDuration = 200;
  int _playRequestId = 0;
  bool _pauseOnDisconnect = true;
  bool _autoPlayAfterCall = true;
  bool _playTogether = false;
  int _playCountThreshold = 10;
  String _activeFont = activeFontNotifier.value;
  double _fontScale = 1.0;
  String _specificFolderScan = '';
  bool _skipSilence = false;
  bool _stopOnLowBattery = false;
  bool _monoAudio = false;
  String _libraryDensity = 'standard';
  bool _autoPlayOnConnect = false;
  double _playbackSpeed = 1.0;
  bool _pitchLock = true;
  double _lyricFontSize = 22.0;
  Timer? _batteryCheckTimer;
  String _sortBy = 'date';
  String _detailSortBy = 'default';
  final Set<String> _animatedTrackIds = {};
  final Set<String> _animatedPlaylistIds = {};
  final Set<String> _animatedArtistIds = {};
  final Set<String> _animatedAlbumIds = {};
  String _artistViewMode = 'grid';
  String _albumViewMode = 'grid';
  List<Track>? _memoSortedTracks;
  String? _memoSongSortBy;
  int? _memoSongPoolLen;
  Map<String, List<Track>>? _memoArtistTracksMap;
  List<String>? _memoArtistsList;
  List<String>? _memoTopArtistsList;
  String? _memoArtistSortBy;
  String? _memoArtistSearchQuery;
  int? _memoArtistPoolLen;
  Map<String, List<Track>>? _memoAlbumTracksMap;
  List<String>? _memoAlbumsList;
  List<String>? _memoTopAlbumsList;
  String? _memoAlbumSortBy;
  String? _memoAlbumSearchQuery;
  int? _memoAlbumPoolLen;
  final Set<String> _visitedTabKeys = {};
  final int _artistsAnimToken = 0;
  final int _albumsAnimToken = 0;

  List<Track> _allTracks = [];
  final Map<String, Track> _onlineTracksMap = {};
  List<YtTrack> _ytmQuickPicksTracks = [];
  bool _ytmQuickPicksLoading = false;
  bool _ytmQuickPicksFailed = false;
  List<YtTrack> _ytmTrendingTracks = [];
  bool _ytmTrendingLoading = false;
  bool _ytmTrendingFailed = false;
  List<YtTrack> _recommendedTracks = [];
  String _recommendedArtist = '';
  bool _recommendedLoading = false;
  bool _recommendedFailed = false;
  YtPlaylist? _selectedOnlinePlaylist;
  OnlineDetailTarget? _selectedOnlineDetail;
  List<Track> _onlinePlaylistTracks = [];
  bool _onlinePlaylistLoading = false;
  bool _isLoading = true;
  bool _showSplash = true;
  bool _isPlayerOpen = false;
  bool _showLyrics = false;
  String? _currentLyricsPlain;
  List<LyricsLine> _currentLyricsSynced = [];
  double _lyricsOffsetSec = 0.0;
  bool _lyricsAutoWave = true;
  bool _isLyricsLoading = false;
  bool _isLyricsSynced = false;
  int _lastActiveLyricsIndex = -1;
  bool _lyricsUserScrolling = false;
  Timer? _lyricsResumeTimer;
  DateTime? _lyricsOpenedTime;
  String _playingFromType = 'LIBRARY';
  String _playingFromName = 'All Songs';
  String? _lastIncrementedTrackId;
  bool _hasResetPosition = false;
  DateTime _lastTrackStartTime = DateTime.now();

  List<Track> _playbackQueue = [];
  List<int> _shuffledIndices = [];
  Track? _playingTrack;
  int _currentIndex = 0;
  bool _isProgrammaticLoading = false;

  final Set<String> _favoriteTrackIds = {};
  final Set<String> _hiddenTrackIds = {};
  String _searchQuery = '';
  String? _selectedArtistDetail;
  String? _selectedAlbumDetail;
  String? _selectedPlaylistDetail;

  final Set<String> _multiSelectedTrackIds = {};

  void _toggleMultiSelect(String trackId) {
    setState(() {
      if (_multiSelectedTrackIds.contains(trackId)) {
        _multiSelectedTrackIds.remove(trackId);
      } else {
        _multiSelectedTrackIds.add(trackId);
      }
    });
  }

  void _clearMultiSelect() {
    setState(() {
      _multiSelectedTrackIds.clear();
    });
  }

  late PageController _pageController;
  late PageController _rootNavPageController;
  int _currentPageIndex = 0;
  int _currentNavIndex = 0;

  void _switchToNavTab(int index) {
    if (_currentNavIndex == 1 && index != 1) {
      _searchFocusNode.unfocus();
    }
    final isDetail =
        _selectedPlaylistDetail != null ||
        _selectedArtistDetail != null ||
        _selectedAlbumDetail != null ||
        _selectedOnlinePlaylist != null ||
        _selectedOnlineDetail != null;
    if (_currentNavIndex == index && !isDetail) return;
    setState(() {
      _selectedPlaylistDetail = null;
      _selectedArtistDetail = null;
      _selectedAlbumDetail = null;
      _selectedOnlinePlaylist = null;
      _selectedOnlineDetail = null;
      _currentNavIndex = index;
    });
    if (_rootNavPageController.hasClients) {
      _rootNavPageController.jumpToPage(index);
    }
  }

  List<String> _lastPlayedTrackIds = [];
  int _lastPlaybackPositionMs = 0;
  String? _lastPlaybackTrackId;
  List<String> get _allPlayedTrackIdsOrdered {
    final result = <String>[];
    final added = <String>{};
    for (var id in _lastPlayedTrackIds) {
      if (added.add(id)) result.add(id);
    }
    for (var entry in _playCounts.entries) {
      if (entry.value > 0 && added.add(entry.key)) {
        result.add(entry.key);
      }
    }
    return result;
  }

  List<String> _recentSearchedTrackIds = [];
  List<YtTrack> _recentOnlineSearches = [];

  // YT Music search state
  String _searchMode = 'local'; // 'local' | 'online'
  List<YtTrack> _ytmResults = [];
  bool _ytmSearching = false;
  String? _ytmError;
  String? _ytmLoadingVideoId;
  Timer? _ytmDebouncer;

  bool get _isYtmPlaying => _playingTrack?.id.startsWith('ytm_') == true;

  bool get _isBuffering =>
      _isYtmPlaying
          ? YtPlayerService.instance.isBuffering
          : (_processingState == ProcessingState.loading ||
              _processingState == ProcessingState.buffering);

  Stream<Duration> get _currentPlaybackPositionStream =>
      _isYtmPlaying
          ? YtPlayerService.instance.positionStream
          : _audioPlayer.positionStream;

  Duration get _currentPlaybackPosition =>
      _isYtmPlaying
          ? YtPlayerService.instance.currentPosition
          : _audioPlayer.position;

  Duration? get _currentPlaybackDuration {
    if (_isYtmPlaying) {
      final dur = YtPlayerService.instance.currentDuration;
      if (dur > Duration.zero) return dur;
      if (_playingTrack != null && _playingTrack!.duration > 0) {
        return Duration(milliseconds: _playingTrack!.duration);
      }
      return null;
    }
    return _audioPlayer.duration;
  }

  void _addToRecentSearches(String trackId) async {
    setState(() {
      _recentSearchedTrackIds.remove(trackId);
      _recentSearchedTrackIds.insert(0, trackId);
      if (_recentSearchedTrackIds.length > 20) {
        _recentSearchedTrackIds = _recentSearchedTrackIds.sublist(0, 20);
      }
    });
    final prefs = await SharedPreferences.getInstance();
    prefs.setStringList('recent_searched_track_ids', _recentSearchedTrackIds);
  }

  void _addToRecentOnlineSearches(YtTrack track) {
    setState(() {
      _recentOnlineSearches.removeWhere((t) => t.videoId == track.videoId);
      _recentOnlineSearches.insert(0, track);
      if (_recentOnlineSearches.length > 20) {
        _recentOnlineSearches = _recentOnlineSearches.sublist(0, 20);
      }
    });
    SharedPreferences.getInstance().then((prefs) {
      prefs.setString(
        'recent_online_searches',
        jsonEncode(
          _recentOnlineSearches
              .map((t) => {
                    'videoId': t.videoId,
                    'title': t.title,
                    'artist': t.artist,
                    'album': t.album,
                    'durationMs': t.durationMs,
                    'thumbnailUrl': t.thumbnailUrl,
                  })
              .toList(),
        ),
      );
    });
  }

  Map<String, int> _playCounts = {};
  Map<String, List<String>> _userPlaylists = {};
  Map<String, String> _playlistCovers = {};
  Map<String, Map<String, String>> _metadataOverrides = {};
  final TextEditingController _searchController = TextEditingController();
  final FocusNode _searchFocusNode = FocusNode();
  Timer? _searchDebouncer;
  final ImagePicker _imagePicker = ImagePicker();

  bool _isPlaying = false;
  bool _isShuffle = false;
  int _repeatMode = 1;
  final double _volume = 1.0;
  ProcessingState _processingState = ProcessingState.idle;
  double? _dragValue;
  Color? _dominantColor;
  ValueNotifier<Color?> get _dominantColorNotifier => dominantColorNotifier;
  String _themeMode = 'dark';
  String _customThemeBg = 'dynamic';
  String? _customThemeBgPath;
  double _customThemeBgBlur = 25.0;
  final ValueNotifier<double> _customThemeBgBlurNotifier =
      customThemeBgBlurNotifier;
  double _customThemeBgDim = 0.65;
  final ValueNotifier<double> _customThemeBgDimNotifier =
      customThemeBgDimNotifier;
  double _customThemeBgScale = 1.0;
  final ValueNotifier<double> _customThemeBgScaleNotifier =
      customThemeBgScaleNotifier;
  String _customThemeStyle = 'dark';
  final ValueNotifier<String> _customThemeStyleNotifier =
      customThemeStyleNotifier;

  Color _ensureLuminance(Color color) {
    final hsl = HSLColor.fromColor(color);
    if (hsl.lightness < 0.55) {
      if (hsl.saturation < 0.12) {
        return const Color(0xFFB3B3B3);
      }
      return hsl.withLightness(0.6).toColor();
    }
    return color;
  }

  Color get _activeAccentColor =>
      resolveThemeAccentColor(themeAccentPresetNotifier.value, _dominantColor);

  Future<Color?>? _detailColorFuture;
  final Map<String, Color> _detailColorCache = {};
  int _fadeSessionId = 0;
  final ValueNotifier<double> _playerDragOffsetNotifier = ValueNotifier(0.0);
  final ValueNotifier<bool> _isDraggingPlayerNotifier = ValueNotifier(false);
  final ValueNotifier<double> _detailDragOffsetNotifier = ValueNotifier(0.0);
  final ValueNotifier<bool> _isDraggingDetailNotifier = ValueNotifier(false);
  final ValueNotifier<double> _detailScrollOffsetNotifier = ValueNotifier(0.0);

  Widget? _lastDetailView;
  String? _cachedDetailKey;
  String? _cachedDetailBaseKey;
  List<Track>? _cachedDetailSongs;
  Widget? _cachedDetailImage;
  bool _isFading = false;
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    mainScreenState = this;
    _pageController = PageController(initialPage: _currentPageIndex);
    _rootNavPageController = PageController(initialPage: _currentNavIndex);
    _loadSettings();
    _requestPermissionAndScan();
    _setupAudioStreams();
    _startBatteryMonitor();
    ytmRegionNotifier.addListener(_onYtmRegionChanged);

    DownloadService.instance.onTrackDownloaded = (newTrack, artBytes) {
      if (!mounted) return;
      ArtworkCacheManager.registerTrackPath(newTrack.id, newTrack.path);
      if (artBytes != null) {
        ArtworkCacheManager.setCachedArtwork(newTrack.id, artBytes);
      }
      setState(() {
        _allTracks.removeWhere(
          (t) => t.id == newTrack.id || t.path == newTrack.path,
        );
        _allTracks.insert(0, newTrack);
        _cachedDetailKey = null;
        _memoSortedTracks = null;
      });
      SharedPreferences.getInstance().then((prefs) {
        final serialized = _allTracks.map((t) => t.toMap()).toList();
        prefs.setString('cached_tracks_list', jsonEncode(serialized));
      });
      showFleyToast(
        lookupAppLocalizations(Locale(FleyStrings.currentLang))
            .downloadSuccess(newTrack.title),
      );
    };

    DownloadService.instance.onTrackDeleted = (trackId) {
      if (!mounted) return;
      setState(() {
        _allTracks.removeWhere((t) => t.id == trackId);
        _cachedDetailKey = null;
        _memoSortedTracks = null;
      });
      SharedPreferences.getInstance().then((prefs) {
        final serialized = _allTracks.map((t) => t.toMap()).toList();
        prefs.setString('cached_tracks_list', jsonEncode(serialized));
      });
    };

    YtPlayerService.instance.onStateChange = () {
      if (mounted && _isYtmPlaying) {
        final dur = YtPlayerService.instance.currentDuration;
        if (_playingTrack != null &&
            _playingTrack!.id.startsWith('ytm_') &&
            dur > Duration.zero &&
            (_playingTrack!.duration <= 0 ||
                _playingTrack!.duration != dur.inMilliseconds)) {
          _playingTrack = _playingTrack!.copyWith(duration: dur.inMilliseconds);
          _onlineTracksMap[_playingTrack!.id] = _playingTrack!;
          final idx = _recentOnlineSearches.indexWhere(
            (yt) =>
                'ytm_${yt.videoId}' == _playingTrack!.id ||
                yt.videoId == _playingTrack!.path,
          );
          if (idx != -1) {
            _recentOnlineSearches[idx] = _recentOnlineSearches[idx].copyWith(
              durationMs: dur.inMilliseconds,
            );
          }
          if (audioHandler is MyAudioHandler) {
            final cur = (audioHandler as MyAudioHandler).mediaItem.value;
            if (cur != null) {
              (audioHandler as MyAudioHandler).updateYtmMediaItem(
                cur.copyWith(duration: dur),
              );
            }
          }
        }
        setState(() {
          _isPlaying = YtPlayerService.instance.isPlaying;
        });
        if (audioHandler is MyAudioHandler) {
          (audioHandler as MyAudioHandler).updateYtmPlaybackState(
            isPlaying: YtPlayerService.instance.isPlaying,
            position: YtPlayerService.instance.currentPosition,
          );
        }
      }
    };
    DateTime? lastYtmSongEndedTime;
    YtPlayerService.instance.onSongEnded = () {
      final now = DateTime.now();
      if (lastYtmSongEndedTime != null &&
          now.difference(lastYtmSongEndedTime!).inMilliseconds < 4000) {
        return;
      }
      if (YtPlayerService.instance.currentPosition < const Duration(seconds: 3)) {
        return;
      }
      lastYtmSongEndedTime = now;
      if (mounted && _isYtmPlaying) {
        if (_repeatMode == 2) {
          final current = _playingTrack;
          if (current != null) {
            final videoId = current.path.isNotEmpty
                ? current.path
                : current.id.replaceFirst('ytm_', '');
            YtPlayerService.instance.loadAndPlay(videoId);
          } else {
            YtPlayerService.instance.seekTo(Duration.zero);
            YtPlayerService.instance.play();
          }
        } else {
          _playNext();
        }
      }
    };

    AudioSession.instance.then((session) {
      session.becomingNoisyEventStream.listen((_) {
        if (_pauseOnDisconnect &&
            (_audioPlayer.playing || (_isYtmPlaying && _isPlaying))) {
          _pauseWithFade();
          showFleyToast(
            lookupAppLocalizations(
              Locale(FleyStrings.currentLang),
            ).toastHeadphonesUnplugged,
          );
        }
      });

      bool playBeforeInterruption = false;
      session.interruptionEventStream.listen((event) {
        if (_isProgrammaticLoading) return;
        if (DateTime.now().difference(_lastTrackStartTime).inMilliseconds <
            2000) {
          return;
        }
        if (event.begin) {
          switch (event.type) {
            case AudioInterruptionType.duck:
              _audioPlayer.setVolume(_volume);
              break;
            case AudioInterruptionType.pause:
            case AudioInterruptionType.unknown:
              if ((_audioPlayer.playing || (_isYtmPlaying && _isPlaying)) &&
                  !_playTogether) {
                playBeforeInterruption = true;
                _pauseWithFade();
              }
              break;
          }
        } else {
          switch (event.type) {
            case AudioInterruptionType.duck:
              _audioPlayer.setVolume(_volume);
              break;
            case AudioInterruptionType.pause:
            case AudioInterruptionType.unknown:
              if (playBeforeInterruption && _autoPlayAfterCall) {
                _playWithFade();
              }
              playBeforeInterruption = false;
              break;
          }
        }
      });
    });

    if (backgroundInitError != null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        showDialog(
          context: context,
          barrierDismissible: false,
          builder: (context) => AlertDialog(
            title: const Row(
              children: [
                Icon(Icons.error, color: Colors.red),
                SizedBox(width: 8),
                Text("Background Audio Error"),
              ],
            ),
            content: SingleChildScrollView(
              child: SelectableText(
                "If you see this, background audio initialization has failed with the following native stack trace:\n\n$backgroundInitError",
                style: const TextStyle(fontFamily: 'monospace', fontSize: 12),
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text("CLOSE"),
              ),
            ],
          ),
        );
      });
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.detached) {
      YtPlayerService.instance.stop();
      _audioPlayer.stop();
      audioHandler.stop();
    }
    super.didChangeAppLifecycleState(state);
  }

  void _onYtmRegionChanged() {
    if (!mounted) return;
    setState(() {
      _ytmQuickPicksTracks.clear();
      _ytmQuickPicksLoading = false;
      _ytmQuickPicksFailed = false;
      _ytmTrendingTracks.clear();
      _ytmTrendingLoading = false;
      _ytmTrendingFailed = false;
    });
  }

  @override
  void dispose() {
    ytmRegionNotifier.removeListener(_onYtmRegionChanged);
    YtPlayerService.instance.stop();
    WidgetsBinding.instance.removeObserver(this);
    _batteryCheckTimer?.cancel();
    _searchController.dispose();
    _lyricsResumeTimer?.cancel();
    _lyricsScrollController.dispose();
    _detailScrollController.dispose();
    _playerScrollController.dispose();
    _pageController.dispose();
    _rootNavPageController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        if (constraints.maxWidth >= 768) {
          final isLight = Theme.of(context).brightness == Brightness.light;
          final appBgColor = Theme.of(context).scaffoldBackgroundColor;
          final cardColor = Theme.of(context).colorScheme.surface;
          final activeAccent = Theme.of(context).colorScheme.primary;

          return DesktopLayoutShell(
            allTracks: _allTracks,
            playbackQueue: _playbackQueue,
            playingTrack: _playingTrack,
            player: player,
            favoriteTrackIds: _favoriteTrackIds,
            activeAccentColor: activeAccent,
            backgroundColor: appBgColor,
            cardColor: cardColor,
            isLight: isLight,
            onPlayTrack: (track, queue, index) {
              _playTrack(index, sourceList: queue);
            },
            onTogglePlayPause: () {
              if (_isPlaying) {
                _pauseWithFade();
              } else {
                _playWithFade();
              }
            },
            onPlayNext: _playNext,
            onPlayPrevious: _playPrevious,
            onToggleFavorite: _toggleFavorite,
            onOpenSettings: _openSettings,
            onOpenDownloads: _openDownloads,
            onRescan: () => _requestPermissionAndScan(showLoading: true),
            userPlaylists: _userPlaylists,
            playCounts: _playCounts,
            allPlayedTrackIdsOrdered: _allPlayedTrackIdsOrdered,
            playlistCovers: _playlistCovers,
            lastPlaybackTrackId: _lastPlaybackTrackId,
            lastPlaybackPositionMs: _lastPlaybackPositionMs,
            currentLyricsPlain: _currentLyricsPlain,
            currentLyricsSynced: _currentLyricsSynced,
            isLyricsLoading: _isLyricsLoading,
            isLyricsSynced: _isLyricsSynced,
            onRefreshLyrics: _playingTrack != null
                ? () => _loadLyricsForTrack(_playingTrack!)
                : null,
            onSaveManualLyrics: (track, text) => _saveManualLyrics(track, text),
            onPlayNextInQueue: (track) =>
                _moveTrackInQueue(track, _currentIndex + 1),
            onAddToQueue: (track) => _addTracksToQueue([track]),
            onCreatePlaylist: (name) {
              setState(() {
                _userPlaylists[name] = [];
                _saveUserPlaylists();
              });
            },
            onDeletePlaylist: (name) {
              setState(() {
                _userPlaylists.remove(name);
                _saveUserPlaylists();
              });
            },
            onAddToPlaylist: (name, track) {
              setState(() {
                final list = _userPlaylists.putIfAbsent(name, () => []);
                if (!list.contains(track.id)) {
                  list.add(track.id);
                }
                _saveUserPlaylists();
              });
            },
            onRenamePlaylist: (oldName, newName) {
              setState(() {
                if (_userPlaylists.containsKey(oldName)) {
                  final tracks = _userPlaylists.remove(oldName)!;
                  _userPlaylists[newName] = tracks;
                  _saveUserPlaylists();
                }
                if (_playlistCovers.containsKey(oldName)) {
                  final cover = _playlistCovers.remove(oldName)!;
                  _playlistCovers[newName] = cover;
                  _savePlaylistCovers();
                }
              });
            },
            onChangePlaylistCover: (name, coverPath) {
              setState(() {
                if (coverPath == null) {
                  _playlistCovers.remove(name);
                } else {
                  _playlistCovers[name] = coverPath;
                }
                _savePlaylistCovers();
              });
            },
            onRemoveFromPlaylist: (name, trackId) {
              setState(() {
                _userPlaylists[name]?.remove(trackId);
                _saveUserPlaylists();
              });
            },
            onHideTrack: (track) {
              setState(() {
                _hiddenTrackIds.add(track.id);
                _allTracks.removeWhere((t) => t.id == track.id);
              });
              SharedPreferences.getInstance().then((prefs) {
                prefs.setStringList('hidden_track_ids', _hiddenTrackIds.toList());
              });
            },
            hiddenTrackIds: _hiddenTrackIds,
            onUnhideTrack: (trackId) async {
              setState(() {
                _hiddenTrackIds.remove(trackId);
              });
              final prefs = await SharedPreferences.getInstance();
              await prefs.setStringList('hidden_track_ids', _hiddenTrackIds.toList());
              _requestPermissionAndScan(showLoading: false);
            },
            onRemoveFromQueue: (trackId) => _removeFromQueueAndPlayer(trackId),
            onReorderQueue: (track, newIndex) => _moveTrackInQueue(track, newIndex),
            onDeletePermanently: (track) async {
              try {
                final file = File(track.path);
                if (track.path.isNotEmpty && await file.exists()) {
                  await file.delete();
                  setState(() {
                    _allTracks.removeWhere((t) => t.id == track.id);
                  });
                  _removeFromQueueAndPlayer(track.id);
                  final prefs = await SharedPreferences.getInstance();
                  final serialized = _allTracks.map((t) => t.toMap()).toList();
                  await prefs.setString('cached_tracks_list', jsonEncode(serialized));
                  showFleyToast(
                    lookupAppLocalizations(
                      Locale(FleyStrings.currentLang),
                    ).trackDeleted,
                  );
                }
              } catch (e) {
                debugPrint('Delete error: $e');
              }
            },
            onLibraryUpdated: () => _requestPermissionAndScan(showLoading: false),
            onOpenEqualizer: Platform.isAndroid ? () => _showEqualizerSheet(context) : null,
            onOpenSleepTimer: () => _showFullSleepTimerDialog(context),
          );
        }

        final isDetailView =
            _selectedPlaylistDetail != null ||
            _selectedArtistDetail != null ||
            _selectedAlbumDetail != null ||
            _selectedOnlinePlaylist != null ||
            _selectedOnlineDetail != null;

        return AnnotatedRegion<SystemUiOverlayStyle>(
      value: const SystemUiOverlayStyle(
        statusBarColor: Colors.transparent,
        statusBarIconBrightness: Brightness.light,
        systemNavigationBarColor: Colors.transparent,
        systemNavigationBarIconBrightness: Brightness.light,
      ),
      child: PopScope(
        canPop: !_isPlayerOpen && !isDetailView && _currentNavIndex == 0,
        onPopInvokedWithResult: (didPop, result) {
          if (didPop) return;
          if (_isPlayerOpen) {
            setState(() {
              _isPlayerOpen = false;
              _showLyrics = false;
            });
          } else if (isDetailView) {
            setState(() {
              _selectedPlaylistDetail = null;
              _selectedArtistDetail = null;
              _selectedAlbumDetail = null;
              _selectedOnlinePlaylist = null;
              _selectedOnlineDetail = null;
            });
          } else if (_currentNavIndex != 0) {
            _switchToNavTab(0);
          }
        },
        child: Scaffold(
          resizeToAvoidBottomInset: false,
          body: Stack(
            children: [
              if (Platform.isAndroid || Platform.isIOS)
                Positioned(
                  bottom: 0,
                  right: 0,
                  width: 1,
                  height: 1,
                  child: IgnorePointer(
                    child: YtPlayerService.instance.buildWidget(),
                  ),
                ),
              ValueListenableBuilder<String>(
                valueListenable: themeModeNotifier,
                builder: (context, themeMode, child) {
                  return ValueListenableBuilder<String>(
                    valueListenable: customThemeBgNotifier,
                    builder: (context, customBg, child) {
                      if (themeMode == 'custom' && customBg == 'custom_image') {
                        return ValueListenableBuilder<String?>(
                          valueListenable: customThemeBgPathNotifier,
                          builder: (context, customPath, child) {
                            if (customPath != null &&
                                File(customPath).existsSync()) {
                              return ValueListenableBuilder<double>(
                                valueListenable: customThemeBgBlurNotifier,
                                builder: (context, blurVal, child) {
                                  return ValueListenableBuilder<double>(
                                    valueListenable: customThemeBgDimNotifier,
                                    builder: (context, dimVal, child) {
                                      return AnimatedBuilder(
                                        animation: Listenable.merge([
                                          customThemeBgScaleNotifier,
                                          customThemeBgOffsetXNotifier,
                                          customThemeBgOffsetYNotifier,
                                        ]),
                                        builder: (context, child) {
                                          return Positioned.fill(
                                            child: Stack(
                                              children: [
                                                Positioned.fill(
                                                  child: ClipRect(
                                                    child: ImageFiltered(
                                                      imageFilter:
                                                          ImageFilter.blur(
                                                            sigmaX: blurVal,
                                                            sigmaY: blurVal,
                                                          ),
                                                      child: Transform.scale(
                                                        scale:
                                                            customThemeBgScaleNotifier
                                                                .value,
                                                        alignment: Alignment(
                                                          customThemeBgOffsetXNotifier
                                                              .value,
                                                          customThemeBgOffsetYNotifier
                                                              .value,
                                                        ),
                                                        child: Image.file(
                                                          File(customPath),
                                                          fit: BoxFit.cover,
                                                        ),
                                                      ),
                                                    ),
                                                  ),
                                                ),
                                                Positioned.fill(
                                                  child: Container(
                                                    color: Colors.black
                                                        .withValues(
                                                          alpha: dimVal,
                                                        ),
                                                  ),
                                                ),
                                              ],
                                            ),
                                          );
                                        },
                                      );
                                    },
                                  );
                                },
                              );
                            }
                            return Positioned.fill(
                              child: Container(color: const Color(0xFF0F0F15)),
                            );
                          },
                        );
                      }
                      return const SizedBox.shrink();
                    },
                  );
                },
              ),
              SafeArea(
                bottom: false,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (_multiSelectedTrackIds.isNotEmpty)
                      _buildMultiSelectHeader()
                    else
                      _buildHeader(),
                    Expanded(
                      child: Stack(
                        children: [
                          PageView(
                            controller: _rootNavPageController,
                            physics: (isDetailView || _isPlayerOpen)
                                ? const NeverScrollableScrollPhysics()
                                : const ClampingScrollPhysics(),
                            onPageChanged: (index) {
                              if (_currentNavIndex == 1 && index != 1) {
                                _searchFocusNode.unfocus();
                              }
                              setState(() {
                                _currentNavIndex = index;
                              });
                            },
                            children: [
                              _KeepAliveWrapper(child: _buildHomeScreen()),
                              _KeepAliveWrapper(child: _buildSearchTab()),
                              _KeepAliveWrapper(child: _buildLibraryTab()),
                            ],
                          ),
                          if (_isLoading && !_showSplash)
                            Positioned.fill(
                              child: Container(
                                color: Colors.black.withValues(alpha: 0.5),
                                child: Center(
                                  child: CircularProgressIndicator(
                                    color: _activeAccentColor,
                                  ),
                                ),
                              ),
                            ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),

              Positioned.fill(
                child: ListenableBuilder(
                  listenable: Listenable.merge([
                    _detailDragOffsetNotifier,
                    _isDraggingDetailNotifier,
                  ]),
                  child: ClipRRect(
                    borderRadius: const BorderRadius.vertical(
                      top: Radius.circular(28),
                    ),
                    child: _getActiveDetailView(),
                  ),
                  builder: (context, child) {
                    final isDragging = _isDraggingDetailNotifier.value;
                    final dragOffset = _detailDragOffsetNotifier.value;

                    if (!isDetailView && dragOffset != 0.0) {
                      WidgetsBinding.instance.addPostFrameCallback((_) {
                        if (mounted) _detailDragOffsetNotifier.value = 0.0;
                      });
                    }

                    return AnimatedSlide(
                      duration: isDragging
                          ? Duration.zero
                          : const Duration(milliseconds: 380),
                      curve: Curves.easeOutQuint,
                      offset: isDetailView
                          ? Offset(0, dragOffset)
                          : const Offset(0, 1),
                      child: child!,
                    );
                  },
                ),
              ),

              if (_playingTrack != null) _buildMiniPlayer(_playingTrack!),

              if (_multiSelectedTrackIds.isNotEmpty)
                _buildMultiSelectBottomBar()
              else
                _buildBottomNavBar(),

              Positioned.fill(
                child: ListenableBuilder(
                  listenable: Listenable.merge([
                    _playerDragOffsetNotifier,
                    _isDraggingPlayerNotifier,
                  ]),
                  child: ClipRRect(
                    borderRadius: const BorderRadius.vertical(
                      top: Radius.circular(28),
                    ),
                    child: _playingTrack != null
                        ? _buildFullScreenPlayer(_playingTrack!)
                        : const SizedBox.shrink(),
                  ),
                  builder: (context, child) {
                    final isDragging = _isDraggingPlayerNotifier.value;
                    final dragOffset = _playerDragOffsetNotifier.value;

                    return AnimatedSlide(
                      duration: isDragging
                          ? Duration.zero
                          : const Duration(milliseconds: 380),
                      curve: Curves.easeOutQuint,
                      offset: _isPlayerOpen
                          ? Offset(0, dragOffset)
                          : const Offset(0, 1),
                      child: child!,
                    );
                  },
                ),
              ),

              if (_showSplash)
                Positioned.fill(
                  child: AnimatedSplashScreen(
                    accentColor: _activeAccentColor,
                    isReady: !_isLoading,
                    fontFamily: getFontFamily(activeFontNotifier.value),
                    onFinish: () {
                      if (mounted) {
                        setState(() {
                          _showSplash = false;
                        });
                      }
                    },
                  ),
                ),
            ],
          ),
        ),
      ),
    );
      },
    );
  }
}
