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
          const SizedBox(height: 8),
          _buildHomeBanner(),
          const SizedBox(height: 20),
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

    return Container(
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
          child: Image.asset(
            'assets/hey.gif',
            fit: BoxFit.cover,
          ),
        ),
      ),
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

  Widget _buildRecentRotationSection() {
    final isLight = isAppLight;
    final textColor = isLight ? const Color(0xFF1A1A1A) : Colors.white;

    final trackMap = {for (var t in _allTracks) t.id: t};
    List<Track> recentTracks = _allPlayedTrackIdsOrdered
        .where((id) => trackMap.containsKey(id))
        .map((id) => trackMap[id]!)
        .take(4)
        .toList();

    if (recentTracks.isEmpty && _allTracks.isNotEmpty) {
      recentTracks = _allTracks.take(4).toList();
    }

    if (recentTracks.isEmpty) return const SizedBox.shrink();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Your recent rotation',
          style: TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.w800,
            letterSpacing: -0.4,
            color: textColor,
            fontFamily: getFontFamily(activeFontNotifier.value),
          ),
        ),
        const SizedBox(height: 12),
        ...recentTracks.map((track) {
          final isPlayingThis = _playingTrack?.id == track.id;

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
                            color: isPlayingThis ? _activeAccentColor : textColor,
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
                      if (isPlayingThis)
                        SizedBox(
                          width: 16,
                          height: 14,
                          child: MiniMusicVisualizer(
                            color: _activeAccentColor,
                            width: 4,
                            height: 14,
                            radius: 2,
                            animate: _isPlaying,
                          ),
                        )
                      else
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
        'subtitle': 'Playlist • ${pSongs.length} songs',
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
          'subtitle': 'Album • ${track.artist}',
          'sampleTrack': track,
        });
        if (seenAlbums.length >= 6) break;
      }
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Recents',
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
          'Jump back in',
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
                        'Artist',
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
