// ignore_for_file: invalid_use_of_protected_member, deprecated_member_use
part of '../main.dart';

extension _AudioLibraryScanLogic on _MainScreenState {
  Future<void> _requestPermissionAndScan({bool showLoading = true}) async {
    if (showLoading) {
      setState(() => _isLoading = true);
    }
    try {
      SharedPreferences prefs = await SharedPreferences.getInstance();
      List<String>? favs = prefs.getStringList('favorite_track_ids');
      List<String>? lastPlayed = prefs.getStringList('last_played_track_ids');
      String? playCountsStr = prefs.getString('play_counts');
      String? userPlaylistsStr = prefs.getString('user_playlists');
      String? playlistCoversStr = prefs.getString('playlist_covers');
      String? metadataStr = prefs.getString('metadata_overrides');

      if (favs != null) {
        _favoriteTrackIds.clear();
        _favoriteTrackIds.addAll(favs);
      }
      List<String>? hidden = prefs.getStringList('hidden_track_ids');
      if (hidden != null) {
        _hiddenTrackIds.clear();
        _hiddenTrackIds.addAll(hidden);
      }
      if (lastPlayed != null) {
        _lastPlayedTrackIds = List<String>.from(lastPlayed);
      }
      _lastPlaybackPositionMs = prefs.getInt('last_playback_position_ms') ?? 0;
      _lastPlaybackTrackId = prefs.getString('last_playback_track_id');
      List<String>? recentSearches = prefs.getStringList('recent_searched_track_ids');
      if (recentSearches != null) {
        _recentSearchedTrackIds = List<String>.from(recentSearches);
      }
      if (playCountsStr != null) {
        try {
          Map<String, dynamic> decoded = jsonDecode(playCountsStr);
          _playCounts = decoded.map((k, v) => MapEntry(k, v as int));
        } catch (_) {}
      }
      for (var entry in _playCounts.entries) {
        if (entry.value > 0 && !_lastPlayedTrackIds.contains(entry.key)) {
          _lastPlayedTrackIds.add(entry.key);
        }
      }
      if (userPlaylistsStr != null) {
        try {
          Map<String, dynamic> decoded = jsonDecode(userPlaylistsStr);
          _userPlaylists = decoded.map(
            (k, v) => MapEntry(k, List<String>.from(v)),
          );
        } catch (_) {}
      }
      if (playlistCoversStr != null) {
        try {
          Map<String, dynamic> decoded = jsonDecode(playlistCoversStr);
          _playlistCovers = decoded.map((k, v) => MapEntry(k, v.toString()));
        } catch (_) {}
      }
      if (metadataStr != null) {
        try {
          Map<String, dynamic> decoded = jsonDecode(metadataStr);
          _metadataOverrides = decoded.map(
            (k, v) => MapEntry(k, Map<String, String>.from(v)),
          );
        } catch (_) {}
      }

      final isDesktop =
          Platform.isMacOS || Platform.isWindows || Platform.isLinux;

      if (isDesktop) {
        final desktopTracks = await DesktopAudioScanner.scanAllTracks(
          filterShortAudio: _filterShortAudio,
        );
        _allTracks = desktopTracks
            .map((track) {
              String title = track.title;
              String artist = track.artist;
              String album = track.album;
              if (_metadataOverrides.containsKey(track.id)) {
                final overrides = _metadataOverrides[track.id]!;
                title = overrides['title'] ?? title;
                artist = overrides['artist'] ?? artist;
                album = overrides['album'] ?? album;
              }
              return Track(
                id: track.id,
                title: title,
                artist: artist,
                album: album,
                url: track.url,
                path: track.path,
                lyrics: track.lyrics,
                duration: track.duration,
              );
            })
            .where((t) => !_hiddenTrackIds.contains(t.id))
            .toList();

        if (_allTracks.isNotEmpty) {
          final serialized = _allTracks.map((t) => t.toMap()).toList();
          prefs.setString('cached_tracks_list', jsonEncode(serialized));
        }
      } else {
        bool permissionGranted = await _audioQuery.permissionsStatus();
        if (!permissionGranted) {
          permissionGranted = await _audioQuery.permissionsRequest();
        }

        final notificationStatus = await Permission.notification.request();
        if (!notificationStatus.isGranted) {
          if (mounted) {
            showDialog(
              context: context,
              barrierDismissible: false,
              builder: (context) => AlertDialog(
                title: const Row(
                  children: [
                    Icon(Icons.warning, color: Colors.orange),
                    SizedBox(width: 8),
                    Text("Notification Required"),
                  ],
                ),
                content: const Text(
                  "Fley needs the Notification permission to show music playback controls on your lock screen and background.\n\nPlease enable Notifications for Fley in your phone's App Settings.",
                ),
                actions: [
                  TextButton(
                    onPressed: () => Navigator.pop(context),
                    child: const Text("CANCEL"),
                  ),
                  ElevatedButton(
                    onPressed: () async {
                      Navigator.pop(context);
                      await openAppSettings();
                    },
                    child: const Text("OPEN SETTINGS"),
                  ),
                ],
              ),
            );
          }
        }

        if (permissionGranted) {
          final List<SongModel> songs = await _audioQuery.querySongs(
            sortType: SongSortType.DATE_ADDED,
            orderType: OrderType.DESC_OR_GREATER,
            uriType: UriType.EXTERNAL,
            ignoreCase: true,
          );

        if (songs.isNotEmpty) {
          var filteredSongs = songs;
          if (_filterShortAudio) {
            filteredSongs = filteredSongs
                .where((s) => (s.duration ?? 0) >= 30000)
                .toList();
          }
          if (_specificFolderScan.isNotEmpty) {
            try {
              final allowedDirs = List<String>.from(
                jsonDecode(_specificFolderScan),
              );
              if (allowedDirs.isNotEmpty) {
                filteredSongs = filteredSongs.where((song) {
                  final parentDir = _getParentDirectory(song.data);
                  return allowedDirs.contains(parentDir);
                }).toList();
              }
            } catch (_) {}
          }

          final seenPaths = <String>{};
          final seenUris = <String>{};
          final List<SongModel> deduplicatedSongs = [];

          for (final song in filteredSongs) {
            final pathKey = song.data.trim().toLowerCase();
            final uriKey = (song.uri != null && song.uri!.isNotEmpty)
                ? song.uri!
                : 'content://media/external/audio/media/${song.id}';

            if (pathKey.isNotEmpty) {
              if (seenPaths.add(pathKey)) {
                seenUris.add(uriKey);
                deduplicatedSongs.add(song);
              }
            } else if (seenUris.add(uriKey)) {
              deduplicatedSongs.add(song);
            }
          }

          _allTracks = deduplicatedSongs
              .map((song) {
                String safeUri = (song.uri != null && song.uri!.isNotEmpty)
                    ? song.uri!
                    : 'content://media/external/audio/media/${song.id}';

                String title = song.title;
                String artist =
                    (song.artist == null || song.artist == '<unknown>')
                    ? AppLocalizations.of(context).unknownArtist
                    : song.artist!;
                String album = song.album ?? 'Unknown Album';

                if (_metadataOverrides.containsKey(song.id.toString())) {
                  final overrides = _metadataOverrides[song.id.toString()]!;
                  title = overrides['title'] ?? title;
                  artist = overrides['artist'] ?? artist;
                  album = overrides['album'] ?? album;
                }

                if (_autoRegexClean &&
                    !_metadataOverrides.containsKey(song.id.toString())) {
                  final artistPrefix = RegExp(
                    '^${RegExp.escape(artist)}\\s*[-|:]\\s*',
                    caseSensitive: false,
                  );
                  if (artistPrefix.hasMatch(title)) {
                    title = title.replaceAll(artistPrefix, '');
                  }
                  final tagsToRemove = RegExp(
                    r'[\[\(](official|audio|video|lyric|lyrics|music video|official video|official audio|official lyric video|official music video)[\]\)]',
                    caseSensitive: false,
                  );
                  title = title.replaceAll(tagsToRemove, '').trim();

                  final artistSuffix = RegExp(
                    r'\s*[-|:]\s*' + RegExp.escape(artist) + r'$',
                    caseSensitive: false,
                  );
                  if (artistSuffix.hasMatch(title)) {
                    title = title.replaceAll(artistSuffix, '').trim();
                  }
                }

                return Track(
                  id: song.id.toString(),
                  title: title,
                  artist: artist,
                  album: album,
                  url: safeUri,
                  path: song.data,
                  lyrics: [
                    "Playing '$title'...",
                    "Brought to you by Fley Music,",
                    "Your premium local audio choice.",
                    "Feel the deep rhythm in your soul.",
                    "Let the notes carry you away,",
                    "Into the beautiful flow of the day.",
                    "Pure high fidelity local sound.",
                  ],
                  duration: song.duration ?? 0,
                );
              })
              .where((t) => !_hiddenTrackIds.contains(t.id))
              .toList();
          if (_allTracks.isNotEmpty) {
            final serialized = _allTracks.map((t) => t.toMap()).toList();
            prefs.setString('cached_tracks_list', jsonEncode(serialized));
          }
        }
      }
    }

      if (mounted) {
        setState(() {
          _isLoading = false;
          _cachedDetailKey = null;
        });

        if (_allTracks.isNotEmpty) {
          _playbackQueue = List.from(_allTracks);
          ArtworkCacheManager.preloadAllArtworks(
            _allTracks,
            _metadataOverrides,
          );
        }

        final autoCheck = prefs.getBool('auto_check_updates') ?? true;
        if (autoCheck) {
          _checkForUpdatesStartup();
        }
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  Future<void> _checkForUpdatesStartup() async {
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
            builder: (dialogContext) {
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
                    onPressed: () => Navigator.pop(dialogContext),
                    child: Text(
                      AppLocalizations.of(context).later,
                      style: TextStyle(
                        color: isLight ? Colors.black54 : Colors.white54,
                      ),
                    ),
                  ),
                  TextButton(
                    onPressed: () async {
                      Navigator.pop(dialogContext);
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
        }
      }
    } catch (_) {}
  }

  void _filterSongs() {
    setState(() {
      _animatedTrackIds.clear();
      _animatedPlaylistIds.clear();
      _animatedArtistIds.clear();
      _animatedAlbumIds.clear();
    });
  }

  Future<void> _updateDominantColor(Track track) async {
    try {
      final customPath = _metadataOverrides[track.id]?['coverPath'];
      ImageProvider? imageProvider;

      if (customPath != null) {
        imageProvider = ResizeImage(FileImage(File(customPath)), width: 600);
      } else {
        final artwork = await _audioQuery.queryArtwork(
          int.parse(track.id),
          ArtworkType.AUDIO,
          size: 200,
        );
        if (artwork != null) {
          imageProvider = MemoryImage(artwork);
        }
      }

      if (imageProvider != null) {
        final palette = await PaletteGenerator.fromImageProvider(imageProvider);
        if (mounted) {
          setState(() {
            _dominantColor =
                palette.dominantColor?.color ??
                palette.vibrantColor?.color ??
                palette.mutedColor?.color;
            _dominantColorNotifier.value = _dominantColor != null
                ? _ensureLuminance(_dominantColor!)
                : null;
          });
        }
      } else {
        if (mounted) {
          setState(() {
            _dominantColor = null;
            _dominantColorNotifier.value = null;
          });
        }
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _dominantColor = null;
          _dominantColorNotifier.value = null;
        });
      }
    }
  }

