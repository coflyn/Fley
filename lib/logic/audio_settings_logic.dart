// ignore_for_file: invalid_use_of_protected_member, deprecated_member_use
part of '../main.dart';

extension _AudioSettingsLogic on _MainScreenState {
  Future<void> _loadSettings() async {
    final prefs = await SharedPreferences.getInstance();
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
      activeFontNotifier.value = _activeFont;
      fontScaleNotifier.value = _fontScale;
      _specificFolderScan = prefs.getString('specificFolderScan') ?? '';
      _skipSilence = prefs.getBool('skipSilence') ?? false;
      final savedLang = prefs.getString('language') ?? 'en';
      languageNotifier.value = savedLang;
      _stopOnLowBattery = prefs.getBool('stopOnLowBattery') ?? false;
      _monoAudio = prefs.getBool('monoAudio') ?? false;
      _libraryDensity = prefs.getString('libraryDensity') ?? 'standard';
      _autoPlayOnConnect = prefs.getBool('autoPlayOnConnect') ?? false;
      _playbackSpeed = prefs.getDouble('playbackSpeed') ?? 1.0;
      _pitchLock = prefs.getBool('pitchLock') ?? true;
      _lyricFontSize = prefs.getDouble('lyricFontSize') ?? 22.0;
      lyricsHidePastNotifier.value = prefs.getBool('lyricsHidePast') ?? true;
      lyricsAutoFollowNotifier.value =
          prefs.getBool('lyricsAutoFollow') ?? true;

      _applyPlaybackSpeedAndPitch();
      _sortBy = prefs.getString('sortBy') ?? 'date';
      _detailSortBy = prefs.getString('detailSortBy') ?? 'default';
      themeAccentPresetNotifier.value =
          prefs.getString('themeAccentPreset') ?? 'spotify';
      _themeMode = prefs.getString('themeMode') ?? 'dark';
      _customThemeBg = prefs.getString('customThemeBg') ?? 'dynamic';
      _customThemeBgPath = prefs.getString('customThemeBgPath');
      _customThemeBgBlur = prefs.getDouble('customThemeBgBlur') ?? 25.0;
      _customThemeBgDim = prefs.getDouble('customThemeBgDim') ?? 0.65;
      _customThemeBgScale = prefs.getDouble('customThemeBgScale') ?? 1.0;
      double customOffsetX = prefs.getDouble('customThemeBgOffsetX') ?? 0.0;
      double customOffsetY = prefs.getDouble('customThemeBgOffsetY') ?? 0.0;
      customThemeBgOffsetXNotifier.value = customOffsetX;
      customThemeBgOffsetYNotifier.value = customOffsetY;

      _customThemeStyle = prefs.getString('customThemeStyle') ?? 'dark';
      themeModeNotifier.value = _themeMode;
      customThemeBgNotifier.value = _customThemeBg;
      customThemeBgPathNotifier.value = _customThemeBgPath;
      customThemeBgBlurNotifier.value = _customThemeBgBlur;
      customThemeBgDimNotifier.value = _customThemeBgDim;
      customThemeBgScaleNotifier.value = _customThemeBgScale;
      customThemeStyleNotifier.value = _customThemeStyle;
      playerBackgroundStyleNotifier.value =
          prefs.getString('playerBackgroundStyle') ?? 'gradient';
      playerCustomBgPathNotifier.value = prefs.getString('playerCustomBgPath');
      playerCustomBgBlurNotifier.value =
          prefs.getDouble('playerCustomBgBlur') ?? 0.0;
      playerCustomBgDimNotifier.value =
          prefs.getDouble('playerCustomBgDim') ?? 0.4;
      playerCustomBgScaleNotifier.value =
          prefs.getDouble('playerCustomBgScale') ?? 1.0;
      themeAccentPresetNotifier.value =
          prefs.getString('themeAccentPreset') ?? 'spotify';
      double playerOffsetX = prefs.getDouble('playerCustomBgOffsetX') ?? 0.0;
      double playerOffsetY = prefs.getDouble('playerCustomBgOffsetY') ?? 0.0;
      playerCustomBgOffsetXNotifier.value = playerOffsetX;
      playerCustomBgOffsetYNotifier.value = playerOffsetY;

      _audioPlayer.setSkipSilenceEnabled(_skipSilence);

      final cachedSongsStr = prefs.getString('cached_tracks_list');
      if (cachedSongsStr != null) {
        try {
          final List<dynamic> decodedList = jsonDecode(cachedSongsStr);
          final loadedTracks = decodedList
              .map((item) => Track.fromMap(Map<String, dynamic>.from(item)))
              .toList();
          if (loadedTracks.isNotEmpty) {
            _allTracks = loadedTracks;
            _playbackQueue = List.from(loadedTracks);
            _isLoading = false;
          }
        } catch (_) {}
      }
    });
  }

  void _startSleepTimer(int minutes) {
    _sleepTimer?.cancel();
    if (minutes == -1) {
      setState(() {
        _sleepAtEndOfTrack = true;
        _sleepTimerNotifier.value = -1;
      });
      return;
    }
    setState(() {
      _sleepAtEndOfTrack = false;
    });
    if (minutes <= 0) {
      _sleepTimerNotifier.value = 0;
      return;
    }
    _sleepTimerNotifier.value = minutes * 60;
    _sleepTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (_sleepTimerNotifier.value > 0) {
        _sleepTimerNotifier.value--;
        if (_sleepTimerNotifier.value <= 20) {
          final factor = (_sleepTimerNotifier.value / 20.0).clamp(0.0, 1.0);
          _audioPlayer.setVolume(factor);
        }
      } else {
        _sleepTimer?.cancel();
        _audioPlayer.pause();
        if (mounted) {
          setState(() {
            _isPlaying = false;
          });
        }
        _audioPlayer.setVolume(1.0);
      }
    });
  }

  void _updatePlayingFrom() {
    setState(() {
      if (_selectedPlaylistDetail != null) {
        _playingFromType = 'PLAYLIST';
        _playingFromName = _selectedPlaylistDetail!;
      } else if (_selectedArtistDetail != null) {
        _playingFromType = 'ARTIST';
        _playingFromName = _selectedArtistDetail!;
      } else if (_selectedAlbumDetail != null) {
        _playingFromType = 'ALBUM';
        _playingFromName = _selectedAlbumDetail!;
      } else {
        _playingFromType = 'LIBRARY';
        _playingFromName = 'All Songs';
      }
    });
  }

  Future<void> _resetAppData() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.clear();
    setState(() {
      _favoriteTrackIds.clear();
      _playCounts.clear();
      _lastPlayedTrackIds.clear();
      _userPlaylists.clear();
      _metadataOverrides.clear();
      _playlistCovers.clear();
    });
    showFlowToast(
      lookupAppLocalizations(Locale(FlowStrings.currentLang)).toastAppDataReset,
    );
    _loadSettings();
  }

  Future<void> _applyPlaybackSpeedAndPitch() async {
    try {
      if (_playbackSpeed == 1.0 && _pitchLock) {
        await _audioPlayer.setPitch(1.0);
        await _audioPlayer.setSpeed(1.0);
      } else if (_pitchLock) {
        await _audioPlayer.setPitch(1.0);
        await _audioPlayer.setSpeed(_playbackSpeed);
      } else {
        await _audioPlayer.setSpeed(_playbackSpeed);
        await _audioPlayer.setPitch(_playbackSpeed);
      }
    } catch (_) {}
  }

  void _startBatteryMonitor() {
    _batteryCheckTimer?.cancel();
    _batteryCheckTimer = Timer.periodic(const Duration(seconds: 30), (
      timer,
    ) async {
      if (_stopOnLowBattery && _audioPlayer.playing) {
        try {
          const channel = MethodChannel('com.fley.audio/equalizer');
          final result = await channel.invokeMapMethod<String, dynamic>(
            'getBatteryStatus',
          );
          if (result != null) {
            final int level = result['level'] ?? -1;
            final bool isCharging = result['isCharging'] ?? false;
            if (level != -1 && level <= 15 && !isCharging) {
              _pauseWithFade();
              showFlowToast(
                "Battery low ($level%). Playback paused.",
                isLong: true,
              );
            }
          }
        } catch (_) {}
      }
    });
  }

  Future<Color?> _getDetailColor(Track? track, {String? playlistName}) async {
    final String cacheKey = playlistName ?? (track != null ? track.id : '');
    if (cacheKey.isNotEmpty && _detailColorCache.containsKey(cacheKey)) {
      return _detailColorCache[cacheKey];
    }

    ImageProvider? provider;
    if (playlistName != null && _playlistCovers.containsKey(playlistName)) {
      provider = ResizeImage(
        FileImage(File(_playlistCovers[playlistName]!)),
        width: 64,
      );
    } else if (track != null) {
      final customPath = _metadataOverrides[track.id]?['coverPath'];
      if (customPath != null) {
        provider = ResizeImage(FileImage(File(customPath)), width: 64);
      } else {
        final artwork = await _audioQuery.queryArtwork(
          int.parse(track.id),
          ArtworkType.AUDIO,
          size: 100,
        );
        if (artwork != null) provider = MemoryImage(artwork);
      }
    }

    if (provider != null) {
      final palette = await PaletteGenerator.fromImageProvider(
        provider,
        size: const Size(40, 40),
      );
      final color =
          palette.dominantColor?.color ??
          palette.vibrantColor?.color ??
          palette.mutedColor?.color;
      if (color != null && cacheKey.isNotEmpty) {
        _detailColorCache[cacheKey] = color;
      }
      return color;
    }
    return null;
  }
}
