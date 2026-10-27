// ignore_for_file: invalid_use_of_protected_member
part of '../main.dart';

extension _HomeUI on _MainScreenState {
  Widget _buildHomeScreen() {
    return SingleChildScrollView(
      physics: const BouncingScrollPhysics(),
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          ValueListenableBuilder<bool>(
            valueListenable: showHomeBannerNotifier,
            builder: (context, showBanner, _) {
              if (!showBanner) return const SizedBox(height: 8);
              return Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const SizedBox(height: 8),
                  _buildHomeBanner(),
                  const SizedBox(height: 20),
                ],
              );
            },
          ),
          _buildQuickPinsGrid(),
          const SizedBox(height: 28),
          _buildRecentRotationSection(),
          const SizedBox(height: 28),
          _buildRecentsCarouselSection(),
          const SizedBox(height: 28),
          _buildJumpBackInSection(),
          SizedBox(height: _bottomListPadding + 20), // Dynamic padding above miniplayer + bottom navbar
        ],
      ),
    );
  }

  Widget _buildHomeBanner() {
    final isLight = isAppLight;

    return ValueListenableBuilder<String?>(
      valueListenable: homeBannerPathNotifier,
      builder: (context, bannerPath, child) {
        final hasCustom = bannerPath != null && File(bannerPath).existsSync();
        return GestureDetector(
          onTap: () => _showHomeBannerPicker(),
          child: Container(
            width: double.infinity,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(16),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: isLight ? 0.08 : 0.25),
                  blurRadius: 12,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(16),
              child: AspectRatio(
                aspectRatio: 16 / 9,
                child: hasCustom
                    ? Image.file(
                        File(bannerPath),
                        fit: BoxFit.cover,
                      )
                    : Image.asset(
                        'assets/hey.gif',
                        fit: BoxFit.cover,
                      ),
              ),
            ),
          ),
        );
      },
    );
  }

  void _showHomeBannerPicker() {
    final isLight = isAppLight;
    final cardColor = isLight ? Colors.white : const Color(0xFF161616);
    final titleColor = isLight ? const Color(0xFF1A1A1A) : Colors.white;

    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (context) {
        return Container(
          decoration: BoxDecoration(
            color: cardColor,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const SizedBox(height: 12),
              Container(
                width: 40,
                height: 5,
                decoration: BoxDecoration(
                  color: isLight
                      ? Colors.black.withValues(alpha: 0.08)
                      : Colors.white24,
                  borderRadius: BorderRadius.circular(2.5),
                ),
              ),
              const SizedBox(height: 16),
              Text(
                lookupAppLocalizations(
                  Locale(FleyStrings.currentLang),
                ).homeBanner,
                style: TextStyle(
                  color: titleColor,
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  fontFamily: getFontFamily(),
                ),
              ),
              const SizedBox(height: 16),
              ListTile(
                contentPadding:
                    const EdgeInsets.symmetric(horizontal: 24, vertical: 4),
                leading: Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    color: _activeAccentColor.withValues(alpha: 0.1),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    Icons.photo_library_outlined,
                    color: _activeAccentColor,
                    size: 20,
                  ),
                ),
                title: Text(
                  lookupAppLocalizations(
                    Locale(FleyStrings.currentLang),
                  ).changeBannerGif,
                  style: TextStyle(
                    color: titleColor,
                    fontFamily: getFontFamily(),
                  ),
                ),
                subtitle: Text(
                  lookupAppLocalizations(
                    Locale(FleyStrings.currentLang),
                  ).homeBannerDesc,
                  style: TextStyle(
                    color: isLight ? Colors.black45 : Colors.white38,
                    fontSize: 13,
                    fontFamily: getFontFamily(),
                  ),
                ),
                onTap: () async {
                  final picker = ImagePicker();
                  final image =
                      await picker.pickImage(source: ImageSource.gallery);
                  if (image != null) {
                    String? targetPath;
                    if (image.path.toLowerCase().endsWith('.gif')) {
                      final appDir = await getApplicationDocumentsDirectory();
                      final gifFile = File(
                        '${appDir.path}/home_banner_${DateTime.now().millisecondsSinceEpoch}.gif',
                      );
                      await File(image.path).copy(gifFile.path);
                      targetPath = gifFile.path;
                    } else {
                      if (!context.mounted) return;
                      targetPath = await ImageCropperUtil.cropImage(
                        context: context,
                        sourcePath: image.path,
                      );
                    }
                    if (targetPath != null) {
                      final prefs = await SharedPreferences.getInstance();
                      await prefs.setString('homeBannerPath', targetPath);
                      homeBannerPathNotifier.value = targetPath;
                      showFleyToast(
                        lookupAppLocalizations(
                          Locale(FleyStrings.currentLang),
                        ).wallpaperUpdated,
                      );
                      if (context.mounted) Navigator.pop(context);
                    }
                  }
                },
              ),
              ListTile(
                contentPadding:
                    const EdgeInsets.symmetric(horizontal: 24, vertical: 4),
                leading: Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    color: isLight
                        ? Colors.black.withValues(alpha: 0.04)
                        : Colors.white.withValues(alpha: 0.05),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    Icons.restart_alt_rounded,
                    color: isLight ? Colors.black54 : Colors.white70,
                    size: 20,
                  ),
                ),
                title: Text(
                  lookupAppLocalizations(
                    Locale(FleyStrings.currentLang),
                  ).resetDefaultBanner,
                  style: TextStyle(
                    color: titleColor,
                    fontFamily: getFontFamily(),
                  ),
                ),
                subtitle: Text(
                  lookupAppLocalizations(
                    Locale(FleyStrings.currentLang),
                  ).defaultBanner,
                  style: TextStyle(
                    color: isLight ? Colors.black45 : Colors.white38,
                    fontSize: 13,
                    fontFamily: getFontFamily(),
                  ),
                ),
                onTap: () async {
                  final prefs = await SharedPreferences.getInstance();
                  await prefs.remove('homeBannerPath');
                  homeBannerPathNotifier.value = null;
                  showFleyToast(
                    lookupAppLocalizations(
                      Locale(FleyStrings.currentLang),
                    ).wallpaperUpdated,
                  );
                  if (context.mounted) Navigator.pop(context);
                },
              ),
              ValueListenableBuilder<bool>(
                valueListenable: showHomeBannerNotifier,
                builder: (context, showBanner, _) {
                  final loc = lookupAppLocalizations(
                    Locale(FleyStrings.currentLang),
                  );
                  return ListTile(
                    contentPadding:
                        const EdgeInsets.symmetric(horizontal: 24, vertical: 4),
                    leading: Container(
                      width: 40,
                      height: 40,
                      decoration: BoxDecoration(
                        color: isLight
                            ? Colors.black.withValues(alpha: 0.04)
                            : Colors.white.withValues(alpha: 0.05),
                        shape: BoxShape.circle,
                      ),
                      child: Icon(
                        showBanner
                            ? Icons.visibility_off_outlined
                            : Icons.visibility_outlined,
                        color: isLight ? Colors.black54 : Colors.white70,
                        size: 20,
                      ),
                    ),
                    title: Text(
                      showBanner ? loc.hideBanner : loc.showBanner,
                      style: TextStyle(
                        color: titleColor,
                        fontFamily: getFontFamily(),
                      ),
                    ),
                    subtitle: Text(
                      showBanner ? loc.bannerShown : loc.bannerHidden,
                      style: TextStyle(
                        color: isLight ? Colors.black45 : Colors.white38,
                        fontSize: 13,
                        fontFamily: getFontFamily(),
                      ),
                    ),
                    onTap: () async {
                      final newStatus = !showBanner;
                      final prefs = await SharedPreferences.getInstance();
                      await prefs.setBool('showHomeBanner', newStatus);
                      showHomeBannerNotifier.value = newStatus;
                      showFleyToast(
                        newStatus ? loc.bannerShown : loc.bannerHidden,
                      );
                      if (context.mounted) Navigator.pop(context);
                    },
                  );
                },
              ),
              const SizedBox(height: 24),
            ],
          ),
        );
      },
    );
  }

  Widget _buildQuickPinsGrid() {
    final isLight = isAppLight;
    final cardBg = isLight
        ? Colors.black.withValues(alpha: 0.05)
        : const Color(0xFF282828);

    final loc = lookupAppLocalizations(Locale(FleyStrings.currentLang));
    final quickItems = [
      {
        'title': loc.mostPlayed,
        'icon': Icons.local_fire_department,
        'color': const Color(0xFFF44336),
      },
      {
        'title': loc.favourites,
        'icon': Icons.favorite,
        'color': const Color(0xFFE91E63),
      },
      {
        'title': loc.recentlyAdded,
        'icon': Icons.new_releases,
        'color': const Color(0xFF2196F3),
      },
      {
        'title': loc.forgottenGems,
        'icon': Icons.diamond_outlined,
        'color': const Color(0xFF9C27B0),
      },
    ];

    return LayoutBuilder(
      builder: (context, constraints) {
        final cardWidth = (constraints.maxWidth - 8) / 2;
        return Wrap(
          spacing: 8,
          runSpacing: 8,
          children: quickItems.map((item) {
            final title = item['title'] as String;
            final icon = item['icon'] as IconData;
            final color = item['color'] as Color;

            // Find sample track for thumbnail
            Track? sampleTrack;
            if (title == loc.favourites) {
              final favs = _allTracks.where((t) => _favoriteTrackIds.contains(t.id));
              if (favs.isNotEmpty) sampleTrack = favs.first;
            } else if (title == loc.mostPlayed) {
              final sorted = List<Track>.from(_allTracks);
              sorted.sort((a, b) => (_playCounts[b.id] ?? 0).compareTo(_playCounts[a.id] ?? 0));
              if (sorted.isNotEmpty && (_playCounts[sorted.first.id] ?? 0) > 0) {
                sampleTrack = sorted.first;
              }
            } else if (title == loc.forgottenGems) {
              final gems = _allTracks.reversed
                  .where((t) => (_playCounts[t.id] ?? 0) <= 1);
              if (gems.isNotEmpty) {
                sampleTrack = gems.first;
              } else if (_allTracks.isNotEmpty) {
                sampleTrack = _allTracks.last;
              }
            } else if (_allTracks.isNotEmpty) {
              sampleTrack = _allTracks.first;
            }

            final customCover = _playlistCovers[title];
            final hasCustomCover =
                customCover != null && File(customCover).existsSync();

            return GestureDetector(
              onTap: () {
                setState(() {
                  _selectedPlaylistDetail = title;
                  _searchQuery = '';
                  _searchController.clear();
                  _detailColorFuture = _getDetailColor(
                    sampleTrack,
                    playlistName: title,
                  );
                });
              },
              child: Container(
                width: cardWidth,
                height: 54,
                decoration: BoxDecoration(
                  color: cardBg,
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Row(
                  children: [
                    ClipRRect(
                      borderRadius: const BorderRadius.horizontal(left: Radius.circular(6)),
                      child: Container(
                        width: 54,
                        height: 54,
                        color: color.withValues(alpha: 0.15),
                        child: hasCustomCover
                            ? Image(
                                image: ResizeImage(
                                  FileImage(File(customCover)),
                                  width: 150,
                                ),
                                fit: BoxFit.cover,
                              )
                            : (sampleTrack != null
                                ? _buildTrackArtwork(sampleTrack, size: 54, radius: 0)
                                : Icon(icon, color: color, size: 24)),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        title,
                        style: TextStyle(
                          fontSize: 12.5,
                          fontWeight: FontWeight.w700,
                          color: isLight ? const Color(0xFF1A1A1A) : Colors.white,
                          fontFamily: getFontFamily(activeFontNotifier.value),
                        ),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    const SizedBox(width: 8),
                  ],
                ),
              ),
            );
          }).toList(),
        );
      },
    );
  }

  Widget _buildResumeSessionTile(Track track) {
    final isLight = isAppLight;
    final loc = lookupAppLocalizations(Locale(FleyStrings.currentLang));
    final textColor = isLight ? const Color(0xFF1A1A1A) : Colors.white;

    Duration? startPos;
    if (_lastPlaybackTrackId == track.id && _lastPlaybackPositionMs > 1500) {
      startPos = Duration(milliseconds: _lastPlaybackPositionMs);
    }

    return InkWell(
      onTap: () {
        _updatePlayingFrom();
        setState(() {
          _playbackQueue = List.from(_allTracks);
          _shuffledIndices.clear();
          _currentIndex = _playbackQueue.indexWhere((t) => t.id == track.id);
        });
        if (_currentIndex != -1) {
          _playTrack(_currentIndex, initialPosition: startPos);
          setState(() {
            _isPlayerOpen = true;
            _playerDragOffsetNotifier.value = 0.0;
          });
        }
      },
      borderRadius: BorderRadius.circular(8),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 6),
        child: Row(
          children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(6),
              child: _buildTrackArtwork(track, size: 48, radius: 0),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    track.title,
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: textColor,
                      fontFamily: getFontFamily(activeFontNotifier.value),
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 2),
                  Row(
                    children: [
                      Icon(
                        Icons.history_rounded,
                        size: 13,
                        color: _activeAccentColor,
                      ),
                      const SizedBox(width: 5),
                      Text(
                        loc.resumeSession,
                        style: TextStyle(
                          fontSize: 11.5,
                          fontWeight: FontWeight.w700,
                          color: _activeAccentColor,
                          fontFamily: getFontFamily(activeFontNotifier.value),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            GestureDetector(
              onTap: () {
                _updatePlayingFrom();
                setState(() {
                  _playbackQueue = List.from(_allTracks);
                  _shuffledIndices.clear();
                  _currentIndex = _playbackQueue.indexWhere((t) => t.id == track.id);
                });
                if (_currentIndex != -1) {
                  _playTrack(_currentIndex, initialPosition: startPos);
                }
              },
              child: Container(
                width: 32,
                height: 32,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: _activeAccentColor,
                ),
                child: Icon(
                  Icons.play_arrow_rounded,
                  size: 20,
                  color: _activeAccentColor.computeLuminance() > 0.4
                      ? Colors.black
                      : Colors.white,
                ),
              ),
            ),
            const SizedBox(width: 8),
            IconButton(
              icon: Icon(
                Icons.more_vert,
                color: isLight ? Colors.black45 : Colors.white54,
                size: 20,
              ),
              padding: EdgeInsets.zero,
              constraints: const BoxConstraints(),
              onPressed: () => _showTrackOptions(context, track),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildRecentRotationSection() {
    final isLight = isAppLight;
    final loc = lookupAppLocalizations(Locale(FleyStrings.currentLang));
    final textColor = isLight ? const Color(0xFF1A1A1A) : Colors.white;

    final trackMap = {for (var t in _allTracks) t.id: t};

    // Candidate track for Resume Playback (only before any song is loaded/played in session)
    Track? resumeTrack;
    if (_playingTrack == null && _allPlayedTrackIdsOrdered.isNotEmpty) {
      for (final id in _allPlayedTrackIdsOrdered) {
        if (trackMap.containsKey(id)) {
          resumeTrack = trackMap[id];
          break;
        }
      }
      if (resumeTrack == null && _allTracks.isNotEmpty) {
        resumeTrack = _allTracks.first;
      }
    }

    // Only show resume tile when no song is actively loaded in player
    final showResumeTile = _playingTrack == null && resumeTrack != null;

    // Filter recent rotation tracks: only past played tracks, excluding currently playing track
    final excludedId = showResumeTile ? resumeTrack.id : _playingTrack?.id;
    List<Track> recentTracks = _allPlayedTrackIdsOrdered
        .where((id) => trackMap.containsKey(id) && (excludedId == null || id != excludedId))
        .map((id) => trackMap[id]!)
        .take(4)
        .toList();

    if (recentTracks.isEmpty && _allTracks.isNotEmpty) {
      recentTracks = _allTracks
          .where((t) => excludedId == null || t.id != excludedId)
          .take(4)
          .toList();
    }

    if (!showResumeTile && recentTracks.isEmpty) return const SizedBox.shrink();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          loc.recentRotation,
          style: TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.w800,
            letterSpacing: -0.4,
            color: textColor,
            fontFamily: getFontFamily(activeFontNotifier.value),
          ),
        ),
        const SizedBox(height: 12),
        AnimatedSwitcher(
          duration: const Duration(milliseconds: 300),
          switchOutCurve: Curves.easeOutCubic,
          transitionBuilder: (child, animation) {
            return FadeTransition(
              opacity: animation,
              child: SizeTransition(
                sizeFactor: animation,
                child: child,
              ),
            );
          },
          child: showResumeTile
              ? KeyedSubtree(
                  key: const ValueKey('resume_session_tile'),
                  child: _buildResumeSessionTile(resumeTrack),
                )
              : const SizedBox.shrink(key: ValueKey('empty_resume')),
        ),
        ...recentTracks.map((track) {
          return InkWell(
            onTap: () {
              _updatePlayingFrom();
              setState(() {
                _playbackQueue = List.from(_allTracks);
                _shuffledIndices.clear();
                _currentIndex = _playbackQueue.indexWhere((t) => t.id == track.id);
              });
              if (_currentIndex != -1) {
                _playTrack(_currentIndex);
              }
            },
            borderRadius: BorderRadius.circular(8),
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 6),
              child: Row(
                children: [
                  ClipRRect(
                    borderRadius: BorderRadius.circular(6),
                    child: _buildTrackArtwork(track, size: 48, radius: 0),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          track.title,
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                            color: textColor,
                            fontFamily: getFontFamily(activeFontNotifier.value),
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        const SizedBox(height: 2),
                        Text(
                          track.artist,
                          style: TextStyle(
                            fontSize: 12,
                            color: isLight ? Colors.black54 : Colors.white54,
                            fontFamily: getFontFamily(activeFontNotifier.value),
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ),
                  ),
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        _formatDuration(
                          Duration(milliseconds: track.duration),
                        ),
                        style: TextStyle(
                          color: isLight ? Colors.black45 : Colors.white38,
                          fontSize: 12,
                          fontFeatures: const [
                            FontFeature.tabularFigures(),
                          ],
                        ),
                      ),
                      const SizedBox(width: 8),
                      IconButton(
                        icon: Icon(
                          Icons.more_vert,
                          color: isLight ? Colors.black45 : Colors.white54,
                          size: 20,
                        ),
                        padding: EdgeInsets.zero,
                        constraints: const BoxConstraints(),
                        onPressed: () => _showTrackOptions(context, track),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          );
        }),
      ],
    );
  }

  Widget _buildRecentsCarouselSection() {
    final isLight = isAppLight;
    final textColor = isLight ? const Color(0xFF1A1A1A) : Colors.white;

    // Collect playlists and albums
    final loc = lookupAppLocalizations(Locale(FleyStrings.currentLang));
    List<Map<String, dynamic>> items = [];

    // User playlists
    for (var name in _userPlaylists.keys) {
      final pSongs = _userPlaylists[name]!;
      items.add({
        'type': 'playlist',
        'title': name,
        'subtitle': '${loc.playlist} • ${pSongs.length} ${loc.songsCount}',
        'coverPath': _playlistCovers[name],
        'sampleTrack': pSongs.isNotEmpty
            ? _allTracks.firstWhere((t) => t.id == pSongs.first, orElse: () => _allTracks.first)
            : null,
      });
    }

    // System playlists
    items.add({
      'type': 'playlist',
      'title': loc.favourites,
      'subtitle': 'Playlist • ${_favoriteTrackIds.length} songs',
      'coverPath': _playlistCovers[loc.favourites],
      'sampleTrack': _favoriteTrackIds.isNotEmpty
          ? _allTracks.firstWhere((t) => _favoriteTrackIds.contains(t.id), orElse: () => _allTracks.first)
          : null,
    });
    items.add({
      'type': 'playlist',
      'title': loc.mostPlayed,
      'subtitle': 'Playlist',
      'coverPath': _playlistCovers[loc.mostPlayed],
      'sampleTrack': _allTracks.isNotEmpty ? _allTracks.first : null,
    });

    // Recent albums
    Set<String> seenAlbums = {};
    for (var track in _allTracks) {
      if (track.album.isNotEmpty && seenAlbums.add(track.album)) {
        items.add({
          'type': 'album',
          'title': track.album,
          'subtitle': '${loc.album} • ${track.artist}',
          'sampleTrack': track,
        });
        if (seenAlbums.length >= 6) break;
      }
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          loc.recents,
          style: TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.w800,
            letterSpacing: -0.4,
            color: textColor,
            fontFamily: getFontFamily(activeFontNotifier.value),
          ),
        ),
        const SizedBox(height: 12),
        SizedBox(
          height: 195,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            physics: const BouncingScrollPhysics(),
            itemCount: items.length,
            separatorBuilder: (_, _) => const SizedBox(width: 14),
            itemBuilder: (context, index) {
              final item = items[index];
              final title = item['title'] as String;
              final subtitle = item['subtitle'] as String;
              final type = item['type'] as String;
              final Track? sampleTrack = item['sampleTrack'];
              final String? coverPath = item['coverPath'];

              return GestureDetector(
                onTap: () {
                  setState(() {
                    if (type == 'album') {
                      _selectedAlbumDetail = title;
                    } else {
                      _selectedPlaylistDetail = title;
                    }
                    _searchQuery = '';
                    _searchController.clear();
                    _detailColorFuture = _getDetailColor(
                      sampleTrack,
                      playlistName: type == 'album' ? null : title,
                    );
                  });
                },
                child: SizedBox(
                  width: 136,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Container(
                        width: 136,
                        height: 136,
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(8),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withValues(alpha: isLight ? 0.08 : 0.3),
                              blurRadius: 10,
                              offset: const Offset(0, 4),
                            ),
                          ],
                        ),
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(8),
                          child: coverPath != null && File(coverPath).existsSync()
                              ? Image(
                                  image: ResizeImage(FileImage(File(coverPath)), width: 300),
                                  fit: BoxFit.cover,
                                )
                              : sampleTrack != null
                                  ? _buildTrackArtwork(sampleTrack, size: 136, radius: 0)
                                  : Container(
                                      color: const Color(0xFF2A2A2A),
                                      child: const Icon(Icons.music_note, color: Colors.white54, size: 40),
                                    ),
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        title,
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w700,
                          color: textColor,
                          fontFamily: getFontFamily(activeFontNotifier.value),
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 2),
                      Text(
                        subtitle,
                        style: TextStyle(
                          fontSize: 11,
                          color: isLight ? Colors.black54 : Colors.white54,
                          fontFamily: getFontFamily(activeFontNotifier.value),
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),
              );
            },
          ),
        ),
      ],
    );
  }

  Widget _buildJumpBackInSection() {
    final isLight = isAppLight;
    final loc = lookupAppLocalizations(Locale(FleyStrings.currentLang));
    final textColor = isLight ? const Color(0xFF1A1A1A) : Colors.white;

    // Artists with tracks
    Map<String, List<Track>> artistMap = {};
    for (var track in _allTracks) {
      if (track.artist.isNotEmpty) {
        artistMap.putIfAbsent(track.artist, () => []).add(track);
      }
    }

    final topArtists = artistMap.keys.take(6).toList();
    if (topArtists.isEmpty) return const SizedBox.shrink();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          loc.jumpBackIn,
          style: TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.w800,
            letterSpacing: -0.4,
            color: textColor,
            fontFamily: getFontFamily(activeFontNotifier.value),
          ),
        ),
        const SizedBox(height: 12),
        SizedBox(
          height: 175,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            physics: const BouncingScrollPhysics(),
            itemCount: topArtists.length,
            separatorBuilder: (_, _) => const SizedBox(width: 14),
            itemBuilder: (context, index) {
              final artist = topArtists[index];
              final tracks = artistMap[artist]!;

              return GestureDetector(
                onTap: () {
                  setState(() {
                    _selectedArtistDetail = artist;
                    _searchQuery = '';
                    _searchController.clear();
                    _detailColorFuture = _getDetailColor(tracks.first);
                  });
                },
                child: SizedBox(
                  width: 120,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      Container(
                        width: 120,
                        height: 120,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withValues(alpha: isLight ? 0.08 : 0.3),
                              blurRadius: 10,
                              offset: const Offset(0, 4),
                            ),
                          ],
                        ),
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(60),
                          child: _buildTrackArtwork(tracks.first, size: 120, radius: 60),
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        artist,
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w700,
                          color: textColor,
                          fontFamily: getFontFamily(activeFontNotifier.value),
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 2),
                      Text(
                        loc.artist,
                        style: TextStyle(
                          fontSize: 11,
                          color: isLight ? Colors.black54 : Colors.white54,
                          fontFamily: getFontFamily(activeFontNotifier.value),
                        ),
                        textAlign: TextAlign.center,
                      ),
                    ],
                  ),
                ),
              );
            },
          ),
        ),
      ],
    );
  }
}