  Future<Uri?> _getCoverUriForTrack(
    Track track, {
    bool fetchNativeIfMissing = true,
  }) async {
    if (_metadataOverrides.containsKey(track.id) &&
        _metadataOverrides[track.id]!['coverPath'] != null) {
      final customPath = _metadataOverrides[track.id]!['coverPath']!;
      if (File(customPath).existsSync()) {
        return Uri.file(customPath);
      }
    }
    try {
      final cacheDir = await getTemporaryDirectory();
      final cacheFile = File('${cacheDir.path}/album_art_${track.id}.png');
      if (await cacheFile.exists() && (await cacheFile.length()) > 0) {
        return Uri.file(cacheFile.path);
      }

      // 1. Check memory cache first
      final memBytes = ArtworkCacheManager.getCachedArtwork(track.id);
      if (memBytes != null && memBytes.isNotEmpty) {
        await cacheFile.writeAsBytes(memBytes);
        return Uri.file(cacheFile.path);
      }

      if (!fetchNativeIfMissing) return null;

      // 2. Fetch via on_audio_query or ArtworkCacheManager
      final id = int.tryParse(track.id);
      if (id != null) {
        Uint8List? bytes = await _audioQuery.queryArtwork(
          id,
          ArtworkType.AUDIO,
          size: 500,
          quality: 85,
        );
        bytes ??= await ArtworkCacheManager.fetchAndCacheNativeArtwork(track.id);
        if (bytes != null && bytes.isNotEmpty) {
          await cacheFile.writeAsBytes(bytes);
          return Uri.file(cacheFile.path);
        }
      }
    } catch (_) {}
    return null;
  }

