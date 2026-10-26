// ignore_for_file: invalid_use_of_protected_member, deprecated_member_use
part of '../main.dart';

extension _PlaylistEditSongsUI on _MainScreenState {
  void _showMultiSelectSongsModal(
    BuildContext context, {
    required List<Track> candidateTracks,
    String? predefinedTargetPlaylist,
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
                                    if (predefinedTargetPlaylist != null) {
                                      setState(() {
                                        _userPlaylists[predefinedTargetPlaylist]!
                                            .addAll(selectedTrackIds);
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
                              predefinedTargetPlaylist != null
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
    final playlistSongs = _allTracks
        .where((t) => trackIds.contains(t.id))
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
                                candidateTracks: _allTracks,
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
                          : ListView.builder(
                              controller: scrollController,
                              itemCount: playlistSongs.length,
                              itemBuilder: (context, index) {
                                final track = playlistSongs[index];
                                final isSelected = selectedForDeletion.contains(
                                  track.id,
                                );
                                return ListTile(
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
                                  trailing: Checkbox(
                                    value: isSelected,
                                    activeColor: Colors.redAccent,
                                    onChanged: (val) {
                                      setModalState(() {
                                        if (isSelected) {
                                          selectedForDeletion.remove(track.id);
                                        } else {
                                          selectedForDeletion.add(track.id);
                                        }
                                      });
                                    },
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
