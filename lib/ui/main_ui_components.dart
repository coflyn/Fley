// ignore_for_file: invalid_use_of_protected_member, deprecated_member_use
part of '../main.dart';

extension _MainUIComponents on _MainScreenState {
  void _openProfile() {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => ProfileScreen(
          totalSongs: _allTracks.length,
          totalPlaylists: _userPlaylists.length,
          totalFavorites: _favoriteTrackIds.length,
          activeAccentColor: _activeAccentColor,
          onOpenSettings: _openSettings,
        ),
      ),
    );
  }

  void _openSettings() {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => SettingsScreen(
          onSettingsChanged: _loadSettings,
          onRescanLibrary: () {
            _loadSettings();
            _requestPermissionAndScan();
          },
          onSetSleepTimer: _startSleepTimer,
          onResetData: _resetAppData,
          sleepTimerNotifier: _sleepTimerNotifier,
          onManageFolders: () => _showFolderScanDialog(context),
          onSetSkipSilence: (val) {
            setState(() {
              _skipSilence = val;
            });
            _audioPlayer.setSkipSilenceEnabled(val);
          },
        ),
      ),
    );
  }

  Widget _buildHeader() {
    final isLight = isAppLight;
    final headerTextColor = isLight ? const Color(0xFF1A1A1A) : Colors.white;

    String headerTitle;
    if (_currentNavIndex == 0) {
      headerTitle = 'Fley';
    } else if (_currentNavIndex == 1) {
      headerTitle = 'Search';
    } else {
      headerTitle = 'Your Library';
    }

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
      child: SizedBox(
        height: 48,
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            GestureDetector(
              onTap: _openProfile,
              child: ValueListenableBuilder<String?>(
                valueListenable: userProfileImageNotifier,
                builder: (context, imagePath, child) {
                  final hasImage =
                      imagePath != null && File(imagePath).existsSync();

                  return Container(
                    width: 34,
                    height: 34,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: _activeAccentColor.withValues(alpha: 0.2),
                      border: Border.all(
                        color: _activeAccentColor.withValues(alpha: 0.4),
                        width: 1.5,
                      ),
                    ),
                    child: ClipOval(
                      child: hasImage
                          ? Image.file(
                              File(imagePath),
                              width: 34,
                              height: 34,
                              fit: BoxFit.cover,
                            )
                          : Icon(
                              Icons.person_rounded,
                              size: 18,
                              color: _activeAccentColor,
                            ),
                    ),
                  );
                },
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                headerTitle,
                style: TextStyle(
                  fontSize: 28,
                  fontWeight: FontWeight.w800,
                  letterSpacing: -0.8,
                  color: headerTextColor,
                  fontFamily: getFontFamily(activeFontNotifier.value),
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
            IconButton(
              icon: Icon(Icons.settings, color: headerTextColor),
              onPressed: _openSettings,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMultiSelectHeader() {
    final isLight = isAppLight;
    final textColor = isLight ? const Color(0xFF1A1A1A) : Colors.white;
    final iconColor = isLight ? Colors.black87 : Colors.white;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
      color: isLight
          ? Colors.black.withValues(alpha: 0.05)
          : _activeAccentColor.withValues(alpha: 0.1),
      child: Column(
        children: [
          Row(
            children: [
              IconButton(
                icon: Icon(Icons.close, color: iconColor),
                onPressed: _clearMultiSelect,
              ),
              const SizedBox(width: 8),
              Text(
                '${_multiSelectedTrackIds.length} ${AppLocalizations.of(context).selected}',
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  color: textColor,
                ),
              ),
              const Spacer(),
              IconButton(
                icon: Icon(Icons.select_all, color: iconColor),
                onPressed: () {
                  setState(() {
                    if (_multiSelectedTrackIds.length == _allTracks.length) {
                      _multiSelectedTrackIds.clear();
                    } else {
                      _multiSelectedTrackIds.addAll(
                        _allTracks.map((t) => t.id),
                      );
                    }
                  });
                },
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: ElevatedButton.icon(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: _activeAccentColor,
                    foregroundColor: Colors.black,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    padding: const EdgeInsets.symmetric(vertical: 12),
                  ),
                  onPressed: () {
                    // Collect selected tracks
                    final selectedTracks = _allTracks
                        .where((t) => _multiSelectedTrackIds.contains(t.id))
                        .toList();
                    _showAddToPlaylistModal(context, selectedTracks);
                    _clearMultiSelect();
                  },
                  icon: const Icon(Icons.playlist_add),
                  label: Text(AppLocalizations.of(context).addToPlaylist),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(40.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: Colors.white.withValues(alpha: 0.03),
              ),
              child: Icon(
                Icons.music_note_outlined,
                size: 40,
                color: Colors.white.withValues(alpha: 0.4),
              ),
            ),
            const SizedBox(height: 20),
            Text(
              AppLocalizations.of(context).noSongsFound,
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
                color: Colors.white,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              AppLocalizations.of(context).noSongsSubtitle,
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 13,
                color: Colors.white.withValues(alpha: 0.5),
                height: 1.4,
              ),
            ),
            const SizedBox(height: 24),
            OutlinedButton.icon(
              style: OutlinedButton.styleFrom(
                side: BorderSide(color: Colors.white.withValues(alpha: 0.15)),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 12,
                ),
              ),
              onPressed: _requestPermissionAndScan,
              icon: const Icon(Icons.refresh, color: Colors.white, size: 18),
              label: Text(
                AppLocalizations.of(context).refreshLibrary,
                style: TextStyle(color: Colors.white, fontSize: 13),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPlaylistCard(
    String title,
    List<Track> songs,
    Color color,
    IconData icon,
  ) {
    return ListTile(
      contentPadding: const EdgeInsets.only(
        left: 8,
        right: 0,
        top: 8,
        bottom: 8,
      ),
      onTap: () {
        setState(() {
          _selectedPlaylistDetail = title;
          _searchQuery = '';
          _searchController.clear();

          List<Track> pSongs = [];
          if (title == AppLocalizations.of(context).favourites) {
            pSongs = _allTracks
                .where((t) => _favoriteTrackIds.contains(t.id))
                .toList();
          } else if (title == AppLocalizations.of(context).recentlyAdded) {
            pSongs = List.from(_allTracks);
          } else if (title == AppLocalizations.of(context).lastPlayed) {
            final trackMap = {for (var t in _allTracks) t.id: t};
            pSongs = _allPlayedTrackIdsOrdered
                .where((id) => trackMap.containsKey(id))
                .map((id) => trackMap[id]!)
                .toList();
          } else if (title == AppLocalizations.of(context).mostPlayed) {
            pSongs = List.from(_allTracks);
            pSongs.sort(
              (a, b) =>
                  (_playCounts[b.id] ?? 0).compareTo(_playCounts[a.id] ?? 0),
            );
            pSongs = pSongs.where((t) => (_playCounts[t.id] ?? 0) > 0).toList();
          } else if (title == AppLocalizations.of(context).forgottenGems) {
            pSongs = _allTracks.reversed
                .where((t) => (_playCounts[t.id] ?? 0) <= 1)
                .toList();
          } else if (_userPlaylists.containsKey(title)) {
            pSongs = _allTracks
                .where((t) => _userPlaylists[title]!.contains(t.id))
                .toList();
          }
          _detailColorFuture = _getDetailColor(
            pSongs.isNotEmpty ? pSongs.first : null,
            playlistName: title,
          );
        });
      },
      leading: _playlistCovers.containsKey(title)
          ? Container(
              width: 56,
              height: 56,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(8),
                image: DecorationImage(
                  image: ResizeImage(
                    FileImage(File(_playlistCovers[title]!)),
                    width: 150,
                  ),
                  fit: BoxFit.cover,
                ),
              ),
            )
          : _buildStackedArtwork(
              songs,
              color,
              icon,
              title == AppLocalizations.of(context).favourites,
            ),
      title: Text(
        title,
        style: TextStyle(
          fontSize: 16,
          fontWeight: FontWeight.w600,
          color: isAppLight ? const Color(0xFF1A1A1A) : Colors.white,
        ),
      ),
      subtitle: Text(
        '${songs.length} ${AppLocalizations.of(context).songsCount}',
        style: TextStyle(
          fontSize: 13,
          color: isAppLight ? Colors.black54 : Colors.white54,
        ),
      ),
      trailing: Transform.translate(
        offset: const Offset(12, 0),
        child: IconButton(
          icon: Icon(
            Icons.more_vert,
            color: isAppLight ? Colors.black26 : Colors.white24,
            size: 20,
          ),
          padding: EdgeInsets.zero,
          constraints: const BoxConstraints(),
          onPressed: () => _showPlaylistOptions(context, title, songs),
        ),
      ),
    );
  }

  Widget _buildStackedArtwork(
    List<Track> tracks,
    Color color,
    IconData fallbackIcon,
    bool isFavorites,
  ) {
    final displayTracks = tracks.take(3).toList();

    if (displayTracks.isEmpty && !isFavorites) {
      return Container(
        width: 56,
        height: 56,
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.1),
          shape: BoxShape.circle,
        ),
        child: Icon(fallbackIcon, color: color, size: 24),
      );
    }

    Widget topmostWidget;
    if (isFavorites) {
      topmostWidget = Container(
        width: 56,
        height: 56,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          border: Border.all(color: const Color(0xFF0A0A0A), width: 2),
          gradient: const LinearGradient(
            colors: [Color(0xFFFF9800), Color(0xFFE91E63), Color(0xFF9C27B0)],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
        ),
        child: const Icon(Icons.favorite, color: Colors.white, size: 28),
      );
    } else {
      topmostWidget = Container(
        width: 56,
        height: 56,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          border: Border.all(color: const Color(0xFF0A0A0A), width: 2),
          color: color.withValues(alpha: 0.1),
        ),
        child: _buildTrackArtwork(displayTracks.first, size: 56, radius: 28),
      );
    }

    int totalItems = displayTracks.length;
    if (isFavorites) {
      totalItems = min(3, displayTracks.length + 1);
    }

    return SizedBox(
      width: 56 + (totalItems - 1) * 16.0,
      height: 56,
      child: Stack(
        alignment: Alignment.centerLeft,
        children: List.generate(totalItems, (index) {
          final reversedIndex = totalItems - 1 - index;

          if (reversedIndex == 0) {
            return Positioned(left: 0, child: topmostWidget);
          }

          final track =
              displayTracks[isFavorites ? reversedIndex - 1 : reversedIndex];

          return Positioned(
            left: reversedIndex * 16.0,
            child: Container(
              width: 56,
              height: 56,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(color: const Color(0xFF0A0A0A), width: 2),
                color: const Color(0xFF161616),
              ),
              child: _buildTrackArtwork(track, size: 56, radius: 28),
            ),
          );
        }),
      ),
    );
  }

  void _showQueueBottomSheet() {
    showModalBottomSheet(
      context: context,
      backgroundColor: const Color(0xFF161616),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (BuildContext context) {
        return StatefulBuilder(
          builder: (BuildContext context, StateSetter setModalState) {
            List<int> effectiveIndices = [];
            if (_repeatMode == 2) {
              effectiveIndices = [_currentIndex];
            } else if (_repeatMode == 1) {
              if (_isShuffle &&
                  _shuffledIndices.length == _playbackQueue.length) {
                int pos = _shuffledIndices.indexOf(_currentIndex);
                if (pos != -1) {
                  effectiveIndices = [
                    ..._shuffledIndices.sublist(pos),
                    ..._shuffledIndices.sublist(0, pos),
                  ];
                } else {
                  effectiveIndices = _shuffledIndices;
                }
              } else {
                effectiveIndices = [
                  ...List.generate(
                    _playbackQueue.length - _currentIndex,
                    (i) => _currentIndex + i,
                  ),
                  ...List.generate(_currentIndex, (i) => i),
                ];
              }
            } else {
              if (_isShuffle &&
                  _shuffledIndices.length == _playbackQueue.length) {
                int pos = _shuffledIndices.indexOf(_currentIndex);
                if (pos != -1) {
                  effectiveIndices = _shuffledIndices.sublist(pos);
                } else {
                  effectiveIndices = _shuffledIndices;
                }
              } else {
                effectiveIndices = List.generate(
                  _playbackQueue.length - _currentIndex,
                  (i) => _currentIndex + i,
                );
              }
            }

            return Column(
              children: [
                const SizedBox(height: 12),
                Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: Colors.white24,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
                const SizedBox(height: 16),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 24),
                  child: Row(
                    children: [
                      Text(
                        AppLocalizations.of(context).upNext,
                        style: const TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                        ),
                      ),
                      const Spacer(),
                      if (_isShuffle)
                        Icon(
                          Icons.shuffle,
                          color: _activeAccentColor,
                          size: 18,
                        ),
                      if (_isShuffle) const SizedBox(width: 8),
                      if (_repeatMode != 0)
                        Icon(
                          _repeatMode == 2 ? Icons.repeat_one : Icons.repeat,
                          color: _activeAccentColor,
                          size: 18,
                        ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),
                Expanded(
                  child: ReorderableListView.builder(
                    padding: EdgeInsets.zero,
                    physics: const BouncingScrollPhysics(),
                    itemCount: effectiveIndices.length,
                    onReorder: (oldIndex, newIndex) {
                      if (oldIndex == 0) {
                        return; // Cannot move currently playing track
                      }
                      if (oldIndex < newIndex) {
                        newIndex -= 1;
                      }
                      if (newIndex == 0) {
                        newIndex =
                            1; // Cannot move above currently playing track
                      }

                      setModalState(() {
                        final item = effectiveIndices.removeAt(oldIndex);
                        effectiveIndices.insert(newIndex, item);
                      });
                      reorderUpNext(effectiveIndices);
                    },
                    itemBuilder: (context, idx) {
                      final realIndex = effectiveIndices[idx];
                      final track = _playbackQueue[realIndex];
                      final isCurrent = realIndex == _currentIndex;
                      return ListTile(
                        key: ValueKey('up_next_${track.id}_$realIndex'),
                        contentPadding: const EdgeInsets.symmetric(
                          horizontal: 24,
                        ),
                        leading: _buildTrackArtwork(track, size: 40, radius: 6),
                        trailing: isCurrent
                            ? SizedBox(
                                width: 24,
                                height: 24,
                                child: Center(
                                  child: MiniMusicVisualizer(
                                    color: _activeAccentColor,
                                    width: 4,
                                    height: 14,
                                    radius: 2,
                                    animate: _isPlaying,
                                  ),
                                ),
                              )
                            : const Icon(
                                Icons.drag_handle,
                                color: Colors.white30,
                              ),
                        title: Text(
                          track.title,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            color: isCurrent
                                ? _activeAccentColor
                                : Colors.white,
                            fontWeight: isCurrent
                                ? FontWeight.bold
                                : FontWeight.normal,
                          ),
                        ),
                        subtitle: Text(
                          track.artist,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            color: Colors.white54,
                            fontSize: 12,
                          ),
                        ),
                        onTap: () {
                          Navigator.pop(context);
                          _playTrack(realIndex);
                        },
                      );
                    },
                  ),
                ),
              ],
            );
          },
        );
      },
    );
  }

  String _getParentDirectory(String filePath) {
    final lastSeparator = filePath.lastIndexOf('/');
    if (lastSeparator == -1) return '';
    return filePath.substring(0, lastSeparator);
  }
}
