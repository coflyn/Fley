// ignore_for_file: invalid_use_of_protected_member
part of 'desktop_layout_shell.dart';

extension _DesktopHomeViewUI on _DesktopLayoutShellState {
  /// Fley Signature Desktop Home Screen (Quick Pins + Banner + Rotation + Recents)
  Widget _buildDesktopHomeScreen(Color textColor, Color secondaryTextColor) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(28),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Banner Gif
          ClipRRect(
            borderRadius: BorderRadius.circular(16),
            child: SizedBox(
              height: 180,
              width: double.infinity,
              child: Image.asset(
                'assets/hey.gif',
                fit: BoxFit.cover,
                errorBuilder: (context, error, stackTrace) => Container(
                  color: widget.activeAccentColor.withValues(alpha: 0.2),
                  child: Center(
                    child: Icon(
                      Icons.music_note_rounded,
                      size: 48,
                      color: widget.activeAccentColor,
                    ),
                  ),
                ),
              ),
            ),
          ),

          const SizedBox(height: 28),

          // 4 Quick Pins Cards
          _buildQuickPinsGrid(textColor, secondaryTextColor),

          const SizedBox(height: 32),

          // Your Recent Rotation Section
          _buildRecentRotationSection(textColor, secondaryTextColor),

          const SizedBox(height: 32),

          // Recents Section (Playlists & Albums)
          _buildRecentsCarouselSection(textColor, secondaryTextColor),

          const SizedBox(height: 32),

