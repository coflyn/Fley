// ignore_for_file: invalid_use_of_protected_member
part of 'desktop_layout_shell.dart';

extension _DesktopSongsViewUI on _DesktopLayoutShellState {
  Widget _buildSongsTableView(Color textColor, Color secondaryTextColor) {
    final loc = AppLocalizations.of(context);
    final tracks = _filteredTracks;
    final totalDurationMs = tracks.fold<int>(0, (sum, t) => sum + t.duration);

    // Metadata & Cover for the Album-View Header
    String categoryName = 'COLLECTION';
    String title = loc.allSongs;
    Widget coverWidget;

    Widget buildCollectionCover(
      IconData fallbackIcon,
      List<Color> fallbackColors,
    ) {
      if (tracks.isNotEmpty) {
        return Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(12),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.35),
                blurRadius: 20,
                offset: const Offset(0, 8),
              ),
            ],
          ),
          child: _DesktopTrackArtwork(
            track: tracks.first,
            size: 170,
            radius: 12,
          ),
        );
      }
      return Container(
        width: 170,
        height: 170,
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: fallbackColors,
          ),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Center(
          child: Icon(fallbackIcon, size: 68, color: Colors.white),
        ),
      );
    }

    if (_selectedPlaylistName != null) {
      categoryName = 'PLAYLIST';
      title = _selectedPlaylistName!;
      final customCoverPath = widget.playlistCovers[_selectedPlaylistName!];
      if (_isSafeImage(customCoverPath)) {
        coverWidget = Container(
          width: 170,
          height: 170,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(12),
            image: DecorationImage(
              image: FileImage(File(customCoverPath!)),
              fit: BoxFit.cover,
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.35),
                blurRadius: 20,
                offset: const Offset(0, 8),
              ),
            ],
          ),
        );
      } else {
        coverWidget = buildCollectionCover(
          Icons.queue_music_rounded,
          [
            widget.activeAccentColor.withValues(alpha: 0.5),
            widget.activeAccentColor,
          ],
        );
      }
    } else if (_searchQuery.isNotEmpty) {
      categoryName = 'SEARCH RESULTS';
      title = '"$_searchQuery"';
      coverWidget = Container(
        width: 170,
        height: 170,
        decoration: BoxDecoration(
          color: widget.activeAccentColor.withValues(alpha: 0.15),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Icon(
          Icons.search_rounded,
          size: 64,
          color: widget.activeAccentColor,
        ),
      );
    } else {

      switch (_activeSongFilter) {
        case SongFilter.all:
          categoryName = 'COLLECTION';
          title = loc.allSongs;
          coverWidget = buildCollectionCover(
            Icons.music_note_rounded,
            [
              widget.activeAccentColor.withValues(alpha: 0.4),
              widget.activeAccentColor,
            ],
          );
          break;
        case SongFilter.favorites:
          categoryName = 'COLLECTION';
          title = loc.favourites;
          coverWidget = buildCollectionCover(
            Icons.favorite_rounded,
            const [Color(0xFFE91E63), Color(0xFF9C27B0)],
          );
          break;
        case SongFilter.mostPlayed:
          categoryName = 'COLLECTION';
          title = loc.mostPlayed;
          coverWidget = buildCollectionCover(
            Icons.local_fire_department_rounded,
            const [Color(0xFFF44336), Color(0xFFFF9800)],
          );
          break;
        case SongFilter.recentlyAdded:
          categoryName = 'COLLECTION';
          title = loc.recentlyAdded;
          coverWidget = buildCollectionCover(
            Icons.new_releases_rounded,
            const [Color(0xFF2196F3), Color(0xFF00BCD4)],
          );
          break;
        case SongFilter.lastPlayed:
          categoryName = 'COLLECTION';
          title = loc.lastPlayed;
          coverWidget = buildCollectionCover(
            Icons.history_rounded,
            const [Color(0xFFFF9800), Color(0xFFFFC107)],
          );
          break;
        case SongFilter.forgottenGems:
          categoryName = 'COLLECTION';
          title = loc.forgottenGems;
          coverWidget = buildCollectionCover(
            Icons.diamond_outlined,
            const [Color(0xFF9C27B0), Color(0xFF673AB7)],
          );
          break;
      }
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Album/Collection Style Header
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              coverWidget,
              const SizedBox(width: 24),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      categoryName,
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w800,
                        letterSpacing: 1.5,
                        color: widget.activeAccentColor,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      title,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 32,
                        fontWeight: FontWeight.bold,
                        color: textColor,
                        height: 1.15,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      '${tracks.length} ${loc.songsCount} • ${_formatTotalAlbumDuration(totalDurationMs)}',
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
                            if (tracks.isNotEmpty) {
                              widget.onPlayTrack(tracks.first, tracks, 0);
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
                            if (tracks.isNotEmpty) {
                              final shuffled = List<Track>.from(tracks)
                                ..shuffle();
                              widget.onPlayTrack(shuffled.first, shuffled, 0);
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
                        const SizedBox(width: 8),
                        PopupMenuButton<String>(
                          tooltip: loc.sortSongs,
                          initialValue: _songSortKey,
                          onSelected: (key) => setState(() => _songSortKey = key),
                          icon: Container(
                            padding: const EdgeInsets.all(8),
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              border: Border.all(
                                color: widget.isLight
                                    ? Colors.black12
                                    : Colors.white24,
                              ),
                            ),
                            child: Icon(
                              Icons.sort_rounded,
                              color: textColor,
                              size: 18,
                            ),
                          ),
                          itemBuilder: (context) => [
                            const PopupMenuItem(
                              value: 'title_asc',
                              child: Text('Title (A to Z)'),
                            ),
                            const PopupMenuItem(
                              value: 'title_desc',
                              child: Text('Title (Z to A)'),
                            ),
                            const PopupMenuItem(
                              value: 'artist',
                              child: Text('Artist'),
                            ),
                            const PopupMenuItem(
                              value: 'album',
                              child: Text('Album'),
                            ),
                            const PopupMenuItem(
                              value: 'duration_desc',
                              child: Text('Duration (Longest)'),
                            ),
                            const PopupMenuItem(
                              value: 'duration_asc',
                              child: Text('Duration (Shortest)'),
                            ),
                          ],
                        ),
                        if (_selectedPlaylistName != null) ...[
                          const SizedBox(width: 8),
                          IconButton(
                            icon: const Icon(
                              Icons.edit_outlined,
                              size: 19,
                            ),
                            color: textColor,
                            tooltip: loc.rename,
                            onPressed: () => _renamePlaylistDialog(_selectedPlaylistName!),
                          ),
                          const SizedBox(width: 4),
                          IconButton(
                            icon: const Icon(
                              Icons.image_outlined,
                              size: 19,
                            ),
                            color: textColor,
                            tooltip: loc.editCover,
                            onPressed: () => _changePlaylistCoverDialog(_selectedPlaylistName!),
                          ),
                          const SizedBox(width: 4),
                          IconButton(
                            icon: const Icon(
                              Icons.delete_outline_rounded,
                              size: 20,
                            ),
                            color: Colors.redAccent,
                            tooltip: loc.delete,
                            onPressed: () {
                              final name = _selectedPlaylistName!;
                              showDialog(
                                context: context,
                                builder: (context) => AlertDialog(
                                  backgroundColor: widget.isLight
                                      ? const Color(0xFFFAFAFD)
                                      : const Color(0xFF1E1E24),
                                  title: Text(loc.delete),
                                  content: Text(
                                    'Are you sure you want to delete "$name"?',
                                  ),
                                  actions: [
                                    TextButton(
                                      onPressed: () => Navigator.pop(context),
                                      child: Text(loc.cancel),
                                    ),
                                    FilledButton(
                                      onPressed: () {
                                        Navigator.pop(context);
                                        widget.onDeletePlaylist?.call(name);
                                        setState(
                                          () => _selectedPlaylistName = null,
                                        );
                                      },
                                      style: FilledButton.styleFrom(
                                        backgroundColor: Colors.redAccent,
                                      ),
                                      child: Text(loc.delete),
                                    ),
                                  ],
                                ),
                              );
                            },
                          ),
                        ],
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),

        const SizedBox(height: 8),
        Divider(
          color: widget.isLight
              ? Colors.black.withValues(alpha: 0.06)
              : Colors.white.withValues(alpha: 0.06),
          height: 1,
        ),

        if (tracks.isEmpty)
          Expanded(
            child: Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    Icons.music_off_outlined,
                    size: 48,
                    color: secondaryTextColor,
                  ),
                  const SizedBox(height: 12),
                  Text(
                    loc.noMatchingSongs,
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                      color: textColor,
                    ),
                  ),
                ],
              ),
            ),
          )
        else ...[
          const SizedBox(height: 6),
          // Table Rows
          Expanded(
            child: StreamBuilder<PlayerState>(
              stream: widget.player.playerStateStream,
              builder: (context, snapshot) {
                final isAudioPlaying =
                    snapshot.data?.playing ?? widget.player.playing;

                return ListView.builder(
                  itemCount: tracks.length,
                  padding: const EdgeInsets.symmetric(vertical: 4),
                  itemBuilder: (context, index) {
                    final track = tracks[index];
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
                      onTap: () => widget.onPlayTrack(track, tracks, index),
                      onToggleFavorite: () => widget.onToggleFavorite(track.id),
                      onPlayNext: () => widget.onPlayNextInQueue?.call(track),
                      onAddToQueue: () => widget.onAddToQueue?.call(track),
                      onAddToPlaylist: (t) => _showAddToPlaylistDialog(t),
                      onRemoveFromPlaylist: _selectedPlaylistName != null
                          ? (t) => widget.onRemoveFromPlaylist?.call(_selectedPlaylistName!, t.id)
                          : null,
                      onShowDetails: (t) => _showSongDetailsDialog(t),
                      onEditTags: (t) => _showEditSongTagsDialog(t),
                      onChangeArtwork: (t) => _changeTrackArtwork(t),
                      onHideTrack: (t) => _hideTrack(t),
                      onDeletePermanently: widget.onDeletePermanently != null
                          ? (t) => _showDeletePermanentlyDialog(t)
                          : null,
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
      ],
    );
  }
}
