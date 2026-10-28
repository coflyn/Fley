// ignore_for_file: invalid_use_of_protected_member, deprecated_member_use
part of '../main.dart';

extension _SortModalsUI on _MainScreenState {
  void _showDetailOptions(String title, String type, List<Track> tracks) {
    final isLight = isAppLight;
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: isLight
          ? const Color(0xFFF0F0F3)
          : const Color(0xFF161616),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (context) {
        return SafeArea(
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const SizedBox(height: 16),
                Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: isLight ? Colors.black12 : Colors.white24,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
                const SizedBox(height: 16),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 24),
                  child: Text(
                    title,
                    style: TextStyle(
                      color: isLight ? const Color(0xFF1A1A1A) : Colors.white,
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      fontFamily: getFontFamily(_activeFont),
                    ),
                    textAlign: TextAlign.center,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                const SizedBox(height: 24),
                _buildOptionItem(
                  Icons.playlist_play,
                  AppLocalizations.of(context).playNext,
                  () {
                    Navigator.pop(context);
                    if (tracks.length == 1 &&
                        _playingTrack?.id == tracks.first.id) {
                      showFleyToast(
                        AppLocalizations.of(context).cannotPlayNextActive,
                      );
                      return;
                    }
                    if (tracks.isNotEmpty) {
                      int insertPos = _currentIndex + 1;
                      int addedCount = 0;
                      for (final track in tracks) {
                        if (_playingTrack?.id == track.id) continue;
                        _moveTrackInQueue(track, insertPos);
                        insertPos++;
                        addedCount++;
                      }
                      if (addedCount > 0) {
                        showFleyToast(
                          lookupAppLocalizations(
                            Locale(FleyStrings.currentLang),
                          ).addedPlayNext,
                        );
                      } else {
                        showFleyToast(
                          AppLocalizations.of(context).cannotPlayNextActive,
                        );
                      }
                    }
                  },
                ),
                _buildOptionItem(
                  Icons.queue_music,
                  AppLocalizations.of(context).addToQueue,
                  () {
                    Navigator.pop(context);
                    if (tracks.isNotEmpty) {
                      _addTracksToQueue(tracks);
                      showFleyToast(
                        lookupAppLocalizations(
                          Locale(FleyStrings.currentLang),
                        ).addedSongsToQueue,
                      );
                    }
                  },
                ),
                _buildOptionItem(
                  Icons.playlist_add,
                  AppLocalizations.of(context).addToPlaylist,
                  () {
                    Navigator.pop(context);
                    _showMultiSelectSongsModal(
                      context,
                      candidateTracks: tracks,
                    );
                  },
                ),
                _buildOptionItem(
                  Icons.sort_rounded,
                  AppLocalizations.of(context).sortSongs,
                  () {
                    Navigator.pop(context);
                    _showDetailSortModal(context);
                  },
                ),
                if (type == AppLocalizations.of(context).album) ...[
                  _buildOptionItem(
                    Icons.image,
                    AppLocalizations.of(context).editAlbumCover,
                    () async {
                      Navigator.pop(context);
                      final String? imagePath = await _showCoverSourceSelector(
                        this.context,
                      );
                      if (imagePath != null) {
                        setState(() {
                          for (final track in tracks) {
                            if (imagePath == 'reset') {
                              if (_metadataOverrides.containsKey(track.id)) {
                                _metadataOverrides[track.id]!.remove('coverPath');
                              }
                            } else {
                              _metadataOverrides[track.id] ??= {
                                'title': track.title,
                                'artist': track.artist,
                                'album': track.album,
                              };
                              _metadataOverrides[track.id]!['coverPath'] =
                                  imagePath;
                            }
                          }
                          _cachedDetailKey =
                              null; // Force rebuild to show new cover
                        });
                        await _saveMetadataOverrides();
                        if (_playingTrack != null &&
                            tracks.any((t) => t.id == _playingTrack!.id)) {
                          _updateDominantColor(_playingTrack!);
                        }
                        showFleyToast(
                          imagePath == 'reset'
                              ? lookupAppLocalizations(
                                  Locale(FleyStrings.currentLang),
                                ).coverResetSuccess
                              : lookupAppLocalizations(
                                  Locale(FleyStrings.currentLang),
                                ).albumCoverUpdatedLocal,
                        );
                      }
                    },
                  ),
                ],
                if (type == 'Playlist') ...[
                  _buildOptionItem(
                    Icons.image,
                    AppLocalizations.of(context).editCover,
                    () async {
                      Navigator.pop(context);
                      final String? imagePath = await _showCoverSourceSelector(
                        this.context,
                      );
                      if (imagePath != null) {
                        setState(() {
                          if (imagePath == 'reset') {
                            _playlistCovers.remove(title);
                          } else {
                            _playlistCovers[title] = imagePath;
                          }
                          _cachedDetailKey =
                              null; // Force rebuild to show new cover
                        });
                        SharedPreferences.getInstance().then((prefs) {
                          prefs.setString(
                            'playlist_covers',
                            jsonEncode(_playlistCovers),
                          );
                        });
                        showFleyToast(
                          imagePath == 'reset'
                              ? lookupAppLocalizations(
                                  Locale(FleyStrings.currentLang),
                                ).coverResetSuccess
                              : lookupAppLocalizations(
                                  Locale(FleyStrings.currentLang),
                                ).coverUpdatedSuccess,
                        );
                      }
                    },
                  ),
                ],
                if (type == 'Playlist' &&
                    _userPlaylists.containsKey(title)) ...[
                  _buildOptionItem(
                    Icons.edit_note_rounded,
                    AppLocalizations.of(context).editSongs,
                    () {
                      Navigator.pop(context);
                      _showEditPlaylistSongsModal(context, title);
                    },
                  ),
                  _buildOptionItem(
                    Icons.add,
                    AppLocalizations.of(context).addSongs,
                    () {
                      Navigator.pop(context);
                      _showMultiSelectSongsModal(
                        context,
                        candidateTracks: _allTracks,
                        predefinedTargetPlaylist: title,
                      );
                    },
                  ),
                  _buildOptionItem(
                    Icons.edit,
                    AppLocalizations.of(context).renamePlaylist,
                    () {
                      Navigator.pop(context);
                      _showRenamePlaylistModal(context, title);
                    },
                  ),
                  _buildOptionItem(
                    Icons.delete_outline,
                    AppLocalizations.of(context).deletePlaylist,
                    () async {
                      Navigator.pop(context);
                      final bool? confirm = await showConfirmationDialog(
                        this.context,
                        title: AppLocalizations.of(context).confirmDelete,
                        content: AppLocalizations.of(
                          context,
                        ).confirmDeletePlaylist,
                        confirmText: AppLocalizations.of(context).delete,
                      );
                      if (confirm != true) return;

                      setState(() {
                        _userPlaylists.remove(title);
                        _playlistCovers.remove(title);
                        _selectedPlaylistDetail = null;
                      });
                      SharedPreferences.getInstance().then((prefs) {
                        prefs.setString(
                          'user_playlists',
                          jsonEncode(_userPlaylists),
                        );
                        prefs.setString(
                          'playlist_covers',
                          jsonEncode(_playlistCovers),
                        );
                      });
                    },
                    iconColor: Colors.red,
                  ),
                ],
                const SizedBox(height: 16),
              ],
            ),
          ),
        );
      },
    );
  }
}