          // Jump Back In Section
          _buildJumpBackInSection(textColor, secondaryTextColor),
        ],
      ),
    );
  }

  Widget _buildQuickPinsGrid(Color textColor, Color secondaryTextColor) {
    final quickItems = [
      (
        'Most Played',
        Icons.local_fire_department,
        const Color(0xFFF44336),
        _mostPlayedTracks,
        SongFilter.mostPlayed,
      ),
      (
        'Favourites',
        Icons.favorite,
        const Color(0xFFE91E63),
        _favoriteTracks,
        SongFilter.favorites,
      ),
      (
        'Recently Added',
        Icons.new_releases,
        const Color(0xFF2196F3),
        _recentlyAddedTracks,
        SongFilter.recentlyAdded,
      ),
      (
        'Forgotten Gems',
        Icons.diamond_outlined,
        const Color(0xFF9C27B0),
        _forgottenGemsTracks,
        SongFilter.forgottenGems,
      ),
    ];

    return LayoutBuilder(
      builder: (context, constraints) {
        final crossCount = constraints.maxWidth > 900 ? 4 : 2;
        return GridView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: crossCount,
            mainAxisExtent: 64,
            crossAxisSpacing: 14,
            mainAxisSpacing: 14,
          ),
          itemCount: quickItems.length,
          itemBuilder: (context, i) {
            final (title, icon, color, tracks, filter) = quickItems[i];
            final sampleTrack = tracks.firstOrNull;

            return InkWell(
              borderRadius: BorderRadius.circular(8),
              onTap: () {
                setState(() {
                  _activeSongFilter = filter;
                  _activeSection = DesktopNavSection.songs;
                  _searchQuery = '';
                  _searchController.clear();
                });
              },
              child: Container(
                decoration: BoxDecoration(
                  color: widget.isLight
                      ? Colors.black.withValues(alpha: 0.04)
                      : Colors.white.withValues(alpha: 0.06),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  children: [
                    ClipRRect(
                      borderRadius: const BorderRadius.horizontal(
                        left: Radius.circular(8),
                      ),
                      child: sampleTrack != null
                          ? _DesktopTrackArtwork(
                              track: sampleTrack,
                              size: 64,
                              radius: 0,
                            )
                          : Container(
                              width: 64,
                              height: 64,
                              color: color.withValues(alpha: 0.2),
                              child: Icon(icon, color: color, size: 28),
                            ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            title,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w700,
                              color: textColor,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            '${tracks.length} songs',
                            style: TextStyle(
                              fontSize: 11.5,
                              color: secondaryTextColor,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 12),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  Widget _buildRecentRotationSection(Color textColor, Color secondaryTextColor) {
    final trackMap = {for (var t in widget.allTracks) t.id: t};

    Track? resumeTrack;
    if (widget.playingTrack == null && widget.allPlayedTrackIdsOrdered.isNotEmpty) {
      for (final id in widget.allPlayedTrackIdsOrdered) {
        if (trackMap.containsKey(id)) {
          resumeTrack = trackMap[id];
          break;
        }
      }
      if (resumeTrack == null && widget.allTracks.isNotEmpty) {
        resumeTrack = widget.allTracks.first;
      }
    }

    final showResumeTile = widget.playingTrack == null && resumeTrack != null;
    final excludedId = showResumeTile ? resumeTrack.id : widget.playingTrack?.id;

    List<Track> recentTracks = widget.allPlayedTrackIdsOrdered
        .where((id) => trackMap.containsKey(id) && (excludedId == null || id != excludedId))
        .map((id) => trackMap[id]!)
        .take(4)
        .toList();

    if (recentTracks.isEmpty && widget.allTracks.isNotEmpty) {
      recentTracks = widget.allTracks
          .where((t) => excludedId == null || t.id != excludedId)
          .take(4)
          .toList();
    }

    if (!showResumeTile && recentTracks.isEmpty) return const SizedBox.shrink();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Your Recent Rotation',
          style: TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.w700,
            color: textColor,
            letterSpacing: -0.5,
          ),
        ),
        const SizedBox(height: 14),

        if (showResumeTile) ...[
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
            margin: const EdgeInsets.only(bottom: 14),
            decoration: BoxDecoration(
              color: widget.activeAccentColor.withValues(alpha: widget.isLight ? 0.08 : 0.12),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(
                color: widget.activeAccentColor.withValues(alpha: 0.25),
              ),
            ),
            child: Row(
              children: [
                _DesktopTrackArtwork(track: resumeTrack, size: 48, radius: 8),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        resumeTrack.title,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: 13.5,
                          fontWeight: FontWeight.w600,
                          color: textColor,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Row(
                        children: [
                          Icon(
                            Icons.history_rounded,
                            size: 13,
                            color: widget.activeAccentColor,
                          ),
                          const SizedBox(width: 4),
                          Text(
                            'Resume Playback Session',
                            style: TextStyle(
                              fontSize: 11.5,
                              fontWeight: FontWeight.w600,
                              color: widget.activeAccentColor,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                IconButton(
                  icon: Icon(
                    Icons.play_circle_filled_rounded,
                    color: widget.activeAccentColor,
                    size: 36,
                  ),
                  onPressed: () {
                    final idx = widget.allTracks.indexWhere((t) => t.id == resumeTrack?.id);
                    if (idx != -1) {
                      widget.onPlayTrack(
                        resumeTrack!,
                        widget.allTracks,
                        idx,
                      );
                    }
                  },
                ),
              ],
            ),
          ),
        ],

        LayoutBuilder(
          builder: (context, constraints) {
            final crossCount = constraints.maxWidth > 900 ? 4 : 2;
            return GridView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: crossCount,
                mainAxisExtent: 68,
                crossAxisSpacing: 12,
                mainAxisSpacing: 12,
              ),
              itemCount: recentTracks.length,
              itemBuilder: (context, i) {
                final track = recentTracks[i];
                final isPlayingThis = widget.playingTrack?.id == track.id;

                return InkWell(
                  borderRadius: BorderRadius.circular(8),
                  onTap: () {
                    final idx = widget.allTracks.indexWhere((t) => t.id == track.id);
                    widget.onPlayTrack(
                      track,
                      widget.allTracks,
                      idx != -1 ? idx : 0,
                    );
                  },
                  child: Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: widget.isLight
                          ? Colors.black.withValues(alpha: 0.03)
                          : Colors.white.withValues(alpha: 0.04),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Row(
                      children: [
                        _DesktopTrackArtwork(track: track, size: 52, radius: 6),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                track.title,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(
                                  fontSize: 12.5,
                                  fontWeight: FontWeight.w600,
                                  color: isPlayingThis
                                      ? widget.activeAccentColor
                                      : textColor,
                                ),
                              ),
                              const SizedBox(height: 2),
                              Text(
                                track.artist,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(
                                  fontSize: 11,
                                  color: secondaryTextColor,
                                ),
                              ),
                            ],
                          ),
                        ),
                        Icon(
                          isPlayingThis
                              ? Icons.pause_circle_filled_rounded
                              : Icons.play_circle_filled_rounded,
                          color: widget.activeAccentColor,
                          size: 28,
                        ),
                      ],
                    ),
                  ),
                );
              },
            );
          },
        ),
      ],
    );
  }

  Widget _buildRecentsCarouselSection(Color textColor, Color secondaryTextColor) {
    List<Map<String, dynamic>> items = [];

    items.add({
      'title': 'Favourites',
      'subtitle': 'Playlist • ${_favoriteTracks.length} songs',
      'sampleTrack': _favoriteTracks.firstOrNull,
      'color': const Color(0xFFE91E63),
      'icon': Icons.favorite,
      'filter': SongFilter.favorites,
    });
    items.add({
      'title': 'Most Played',
      'subtitle': 'Playlist • ${_mostPlayedTracks.length} songs',
      'sampleTrack': _mostPlayedTracks.firstOrNull,
      'color': const Color(0xFFF44336),
      'icon': Icons.local_fire_department,
      'filter': SongFilter.mostPlayed,
    });
    items.add({
      'title': 'Recently Added',
      'subtitle': 'Playlist • ${_recentlyAddedTracks.length} songs',
      'sampleTrack': _recentlyAddedTracks.firstOrNull,
      'color': const Color(0xFF2196F3),
      'icon': Icons.new_releases,
      'filter': SongFilter.recentlyAdded,
    });
    items.add({
      'title': 'Last Played',
      'subtitle': 'Playlist • ${_lastPlayedTracks.length} songs',
      'sampleTrack': _lastPlayedTracks.firstOrNull,
      'color': const Color(0xFFFF9800),
      'icon': Icons.history_rounded,
      'filter': SongFilter.lastPlayed,
    });
    items.add({
      'title': 'Forgotten Gems',
      'subtitle': 'Playlist • ${_forgottenGemsTracks.length} songs',
      'sampleTrack': _forgottenGemsTracks.firstOrNull,
      'color': const Color(0xFF9C27B0),
      'icon': Icons.diamond_outlined,
      'filter': SongFilter.forgottenGems,
    });

    for (var entry in widget.userPlaylists.entries) {
      final pSongs = entry.value;
      final sample = pSongs.isNotEmpty
          ? widget.allTracks.firstWhere(
              (t) => t.id == pSongs.first,
              orElse: () => widget.allTracks.first,
            )
          : null;
      items.add({
        'title': entry.key,
        'subtitle': 'Playlist • ${pSongs.length} songs',
        'sampleTrack': sample,
        'color': widget.activeAccentColor,
        'icon': Icons.queue_music,
        'playlistTracks': widget.allTracks.where((t) => pSongs.contains(t.id)).toList(),
      });
    }

    final seenAlbums = <String>{};
    for (var track in widget.allTracks) {
      if (track.album.isNotEmpty && seenAlbums.add(track.album)) {
        items.add({
          'title': track.album,
          'subtitle': 'Album • ${track.artist}',
          'sampleTrack': track,
          'albumName': track.album,
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
            fontWeight: FontWeight.w700,
            color: textColor,
            letterSpacing: -0.5,
          ),
        ),
        const SizedBox(height: 14),
        SizedBox(
          height: 195,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            itemCount: items.length,
            separatorBuilder: (_, _) => const SizedBox(width: 14),
            itemBuilder: (context, i) {
              final item = items[i];
              final title = item['title'] as String;
              final subtitle = item['subtitle'] as String;
              final Track? sampleTrack = item['sampleTrack'];
              final IconData? icon = item['icon'];
              final Color color = item['color'] ?? widget.activeAccentColor;
              final SongFilter? filter = item['filter'];
              final String? albumName = item['albumName'];
              final List<Track>? pTracks = item['playlistTracks'];

              return SizedBox(
                width: 140,
                child: InkWell(
                  borderRadius: BorderRadius.circular(10),
                  onTap: () {
                    if (filter != null) {
                      setState(() {
                        _activeSongFilter = filter;
                        _activeSection = DesktopNavSection.songs;
                      });
                    } else if (albumName != null) {
                      setState(() {
                        _selectedAlbumName = albumName;
                        _activeSection = DesktopNavSection.albums;
                        _isFullscreenPlayerOpen = false;
                      });
                    } else if (pTracks != null && pTracks.isNotEmpty) {
                      widget.onPlayTrack(pTracks.first, pTracks, 0);
                    }
                  },
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      sampleTrack != null
                          ? _DesktopTrackArtwork(
                              track: sampleTrack,
                              size: 140,
                              radius: 10,
                            )
                          : Container(
                              width: 140,
                              height: 140,
                              decoration: BoxDecoration(
                                color: color.withValues(alpha: 0.15),
                                borderRadius: BorderRadius.circular(10),
                              ),
                              child: Icon(icon ?? Icons.music_note, color: color, size: 48),
                            ),
                      const SizedBox(height: 8),
                      Text(
                        title,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                          color: textColor,
                        ),
                      ),
                      Text(
                        subtitle,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: 11.5,
                          color: secondaryTextColor,
                        ),
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

  Widget _buildJumpBackInSection(Color textColor, Color secondaryTextColor) {
    if (widget.allTracks.isEmpty) return const SizedBox.shrink();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Jump Back In',
          style: TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.w700,
            color: textColor,
            letterSpacing: -0.5,
          ),
        ),
        const SizedBox(height: 14),
        SizedBox(
          height: 195,
          child: ListView.builder(
            scrollDirection: Axis.horizontal,
            itemCount: widget.allTracks.length > 15
                ? 15
                : widget.allTracks.length,
            itemBuilder: (context, index) {
              final track = widget.allTracks[index];
              return Container(
                width: 140,
                margin: const EdgeInsets.only(right: 14),
                child: InkWell(
                  borderRadius: BorderRadius.circular(10),
                  onTap: () => widget.onPlayTrack(
                    track,
                    widget.allTracks,
                    index,
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _DesktopTrackArtwork(
                        track: track,
                        size: 140,
                        radius: 10,
                      ),
                      const SizedBox(height: 8),
                      Text(
                        track.title,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                          color: textColor,
                        ),
                      ),
                      Text(
                        track.artist,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: 11.5,
                          color: secondaryTextColor,
                        ),
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
