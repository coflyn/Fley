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

  void _showImportPlaylistModal(BuildContext context) {
    final urlController = TextEditingController();
    final isLight = isAppLight;
    bool isLoading = false;
    String statusMessage = '';
    double progressValue = 0.0;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor:
          isLight ? const Color(0xFFF0F0F3) : const Color(0xFF1E1E22),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setModalState) {
            final bottomPadding = MediaQuery.of(context).viewInsets.bottom;
            return Padding(
              padding: EdgeInsets.only(
                left: 20,
                right: 20,
                top: 16,
                bottom: bottomPadding + 24,
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Center(
                    child: Container(
                      width: 36,
                      height: 4,
                      decoration: BoxDecoration(
                        color: isLight ? Colors.black12 : Colors.white24,
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                  ),
                  const SizedBox(height: 18),
                  Row(
                    children: [
                      Container(
                        width: 38,
                        height: 38,
                        decoration: BoxDecoration(
                          color: _activeAccentColor.withValues(alpha: 0.15),
                          shape: BoxShape.circle,
                        ),
                        child: Icon(
                          Icons.cloud_download_rounded,
                          color: _activeAccentColor,
                          size: 20,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Import Playlist',
                              style: TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                                color: isLight
                                    ? const Color(0xFF1A1A1A)
                                    : Colors.white,
                                fontFamily:
                                    getFontFamily(activeFontNotifier.value),
                              ),
                            ),
                            Text(
                              'Spotify / Apple Music / YouTube Music',
                              style: TextStyle(
                                fontSize: 12,
                                color:
                                    isLight ? Colors.black45 : Colors.white54,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 18),
                  if (!isLoading) ...[
                    Container(
                      decoration: BoxDecoration(
                        color: isLight
                            ? Colors.black.withValues(alpha: 0.04)
                            : Colors.white.withValues(alpha: 0.06),
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(
                          color: isLight
                              ? Colors.black.withValues(alpha: 0.08)
                              : Colors.white.withValues(alpha: 0.1),
                        ),
                      ),
                      child: TextField(
                        controller: urlController,
                        style: TextStyle(
                          fontSize: 14,
                          color:
                              isLight ? const Color(0xFF1A1A1A) : Colors.white,
                        ),
                        decoration: InputDecoration(
                          hintText:
                              'Paste Spotify, Apple Music, or YouTube link...',
                          hintStyle: TextStyle(
                            fontSize: 13,
                            color: isLight ? Colors.black38 : Colors.white38,
                          ),
                          border: InputBorder.none,
                          contentPadding: const EdgeInsets.symmetric(
                            horizontal: 16,
                            vertical: 14,
                          ),
                          suffixIcon: IconButton(
                            icon: const Icon(
                              Icons.content_paste_rounded,
                              size: 18,
                            ),
                            tooltip: 'Paste from clipboard',
                            onPressed: () async {
                              final data = await Clipboard.getData(
                                Clipboard.kTextPlain,
                              );
                              if (data?.text != null &&
                                  data!.text!.isNotEmpty) {
                                urlController.text = data.text!.trim();
                                setModalState(() {});
                              }
                            },
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 18),
                    Row(
                      children: [
                        Expanded(
                          child: TextButton(
                            style: TextButton.styleFrom(
                              padding: const EdgeInsets.symmetric(vertical: 14),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                            ),
                            onPressed: () => Navigator.pop(context),
                            child: Text(
                              AppLocalizations.of(context).cancel,
                              style: TextStyle(
                                color:
                                    isLight ? Colors.black54 : Colors.white60,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: ElevatedButton(
                            style: ElevatedButton.styleFrom(
                              backgroundColor: _activeAccentColor,
                              foregroundColor:
                                  _activeAccentColor.computeLuminance() > 0.4
                                      ? Colors.black
                                      : Colors.white,
                              padding: const EdgeInsets.symmetric(vertical: 14),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                              elevation: 0,
                            ),
                            onPressed: () async {
                              final url = urlController.text.trim();
                              if (url.isEmpty ||
                                  !PlaylistImportService.isSupportedUrl(url)) {
                                showFleyToast(
                                  'Invalid link. Please enter a Spotify, Apple Music, or YouTube link.',
                                );
                                return;
                              }

                              setModalState(() {
                                isLoading = true;
                                statusMessage = 'Processing playlist...';
                                progressValue = 0.1;
                              });

                              try {
                                final result =
                                    await PlaylistImportService.importPlaylist(
                                  url,
                                  onProgress: (msg, prog) {
                                    setModalState(() {
                                      statusMessage = msg;
                                      progressValue = prog;
                                    });
                                  },
                                );

                                if (result == null || result.tracks.isEmpty) {
                                  setModalState(() => isLoading = false);
                                  showFleyToast(
                                    'Failed to import. Make sure playlist is public.',
                                  );
                                  return;
                                }

                                var playlistName = result.title.trim();
                                if (playlistName.isEmpty) {
                                  playlistName = 'Imported Playlist';
                                }
                                if (_userPlaylists.containsKey(playlistName)) {
                                  playlistName = '$playlistName (Imported)';
                                }

                                for (final t in result.tracks) {
                                  _onlineTracksMap[t.id] = t;
                                }

                                setState(() {
                                  _userPlaylists[playlistName] =
                                      result.tracks.map((t) => t.id).toList();
                                  if (result.coverUrl != null &&
                                      result.coverUrl!.isNotEmpty) {
                                    _playlistCovers[playlistName] =
                                        result.coverUrl!;
                                    _savePlaylistCovers();
                                  }
                                  _cachedDetailKey = null;
                                  _saveUserPlaylists();
                                });

                                SharedPreferences.getInstance().then((prefs) {
                                  prefs.setString(
                                    'online_tracks_cache',
                                    jsonEncode(
                                      _onlineTracksMap.map(
                                        (k, v) => MapEntry(k, v.toMap()),
                                      ),
                                    ),
                                  );
                                });

                                if (!context.mounted) return;
                                Navigator.pop(context);
                                showFleyToast(
                                  'Imported "$playlistName" (${result.tracks.length} songs)',
                                );
                              } catch (e) {
                                setModalState(() => isLoading = false);
                                showFleyToast('Error: $e');
                              }
                            },
                            child: const Text(
                              'Import',
                              style: TextStyle(fontWeight: FontWeight.bold),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ] else ...[
                    Padding(
                      padding: const EdgeInsets.symmetric(vertical: 24),
                      child: Column(
                        children: [
                          LinearProgressIndicator(
                            value: progressValue > 0 ? progressValue : null,
                            backgroundColor:
                                (isLight ? Colors.black : Colors.white)
                                    .withValues(alpha: 0.1),
                            color: _activeAccentColor,
                            borderRadius: BorderRadius.circular(4),
                          ),
                          const SizedBox(height: 16),
                          Text(
                            statusMessage,
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              fontSize: 13,
                              color: isLight ? Colors.black54 : Colors.white70,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ],
              ),
            );
          },
        );
      },
    );
  }
}
