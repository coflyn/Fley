// ignore_for_file: invalid_use_of_protected_member
part of '../main.dart';

extension _TabsUI on _MainScreenState {
  double get _bottomListPadding {
    final isDetailView = _selectedPlaylistDetail != null ||
        _selectedArtistDetail != null ||
        _selectedAlbumDetail != null;
    final double bottomInset = MediaQuery.of(context).padding.bottom;
    final navPadding = isDetailView ? 0.0 : 64.0;
    return navPadding + bottomInset + (_playingTrack != null ? 88.0 : 24.0);
  }

  Widget _buildBodyContent() {
    if (_allTracks.isEmpty) {
      return _buildEmptyState();
    }

    final isDetailView =
        (_currentPageIndex == 1 && _selectedPlaylistDetail != null) ||
        (_currentPageIndex == 2 && _selectedArtistDetail != null) ||
        (_currentPageIndex == 3 && _selectedAlbumDetail != null);

    return PageView(
      controller: _pageController,
      physics: isDetailView
          ? const NeverScrollableScrollPhysics()
          : const BouncingScrollPhysics(),
      onPageChanged: (index) {
        setState(() {
          _currentPageIndex = index;
        });
      },
      children: [
        _KeepAliveWrapper(child: _buildSongsTab()),
        _KeepAliveWrapper(child: _buildPlaylistsTab()),
        _KeepAliveWrapper(child: _buildArtistsTab()),
        _KeepAliveWrapper(child: _buildAlbumsTab()),
      ],
    );
  }

  Widget _buildSongsTab() {
    List<Track> allSorted = List<Track>.from(_allTracks);

    if (_sortBy == 'title') {
      allSorted.sort(
        (a, b) => a.title.toLowerCase().compareTo(b.title.toLowerCase()),
      );
    } else if (_sortBy == 'artist') {
      allSorted.sort(
        (a, b) => a.artist.toLowerCase().compareTo(b.artist.toLowerCase()),
      );
    } else if (_sortBy == 'album') {
      allSorted.sort(
        (a, b) => a.album.toLowerCase().compareTo(b.album.toLowerCase()),
      );
    } else if (_sortBy == 'date_oldest') {
      allSorted = allSorted.reversed.toList();
    } else if (_sortBy == 'duration_longest') {
      allSorted.sort((a, b) => b.duration.compareTo(a.duration));
    } else if (_sortBy == 'duration_shortest') {
      allSorted.sort((a, b) => a.duration.compareTo(b.duration));
    }

    List<Track> displayed = allSorted;
    if (_searchQuery.isNotEmpty) {
      displayed = allSorted
          .where(
            (t) =>
                t.title.toLowerCase().contains(_searchQuery.toLowerCase()) ||
                t.artist.toLowerCase().contains(_searchQuery.toLowerCase()) ||
                t.album.toLowerCase().contains(_searchQuery.toLowerCase()),
          )
          .toList();
    }

    return _buildSongList(
      displayed,
      fullQueueList: _searchQuery.isNotEmpty ? allSorted : null,
    );
  }

