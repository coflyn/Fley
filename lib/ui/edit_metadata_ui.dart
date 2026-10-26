// ignore_for_file: invalid_use_of_protected_member, deprecated_member_use
part of '../main.dart';

extension _EditMetadataUI on _MainScreenState {
  void _showEditMetadataModal(BuildContext context, Track track) {
    final TextEditingController titleController = TextEditingController(
      text: track.title,
    );
    final TextEditingController artistController = TextEditingController(
      text: track.artist,
    );
    final TextEditingController albumController = TextEditingController(
      text: track.album,
    );

    String? currentCoverPath = _metadataOverrides[track.id]?['coverPath'];

    final isLight = isAppLight;

    showModalBottomSheet(
      context: context,
      backgroundColor: isLight
          ? const Color(0xFFF0F0F3)
          : const Color(0xFF161616),
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setModalState) {
            return Padding(
              padding: EdgeInsets.only(
                bottom: MediaQuery.of(context).viewInsets.bottom,
              ),
              child: SafeArea(
                child: Padding(
                  padding: const EdgeInsets.all(24.0),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        AppLocalizations.of(context).editMetadata,
                        style: TextStyle(
                          color: isLight
                              ? const Color(0xFF1A1A1A)
                              : Colors.white,
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          fontFamily: getFontFamily(_activeFont),
                        ),
                      ),
                      const SizedBox(height: 16),
                      Center(
                        child: GestureDetector(
                          onTap: () async {
                            final String? imagePath =
                                await _showCoverSourceSelector(this.context);
                            if (imagePath != null) {
                              setModalState(() {
                                currentCoverPath = imagePath == 'reset'
                                    ? null
                                    : imagePath;
                              });
                            }
                          },
                          child: Container(
                            width: 120,
                            height: 120,
                            decoration: BoxDecoration(
                              color: isLight
                                  ? Colors.black.withValues(alpha: 0.05)
                                  : Colors.white10,
                              borderRadius: BorderRadius.circular(12),
                              image: currentCoverPath != null
                                  ? DecorationImage(
                                      image: ResizeImage(
                                        FileImage(File(currentCoverPath!)),
                                        width: 300,
                                      ),
                                      fit: BoxFit.cover,
                                    )
                                  : null,
                            ),
                            child: currentCoverPath == null
                                ? Icon(
                                    Icons.add_a_photo,
                                    color: isLight
                                        ? Colors.black45
                                        : Colors.white54,
                                    size: 40,
                                  )
                                : null,
                          ),
                        ),
                      ),
                      const SizedBox(height: 16),
                      TextField(
                        controller: titleController,
                        style: TextStyle(
                          color: isLight
                              ? const Color(0xFF1A1A1A)
                              : Colors.white,
                          fontFamily: getFontFamily(_activeFont),
                        ),
                        decoration: InputDecoration(
                          labelText: AppLocalizations.of(context).title,
                          labelStyle: TextStyle(
                            color: isLight ? Colors.black54 : Colors.white54,
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
                      const SizedBox(height: 8),
                      TextField(
                        controller: artistController,
                        style: TextStyle(
                          color: isLight
                              ? const Color(0xFF1A1A1A)
                              : Colors.white,
                          fontFamily: getFontFamily(_activeFont),
                        ),
                        decoration: InputDecoration(
                          labelText: AppLocalizations.of(context).artist,
                          labelStyle: TextStyle(
                            color: isLight ? Colors.black54 : Colors.white54,
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
                      const SizedBox(height: 8),
                      TextField(
                        controller: albumController,
                        style: TextStyle(
                          color: isLight
                              ? const Color(0xFF1A1A1A)
                              : Colors.white,
                          fontFamily: getFontFamily(_activeFont),
                        ),
                        decoration: InputDecoration(
                          labelText: AppLocalizations.of(context).album,
                          labelStyle: TextStyle(
                            color: isLight ? Colors.black54 : Colors.white54,
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
                      const SizedBox(height: 24),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.end,
                        children: [
                          if (_metadataOverrides.containsKey(track.id))
                            TextButton(
                              onPressed: () async {
                                setState(() {
                                  _metadataOverrides.remove(track.id);
                                  _cachedDetailKey = null;
                                });
                                final msg = AppLocalizations.of(
                                  context,
                                ).metadataReset;
                                await _saveMetadataOverrides();
                                await _requestPermissionAndScan();

                                if (context.mounted) {
                                  final index = _allTracks.indexWhere(
                                    (t) => t.id == track.id,
                                  );
                                  if (index != -1) {
                                    final nativeTrack = _allTracks[index];
                                    setState(() {
                                      if (_playingTrack?.id == track.id) {
                                        _playingTrack = nativeTrack;
                                        _updateDominantColor(_playingTrack!);

                                        final currentMediaItem =
                                            audioHandler.mediaItem.value;
                                        if (currentMediaItem != null &&
                                            currentMediaItem.id == track.id) {
                                          _getCoverUriForTrack(
                                            nativeTrack,
                                          ).then((coverUri) {
                                            audioHandler.updateMediaItem(
                                              currentMediaItem.copyWith(
                                                title: nativeTrack.title,
                                                artist: nativeTrack.artist,
                                                album: nativeTrack.album,
                                                artUri: coverUri,
                                              ),
                                            );
                                          });
                                        }
                                      }
                                      for (
                                        int i = 0;
                                        i < _playbackQueue.length;
                                        i++
                                      ) {
                                        if (_playbackQueue[i].id == track.id) {
                                          _playbackQueue[i] = nativeTrack;
                                        }
                                      }
                                    });
                                  }
                                  Navigator.pop(context);
                                  showFleyToast(msg);
                                }
                              },
                              child: Text(
                                AppLocalizations.of(context).reset,
                                style: TextStyle(
                                  color: Colors.redAccent,
                                  fontFamily: getFontFamily(_activeFont),
                                ),
                              ),
                            ),
                          TextButton(
                            onPressed: () => Navigator.pop(context),
                            child: Text(
                              AppLocalizations.of(context).cancel,
                              style: TextStyle(
                                color: isLight
                                    ? Colors.black54
                                    : Colors.white54,
                                fontFamily: getFontFamily(_activeFont),
                              ),
                            ),
                          ),
                          const SizedBox(width: 8),
                          ElevatedButton(
                            style: ElevatedButton.styleFrom(
                              backgroundColor: _activeAccentColor,
                              foregroundColor: Colors.white,
                            ),
                            onPressed: () async {
                              setState(() {
                                _metadataOverrides[track.id] = {
                                  'title': titleController.text.trim(),
                                  'artist': artistController.text.trim(),
                                  'album': albumController.text.trim(),
                                };
                                if (currentCoverPath != null) {
                                  _metadataOverrides[track.id]!['coverPath'] =
                                      currentCoverPath!;
                                }

                                final index = _allTracks.indexWhere(
                                  (t) => t.id == track.id,
                                );
                                if (index != -1) {
                                  final t = _allTracks[index];
                                  _allTracks[index] = Track(
                                    id: t.id,
                                    title: titleController.text.trim(),
                                    artist: artistController.text.trim(),
                                    album: albumController.text.trim(),
                                    url: t.url,
                                    path: t.path,
                                    lyrics: t.lyrics,
                                    duration: t.duration,
                                  );
                                }

                                if (_playingTrack?.id == track.id &&
                                    index != -1) {
                                  _playingTrack = _allTracks[index];
                                  if (currentCoverPath != null) {
                                    _updateDominantColor(_playingTrack!);
                                  }

                                  final currentMediaItem =
                                      audioHandler.mediaItem.value;
                                  if (currentMediaItem != null &&
                                      currentMediaItem.id == track.id) {
                                    audioHandler.updateMediaItem(
                                      currentMediaItem.copyWith(
                                        title: titleController.text.trim(),
                                        artist: artistController.text.trim(),
                                        album: albumController.text.trim(),
                                        artUri: currentCoverPath != null
                                            ? Uri.file(currentCoverPath!)
                                            : currentMediaItem.artUri,
                                      ),
                                    );
                                  }
                                }

                                if (index != -1) {
                                  for (
                                    int i = 0;
                                    i < _playbackQueue.length;
                                    i++
                                  ) {
                                    if (_playbackQueue[i].id == track.id) {
                                      _playbackQueue[i] = _allTracks[index];
                                    }
                                  }
                                }
                                _cachedDetailKey =
                                    null; // Clear cache so Lists like Recently Added auto-update
                              });

                              await _saveMetadataOverrides();
                              if (context.mounted) Navigator.pop(context);

                              // Trigger a rebuild of the main application state after pop
                              Future.delayed(
                                const Duration(milliseconds: 50),
                                () {
                                  if (mounted) setState(() {});
                                },
                              );
                              showFleyToast(
                                lookupAppLocalizations(
                                  Locale(FleyStrings.currentLang),
                                ).metadataUpdatedLocal,
                              );
                            },
                            child: Text(
                              AppLocalizations.of(context).save,
                              style: TextStyle(color: Colors.black),
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
        );
      },
    );
  }
}
