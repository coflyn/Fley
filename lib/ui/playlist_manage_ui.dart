// ignore_for_file: invalid_use_of_protected_member, deprecated_member_use
part of '../main.dart';

extension _PlaylistManageUI on _MainScreenState {
  void _showAddToPlaylistModal(BuildContext context, List<Track> tracksToAdd) {
    final isLight = isAppLight;
    showModalBottomSheet(
      context: context,
      backgroundColor: isLight
          ? const Color(0xFFF0F0F3)
          : const Color(0xFF161616),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setModalState) {
            return SafeArea(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Padding(
                    padding: const EdgeInsets.all(16.0),
                    child: Text(
                      AppLocalizations.of(context).addToPlaylist,
                      style: TextStyle(
                        color: isLight ? const Color(0xFF1A1A1A) : Colors.white,
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        fontFamily: getFontFamily(_activeFont),
                      ),
                    ),
                  ),
                  Divider(
                    color: isLight
                        ? Colors.black.withValues(alpha: 0.08)
                        : Colors.white10,
                    height: 1,
                  ),
                  ListTile(
                    leading: Icon(Icons.add, color: _activeAccentColor),
                    title: Text(
                      AppLocalizations.of(context).createNewPlaylist,
                      style: TextStyle(
                        color: _activeAccentColor,
                        fontFamily: getFontFamily(_activeFont),
                      ),
                    ),
                    onTap: () {
                      Navigator.pop(context);
                      _showCreatePlaylistModal(
                        context,
                        tracksToAdd: tracksToAdd,
                      );
                    },
                  ),
                  if (_userPlaylists.isNotEmpty)
                    Divider(
                      color: isLight
                          ? Colors.black.withValues(alpha: 0.08)
                          : Colors.white10,
                      height: 1,
                    ),
                  ..._userPlaylists.keys.map((playlistName) {
                    return ListTile(
                      leading: Icon(
                        Icons.queue_music,
                        color: isLight ? Colors.black54 : Colors.white70,
                      ),
                      title: Text(
                        playlistName,
                        style: TextStyle(
                          color: isLight
                              ? const Color(0xFF1A1A1A)
                              : Colors.white,
                          fontFamily: getFontFamily(_activeFont),
                        ),
                      ),
                      onTap: () {
                        int addedCount = 0;
                        int skippedCount = 0;
                        setState(() {
                          for (final track in tracksToAdd) {
                            if (!_userPlaylists[playlistName]!.contains(
                              track.id,
                            )) {
                              _userPlaylists[playlistName]!.add(track.id);
                              addedCount++;
                              if (_MainScreenState
                                      .mainScreenState!
                                      ._playingFromName ==
                                  playlistName) {
                                _MainScreenState.mainScreenState!
                                    ._addTrackToQueueDynamically(track.id);
                              }
                            } else {
                              skippedCount++;
                            }
                          }
                          if (addedCount > 0) {
                            _cachedDetailKey = null;
                            _saveUserPlaylists();
                          }
                        });
                        Navigator.pop(context);
                        if (tracksToAdd.length == 1) {
                          if (skippedCount > 0) {
                            showFleyToast(
                              AppLocalizations.of(context)
                                  .toastSongAlreadyInPlaylist
                                  .replaceFirst(
                                    '[placeholder]',
                                    tracksToAdd.first.title,
                                  )
                                  .replaceFirst('[placeholder]', playlistName),
                            );
                          } else {
                            showFleyToast(
                              AppLocalizations.of(context).toastAddedSongTo
                                  .replaceFirst(
                                    '[placeholder]',
                                    tracksToAdd.first.title,
                                  )
                                  .replaceFirst('[placeholder]', playlistName),
                            );
                          }
                        } else {
                          if (addedCount == 0) {
                            showFleyToast(
                              AppLocalizations.of(context)
                                  .toastSelectedSongsAlreadyIn
                                  .replaceFirst('[placeholder]', playlistName),
                            );
                          } else if (skippedCount > 0) {
                            showFleyToast(
                              AppLocalizations.of(context)
                                  .toastAddedSongsSkipped
                                  .replaceFirst('[placeholder]', '$addedCount')
                                  .replaceFirst('[placeholder]', playlistName)
                                  .replaceFirst(
                                    '[placeholder]',
                                    '$skippedCount',
                                  ),
                            );
                          } else {
                            showFleyToast(
                              AppLocalizations.of(context)
                                  .toastAddedSongsToSimple
                                  .replaceFirst('[placeholder]', '$addedCount')
                                  .replaceFirst('[placeholder]', playlistName),
                            );
                          }
                        }
                      },
                    );
                  }),
                  const SizedBox(height: 16),
                ],
              ),
            );
          },
        );
      },
    );
  }

  void _showCreatePlaylistModal(
    BuildContext context, {
    List<Track>? tracksToAdd,
  }) {
    final TextEditingController nameController = TextEditingController();
    final isLight = isAppLight;
    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          backgroundColor: isLight
              ? const Color(0xFFF0F0F3)
              : const Color(0xFF282828),
          title: Text(
            AppLocalizations.of(context).newPlaylist,
            style: TextStyle(
              color: isLight ? const Color(0xFF1A1A1A) : Colors.white,
              fontFamily: getFontFamily(_activeFont),
            ),
          ),
          content: TextField(
            controller: nameController,
            style: TextStyle(
              color: isLight ? const Color(0xFF1A1A1A) : Colors.white,
              fontFamily: getFontFamily(_activeFont),
            ),
            decoration: InputDecoration(
              hintText: AppLocalizations.of(context).playlistNamePlaceholder,
              hintStyle: TextStyle(
                color: isLight ? Colors.black38 : Colors.white54,
                fontFamily: getFontFamily(_activeFont),
              ),
              enabledBorder: UnderlineInputBorder(
                borderSide: BorderSide(
                  color: isLight ? Colors.black12 : Colors.white24,
                ),
              ),
              focusedBorder: UnderlineInputBorder(
                borderSide: BorderSide(color: _activeAccentColor),
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: Text(
                AppLocalizations.of(context).cancel,
                style: TextStyle(
                  color: isLight ? Colors.black45 : Colors.white54,
                  fontFamily: getFontFamily(_activeFont),
                ),
              ),
            ),
            TextButton(
              onPressed: () {
                final name = nameController.text.trim();
                if (name.isNotEmpty && !_userPlaylists.containsKey(name)) {
                  setState(() {
                    _userPlaylists[name] = tracksToAdd != null
                        ? tracksToAdd.map((t) => t.id).toList()
                        : [];
                    _cachedDetailKey = null;
                    _saveUserPlaylists();
                  });
                  Navigator.pop(context);
                  showFleyToast(
                    AppLocalizations.of(
                      context,
                    ).playlistCreatedFormat.replaceFirst('[placeholder]', name),
                  );
                }
              },
              child: Text(
                AppLocalizations.of(context).createPlaylist.split(' ')[0],
                style: TextStyle(
                  color: _activeAccentColor,
                  fontWeight: FontWeight.bold,
                  fontFamily: getFontFamily(_activeFont),
                ),
              ),
            ),
          ],
        );
      },
    );
  }

  void _showRenamePlaylistModal(BuildContext context, String oldName) {
    final TextEditingController nameController = TextEditingController(
      text: oldName,
    );
    final isLight = isAppLight;
    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          backgroundColor: isLight
              ? const Color(0xFFF0F0F3)
              : const Color(0xFF282828),
          title: Text(
            AppLocalizations.of(context).renamePlaylist,
            style: TextStyle(
              color: isLight ? const Color(0xFF1A1A1A) : Colors.white,
              fontFamily: getFontFamily(_activeFont),
            ),
          ),
          content: TextField(
            controller: nameController,
            style: TextStyle(
              color: isLight ? const Color(0xFF1A1A1A) : Colors.white,
              fontFamily: getFontFamily(_activeFont),
            ),
            decoration: InputDecoration(
              hintText: AppLocalizations.of(context).playlistNamePlaceholder,
              hintStyle: TextStyle(
                color: isLight ? Colors.black38 : Colors.white54,
                fontFamily: getFontFamily(_activeFont),
              ),
              enabledBorder: UnderlineInputBorder(
                borderSide: BorderSide(
                  color: isLight ? Colors.black12 : Colors.white24,
                ),
              ),
              focusedBorder: UnderlineInputBorder(
                borderSide: BorderSide(color: _activeAccentColor),
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: Text(
                AppLocalizations.of(context).cancel,
                style: TextStyle(
                  color: isLight ? Colors.black45 : Colors.white54,
                  fontFamily: getFontFamily(_activeFont),
                ),
              ),
            ),
            TextButton(
              onPressed: () {
                final newName = nameController.text.trim();
                if (newName.isNotEmpty &&
                    newName != oldName &&
                    !_userPlaylists.containsKey(newName)) {
                  setState(() {
                    final tracks = _userPlaylists.remove(oldName);
                    _userPlaylists[newName] = tracks!;
                    if (_playlistCovers.containsKey(oldName)) {
                      _playlistCovers[newName] = _playlistCovers.remove(
                        oldName,
                      )!;
                      _savePlaylistCovers();
                    }
                    if (_selectedPlaylistDetail == oldName) {
                      _selectedPlaylistDetail = newName;
                    }
                    _saveUserPlaylists();
                  });
                  Navigator.pop(context);
                  showFleyToast(AppLocalizations.of(context).playlistRenamed);
                } else if (_userPlaylists.containsKey(newName)) {
                  showFleyToast(
                    AppLocalizations.of(context).playlistNameExists,
                  );
                }
              },
              child: Text(
                AppLocalizations.of(context).save,
                style: TextStyle(
                  color: _activeAccentColor,
                  fontWeight: FontWeight.bold,
                  fontFamily: getFontFamily(_activeFont),
                ),
              ),
            ),
          ],
        );
      },
    );
  }

  void _showPlaylistOptions(
    BuildContext context,
    String title,
    List<Track> songs,
  ) {
    final isCustomPlaylist = _userPlaylists.containsKey(title);
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
                  Icons.play_arrow,
                  AppLocalizations.of(context).playAll,
                  () {
                    Navigator.pop(context);
                    if (songs.isNotEmpty) {
                      _playTrack(0, sourceList: songs);
                    } else {
                      showFleyToast(AppLocalizations.of(context).playlistEmpty);
                    }
                  },
                ),
                _buildOptionItem(
                  Icons.queue_music,
                  AppLocalizations.of(context).addToQueue,
                  () {
                    Navigator.pop(context);
                    if (songs.isNotEmpty) {
                      _playbackQueue.addAll(songs);
                      showFleyToast(
                        AppLocalizations.of(context).addedSongsToQueue,
                      );
                    }
                  },
                ),
                _buildOptionItem(
                  Icons.playlist_add,
                  AppLocalizations.of(context).addToPlaylist,
                  () {
                    Navigator.pop(context);
                    _showMultiSelectSongsModal(context, candidateTracks: songs);
                  },
                ),
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
                      });
                      _savePlaylistCovers();
                      showFleyToast(
                        imagePath == 'reset'
                            ? lookupAppLocalizations(
                                Locale(FleyStrings.currentLang),
                              ).coverResetSuccess
                            : lookupAppLocalizations(
                                Locale(FleyStrings.currentLang),
                              ).playlistCoverUpdated,
                      );
                    }
                  },
                ),
                if (isCustomPlaylist) ...[
                  Divider(
                    color: isLight
                        ? Colors.black.withValues(alpha: 0.08)
                        : Colors.white10,
                    height: 1,
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
                        _savePlaylistCovers();
                        if (_selectedPlaylistDetail == title) {
                          _selectedPlaylistDetail = null;
                        }
                      });
                      _saveUserPlaylists();
                      showFleyToast(
                        lookupAppLocalizations(
                          Locale(FleyStrings.currentLang),
                        ).playlistDeleted,
                      );
                    },
                    iconColor: Colors.redAccent,
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
