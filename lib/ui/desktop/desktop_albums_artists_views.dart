// ignore_for_file: invalid_use_of_protected_member
part of 'desktop_layout_shell.dart';

extension _DesktopAlbumsArtistsViewsUI on _DesktopLayoutShellState {
  String _formatTotalAlbumDuration(int ms) {
    if (ms <= 0) return '0 min';
    final duration = Duration(milliseconds: ms);
    final hours = duration.inHours;
    final minutes = duration.inMinutes.remainder(60);
    final seconds = duration.inSeconds.remainder(60);
    if (hours > 0) {
      return '$hours hr $minutes min';
    }
    return '$minutes min $seconds sec';
  }

  Widget _buildAlbumsGridView(Color textColor, Color secondaryTextColor) {
    final Map<String, List<Track>> albumGroups = {};
    for (final track in widget.allTracks) {
      albumGroups.putIfAbsent(track.album, () => []).add(track);
    }
    final albums = albumGroups.keys.toList()..sort();

    return GridView.builder(
      padding: const EdgeInsets.all(24),
      gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
        maxCrossAxisExtent: 200,
        mainAxisSpacing: 20,
        crossAxisSpacing: 20,
        childAspectRatio: 0.78,
      ),
      itemCount: albums.length,
      itemBuilder: (context, index) {
        final albumName = albums[index];
        final tracks = albumGroups[albumName] ?? [];
        final firstTrack = tracks.isNotEmpty ? tracks.first : null;

        return InkWell(
          borderRadius: BorderRadius.circular(10),
          onTap: () {
            setState(() {
              _selectedAlbumName = albumName;
            });
          },
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: firstTrack != null
                    ? _DesktopTrackArtwork(
                        track: firstTrack,
                        size: 200,
                        radius: 10,
                      )
                    : Container(
                        decoration: BoxDecoration(
                          color: widget.isLight
                              ? Colors.black.withValues(alpha: 0.05)
                              : Colors.white.withValues(alpha: 0.05),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: const Center(
                          child: Icon(Icons.album_rounded, size: 40),
                        ),
                      ),
              ),
              const SizedBox(height: 10),
              Text(
                albumName,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontSize: 13.5,
                  fontWeight: FontWeight.w600,
                  color: textColor,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                '${tracks.length} songs',
                style: TextStyle(
                  fontSize: 12,
                  color: secondaryTextColor,
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildArtistsGridView(Color textColor, Color secondaryTextColor) {
    final Map<String, List<Track>> artistGroups = {};
    for (final track in widget.allTracks) {
      artistGroups.putIfAbsent(track.artist, () => []).add(track);
    }
    final artists = artistGroups.keys.toList()..sort();

    return GridView.builder(
      padding: const EdgeInsets.all(24),
      gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
        maxCrossAxisExtent: 180,
        mainAxisSpacing: 20,
        crossAxisSpacing: 20,
        childAspectRatio: 0.82,
      ),
      itemCount: artists.length,
      itemBuilder: (context, index) {
        final artistName = artists[index];
        final tracks = artistGroups[artistName] ?? [];
        final firstTrack = tracks.isNotEmpty ? tracks.first : null;

        return InkWell(
          borderRadius: BorderRadius.circular(10),
          onTap: () {
            setState(() {
              _selectedArtistName = artistName;
            });
          },
          child: Column(
            children: [
              Expanded(
                child: firstTrack != null
                    ? Center(
                        child: AspectRatio(
                          aspectRatio: 1,
                          child: ClipOval(
                            child: _DesktopTrackArtwork(
                              track: firstTrack,
                              size: 160,
                              radius: 80,
                            ),
                          ),
                        ),
                      )
                    : CircleAvatar(
                        radius: 70,
                        backgroundColor: widget.isLight
                            ? Colors.black.withValues(alpha: 0.05)
                            : Colors.white.withValues(alpha: 0.05),
                        child: Icon(
                          Icons.person_rounded,
                          size: 48,
                          color: widget.activeAccentColor,
                        ),
                      ),
              ),
              const SizedBox(height: 10),
              Text(
                artistName,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 13.5,
                  fontWeight: FontWeight.w600,
                  color: textColor,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                '${tracks.length} songs',
                style: TextStyle(fontSize: 12, color: secondaryTextColor),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildAlbumDetailView(
    String albumName,
    Color textColor,
    Color secondaryTextColor,
  ) {
    final albumTracks = widget.allTracks
        .where((t) => t.album.toLowerCase() == albumName.toLowerCase())
        .toList();
    final firstTrack = albumTracks.isNotEmpty ? albumTracks.first : null;
    final totalDurationMs =
        albumTracks.fold<int>(0, (sum, t) => sum + t.duration);
    final artistName = firstTrack?.artist ?? 'Various Artists';

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Top breadcrumb / Back Button
        Padding(
          padding: const EdgeInsets.only(left: 20, top: 16, bottom: 4),
          child: InkWell(
            borderRadius: BorderRadius.circular(8),
            onTap: () => setState(() => _selectedAlbumName = null),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    Icons.arrow_back_rounded,
                    size: 18,
                    color: secondaryTextColor,
                  ),
                  const SizedBox(width: 8),
                  Text(
                    'Albums',
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: secondaryTextColor,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),

        // Album Header
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              if (firstTrack != null)
                _DesktopTrackArtwork(
                  track: firstTrack,
                  size: 180,
                  radius: 12,
                )
              else
                Container(
                  width: 180,
                  height: 180,
                  decoration: BoxDecoration(
                    color: widget.isLight
                        ? Colors.black.withValues(alpha: 0.05)
                        : Colors.white.withValues(alpha: 0.05),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Center(
                    child: Icon(Icons.album_rounded, size: 64),
                  ),
                ),
              const SizedBox(width: 24),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      'ALBUM',
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w800,
                        letterSpacing: 1.5,
                        color: widget.activeAccentColor,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      albumName,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 28,
                        fontWeight: FontWeight.bold,
                        color: textColor,
                        height: 1.15,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      artistName,
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w600,
                        color: textColor.withValues(alpha: 0.85),
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      '${albumTracks.length} songs • ${_formatTotalAlbumDuration(totalDurationMs)}',
                      style: TextStyle(
                        fontSize: 12.5,
                        color: secondaryTextColor,
                      ),
                    ),
                    const SizedBox(height: 18),
                    Row(
                      children: [
                        FilledButton.icon(
                          onPressed: () {
                            if (albumTracks.isNotEmpty) {
                              widget.onPlayTrack(
                                albumTracks.first,
                                albumTracks,
                                0,
                              );
                            }
                          },
                          icon: const Icon(Icons.play_arrow_rounded, size: 20),
                          label: const Text('Play'),
                          style: FilledButton.styleFrom(
                            backgroundColor: widget.activeAccentColor,
                            foregroundColor: Colors.black,
                            padding: const EdgeInsets.symmetric(
                              horizontal: 24,
                              vertical: 12,
                            ),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(24),
                            ),
                          ),
                        ),
                        const SizedBox(width: 12),
                        OutlinedButton.icon(
                          onPressed: () {
                            if (albumTracks.isNotEmpty) {
                              final shuffled = List<Track>.from(albumTracks)
                                ..shuffle();
                              widget.onPlayTrack(
                                shuffled.first,
                                shuffled,
                                0,
                              );
                            }
                          },
                          icon: const Icon(Icons.shuffle_rounded, size: 18),
                          label: const Text('Shuffle'),
                          style: OutlinedButton.styleFrom(
                            foregroundColor: textColor,
                            side: BorderSide(
                              color: widget.isLight
                                  ? Colors.black12
                                  : Colors.white24,
                            ),
                            padding: const EdgeInsets.symmetric(
                              horizontal: 20,
                              vertical: 12,
                            ),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(24),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),

        const SizedBox(height: 12),
        Divider(
          color: widget.isLight
              ? Colors.black.withValues(alpha: 0.06)
              : Colors.white.withValues(alpha: 0.06),
          height: 1,
        ),

        const SizedBox(height: 6),

        // Song Rows
        Expanded(
          child: StreamBuilder<PlayerState>(
            stream: widget.player.playerStateStream,
            builder: (context, snapshot) {
              final isAudioPlaying =
                  snapshot.data?.playing ?? widget.player.playing;

              return ListView.builder(
                itemCount: albumTracks.length,
                padding: const EdgeInsets.symmetric(vertical: 4),
                itemBuilder: (context, index) {
                  final track = albumTracks[index];
                  final isCurrentTrack = widget.playingTrack?.id == track.id;
                  final isFav = widget.favoriteTrackIds.contains(track.id);

                  return _DesktopSongRow(
                    index: index + 1,
                    track: track,
                    isCurrentTrack: isCurrentTrack,
                    isPlaying: isCurrentTrack && isAudioPlaying,
                    isFavorite: isFav,
                    activeAccentColor: widget.activeAccentColor,
                    textColor: textColor,
                    secondaryTextColor: secondaryTextColor,
                    isLight: widget.isLight,
                    onTap: () => widget.onPlayTrack(
                      track,
                      albumTracks,
                      index,
                    ),
                    onToggleFavorite: () => widget.onToggleFavorite(track.id),
                    onPlayNext: () => widget.onPlayNextInQueue?.call(track),
                    onAddToQueue: () => widget.onAddToQueue?.call(track),
                    onAddToPlaylist: (t) => _showAddToPlaylistDialog(t),
                    onShowDetails: (t) => _showSongDetailsDialog(t),
                    onEditTags: (t) => _showEditSongTagsDialog(t),
                    onChangeArtwork: (t) => _changeTrackArtwork(t),
                    onHideTrack: (t) => _hideTrack(t),
                    onGoToArtist: (artist) {
                      setState(() {
                        _selectedArtistName = artist;
                        _activeSection = DesktopNavSection.artists;
                      });
                    },
                    onGoToAlbum: (album) {
                      setState(() {
                        _selectedAlbumName = album;
                        _activeSection = DesktopNavSection.albums;
                      });
                    },
                    onArtistTap: (artist) {
                      setState(() {
                        _selectedArtistName = artist;
                        _activeSection = DesktopNavSection.artists;
                      });
                    },
                  );
                },
              );
            },
          ),
        ),
      ],
    );
  }

  Widget _buildArtistDetailView(
    String artistName,
    Color textColor,
    Color secondaryTextColor,
  ) {
    final artistTracks = widget.allTracks
        .where((t) => t.artist.toLowerCase() == artistName.toLowerCase())
        .toList();
    final firstTrack = artistTracks.isNotEmpty ? artistTracks.first : null;
    final totalDurationMs =
        artistTracks.fold<int>(0, (sum, t) => sum + t.duration);
    final distinctAlbums = artistTracks
        .map((t) => t.album)
        .where((a) => a.isNotEmpty)
        .toSet()
        .toList();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Top breadcrumb / Back Button
        Padding(
          padding: const EdgeInsets.only(left: 20, top: 16, bottom: 4),
          child: InkWell(
            borderRadius: BorderRadius.circular(8),
            onTap: () => setState(() => _selectedArtistName = null),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    Icons.arrow_back_rounded,
                    size: 18,
                    color: secondaryTextColor,
                  ),
                  const SizedBox(width: 8),
                  Text(
                    'Artists',
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: secondaryTextColor,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),

        // Artist Header
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              ClipOval(
                child: firstTrack != null
                    ? _DesktopTrackArtwork(
                        track: firstTrack,
                        size: 170,
                        radius: 85,
                      )
                    : Container(
                        width: 170,
                        height: 170,
                        decoration: BoxDecoration(
                          color: widget.isLight
                              ? Colors.black.withValues(alpha: 0.05)
                              : Colors.white.withValues(alpha: 0.05),
                          shape: BoxShape.circle,
                        ),
                        child: Center(
                          child: Icon(
                            Icons.person_rounded,
                            size: 64,
                            color: widget.activeAccentColor,
                          ),
                        ),
                      ),
              ),
              const SizedBox(width: 24),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      'ARTIST',
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w800,
                        letterSpacing: 1.5,
                        color: widget.activeAccentColor,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      artistName,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 30,
                        fontWeight: FontWeight.bold,
                        color: textColor,
                        height: 1.15,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      '${artistTracks.length} songs • ${distinctAlbums.length} albums • ${_formatTotalAlbumDuration(totalDurationMs)}',
                      style: TextStyle(
                        fontSize: 12.5,
                        color: secondaryTextColor,
                      ),
                    ),
                    const SizedBox(height: 18),
                    Row(
                      children: [
                        FilledButton.icon(
                          onPressed: () {
                            if (artistTracks.isNotEmpty) {
                              widget.onPlayTrack(
                                artistTracks.first,
                                artistTracks,
                                0,
                              );
                            }
                          },
                          icon: const Icon(Icons.play_arrow_rounded, size: 20),
                          label: const Text('Play'),
                          style: FilledButton.styleFrom(
                            backgroundColor: widget.activeAccentColor,
                            foregroundColor: Colors.black,
                            padding: const EdgeInsets.symmetric(
                              horizontal: 24,
                              vertical: 12,
                            ),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(24),
                            ),
                          ),
                        ),
                        const SizedBox(width: 12),
                        OutlinedButton.icon(
                          onPressed: () {
                            if (artistTracks.isNotEmpty) {
                              final shuffled = List<Track>.from(artistTracks)
                                ..shuffle();
                              widget.onPlayTrack(
                                shuffled.first,
                                shuffled,
                                0,
                              );
                            }
                          },
                          icon: const Icon(Icons.shuffle_rounded, size: 18),
                          label: const Text('Shuffle'),
                          style: OutlinedButton.styleFrom(
                            foregroundColor: textColor,
                            side: BorderSide(
                              color: widget.isLight
                                  ? Colors.black12
                                  : Colors.white24,
                            ),
                            padding: const EdgeInsets.symmetric(
                              horizontal: 20,
                              vertical: 12,
                            ),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(24),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),

        const SizedBox(height: 12),
        Divider(
          color: widget.isLight
              ? Colors.black.withValues(alpha: 0.06)
              : Colors.white.withValues(alpha: 0.06),
          height: 1,
        ),

        const SizedBox(height: 6),

        // Song Rows
        Expanded(
          child: StreamBuilder<PlayerState>(
            stream: widget.player.playerStateStream,
            builder: (context, snapshot) {
              final isAudioPlaying =
                  snapshot.data?.playing ?? widget.player.playing;

              return ListView.builder(
                itemCount: artistTracks.length,
                padding: const EdgeInsets.symmetric(vertical: 4),
                itemBuilder: (context, index) {
                  final track = artistTracks[index];
                  final isCurrentTrack = widget.playingTrack?.id == track.id;
                  final isFav = widget.favoriteTrackIds.contains(track.id);

                  return _DesktopSongRow(
                    index: index + 1,
                    track: track,
                    isCurrentTrack: isCurrentTrack,
                    isPlaying: isCurrentTrack && isAudioPlaying,
                    isFavorite: isFav,
                    activeAccentColor: widget.activeAccentColor,
                    textColor: textColor,
                    secondaryTextColor: secondaryTextColor,
                    isLight: widget.isLight,
                    onTap: () => widget.onPlayTrack(
                      track,
                      artistTracks,
                      index,
                    ),
                    onToggleFavorite: () => widget.onToggleFavorite(track.id),
                    onPlayNext: () => widget.onPlayNextInQueue?.call(track),
                    onAddToQueue: () => widget.onAddToQueue?.call(track),
                    onAddToPlaylist: (t) => _showAddToPlaylistDialog(t),
                    onShowDetails: (t) => _showSongDetailsDialog(t),
                    onEditTags: (t) => _showEditSongTagsDialog(t),
                    onChangeArtwork: (t) => _changeTrackArtwork(t),
                    onHideTrack: (t) => _hideTrack(t),
                    onGoToArtist: (artist) {
                      setState(() {
                        _selectedArtistName = artist;
                        _activeSection = DesktopNavSection.artists;
                      });
                    },
                    onGoToAlbum: (album) {
                      setState(() {
                        _selectedAlbumName = album;
                        _activeSection = DesktopNavSection.albums;
                      });
                    },
                    onAlbumTap: (album) {
                      setState(() {
                        _selectedAlbumName = album;
                        _activeSection = DesktopNavSection.albums;
                      });
                    },
                  );
                },
              );
            },
          ),
        ),
      ],
    );
  }
}