  void _updateCurrentSourceSilently() async {
    try {
      if (_audioPlayer.audioSource is ConcatenatingAudioSource) {
        final concatenating =
            _audioPlayer.audioSource as ConcatenatingAudioSource;
        int nextSourceIndexInConcatenating = _currentIndex > 0 ? 2 : 1;

        if (_currentIndex + 1 < _playbackQueue.length) {
          final nextTrack = _playbackQueue[_currentIndex + 1];
          final nextUri = nextTrack.url.startsWith('/')
              ? Uri.file(nextTrack.url)
              : (Uri.tryParse(nextTrack.url) ?? Uri.parse(''));
          final nextCover = await _getCoverUriForTrack(nextTrack);
          final newNextSource = AudioSource.uri(
            nextUri,
            tag: MediaItem(
              id: nextTrack.id,
              album: nextTrack.album.trim().isEmpty
                  ? 'Unknown Album'
                  : nextTrack.album,
              title: nextTrack.title.trim().isEmpty
                  ? 'Unknown Title'
                  : nextTrack.title,
              artist:
                  (nextTrack.artist.trim().isEmpty ||
                      nextTrack.artist == '<unknown>')
                  ? lookupAppLocalizations(
                      Locale(FleyStrings.currentLang),
                    ).unknownArtist
                  : nextTrack.artist,
              artUri: nextCover,
              duration: Duration(milliseconds: nextTrack.duration),
            ),
          );

          if (nextSourceIndexInConcatenating < concatenating.length) {
            await concatenating.removeAt(nextSourceIndexInConcatenating);
            await concatenating.insert(
              nextSourceIndexInConcatenating,
              newNextSource,
            );
          } else {
            await concatenating.add(newNextSource);
          }
        } else {
          if (nextSourceIndexInConcatenating < concatenating.length) {
            await concatenating.removeAt(nextSourceIndexInConcatenating);
          }
        }
      }
    } catch (_) {}
  }
}