  Widget _buildPlaylistsTab() {
    final favorites = _allTracks
        .where((t) => _favoriteTrackIds.contains(t.id))
        .toList();
    final recentlyAdded = List<Track>.from(_allTracks);
    final trackMap = {for (var t in _allTracks) t.id: t};
    final lastPlayed = _allPlayedTrackIdsOrdered
        .where((id) => trackMap.containsKey(id))
        .map((id) => trackMap[id]!)
        .toList();
    var mostPlayed = List<Track>.from(_allTracks);
    mostPlayed.sort(
      (a, b) => (_playCounts[b.id] ?? 0).compareTo(_playCounts[a.id] ?? 0),
    );
    mostPlayed = mostPlayed.where((t) => (_playCounts[t.id] ?? 0) > 0).toList();
    final forgottenGems = _allTracks.reversed
        .where((t) => (_playCounts[t.id] ?? 0) <= 1)
        .toList();

    final children = [
      ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
        leading: Container(
          width: 56,
          height: 56,
          decoration: BoxDecoration(
            color: _activeAccentColor.withValues(alpha: 0.2),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Icon(Icons.add, color: _activeAccentColor),
        ),
        title: Text(
          AppLocalizations.of(context).createNewPlaylist,
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w600,
            color: _activeAccentColor,
          ),
        ),
        onTap: () => _showCreatePlaylistModal(context),
      ),
      _buildPlaylistCard(
        AppLocalizations.of(context).favourites,
        favorites,
        const Color(0xFFE91E63),
        Icons.favorite,
      ),
      _buildPlaylistCard(
        AppLocalizations.of(context).recentlyAdded,
        recentlyAdded,
        const Color(0xFF2196F3),
        Icons.new_releases,
      ),
      _buildPlaylistCard(
        AppLocalizations.of(context).lastPlayed,
        lastPlayed,
        const Color(0xFFFF9800),
        Icons.history,
      ),
      _buildPlaylistCard(
        AppLocalizations.of(context).mostPlayed,
        mostPlayed,
        const Color(0xFFF44336),
        Icons.local_fire_department,
      ),
      _buildPlaylistCard(
        AppLocalizations.of(context).forgottenGems,
        forgottenGems,
        const Color(0xFF9C27B0),
        Icons.diamond_outlined,
      ),
      if (_userPlaylists.isNotEmpty)
        Padding(
          padding: const EdgeInsets.only(top: 16, bottom: 8, left: 8),
          child: Text(
            AppLocalizations.of(context).myPlaylists,
            style: TextStyle(
              color: isAppLight ? const Color(0xFF1A1A1A) : Colors.white,
              fontSize: 18,
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
      ..._userPlaylists.entries.map((entry) {
        final songs = _allTracks
            .where((t) => entry.value.contains(t.id))
            .toList();
        return _buildPlaylistCard(
          entry.key,
          songs,
          const Color(0xFF9C27B0),
          Icons.queue_music,
        );
      }),
    ];

    return ListView.builder(
      physics: const BouncingScrollPhysics(),
      padding: EdgeInsets.only(
        left: 16,
        right: 16,
        top: 12,
        bottom: _bottomListPadding,
      ),
      itemCount: children.length,
      itemBuilder: (context, index) {
        final keyStr = "playlist_$index";
        final shouldAnimate = !_animatedPlaylistIds.contains(keyStr);
        final count = _animatedPlaylistIds.length;
        final staggerIndex = count < 8 ? count : 0;
        if (shouldAnimate) {
          _animatedPlaylistIds.add(keyStr);
        }
        return _FadeInSlideUp(
          animate: shouldAnimate,
          delay: Duration(milliseconds: staggerIndex * 35),
          child: children[index],
        );
      },
    );
  }

  Widget _buildArtistsTab() {
    final key = "artists_$_artistsAnimToken";
    final bool shouldAnimateTab = !_visitedTabKeys.contains(key);
    if (shouldAnimateTab) {
      _visitedTabKeys.add(key);
    }

    final List<Track> activeTrackPool = _allTracks;

    if (_memoArtistTracksMap == null ||
        _memoArtistPoolLen != activeTrackPool.length ||
        _memoArtistSortBy != _sortBy ||
        _memoArtistSearchQuery != _searchQuery) {
      final Map<String, List<Track>> artistTracksMap = {};
      for (final t in activeTrackPool) {
        if (t.artist.isNotEmpty && t.artist != '<unknown>') {
          (artistTracksMap[t.artist] ??= []).add(t);
        }
      }

      final List<String> artists = [];
      final seenArtists = <String>{};

      if (_sortBy == 'date') {
        for (final t in activeTrackPool) {
          if (t.artist.isNotEmpty &&
              t.artist != '<unknown>' &&
              seenArtists.add(t.artist)) {
            artists.add(t.artist);
          }
        }
      } else if (_sortBy == 'date_oldest') {
        for (final t in activeTrackPool.reversed) {
          if (t.artist.isNotEmpty &&
              t.artist != '<unknown>' &&
              seenArtists.add(t.artist)) {
            artists.add(t.artist);
          }
        }
      } else if (_sortBy == 'duration_longest') {
        final Map<String, int> maxDuration = {};
        for (final t in activeTrackPool) {
          final current = maxDuration[t.artist] ?? 0;
          if (t.duration > current) {
            maxDuration[t.artist] = t.duration;
          }
        }
        final allUnique = artistTracksMap.keys.toList();
        allUnique.sort(
          (a, b) => (maxDuration[b] ?? 0).compareTo(maxDuration[a] ?? 0),
        );
        artists.addAll(allUnique);
      } else if (_sortBy == 'duration_shortest') {
        final Map<String, int> minDuration = {};
        for (final t in activeTrackPool) {
          final current = minDuration[t.artist] ?? 99999999;
          if (t.duration < current) {
            minDuration[t.artist] = t.duration;
          }
        }
        final allUnique = artistTracksMap.keys.toList();
        allUnique.sort(
          (a, b) => (minDuration[a] ?? 0).compareTo(minDuration[b] ?? 0),
        );
        artists.addAll(allUnique);
      } else {
        final allUnique = artistTracksMap.keys.toList()
          ..sort((a, b) => a.toLowerCase().compareTo(b.toLowerCase()));
        artists.addAll(allUnique);
      }

      if (_searchQuery.isNotEmpty) {
        artists.retainWhere(
          (a) => a.toLowerCase().contains(_searchQuery.toLowerCase()),
        );
      }

      final List<MapEntry<String, int>> topArtistCounts = [];
      artistTracksMap.forEach((name, tracks) {
        topArtistCounts.add(MapEntry(name, tracks.length));
      });
      topArtistCounts.sort((a, b) => b.value.compareTo(a.value));
      final topArtistsList = topArtistCounts.take(8).map((e) => e.key).toList();

      _memoArtistTracksMap = artistTracksMap;
      _memoArtistsList = artists;
      _memoTopArtistsList = topArtistsList;
      _memoArtistSortBy = _sortBy;
      _memoArtistSearchQuery = _searchQuery;
      _memoArtistPoolLen = activeTrackPool.length;
    }

    final artistTracksMap = _memoArtistTracksMap!;
    final artists = _memoArtistsList!;
    final topArtistsList = _memoTopArtistsList!;

    final isLight = isAppLight;
    final textColor = isLight ? const Color(0xFF1A1A1A) : Colors.white;
    final subtextColor = isLight ? Colors.black54 : Colors.white54;

    return _FadeInSlideUp(
      key: ValueKey(key),
      animate: shouldAnimateTab,
      delay: Duration.zero,
      child: Column(
        children: [
          // Sub-header with artist count & Grid/List layout switcher
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 8),
            child: Row(
              children: [
                Text(
                  '${artists.length} ${AppLocalizations.of(context).artist}',
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: subtextColor,
                  ),
                ),
                const Spacer(),
                Material(
                  color: Colors.transparent,
                  child: InkWell(
                    borderRadius: BorderRadius.circular(8),
                    onTap: () {
                      setState(() {
                        _artistViewMode = _artistViewMode == 'grid'
                            ? 'list'
                            : 'grid';
                      });
                    },
                    child: Container(
                      padding: const EdgeInsets.all(6),
                      decoration: BoxDecoration(
                        color: isLight
                            ? Colors.black.withValues(alpha: 0.05)
                            : Colors.white.withValues(alpha: 0.08),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Icon(
                        _artistViewMode == 'grid'
                            ? Icons.view_list_rounded
                            : Icons.grid_view_rounded,
                        size: 18,
                        color: _activeAccentColor,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),

          // Expanded Artist List/Grid Content
          Expanded(
            child: CustomScrollView(
              physics: const BouncingScrollPhysics(),
              slivers: [
                // Top Artists Carousel (when search is empty & >= 3 top artists exist)
                if (_searchQuery.isEmpty && topArtistsList.length >= 3)
                  SliverToBoxAdapter(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Padding(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 24,
                            vertical: 4,
                          ),
                          child: Text(
                            'Top Artists',
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                              color: textColor,
                              letterSpacing: -0.3,
                            ),
                          ),
                        ),
                        const SizedBox(height: 10),
                        SizedBox(
                          height: 140,
                          child: ListView.separated(
                            padding: const EdgeInsets.symmetric(horizontal: 24),
                            scrollDirection: Axis.horizontal,
                            itemCount: topArtistsList.length,
                            separatorBuilder: (_, _) => const SizedBox(width: 16),
                            itemBuilder: (context, index) {
                              final artistName = topArtistsList[index];
                              final artistSongs = artistTracksMap[artistName] ?? [];
                              final count = artistSongs.length;
                              final firstTrack = artistSongs.isNotEmpty
                                  ? artistSongs.first
                                  : Track(
                                      id: '',
                                      title: '',
                                      artist: artistName,
                                      album: '',
                                      url: '',
                                      path: '',
                                      lyrics: const [],
                                      duration: 0,
                                    );

                              return GestureDetector(
                                onTap: () {
                                  setState(() {
                                    _selectedArtistDetail = artistName;
                                    _searchQuery = '';
                                    _searchController.clear();
                                    _detailColorFuture = _getDetailColor(
                                      artistSongs.isNotEmpty
                                          ? artistSongs.first
                                          : null,
                                    );
                                  });
                                },
                                child: Column(
                                  children: [
                                    Container(
                                      padding: const EdgeInsets.all(3),
                                      decoration: BoxDecoration(
                                        shape: BoxShape.circle,
                                        border: Border.all(
                                          color: _activeAccentColor.withValues(
                                            alpha: 0.6,
                                          ),
                                          width: 2,
                                        ),
                                      ),
                                      child: _buildTrackArtwork(
                                        firstTrack,
                                        size: 76,
                                        radius: 38,
                                      ),
                                    ),
                                    const SizedBox(height: 6),
                                    SizedBox(
                                      width: 84,
                                      child: Text(
                                        artistName,
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                        textAlign: TextAlign.center,
                                        style: TextStyle(
                                          fontWeight: FontWeight.bold,
                                          fontSize: 12,
                                          color: textColor,
                                        ),
                                      ),
                                    ),
                                    const SizedBox(height: 2),
                                    Text(
                                      '$count ${AppLocalizations.of(context).songsCount}',
                                      style: TextStyle(
                                        fontSize: 11,
                                        color: subtextColor,
                                      ),
                                    ),
                                  ],
                                ),
                              );
                            },
                          ),
                        ),
                        const SizedBox(height: 12),
                        Padding(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 24,
                            vertical: 4,
                          ),
                          child: Text(
                            'All Artists',
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                              color: textColor,
                              letterSpacing: -0.3,
                            ),
                          ),
                        ),
                        const SizedBox(height: 8),
                      ],
                    ),
                  ),

                // Grid View OR List View rendering with zero-overhead viewport virtualization
                if (_artistViewMode == 'grid')
                  SliverPadding(
                    padding: EdgeInsets.only(
                      left: 24,
                      right: 24,
                      bottom: _bottomListPadding,
                    ),
                    sliver: SliverGrid(
                      gridDelegate:
                          const SliverGridDelegateWithFixedCrossAxisCount(
                            crossAxisCount: 2,
                            childAspectRatio: 0.88,
                            crossAxisSpacing: 14,
                            mainAxisSpacing: 14,
                          ),
                      delegate: SliverChildBuilderDelegate(
                        (context, index) {
                          final artist = artists[index];
                          final artistSongs = artistTracksMap[artist] ?? [];
                          final songCount = artistSongs.length;
                          final firstTrack = artistSongs.isNotEmpty
                              ? artistSongs.first
                              : Track(
                                  id: '',
                                  title: '',
                                  artist: artist,
                                  album: '',
                                  url: '',
                                  path: '',
                                  lyrics: const [],
                                  duration: 0,
                                );
                          final bool shouldAnimate = index < 8 &&
                              !_animatedArtistIds.contains(artist);
                          if (shouldAnimate) {
                            _animatedArtistIds.add(artist);
                          }

                          return _FadeInSlideUp(
                            animate: shouldAnimate,
                            delay: Duration(milliseconds: index * 35),
                            child: GestureDetector(
                              onTap: () {
                                setState(() {
                                  _selectedArtistDetail = artist;
                                  _searchQuery = '';
                                  _searchController.clear();
                                  _detailColorFuture = _getDetailColor(
                                    artistSongs.isNotEmpty
                                        ? artistSongs.first
                                        : null,
                                  );
                                });
                              },
                              child: Container(
                                padding: const EdgeInsets.all(12),
                                decoration: BoxDecoration(
                                  color: isLight
                                      ? Colors.white
                                      : const Color(0xFF1B1B1E),
                                  borderRadius: BorderRadius.circular(18),
                                  border: Border.all(
                                    color: isLight
                                        ? Colors.black.withValues(alpha: 0.04)
                                        : Colors.white.withValues(alpha: 0.05),
                                  ),
                                  boxShadow: [
                                    BoxShadow(
                                      color: Colors.black.withValues(
                                        alpha: isLight ? 0.03 : 0.2,
                                      ),
                                      blurRadius: 8,
                                      offset: const Offset(0, 3),
                                    ),
                                  ],
                                ),
                                child: Column(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    _buildTrackArtwork(
                                      firstTrack,
                                      size: 92,
                                      radius: 46,
                                    ),
                                    const SizedBox(height: 10),
                                    Text(
                                      artist,
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                      textAlign: TextAlign.center,
                                      style: TextStyle(
                                        fontWeight: FontWeight.bold,
                                        fontSize: 14,
                                        color: textColor,
                                      ),
                                    ),
                                    const SizedBox(height: 2),
                                    Text(
                                      '$songCount ${AppLocalizations.of(context).songsCount}',
                                      style: TextStyle(
                                        color: subtextColor,
                                        fontSize: 12,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          );
                        },
                        childCount: artists.length,
                      ),
                    ),
                  )
                else
                  SliverPadding(
                    padding: EdgeInsets.only(
                      left: 24,
                      right: 24,
                      bottom: _bottomListPadding,
                    ),
                    sliver: SliverList(
                      delegate: SliverChildBuilderDelegate(
                        (context, index) {
                          final artist = artists[index];
                          final artistSongs = artistTracksMap[artist] ?? [];
                          final songCount = artistSongs.length;
                          final firstTrack = artistSongs.isNotEmpty
                              ? artistSongs.first
                              : Track(
                                  id: '',
                                  title: '',
                                  artist: artist,
                                  album: '',
                                  url: '',
                                  path: '',
                                  lyrics: const [],
                                  duration: 0,
                                );
                          final bool shouldAnimate = index < 8 &&
                              !_animatedArtistIds.contains(artist);
                          if (shouldAnimate) {
                            _animatedArtistIds.add(artist);
                          }

                          return _FadeInSlideUp(
                            animate: shouldAnimate,
                            delay: Duration(milliseconds: index * 35),
                            child: ListTile(
                              contentPadding: const EdgeInsets.symmetric(
                                vertical: 4,
                              ),
                              onTap: () {
                                setState(() {
                                  _selectedArtistDetail = artist;
                                  _searchQuery = '';
                                  _searchController.clear();
                                  _detailColorFuture = _getDetailColor(
                                    artistSongs.isNotEmpty
                                        ? artistSongs.first
                                        : null,
                                  );
                                });
                              },
                              leading: _buildTrackArtwork(
                                firstTrack,
                                size: 48,
                                radius: 24,
                              ),
                              title: Text(
                                artist,
                                style: TextStyle(
                                  fontWeight: FontWeight.w600,
                                  fontSize: 15,
                                  color: textColor,
                                ),
                              ),
                              subtitle: Text(
                                '$songCount ${AppLocalizations.of(context).songsCount}',
                                style: TextStyle(
                                  color: subtextColor,
                                  fontSize: 12,
                                ),
                              ),
                              trailing: Icon(
                                Icons.arrow_forward_ios,
                                color: isLight ? Colors.black26 : Colors.white24,
                                size: 14,
                              ),
                            ),
                          );
                        },
                        childCount: artists.length,
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  bool _isValidAlbumName(String albumName) {
    final l = albumName.toLowerCase().trim();
    return l.isNotEmpty &&
        l != '<unknown>' &&
        l != 'unknown' &&
        l != 'unknown album' &&
        l != 'single' &&
        l != 'singles';
  }

  Widget _buildAlbumsTab() {
    final key = "albums_$_albumsAnimToken";
    final bool shouldAnimateTab = !_visitedTabKeys.contains(key);
    if (shouldAnimateTab) {
      _visitedTabKeys.add(key);
    }

    final List<Track> activeTrackPool = _allTracks;

    if (_memoAlbumTracksMap == null ||
        _memoAlbumPoolLen != activeTrackPool.length ||
        _memoAlbumSortBy != _sortBy ||
        _memoAlbumSearchQuery != _searchQuery) {
      final Map<String, List<Track>> albumTracksMap = {};
      for (final t in activeTrackPool) {
        if (_isValidAlbumName(t.album)) {
          (albumTracksMap[t.album] ??= []).add(t);
        }
      }

      final List<String> albums = [];
      final seenAlbums = <String>{};

      if (_sortBy == 'date') {
        for (final t in activeTrackPool) {
          if (_isValidAlbumName(t.album) && seenAlbums.add(t.album)) {
            albums.add(t.album);
          }
        }
      } else if (_sortBy == 'date_oldest') {
        for (final t in activeTrackPool.reversed) {
          if (_isValidAlbumName(t.album) && seenAlbums.add(t.album)) {
            albums.add(t.album);
          }
        }
      } else if (_sortBy == 'duration_longest') {
        final Map<String, int> maxDuration = {};
        for (final t in activeTrackPool) {
          final current = maxDuration[t.album] ?? 0;
          if (t.duration > current) {
            maxDuration[t.album] = t.duration;
          }
        }
        final allUnique = albumTracksMap.keys.toList();
        allUnique.sort(
          (a, b) => (maxDuration[b] ?? 0).compareTo(maxDuration[a] ?? 0),
        );
        albums.addAll(allUnique);
      } else if (_sortBy == 'duration_shortest') {
        final Map<String, int> minDuration = {};
        for (final t in activeTrackPool) {
          final current = minDuration[t.album] ?? 99999999;
          if (t.duration < current) {
            minDuration[t.album] = t.duration;
          }
        }
        final allUnique = albumTracksMap.keys.toList();
        allUnique.sort(
          (a, b) => (minDuration[a] ?? 0).compareTo(minDuration[b] ?? 0),
        );
        albums.addAll(allUnique);
      } else {
        final allUnique = albumTracksMap.keys.toList()
          ..sort((a, b) => a.toLowerCase().compareTo(b.toLowerCase()));
        albums.addAll(allUnique);
      }

      if (_searchQuery.isNotEmpty) {
        albums.retainWhere(
          (a) => a.toLowerCase().contains(_searchQuery.toLowerCase()),
        );
      }

      final List<MapEntry<String, int>> topAlbumCounts = [];
      albumTracksMap.forEach((name, tracks) {
        topAlbumCounts.add(MapEntry(name, tracks.length));
      });
      topAlbumCounts.sort((a, b) => b.value.compareTo(a.value));
      final topAlbumsList = topAlbumCounts.take(8).map((e) => e.key).toList();

      _memoAlbumTracksMap = albumTracksMap;
      _memoAlbumsList = albums;
      _memoTopAlbumsList = topAlbumsList;
      _memoAlbumSortBy = _sortBy;
      _memoAlbumSearchQuery = _searchQuery;
      _memoAlbumPoolLen = activeTrackPool.length;
    }

    final albumTracksMap = _memoAlbumTracksMap!;
    final albums = _memoAlbumsList!;
    final topAlbumsList = _memoTopAlbumsList!;

    final isLight = isAppLight;
    final textColor = isLight ? const Color(0xFF1A1A1A) : Colors.white;
    final subtextColor = isLight ? Colors.black54 : Colors.white54;

    return _FadeInSlideUp(
      key: ValueKey(key),
      animate: shouldAnimateTab,
      delay: Duration.zero,
      child: Column(
        children: [
          // Sub-header with album count & Grid/List layout switcher
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 8),
            child: Row(
              children: [
                Text(
                  '${albums.length} ${AppLocalizations.of(context).album}',
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: subtextColor,
                  ),
                ),
                const Spacer(),
                Material(
                  color: Colors.transparent,
                  child: InkWell(
                    borderRadius: BorderRadius.circular(8),
                    onTap: () {
                      setState(() {
                        _albumViewMode = _albumViewMode == 'grid'
                            ? 'list'
                            : 'grid';
                      });
                    },
                    child: Container(
                      padding: const EdgeInsets.all(6),
                      decoration: BoxDecoration(
                        color: isLight
                            ? Colors.black.withValues(alpha: 0.05)
                            : Colors.white.withValues(alpha: 0.08),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Icon(
                        _albumViewMode == 'grid'
                            ? Icons.view_list_rounded
                            : Icons.grid_view_rounded,
                        size: 18,
                        color: _activeAccentColor,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),

          // Expanded Album List/Grid Content
          Expanded(
            child: CustomScrollView(
              physics: const BouncingScrollPhysics(),
              slivers: [
                // Top Albums Carousel (when search is empty & >= 3 top albums exist)
                if (_searchQuery.isEmpty && topAlbumsList.length >= 3)
                  SliverToBoxAdapter(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Padding(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 24,
                            vertical: 4,
                          ),
                          child: Text(
                            'Top Albums',
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                              color: textColor,
                              letterSpacing: -0.3,
                            ),
                          ),
                        ),
                        const SizedBox(height: 10),
                        SizedBox(
                          height: 168,
                          child: ListView.separated(
                            padding: const EdgeInsets.symmetric(horizontal: 24),
                            scrollDirection: Axis.horizontal,
                            itemCount: topAlbumsList.length,
                            separatorBuilder: (_, _) => const SizedBox(width: 16),
                            itemBuilder: (context, index) {
                              final albumName = topAlbumsList[index];
                              final albumSongs = albumTracksMap[albumName] ?? [];
                              final count = albumSongs.length;
                              final firstTrack = albumSongs.isNotEmpty
                                  ? albumSongs.first
                                  : Track(
                                      id: '',
                                      title: '',
                                      artist: '',
                                      album: albumName,
                                      url: '',
                                      path: '',
                                      lyrics: const [],
                                      duration: 0,
                                    );

                              return GestureDetector(
                                onTap: () {
                                  setState(() {
                                    _selectedAlbumDetail = albumName;
                                    _searchQuery = '';
                                    _searchController.clear();
                                    _detailColorFuture = _getDetailColor(
                                      albumSongs.isNotEmpty
                                          ? albumSongs.first
                                          : null,
                                    );
                                  });
                                },
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Container(
                                      width: 110,
                                      height: 110,
                                      decoration: BoxDecoration(
                                        borderRadius: BorderRadius.circular(14),
                                        boxShadow: [
                                          BoxShadow(
                                            color: Colors.black.withValues(
                                              alpha: 0.15,
                                            ),
                                            blurRadius: 10,
                                            offset: const Offset(0, 4),
                                          ),
                                        ],
                                      ),
                                      child: ClipRRect(
                                        borderRadius: BorderRadius.circular(14),
                                        child: _buildTrackArtwork(
                                          firstTrack,
                                          size: 110,
                                          radius: 14,
                                        ),
                                      ),
                                    ),
                                    const SizedBox(height: 8),
                                    SizedBox(
                                      width: 110,
                                      child: Text(
                                        albumName,
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                        style: TextStyle(
                                          fontWeight: FontWeight.w700,
                                          fontSize: 13,
                                          color: textColor,
                                        ),
                                      ),
                                    ),
                                    const SizedBox(height: 2),
                                    SizedBox(
                                      width: 110,
                                      child: Text(
                                        firstTrack.artist.isNotEmpty
                                            ? firstTrack.artist
                                            : '$count ${AppLocalizations.of(context).songsCount}',
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                        style: TextStyle(
                                          fontSize: 11,
                                          color: subtextColor,
                                          fontWeight: FontWeight.w400,
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              );
                            },
                          ),
                        ),
                        const SizedBox(height: 12),
                        Padding(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 24,
                            vertical: 4,
                          ),
                          child: Text(
                            'All Albums',
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                              color: textColor,
                              letterSpacing: -0.3,
                            ),
                          ),
                        ),
                        const SizedBox(height: 8),
                      ],
                    ),
                  ),

                // Grid View vs List View with zero-overhead viewport virtualization
                if (_albumViewMode == 'grid')
                  SliverPadding(
                    padding: EdgeInsets.only(
                      left: 24,
                      right: 24,
                      bottom: _bottomListPadding,
                    ),
                    sliver: SliverGrid(
                      gridDelegate:
                          const SliverGridDelegateWithFixedCrossAxisCount(
                            crossAxisCount: 2,
                            childAspectRatio: 0.82,
                            crossAxisSpacing: 14,
                            mainAxisSpacing: 14,
                          ),
                      delegate: SliverChildBuilderDelegate(
                        (context, index) {
                          final album = albums[index];
                          final albumSongs = albumTracksMap[album] ?? [];
                          final songCount = albumSongs.length;
                          final firstTrack = albumSongs.isNotEmpty
                              ? albumSongs.first
                              : Track(
                                  id: '',
                                  title: '',
                                  artist: '',
                                  album: album,
                                  url: '',
                                  path: '',
                                  lyrics: const [],
                                  duration: 0,
                                );
                          final bool shouldAnimate = index < 8 &&
                              !_animatedAlbumIds.contains(album);
                          if (shouldAnimate) {
                            _animatedAlbumIds.add(album);
                          }

                          return _FadeInSlideUp(
                            animate: shouldAnimate,
                            delay: Duration(milliseconds: index * 35),
                            child: GestureDetector(
                              onTap: () {
                                setState(() {
                                  _selectedAlbumDetail = album;
                                  _searchQuery = '';
                                  _searchController.clear();
                                  _detailColorFuture = _getDetailColor(
                                    albumSongs.isNotEmpty
                                        ? albumSongs.first
                                        : null,
                                  );
                                });
                              },
                              child: Container(
                                decoration: BoxDecoration(
                                  color: isLight
                                      ? Colors.black.withValues(alpha: 0.03)
                                      : Colors.white.withValues(alpha: 0.05),
                                  borderRadius: BorderRadius.circular(16),
                                  border: Border.all(
                                    color: isLight
                                        ? Colors.black.withValues(alpha: 0.06)
                                        : Colors.white.withValues(alpha: 0.08),
                                    width: 1,
                                  ),
                                ),
                                padding: const EdgeInsets.all(10),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Expanded(
                                      child: Center(
                                        child: Container(
                                          decoration: BoxDecoration(
                                            borderRadius: BorderRadius.circular(
                                              12,
                                            ),
                                            boxShadow: [
                                              BoxShadow(
                                                color: Colors.black.withValues(
                                                  alpha: 0.15,
                                                ),
                                                blurRadius: 8,
                                                offset: const Offset(0, 4),
                                              ),
                                            ],
                                          ),
                                          child: ClipRRect(
                                            borderRadius: BorderRadius.circular(
                                              12,
                                            ),
                                            child: _buildTrackArtwork(
                                              firstTrack,
                                              size: 140,
                                              radius: 12,
                                            ),
                                          ),
                                        ),
                                      ),
                                    ),
                                    const SizedBox(height: 10),
                                    Text(
                                      album,
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                      style: TextStyle(
                                        fontWeight: FontWeight.w700,
                                        fontSize: 14,
                                        color: textColor,
                                      ),
                                    ),
                                    const SizedBox(height: 2),
                                    Row(
                                      children: [
                                        Expanded(
                                          child: Text(
                                            firstTrack.artist.isNotEmpty
                                                ? firstTrack.artist
                                                : '<unknown>',
                                            maxLines: 1,
                                            overflow: TextOverflow.ellipsis,
                                            style: TextStyle(
                                              fontSize: 12,
                                              color: subtextColor,
                                            ),
                                          ),
                                        ),
                                        Container(
                                          padding: const EdgeInsets.symmetric(
                                            horizontal: 6,
                                            vertical: 2,
                                          ),
                                          decoration: BoxDecoration(
                                            color: _activeAccentColor.withValues(
                                              alpha: 0.15,
                                            ),
                                            borderRadius: BorderRadius.circular(
                                              6,
                                            ),
                                          ),
                                          child: Text(
                                            '$songCount',
                                            style: TextStyle(
                                              fontSize: 11,
                                              fontWeight: FontWeight.bold,
                                              color: _activeAccentColor,
                                            ),
                                          ),
                                        ),
                                      ],
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          );
                        },
                        childCount: albums.length,
                      ),
                    ),
                  )
                else
                  SliverPadding(
                    padding: EdgeInsets.only(
                      left: 24,
                      right: 24,
                      bottom: _bottomListPadding,
                    ),
                    sliver: SliverList(
                      delegate: SliverChildBuilderDelegate(
                        (context, index) {
                          final album = albums[index];
                          final albumSongs = albumTracksMap[album] ?? [];
                          final songCount = albumSongs.length;
                          final firstTrack = albumSongs.isNotEmpty
                              ? albumSongs.first
                              : Track(
                                  id: '',
                                  title: '',
                                  artist: '',
                                  album: album,
                                  url: '',
                                  path: '',
                                  lyrics: const [],
                                  duration: 0,
                                );
                          final bool shouldAnimate = index < 8 &&
                              !_animatedAlbumIds.contains(album);
                          if (shouldAnimate) {
                            _animatedAlbumIds.add(album);
                          }

                          return _FadeInSlideUp(
                            animate: shouldAnimate,
                            delay: Duration(milliseconds: index * 35),
                            child: ListTile(
                              contentPadding: const EdgeInsets.symmetric(
                                vertical: 4,
                              ),
                              onTap: () {
                                setState(() {
                                  _selectedAlbumDetail = album;
                                  _searchQuery = '';
                                  _searchController.clear();
                                  _detailColorFuture = _getDetailColor(
                                    albumSongs.isNotEmpty
                                        ? albumSongs.first
                                        : null,
                                  );
                                });
                              },
                              leading: ClipRRect(
                                borderRadius: BorderRadius.circular(8),
                                child: _buildTrackArtwork(
                                  firstTrack,
                                  size: 48,
                                  radius: 8,
                                ),
                              ),
                              title: Text(
                                album,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(
                                  fontWeight: FontWeight.w600,
                                  fontSize: 15,
                                  color: textColor,
                                ),
                              ),
                              subtitle: Text(
                                '${firstTrack.artist} • $songCount ${AppLocalizations.of(context).songsCount}',
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(
                                  color: subtextColor,
                                  fontSize: 12,
                                ),
                              ),
                              trailing: Icon(
                                Icons.arrow_forward_ios,
                                color: isLight ? Colors.black26 : Colors.white24,
                                size: 14,
                              ),
                            ),
                          );
                        },
                        childCount: albums.length,
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSongList(
    List<Track> list, {
    Widget? header,
    bool isMostPlayed = false,
    ScrollController? controller,
    List<Track>? fullQueueList,
    String? playlistContext,
    void Function(Track track)? onTrackTap,
  }) {
    if (list.isEmpty && header == null) {
      return Center(
        child: Text(
          AppLocalizations.of(context).noMatchingSongs,
          style: TextStyle(
            color: Colors.white.withValues(alpha: 0.4),
            fontSize: 14,
          ),
        ),
      );
    }
    return ListView.builder(
      controller: controller,
      physics: const BouncingScrollPhysics(),
      padding: EdgeInsets.only(
        left: 16,
        right: 16,
        top: 12,
        bottom: _bottomListPadding,
      ),
      itemCount: list.length + (header != null ? 1 : 0),
      itemBuilder: (context, index) {
        if (header != null && index == 0) return header;
        final trackIndex = header != null ? index - 1 : index;
        final track = list[trackIndex];
        final isSelected =
            _playingTrack != null && track.id == _playingTrack!.id;

        final isDetail = header != null;
        final shouldAnimate =
            !isDetail && !_animatedTrackIds.contains(track.id);
        final count = _animatedTrackIds.length;
        final staggerIndex = count < 8 ? count : 0;
        if (shouldAnimate) {
          _animatedTrackIds.add(track.id);
        }

        final isMultiSelected = _multiSelectedTrackIds.contains(track.id);

        return _FadeInSlideUp(
          animate: shouldAnimate,
          delay: Duration(milliseconds: staggerIndex * 35),
          child: Container(
            key: ValueKey("list_item_${track.id}"),
            margin: const EdgeInsets.only(bottom: 4),
            decoration: BoxDecoration(
              color: isMultiSelected
                  ? _activeAccentColor.withValues(alpha: 0.15)
                  : (isSelected
                        ? Colors.white.withValues(alpha: 0.03)
                        : Colors.transparent),
              borderRadius: BorderRadius.circular(8),
              border: isMultiSelected
                  ? Border.all(
                      color: _activeAccentColor.withValues(alpha: 0.5),
                      width: 1,
                    )
                  : Border.all(color: Colors.transparent, width: 1),
            ),
            child: ListTile(
              visualDensity: _libraryDensity == 'compact'
                  ? const VisualDensity(vertical: -2)
                  : VisualDensity.standard,
              contentPadding: EdgeInsets.only(
                left: 8,
                right: 0,
                top: _libraryDensity == 'compact' ? 0 : 4,
                bottom: _libraryDensity == 'compact' ? 0 : 4,
              ),
              onLongPress: () {
                _searchFocusNode.unfocus();
                _toggleMultiSelect(track.id);
              },
              onTap: () {
                _searchFocusNode.unfocus();
                if (_multiSelectedTrackIds.isNotEmpty) {
                  _toggleMultiSelect(track.id);
                  return;
                }

                if (onTrackTap != null) {
                  onTrackTap(track);
                }

                _updatePlayingFrom();
                if (fullQueueList != null) {
                  final realIndex = fullQueueList.indexOf(track);
                  if (realIndex != -1) {
                    _playTrack(realIndex, sourceList: fullQueueList);
                  } else {
                    _playTrack(trackIndex, sourceList: list);
                  }
                } else {
                  _playTrack(trackIndex, sourceList: list);
                }
              },
              leading: _buildTrackArtwork(
                track,
                size: _libraryDensity == 'compact' ? 36 : 44,
                radius: _libraryDensity == 'compact' ? 4 : 6,
              ),
              title: Text(
                track.title,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontWeight: FontWeight.w600,
                  fontSize: 15,
                  color: isSelected
                      ? _activeAccentColor
                      : (isAppLight ? const Color(0xFF1A1A1A) : Colors.white),
                ),
              ),
              subtitle: Text(
                isMostPlayed
                    ? '${_playCounts[track.id] ?? 0} ${AppLocalizations.of(context).playsCount} • ${track.artist}'
                    : track.artist,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  color: isAppLight ? Colors.black45 : Colors.white38,
                  fontSize: 12,
                ),
              ),
              trailing: Transform.translate(
                offset: const Offset(12, 0),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (isSelected)
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
                        _formatDuration(Duration(milliseconds: track.duration)),
                        style: TextStyle(
                          color: isAppLight ? Colors.black45 : Colors.white38,
                          fontSize: 12,
                          fontFeatures: const [FontFeature.tabularFigures()],
                        ),
                      ),
                    const SizedBox(width: 8),
                    IconButton(
                      icon: Icon(
                        Icons.more_vert,
                        color: isAppLight ? Colors.black45 : Colors.white54,
                        size: 20,
                      ),
                      padding: EdgeInsets.zero,
                      constraints: const BoxConstraints(),
                      onPressed: () => _showTrackOptions(
                        context,
                        track,
                        playlistContext: playlistContext,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildSearchBar() {
    final isLight = isAppLight;
    final searchBgColor = isLight
        ? Colors.black.withValues(alpha: 0.05)
        : const Color(0xFF161616);
    final textColor = isLight ? const Color(0xFF1A1A1A) : Colors.white;
    final hintColor = isLight
        ? Colors.black38
        : Colors.white.withValues(alpha: 0.3);
    final iconColor = isLight ? Colors.black45 : Colors.white54;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      child: Container(
        height: 44,
        decoration: BoxDecoration(
          color: searchBgColor,
          borderRadius: BorderRadius.circular(12),
        ),
        child: TextField(
          focusNode: _searchFocusNode,
          controller: _searchController,
          textAlignVertical: TextAlignVertical.center,
          textInputAction: TextInputAction.search,
          onSubmitted: (_) {
            _searchFocusNode.unfocus();
          },
          onChanged: (val) {
            if (_searchDebouncer?.isActive ?? false) {
              _searchDebouncer!.cancel();
            }
            _searchDebouncer = Timer(
              const Duration(milliseconds: 300),
              () {
                _searchQuery = val.trim();
                _filterSongs();
              },
            );
          },
          style: TextStyle(fontSize: 14, color: textColor),
          decoration: InputDecoration(
            hintText: AppLocalizations.of(context).searchSongs,
            hintStyle: TextStyle(color: hintColor, fontSize: 13.5),
            prefixIcon: Icon(Icons.search, color: iconColor, size: 20),
            suffixIcon: _searchQuery.isNotEmpty
                ? IconButton(
                    icon: Icon(Icons.close, color: iconColor, size: 16),
                    onPressed: () {
                      _searchController.clear();
                      _searchQuery = '';
                      _filterSongs();
                    },
                  )
                : null,
            border: InputBorder.none,
            isDense: true,
            contentPadding: const EdgeInsets.symmetric(vertical: 12),
          ),
        ),
      ),
    );
  }

  Widget _buildFilterCapsules() {
    final isLight = isAppLight;
    final filters = [
      AppLocalizations.of(context).songsTitle,
      AppLocalizations.of(context).playlists,
      AppLocalizations.of(context).artists,
      AppLocalizations.of(context).albums,
    ];
    return Padding(
      padding: const EdgeInsets.only(left: 24, right: 24, top: 8, bottom: 8),
      child: SizedBox(
        height: 32,
        child: Row(
          children: filters.asMap().entries.map((entry) {
            final index = entry.key;
            final filter = entry.value;
            final isSelected = _currentPageIndex == index;
            return Expanded(
              child: GestureDetector(
                onTap: () {
                  if (_currentPageIndex != index) {
                    setState(() {
                      if (index == 0) _animatedTrackIds.clear();
                      if (index == 1) _animatedPlaylistIds.clear();
                      if (index == 2) _animatedArtistIds.clear();
                      if (index == 3) _animatedAlbumIds.clear();
                    });
                    _pageController.jumpToPage(index);
                  }
                },
                child: Container(
                  margin: EdgeInsets.only(
                    right: index == filters.length - 1 ? 0 : 8,
                  ),
                  padding: const EdgeInsets.symmetric(vertical: 6),
                  decoration: BoxDecoration(
                    color: isSelected
                        ? (isLight ? const Color(0xFF1A1A1A) : Colors.white)
                        : (isLight
                              ? Colors.black.withValues(alpha: 0.05)
                              : const Color(0xFF161616)),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Center(
                    child: Text(
                      filter,
                      style: TextStyle(
                        color: isSelected
                            ? (isLight ? Colors.white : Colors.black)
                            : (isLight ? Colors.black54 : Colors.white70),
                        fontWeight: FontWeight.w600,
                        fontSize: 12,
                      ),
                    ),
                  ),
                ),
              ),
            );
          }).toList(),
        ),
      ),
    );
  }

  Widget _buildLibrarySortRow() {
    final isLight = isAppLight;
    final subtextColor = isLight ? Colors.black54 : Colors.white60;

    String sortLabel;
    switch (_sortBy) {
      case 'title':
        sortLabel = 'Title';
        break;
      case 'artist':
        sortLabel = 'Artist';
        break;
      case 'album':
        sortLabel = 'Album';
        break;
      case 'date_oldest':
        sortLabel = 'Oldest Added';
        break;
      case 'duration_longest':
        sortLabel = 'Longest';
        break;
      case 'duration_shortest':
        sortLabel = 'Shortest';
        break;
      case 'date_newest':
      default:
        sortLabel = 'Recently Added';
        break;
    }

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          GestureDetector(
            onTap: () => _showSortModal(context),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
              decoration: BoxDecoration(
                color: isLight
                    ? Colors.black.withValues(alpha: 0.05)
                    : Colors.white.withValues(alpha: 0.08),
                borderRadius: BorderRadius.circular(16),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    Icons.swap_vert_rounded,
                    size: 16,
                    color: _activeAccentColor,
                  ),
                  const SizedBox(width: 4),
                  Text(
                    sortLabel,
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: isLight ? const Color(0xFF1A1A1A) : Colors.white,
                      fontFamily: getFontFamily(activeFontNotifier.value),
                    ),
                  ),
                ],
              ),
            ),
          ),
          Text(
            _currentPageIndex == 0
                ? '${_allTracks.length} songs'
                : _currentPageIndex == 1
                    ? '${_userPlaylists.length + 5} playlists'
                    : _currentPageIndex == 2
                        ? '${_allTracks.map((t) => t.artist).toSet().length} artists'
                        : '${_allTracks.map((t) => t.album).toSet().length} albums',
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w500,
              color: subtextColor,
              fontFamily: getFontFamily(activeFontNotifier.value),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildLibraryTab() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildFilterCapsules(),
        _buildLibrarySortRow(),
        Expanded(
          child: _buildBodyContent(),
        ),
      ],
    );
  }

  Widget _buildSearchTab() {
    List<Track> searchResults = [];
    if (_searchQuery.isNotEmpty) {
      final q = _searchQuery.toLowerCase();
      searchResults = _allTracks.where((t) =>
        t.title.toLowerCase().contains(q) ||
        t.artist.toLowerCase().contains(q) ||
        t.album.toLowerCase().contains(q)
      ).toList();
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SizedBox(height: 4),
        _buildSearchBar(),
        const SizedBox(height: 12),
        Expanded(
          child: _searchQuery.isEmpty
              ? _buildSearchBrowseCategories()
              : _buildSongList(
                  searchResults,
                  onTrackTap: (track) {
                    _addToRecentSearches(track.id);
                  },
                ),
        ),
      ],
    );
  }

  Widget _buildSearchBrowseCategories() {
    final isLight = isAppLight;
    final loc = lookupAppLocalizations(Locale(FleyStrings.currentLang));

    final trackMap = {for (var t in _allTracks) t.id: t};
    final recentTracks = _recentSearchedTrackIds
        .where((id) => trackMap.containsKey(id))
        .map((id) => trackMap[id]!)
        .take(3)
        .toList();

    final categories = [
      {
        'title': loc.mostPlayed,
        'color': const Color(0xFFE91E63),
        'icon': Icons.local_fire_department,
      },
      {
        'title': loc.favourites,
        'color': const Color(0xFF9C27B0),
        'icon': Icons.favorite,
      },
      {
        'title': loc.recentlyAdded,
        'color': const Color(0xFF2196F3),
        'icon': Icons.new_releases,
      },
      {
        'title': loc.forgottenGems,
        'color': const Color(0xFF00B0FF),
        'icon': Icons.diamond_outlined,
      },
      {
        'title': loc.artists,
        'color': const Color(0xFFFF9800),
        'icon': Icons.person,
      },
      {
        'title': loc.albums,
        'color': const Color(0xFF009688),
        'icon': Icons.album,
      },
      {
        'title': loc.playlists,
        'color': const Color(0xFF673AB7),
        'icon': Icons.queue_music,
      },
      {
        'title': loc.songsTitle,
        'color': const Color(0xFF1DB954),
        'icon': Icons.music_note,
      },
    ];

    return CustomScrollView(
      physics: const BouncingScrollPhysics(),
      slivers: [
        if (recentTracks.isNotEmpty) ...[
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.only(left: 16, right: 16, top: 4, bottom: 8),
              child: Text(
                'Recent searches',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                  color: isLight ? const Color(0xFF1A1A1A) : Colors.white,
                  fontFamily: getFontFamily(activeFontNotifier.value),
                ),
              ),
            ),
          ),
          SliverPadding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            sliver: SliverList(
              delegate: SliverChildBuilderDelegate(
                (context, index) {
                  final track = recentTracks[index];
                  final isSelected =
                      _playingTrack != null && track.id == _playingTrack!.id;

                  return Container(
                    margin: const EdgeInsets.only(bottom: 4),
                    decoration: BoxDecoration(
                      color: isSelected
                          ? Colors.white.withValues(alpha: 0.03)
                          : Colors.transparent,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: ListTile(
                      visualDensity: _libraryDensity == 'compact'
                          ? const VisualDensity(vertical: -2)
                          : VisualDensity.standard,
                      contentPadding: EdgeInsets.only(
                        left: 8,
                        right: 0,
                        top: _libraryDensity == 'compact' ? 0 : 4,
                        bottom: _libraryDensity == 'compact' ? 0 : 4,
                      ),
                      onLongPress: () {
                        _searchFocusNode.unfocus();
                        _showTrackOptions(context, track);
                      },
                      onTap: () {
                        _searchFocusNode.unfocus();
                        _addToRecentSearches(track.id);
                        _updatePlayingFrom();
                        final realIndex = _allTracks.indexOf(track);
                        if (realIndex != -1) {
                          _playTrack(realIndex, sourceList: _allTracks);
                        } else {
                          _playTrack(index, sourceList: recentTracks);
                        }
                      },
                      leading: _buildTrackArtwork(
                        track,
                        size: _libraryDensity == 'compact' ? 36 : 44,
                        radius: _libraryDensity == 'compact' ? 4 : 6,
                      ),
                      title: Text(
                        track.title,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontWeight: FontWeight.w600,
                          fontSize: 15,
                          color: isSelected
                              ? _activeAccentColor
                              : (isLight ? const Color(0xFF1A1A1A) : Colors.white),
                        ),
                      ),
                      subtitle: Text(
                        track.artist,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          color: isLight ? Colors.black45 : Colors.white38,
                          fontSize: 12,
                        ),
                      ),
                      trailing: Transform.translate(
                        offset: const Offset(12, 0),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            if (isSelected)
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
                                  color: isLight
                                      ? Colors.black45
                                      : Colors.white38,
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
                                color: isLight
                                    ? Colors.black45
                                    : Colors.white54,
                                size: 20,
                              ),
                              padding: EdgeInsets.zero,
                              constraints: const BoxConstraints(),
                              onPressed: () => _showTrackOptions(
                                context,
                                track,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  );
                },
                childCount: recentTracks.length,
              ),
            ),
          ),
          const SliverToBoxAdapter(
            child: SizedBox(height: 16),
          ),
        ],
        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.only(left: 16, right: 16, bottom: 12),
            child: Text(
              'Browse all',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w700,
                color: isLight ? const Color(0xFF1A1A1A) : Colors.white,
                fontFamily: getFontFamily(activeFontNotifier.value),
              ),
            ),
          ),
        ),
        SliverPadding(
          padding: EdgeInsets.only(
            left: 16,
            right: 16,
            bottom: _bottomListPadding,
          ),
          sliver: SliverGrid(
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 2,
              crossAxisSpacing: 12,
              mainAxisSpacing: 12,
              childAspectRatio: 1.6,
            ),
            delegate: SliverChildBuilderDelegate(
              (context, index) {
                final cat = categories[index];
                final title = cat['title'] as String;
                final color = cat['color'] as Color;
                final icon = cat['icon'] as IconData;

                return GestureDetector(
                  onTap: () {
                    if (title == loc.artists) {
                      setState(() {
                        _currentNavIndex = 2;
                        _currentPageIndex = 2;
                        _pageController.jumpToPage(2);
                      });
                    } else if (title == loc.albums) {
                      setState(() {
                        _currentNavIndex = 2;
                        _currentPageIndex = 3;
                        _pageController.jumpToPage(3);
                      });
                    } else if (title == loc.playlists) {
                      setState(() {
                        _currentNavIndex = 2;
                        _currentPageIndex = 1;
                        _pageController.jumpToPage(1);
                      });
                    } else if (title == loc.songsTitle) {
                      setState(() {
                        _currentNavIndex = 2;
                        _currentPageIndex = 0;
                        _pageController.jumpToPage(0);
                      });
                    } else {
                      setState(() {
                        _selectedPlaylistDetail = title;
                        _searchQuery = '';
                        _searchController.clear();
                      });
                    }
                  },
                  child: Container(
                    decoration: BoxDecoration(
                      color: color,
                      borderRadius: BorderRadius.circular(10),
                    ),
                    padding: const EdgeInsets.all(12),
                    child: Stack(
                      children: [
                        Text(
                          title,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 15,
                            fontWeight: FontWeight.bold,
                          ),
                          maxLines: 2,
                        ),
                        Positioned(
                          right: -4,
                          bottom: -4,
                          child: Transform.rotate(
                            angle: 0.3,
                            child: Icon(
                              icon,
                              size: 44,
                              color: Colors.white.withValues(alpha: 0.35),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              },
              childCount: categories.length,
            ),
          ),
        ),
      ],
    );
  }
}

class _KeepAliveWrapper extends StatefulWidget {
  final Widget child;
  const _KeepAliveWrapper({required this.child});

  @override
  State<_KeepAliveWrapper> createState() => _KeepAliveWrapperState();
}

class _KeepAliveWrapperState extends State<_KeepAliveWrapper>
    with AutomaticKeepAliveClientMixin {
  @override
  Widget build(BuildContext context) {
    super.build(context);
    return widget.child;
  }

  @override
  bool get wantKeepAlive => true;
}

class _FadeInSlideUp extends StatefulWidget {
  final Widget child;
  final Duration delay;
  final bool animate;

  const _FadeInSlideUp({
    super.key,
    required this.child,
    required this.delay,
    this.animate = true,
  });

  @override
  State<_FadeInSlideUp> createState() => _FadeInSlideUpState();
}

class _FadeInSlideUpState extends State<_FadeInSlideUp> {
  bool _isMounted = false;
  Timer? _timer;
  late bool _animate;
  int _restartCount = 0;

  @override
  void initState() {
    super.initState();
    _initAnimation();
  }

  @override
  void didUpdateWidget(_FadeInSlideUp oldWidget) {
    super.didUpdateWidget(oldWidget);

    if (widget.animate == true && oldWidget.animate == false) {
      _initAnimation();
    }
  }

  void _initAnimation() {
    _timer?.cancel();
    _restartCount++;
    _animate = widget.animate;
    if (!_animate) {
      _isMounted = true;
    } else {
      _isMounted = false;
      _timer = Timer(widget.delay, () {
        if (mounted) {
          setState(() {
            _isMounted = true;
          });
        }
      });
    }
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (!widget.animate) {
      return widget.child;
    }

    final double targetValue = _isMounted ? 1.0 : 0.0;

    return TweenAnimationBuilder<double>(
      key: ValueKey(_restartCount),
      tween: Tween<double>(begin: 0.0, end: targetValue),
      duration: const Duration(milliseconds: 350),
      curve: Curves.easeOutCubic,
      builder: (context, value, child) {
        return Opacity(
          opacity: value,
          child: Transform.translate(
            offset: Offset(0, (1.0 - value) * 16),
            child: child,
          ),
        );
      },
      child: widget.child,
    );
  }
}
