// ignore_for_file: invalid_use_of_protected_member, deprecated_member_use
part of '../main.dart';

extension _PlaylistEditSongsUI on _MainScreenState {
  void _showMultiSelectSongsModal(
    BuildContext context, {
    required List<Track> candidateTracks,
    String? predefinedTargetPlaylist,
    bool isFavouritesTarget = false,
  }) {
    Set<String> selectedTrackIds = {};

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
        return StatefulBuilder(
          builder: (context, setModalState) {
            return DraggableScrollableSheet(
              initialChildSize: 0.9,
              minChildSize: 0.5,
              maxChildSize: 0.9,
              expand: false,
              builder: (_, scrollController) {
                return Column(
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
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            AppLocalizations.of(context).selectSongs,
                            style: TextStyle(
                              color: isLight
                                  ? const Color(0xFF1A1A1A)
                                  : Colors.white,
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                              fontFamily: getFontFamily(_activeFont),
                            ),
                          ),
                          TextButton(
                            onPressed: selectedTrackIds.isEmpty
                                ? null
                                : () {
                                    Navigator.pop(context);
                                    final selectedTracks = candidateTracks
                                        .where(
                                          (t) =>
                                              selectedTrackIds.contains(t.id),
                                        )
                                        .toList();
                                    if (isFavouritesTarget) {
                                      setState(() {
                                        final addToTop =
                                            playlistAddSongPositionNotifier
                                                    .value ==
                                                'top';
                                        final newIds = selectedTrackIds
                                            .where(
                                              (id) => !_favoriteTrackIds
                                                  .contains(id),
                                            )
                                            .toList();
                                        if (addToTop) {
                                          final currentList =
                                              _favoriteTrackIds.toList();
                                          _favoriteTrackIds.clear();
                                          _favoriteTrackIds.addAll(newIds);
                                          _favoriteTrackIds.addAll(currentList);
                                        } else {
                                          _favoriteTrackIds.addAll(newIds);
                                        }
                                        _cachedDetailKey = null;
                                      });
                                      SharedPreferences.getInstance().then(
                                        (prefs) {
                                          prefs.setStringList(
                                            'favorite_track_ids',
                                            _favoriteTrackIds.toList(),
                                          );
                                        },
                                      );
                                      showFleyToast(
                                        AppLocalizations.of(context)
                                            .toastAddedSongsToSimple
                                            .replaceFirst(
                                              '{}',
                                              '${selectedTrackIds.length}',
                                            )
                                            .replaceFirst(
                                              '{}',
                                              AppLocalizations.of(context)
                                                  .favourites,
                                            ),
                                      );
                                    } else if (predefinedTargetPlaylist != null) {
                                      setState(() {
                                        final addToTop =
                                            playlistAddSongPositionNotifier
                                                    .value ==
                                                'top';
                                        final newIds = selectedTrackIds
                                            .where(
                                              (id) => !_userPlaylists[
                                                      predefinedTargetPlaylist]!
                                                  .contains(id),
                                            )
                                            .toList();
                                        if (addToTop) {
                                          _userPlaylists[
                                                  predefinedTargetPlaylist]!
                                              .insertAll(0, newIds);
                                        } else {
                                          _userPlaylists[
                                                  predefinedTargetPlaylist]!
                                              .addAll(newIds);
                                        }
                                        _cachedDetailKey = null;
                                        _saveUserPlaylists();
                                      });
                                      showFleyToast(
                                        AppLocalizations.of(context)
                                            .toastAddedSongsToSimple
                                            .replaceFirst(
                                              '{}',
                                              '${selectedTrackIds.length}',
                                            )
                                            .replaceFirst(
                                              '{}',
                                              predefinedTargetPlaylist,
                                            ),
                                      );
                                    } else {
                                      _showAddToPlaylistModal(
                                        context,
                                        selectedTracks,
                                      );
                                    }
                                  },
                            child: Text(
                              (predefinedTargetPlaylist != null ||
                                      isFavouritesTarget)
                                  ? AppLocalizations.of(context).save
                                  : AppLocalizations.of(context).next,
                              style: TextStyle(
                                color: selectedTrackIds.isEmpty
                                    ? (isLight
                                          ? Colors.black12
                                          : Colors.white24)
                                    : _activeAccentColor,
                                fontWeight: FontWeight.bold,
                                fontFamily: getFontFamily(_activeFont),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    Divider(
                      color: isLight
                          ? Colors.black.withValues(alpha: 0.08)
                          : Colors.white10,
                    ),
                    Expanded(
                      child: ListView.builder(
                        controller: scrollController,
                        itemCount: candidateTracks.length,
                        itemBuilder: (context, index) {
                          final track = candidateTracks[index];
                          final isSelected = selectedTrackIds.contains(
                            track.id,
                          );
                          return ListTile(
                            leading: _buildTrackArtwork(
                              track,
                              size: 44,
                              radius: 6,
                            ),
                            title: Text(
                              track.title,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                color: isLight
                                    ? const Color(0xFF1A1A1A)
                                    : Colors.white,
                                fontFamily: getFontFamily(_activeFont),
                              ),
                            ),
                            subtitle: Text(
                              track.artist,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                color: isLight
                                    ? Colors.black54
                                    : Colors.white54,
                                fontSize: 12,
                                fontFamily: getFontFamily(_activeFont),
                              ),
                            ),
                            trailing: Checkbox(
                              value: isSelected,
                              activeColor: _activeAccentColor,
                              checkColor: isLight ? Colors.white : Colors.black,
                              onChanged: (val) {
                                setModalState(() {
                                  if (val == true) {
                                    selectedTrackIds.add(track.id);
                                  } else {
                                    selectedTrackIds.remove(track.id);
                                  }
                                });
                              },
                            ),
                            onTap: () {
                              setModalState(() {
                                if (isSelected) {
                                  selectedTrackIds.remove(track.id);
                                } else {
                                  selectedTrackIds.add(track.id);
                                }
                              });
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
      },
    );
  }

  void _showEditPlaylistSongsModal(BuildContext context, String playlistName) {
    final trackIds = _userPlaylists[playlistName] ?? <String>[];
    final trackMap = {for (var t in _allTracks) t.id: t, ..._onlineTracksMap};
    final playlistSongs = trackIds
        .where((id) => trackMap.containsKey(id))
        .map((id) => trackMap[id]!)
        .toList();

    Set<String> selectedForDeletion = {};
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
        return StatefulBuilder(
          builder: (context, setModalState) {
            final hasSelection = selectedForDeletion.isNotEmpty;
            final isAllSelected =
                playlistSongs.isNotEmpty &&
                selectedForDeletion.length == playlistSongs.length;

            return DraggableScrollableSheet(
              initialChildSize: 0.9,
              minChildSize: 0.5,
              maxChildSize: 0.9,
              expand: false,
              builder: (_, scrollController) {
                return Column(
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
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Expanded(
                            child: Text(
                              '${AppLocalizations.of(context).editPlaylistTitle} "$playlistName"',
                              style: TextStyle(
                                color: isLight
                                    ? const Color(0xFF1A1A1A)
                                    : Colors.white,
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                                fontFamily: getFontFamily(_activeFont),
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          TextButton(
                            onPressed: () {
                              Navigator.pop(context);
                            },
                            child: Text(
                              AppLocalizations.of(context).done,
                              style: TextStyle(
                                color: _activeAccentColor,
                                fontWeight: FontWeight.bold,
                                fontFamily: getFontFamily(_activeFont),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    Divider(
                      color: isLight
                          ? Colors.black.withValues(alpha: 0.08)
                          : Colors.white10,
                    ),

                    // Toolbar for Add Songs, Select All, and Delete
                    Padding(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 24,
                        vertical: 8,
                      ),
                      child: Row(
                        children: [
                          // Add Songs Pill
                          OutlinedButton.icon(
                            onPressed: () {
                              Navigator.pop(context);
                              _showMultiSelectSongsModal(
                                context,
                                candidateTracks: [
                                  ..._allTracks,
                                  ..._onlineTracksMap.values.where(
                                    (ot) => !_allTracks.any((t) => t.id == ot.id),
                                  ),
                                ],
                                predefinedTargetPlaylist: playlistName,
                              );
                            },
                            icon: Icon(
                              Icons.add,
                              size: 16,
                              color: isLight ? Colors.black87 : Colors.white,
                            ),
                            label: Text(
                              AppLocalizations.of(context).addSongs,
                              style: TextStyle(
                                color: isLight ? Colors.black87 : Colors.white,
                                fontSize: 12,
                                fontFamily: getFontFamily(_activeFont),
                              ),
                            ),
                            style: OutlinedButton.styleFrom(
                              side: BorderSide(
                                color: isLight
                                    ? Colors.black12
                                    : Colors.white24,
                              ),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(20),
                              ),
                              padding: const EdgeInsets.symmetric(
                                horizontal: 16,
                                vertical: 8,
                              ),
                            ),
                          ),
                          const SizedBox(width: 12),
                          // Select All text
                          TextButton(
                            onPressed: playlistSongs.isEmpty
                                ? null
                                : () {
                                    setModalState(() {
                                      if (isAllSelected) {
                                        selectedForDeletion.clear();
                                      } else {
                                        selectedForDeletion = playlistSongs
                                            .map((t) => t.id)
                                            .toSet();
                                      }
                                    });
                                  },
                            child: Text(
                              isAllSelected
                                  ? AppLocalizations.of(context).deselectAll
                                  : AppLocalizations.of(context).selectAll,
                              style: TextStyle(
                                color: isLight
                                    ? Colors.black54
                                    : Colors.white70,
                                fontSize: 12,
                                fontFamily: getFontFamily(_activeFont),
                              ),
                            ),
                          ),
                          const Spacer(),
                          IconButton(
                            onPressed: !hasSelection
                                ? null
                                : () {
                                    showDialog(
                                      context: context,
                                      builder: (ctx) => AlertDialog(
                                        backgroundColor: isLight
                                            ? const Color(0xFFF0F0F3)
                                            : const Color(0xFF1E1E1E),
                                        title: Text(
                                          AppLocalizations.of(
                                            context,
                                          ).removeSongsConfirm,
                                          style: TextStyle(
                                            color: isLight
                                                ? const Color(0xFF1A1A1A)
                                                : Colors.white,
                                            fontFamily: getFontFamily(_activeFont),
                                          ),
                                        ),
                                        content: Text(
                                          AppLocalizations.of(
                                            context,
                                          ).removeSongsBody,
                                          style: TextStyle(
                                            color: isLight
                                                ? Colors.black54
                                                : Colors.white70,
                                            fontFamily: getFontFamily(_activeFont),
                                          ),
                                        ),
                                        actions: [
                                          TextButton(
                                            onPressed: () => Navigator.pop(ctx),
                                            child: Text(
                                              AppLocalizations.of(
                                                context,
                                              ).cancel,
                                              style: TextStyle(
                                                color: isLight
                                                    ? Colors.black38
                                                    : Colors.white38,
                                                fontFamily: getFontFamily(_activeFont),
                                              ),
                                            ),
                                          ),
                                          TextButton(
                                            onPressed: () {
                                              Navigator.pop(ctx);
                                              setState(() {
                                                _userPlaylists[playlistName]!
                                                    .removeWhere(
                                                      (id) =>
                                                          selectedForDeletion
                                                              .contains(id),
                                                    );
                                                _cachedDetailKey = null;
                                                _saveUserPlaylists();
                                              });
                                              Navigator.pop(
                                                context,
                                              ); // Close sheet
                                              showFleyToast(
                                                AppLocalizations.of(
                                                  context,
                                                ).removedSongsToast,
                                              );
                                            },
                                            child: Text(
                                              AppLocalizations.of(
                                                context,
                                              ).remove,
                                              style: TextStyle(
                                                color: Colors.redAccent,
                                                fontWeight: FontWeight.bold,
                                                fontFamily: getFontFamily(_activeFont),
                                              ),
                                            ),
                                          ),
                                        ],
                                      ),
                                    );
                                  },
                            icon: Icon(
                              Icons.delete_outline,
                              color: hasSelection
                                  ? Colors.redAccent
                                  : (isLight ? Colors.black12 : Colors.white24),
                            ),
                            tooltip: AppLocalizations.of(context).delete,
                          ),
                        ],
                      ),
                    ),
                    Divider(
                      color: isLight
                          ? Colors.black.withValues(alpha: 0.08)
                          : Colors.white10,
                    ),

                    Expanded(
                      child: playlistSongs.isEmpty
                          ? Center(
                              child: Text(
                                AppLocalizations.of(context).noSongsInPlaylist,
                                style: TextStyle(
                                  color: isLight
                                      ? Colors.black38
                                      : Colors.white30,
                                  fontFamily: getFontFamily(_activeFont),
                                ),
                              ),
                            )
                          : ReorderableListView.builder(
                              scrollController: scrollController,
                              buildDefaultDragHandles: false,
                              itemCount: playlistSongs.length,
                              onReorder: (oldIndex, newIndex) {
                                if (oldIndex < newIndex) {
                                  newIndex -= 1;
                                }
                                setModalState(() {
                                  final item = playlistSongs.removeAt(oldIndex);
                                  playlistSongs.insert(newIndex, item);
                                  final id = _userPlaylists[playlistName]!
                                      .removeAt(oldIndex);
                                  _userPlaylists[playlistName]!
                                      .insert(newIndex, id);
                                  _cachedDetailKey = null;
                                  _saveUserPlaylists();
                                });
                                setState(() {
                                  _detailSortBy = 'default';
                                });
                                SharedPreferences.getInstance().then((prefs) {
                                  prefs.setString('detailSortBy', 'default');
                                });
                              },
                              itemBuilder: (context, index) {
                                final track = playlistSongs[index];
                                final isSelected = selectedForDeletion.contains(
                                  track.id,
                                );
                                return ListTile(
                                  key: ValueKey('edit_pl_${track.id}_$index'),
                                  onTap: () {
                                    setModalState(() {
                                      if (isSelected) {
                                        selectedForDeletion.remove(track.id);
                                      } else {
                                        selectedForDeletion.add(track.id);
                                      }
                                    });
                                  },
                                  leading: _buildTrackArtwork(
                                    track,
                                    size: 44,
                                    radius: 6,
                                  ),
                                  title: Text(
                                    track.title,
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: TextStyle(
                                      color: isLight
                                          ? const Color(0xFF1A1A1A)
                                          : Colors.white,
                                      fontFamily: getFontFamily(_activeFont),
                                    ),
                                  ),
                                  subtitle: Text(
                                    track.artist,
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: TextStyle(
                                      color: isLight
                                          ? Colors.black54
                                          : Colors.white54,
                                      fontSize: 12,
                                      fontFamily: getFontFamily(_activeFont),
                                    ),
                                  ),
                                  trailing: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      if (index > 0)
                                        Tooltip(
                                          message: AppLocalizations.of(context)
                                              .moveToTop,
                                          child: IconButton(
                                            icon: const Icon(
                                              Icons.vertical_align_top_rounded,
                                              size: 20,
                                            ),
                                            color: isLight
                                                ? Colors.black45
                                                : Colors.white60,
                                            onPressed: () {
                                              final movedMsg =
                                                  AppLocalizations.of(context)
                                                      .songMovedToTop;
                                              setModalState(() {
                                                final item = playlistSongs
                                                    .removeAt(index);
                                                playlistSongs.insert(0, item);
                                                final id =
                                                    _userPlaylists[playlistName]!
                                                        .removeAt(index);
                                                _userPlaylists[playlistName]!
                                                    .insert(0, id);
                                                _cachedDetailKey = null;
                                                _saveUserPlaylists();
                                              });
                                              setState(() {
                                                _detailSortBy = 'default';
                                              });
                                              SharedPreferences.getInstance()
                                                  .then((prefs) {
                                                prefs.setString(
                                                  'detailSortBy',
                                                  'default',
                                                );
                                              });
                                              showFleyToast(movedMsg);
                                            },
                                          ),
                                        ),
                                      Checkbox(
                                        value: isSelected,
                                        activeColor: Colors.redAccent,
                                        onChanged: (val) {
                                          setModalState(() {
                                            if (isSelected) {
                                              selectedForDeletion
                                                  .remove(track.id);
                                            } else {
                                              selectedForDeletion.add(track.id);
                                            }
                                          });
                                        },
                                      ),
                                      ReorderableDragStartListener(
                                        index: index,
                                        child: Padding(
                                          padding: const EdgeInsets.symmetric(
                                            horizontal: 4,
                                          ),
                                          child: Icon(
                                            Icons.drag_handle_rounded,
                                            color: isLight
                                                ? Colors.black38
                                                : Colors.white38,
                                            size: 22,
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
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
      },
    );
  }
}
