// ignore_for_file: invalid_use_of_protected_member, deprecated_member_use
part of '../main.dart';

extension _TrackOptionsUI on _MainScreenState {
  void _showTrackOptions(
    BuildContext context,
    Track track, {
    bool isFromPlayer = false,
    String? playlistContext,
  }) {
    final isLight = isAppLight;
    final sheetBg = isLight
        ? const Color(0xFFF0F0F3)
        : const Color(0xFF161616);
    final scrollController = ScrollController();
    final canScrollMore = ValueNotifier<bool>(true);

    void checkScroll() {
      if (!scrollController.hasClients) return;
      final max = scrollController.position.maxScrollExtent;
      final current = scrollController.offset;
      final hasMore = max > 10 && current < max - 20;
      if (canScrollMore.value != hasMore) {
        canScrollMore.value = hasMore;
      }
    }

    scrollController.addListener(checkScroll);

    showModalBottomSheet(
      context: context,
      backgroundColor: sheetBg,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (context) {
        WidgetsBinding.instance.addPostFrameCallback((_) => checkScroll());
        return StatefulBuilder(
          builder: (context, setModalState) {
            final isFavorited = _favoriteTrackIds.contains(track.id);
            final isYtm = track.id.startsWith('ytm_');
            final videoId = track.path.isNotEmpty
                ? track.path
                : track.id.replaceFirst('ytm_', '');
            final isDownloaded = isYtm &&
                _allTracks.any(
                  (t) =>
                      t.id == 'local_ytm_$videoId' ||
                      (videoId.isNotEmpty && t.path.contains(videoId)),
                );
            final screenHeight = MediaQuery.sizeOf(context).height;
            return SafeArea(
              child: ConstrainedBox(
                constraints: BoxConstraints(
                  maxHeight: screenHeight * 0.72,
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const SizedBox(height: 12),
                    Container(
                      width: 36,
                      height: 4,
                      decoration: BoxDecoration(
                        color: isLight ? Colors.black12 : Colors.white24,
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                    Padding(
                      padding: const EdgeInsets.fromLTRB(16.0, 10.0, 16.0, 14.0),
                      child: Row(
                        children: [
                          _buildTrackArtwork(track, size: 48, radius: 8),
                          const SizedBox(width: 16),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  track.title,
                                  style: TextStyle(
                                    color: isLight
                                        ? const Color(0xFF1A1A1A)
                                        : Colors.white,
                                    fontSize: 16,
                                    fontWeight: FontWeight.bold,
                                    fontFamily: getFontFamily(_activeFont),
                                  ),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                                Text(
                                  '${track.artist} • ${track.album}',
                                  style: TextStyle(
                                    color: isLight
                                        ? Colors.black54
                                        : Colors.white54,
                                    fontSize: 14,
                                    fontFamily: getFontFamily(_activeFont),
                                  ),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                    Divider(
                      color: isLight
                          ? Colors.black.withValues(alpha: 0.08)
                          : Colors.white10,
                      height: 1,
                    ),
                    Flexible(
                      child: Stack(
                        children: [
                          SingleChildScrollView(
                            controller: scrollController,
                            physics: const BouncingScrollPhysics(),
                              child: Column(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  if (!isFromPlayer) ...[
                    _buildOptionItem(
                      Icons.playlist_play,
                      AppLocalizations.of(context).playNext,
                      () {
                        Navigator.pop(context);
                        if (_playingTrack?.id == track.id) {
                          showFleyToast(
                            AppLocalizations.of(context).cannotPlayNextActive,
                          );
                          return;
                        }
                        if (_playbackQueue.isNotEmpty) {
                          _moveTrackInQueue(track, _currentIndex + 1);
                          showFleyToast(
                            AppLocalizations.of(context).addedPlayNext,
                          );
                        }
                      },
                    ),
                    _buildOptionItem(
                      Icons.queue_music,
                      AppLocalizations.of(context).addToQueue,
                      () {
                        Navigator.pop(context);
                        if (_playingTrack?.id == track.id) {
                          showFleyToast(
                            AppLocalizations.of(context).cannotPlayNextActive,
                          );
                          return;
                        }
                        if (_playbackQueue.isNotEmpty) {
                          _moveTrackInQueue(track, _playbackQueue.length);
                          showFleyToast(
                            AppLocalizations.of(context).addedSongsToQueue,
                          );
                        }
                      },
                    ),
                  ],
                  if (isYtm) ...[
                    _buildOptionItem(
                      isDownloaded
                          ? Icons.check_circle_rounded
                          : Icons.download_rounded,
                      AppLocalizations.of(context).download,
                      () {
                        Navigator.pop(context);
                        if (isDownloaded) {
                          showFleyToast(
                            AppLocalizations.of(context).songAlreadyInLibrary,
                          );
                        } else {
                          _downloadYtmTrack(track);
                        }
                      },
                      iconColor: isDownloaded
                          ? _activeAccentColor
                          : (isLight ? Colors.black54 : Colors.white70),
                    ),
                  ],
                  _buildOptionItem(
                    Icons.playlist_add,
                    AppLocalizations.of(context).addToPlaylist,
                    () {
                      Navigator.pop(context);
                      _showAddToPlaylistModal(context, [track]);
                    },
                  ),
                  _buildOptionItem(
                    Icons.timer,
                    AppLocalizations.of(context).sleepTimer,
                    () {
                      Navigator.pop(context);
                       _showFullSleepTimerDialog(context);
                    },
                  ),
                  if (!isYtm && Platform.isAndroid) ...[
                    _buildOptionItem(
                      Icons.content_cut_rounded,
                      AppLocalizations.of(context).ringtoneCutter,
                      () {
                        Navigator.pop(context);
                        _showRingtoneCutterModal(context, track);
                      },
                    ),
                    _buildOptionItem(
                      Icons.equalizer_rounded,
                      AppLocalizations.of(context).equalizer,
                      () {
                        Navigator.pop(context);
                        MainScreen.showEqualizer(context);
                      },
                    ),
                  ],
                  _buildOptionItem(
                    isFavorited ? Icons.favorite : Icons.favorite_border,
                    AppLocalizations.of(context).favourites,
                    () {
                      _toggleFavorite(track.id, track);
                      if (isFavorited) {
                        final loc = lookupAppLocalizations(
                          Locale(FleyStrings.currentLang),
                        );
                        if (_MainScreenState
                                .mainScreenState!
                                ._playingFromName ==
                            loc.favourites) {
                          _MainScreenState.mainScreenState!
                              ._removeFromQueueAndPlayer(track.id);
                        }
                      }
                      setModalState(() {});
                    },
                    iconColor: isFavorited
                        ? _activeAccentColor
                        : (isLight ? Colors.black54 : Colors.white70),
                  ),
                  if (playlistContext != null &&
                      _userPlaylists.containsKey(playlistContext)) ...[
                    if ((_userPlaylists[playlistContext]?.indexOf(track.id) ?? 0) > 0)
                      _buildOptionItem(
                        Icons.vertical_align_top_rounded,
                        AppLocalizations.of(context).moveToTop,
                        () async {
                          Navigator.pop(context);
                          final movedMsg =
                              AppLocalizations.of(context).songMovedToTop;
                          setState(() {
                            _userPlaylists[playlistContext]!.remove(track.id);
                            _userPlaylists[playlistContext]!.insert(0, track.id);
                            _cachedDetailKey = null;
                            _detailSortBy = 'default';
                            _saveUserPlaylists();
                          });
                          final prefs = await SharedPreferences.getInstance();
                          await prefs.setString('detailSortBy', 'default');
                          showFleyToast(movedMsg);
                        },
                      ),
                    _buildOptionItem(
                      Icons.remove_circle_outline,
                      AppLocalizations.of(context).removeFromPlaylist,
                      () async {
                        Navigator.pop(context);
                        setState(() {
                          _userPlaylists[playlistContext]!.remove(track.id);
                        });
                        final prefs = await SharedPreferences.getInstance();
                        await prefs.setString(
                          'user_playlists',
                          jsonEncode(_userPlaylists),
                        );
                        _MainScreenState.mainScreenState!
                            ._removeFromQueueAndPlayer(track.id);
                        if (!context.mounted) return;
                        showFleyToast(
                          AppLocalizations.of(context).trackDeleted,
                        );
                      },
                      iconColor: Colors.redAccent,
                    ),
                  ],
                  _buildOptionItem(
                    Icons.album_outlined,
                    AppLocalizations.of(context).goToAlbum,
                    () {
                      Navigator.pop(context);
                      final albumName = track.album.trim();
                      final isInvalidAlbum = albumName.isEmpty ||
                          albumName.toLowerCase() == 'unknown album' ||
                          albumName == '<unknown>' ||
                          albumName.toLowerCase() == 'youtube music' ||
                          RegExp(
                            r'^\d+([.,]\d+)?[kmb]?\s*(plays?|views?|ditonton|tayangan|x ditonton)?$',
                            caseSensitive: false,
                          ).hasMatch(albumName);
                      if (isInvalidAlbum) {
                        showFleyToast('No album information available');
                        return;
                      }
                      if (isYtm) {
                        _openOnlineAlbum(
                          track.album,
                          track.artist,
                          browseId: track.albumBrowseId,
                          coverUrl: track.url,
                        );
                      } else {
                        setState(() {
                          _isPlayerOpen = false;
                          _showLyrics = false;
                          _selectedOnlineDetail = null;
                          _selectedOnlinePlaylist = null;
                          _selectedArtistDetail = null;
                          _selectedPlaylistDetail = null;
                          _selectedAlbumDetail = track.album;
                          _searchQuery = '';
                          _searchController.clear();
                          _detailColorFuture = _getDetailColor(track);
                        });
                      }
                    },
                  ),
                  _buildOptionItem(
                    Icons.person_outline,
                    AppLocalizations.of(context).goToArtist,
                    () {
                      Navigator.pop(context);
                      final artistName = track.artist.trim();
                      if (artistName.isEmpty ||
                          artistName.toLowerCase() == 'unknown artist' ||
                          artistName == '<unknown>') {
                        showFleyToast('No artist information available');
                        return;
                      }
                      if (isYtm) {
                        _openOnlineArtist(
                          track.artist,
                          browseId: track.artistBrowseId,
                          coverUrl: track.url,
                        );
                      } else {
                        setState(() {
                          _isPlayerOpen = false;
                          _showLyrics = false;
                          _selectedOnlineDetail = null;
                          _selectedOnlinePlaylist = null;
                          _selectedAlbumDetail = null;
                          _selectedPlaylistDetail = null;
                          _selectedArtistDetail = track.artist;
                          _searchQuery = '';
                          _searchController.clear();
                          _detailColorFuture = _getDetailColor(track);
                        });
                      }
                    },
                  ),
                  if (!isYtm)
                    _buildOptionItem(
                      Icons.edit_outlined,
                      AppLocalizations.of(context).editMetadata,
                      () {
                        Navigator.pop(context);
                        _showEditMetadataModal(context, track);
                      },
                    ),
                  _buildOptionItem(
                    Icons.info_outline,
                    AppLocalizations.of(context).songInfo,
                    () {
                      Navigator.pop(context);
                      _showSongInfoModal(context, track);
                    },
                  ),
                  if (isYtm) ...[
                    _buildOptionItem(
                      Icons.visibility_off_outlined,
                      AppLocalizations.of(context).notInterested,
                      () async {
                        Navigator.pop(context);
                        final notInterestedMsg =
                            AppLocalizations.of(context).notInterested;
                        final prefs = await SharedPreferences.getInstance();
                        final vid = track.path.isNotEmpty
                            ? track.path
                            : track.id.replaceFirst('ytm_', '');
                        _hiddenTrackIds.add(track.id);
                        _hiddenTrackIds.add(vid);
                        _hiddenTrackIds.add('ytm_$vid');
                        await prefs.setStringList(
                          'hidden_track_ids',
                          _hiddenTrackIds.toList(),
                        );
                        setState(() {
                          _ytmQuickPicksTracks.removeWhere((t) => t.videoId == vid);
                          _ytmTrendingTracks.removeWhere((t) => t.videoId == vid);
                          _recommendedTracks.removeWhere((t) => t.videoId == vid);
                          _cachedDetailKey = null;
                        });
                        if (_playingTrack?.id == track.id) {
                          _MainScreenState.mainScreenState!._playNext();
                        }
                        showFleyToast(notInterestedMsg);
                      },
                    ),
                  ],
                  if (!isYtm) ...[
                    _buildOptionItem(
                      Icons.visibility_off_outlined,
                      AppLocalizations.of(context).hideFromLibrary,
                      () async {
                        Navigator.pop(context);
                        final prefs = await SharedPreferences.getInstance();
                        _hiddenTrackIds.add(track.id);
                        await prefs.setStringList(
                          'hidden_track_ids',
                          _hiddenTrackIds.toList(),
                        );
                        setState(() {
                          _allTracks.removeWhere((t) => t.id == track.id);
                          _cachedDetailKey = null;
                        });
                        _MainScreenState.mainScreenState!
                            ._removeFromQueueAndPlayer(track.id);
                        final serialized = _allTracks
                            .map((t) => t.toMap())
                            .toList();
                        await prefs.setString(
                          'cached_tracks_list',
                          jsonEncode(serialized),
                        );
                        showFleyToast(
                          lookupAppLocalizations(
                            Locale(FleyStrings.currentLang),
                          ).trackHidden,
                        );
                      },
                    ),
                    _buildOptionItem(
                      Icons.delete_outline,
                      AppLocalizations.of(context).deleteFromDevice,
                      () async {
                        final parentContext = this.context;
                        Navigator.pop(context);
                        final bool? confirm = await showConfirmationDialog(
                          parentContext,
                          title: AppLocalizations.of(parentContext).confirmDelete,
                          content: AppLocalizations.of(parentContext).confirmDeleteBody,
                          confirmText: AppLocalizations.of(parentContext).delete,
                        );
                        if (confirm != true) return;

                        try {
                          final file = File(track.path);
                          if (track.path.isNotEmpty && await file.exists()) {
                            if (track.id.startsWith('local_ytm_') ||
                                track.path.contains('FleyDownloads') ||
                                track.path.contains('/Music/Fley') ||
                                track.path.contains(r'\Music\Fley')) {
                              await DownloadService.instance.deleteDownload(track);
                            } else {
                              await file.delete();
                            }
                            setState(() {
                              _allTracks.removeWhere((t) => t.id == track.id);
                              _cachedDetailKey = null;
                              _memoSortedTracks = null;
                            });
                            _MainScreenState.mainScreenState!
                                ._removeFromQueueAndPlayer(track.id);
                            final prefs = await SharedPreferences.getInstance();
                            final serialized = _allTracks
                                .map((t) => t.toMap())
                                .toList();
                            await prefs.setString(
                              'cached_tracks_list',
                              jsonEncode(serialized),
                            );
                            showFleyToast(
                              lookupAppLocalizations(
                                Locale(FleyStrings.currentLang),
                              ).trackDeleted,
                            );
                          } else {
                            if (!parentContext.mounted) return;
                            _showScopedStorageFallbackDialog(parentContext, track);
                          }
                        } catch (e) {
                          if (!parentContext.mounted) return;
                          _showScopedStorageFallbackDialog(parentContext, track);
                        }
                      },
                      iconColor: Colors.redAccent,
                    ),
                  ],
                            const SizedBox(height: 24),
                          ],
                        ),
                      ),
                    Positioned(
                      bottom: 0,
                      left: 0,
                      right: 0,
                      child: ValueListenableBuilder<bool>(
                        valueListenable: canScrollMore,
                        builder: (context, hasMore, _) {
                          return IgnorePointer(
                            child: AnimatedOpacity(
                              opacity: hasMore ? 1.0 : 0.0,
                              duration: const Duration(milliseconds: 200),
                              child: Container(
                                height: 36,
                                decoration: BoxDecoration(
                                  gradient: LinearGradient(
                                    begin: Alignment.topCenter,
                                    end: Alignment.bottomCenter,
                                    colors: [
                                      sheetBg.withValues(alpha: 0.0),
                                      sheetBg.withValues(alpha: 0.95),
                                    ],
                                  ),
                                ),
                              ),
                            ),
                          );
                        },
                      ),
                    ),
                    Positioned(
                      bottom: 6,
                      left: 0,
                      right: 0,
                      child: Center(
                        child: ValueListenableBuilder<bool>(
                          valueListenable: canScrollMore,
                          builder: (context, hasMore, _) {
                            return IgnorePointer(
                              ignoring: !hasMore,
                              child: AnimatedOpacity(
                                opacity: hasMore ? 1.0 : 0.0,
                                duration: const Duration(milliseconds: 200),
                                child: GestureDetector(
                                  onTap: () {
                                    if (scrollController.hasClients) {
                                      scrollController.animateTo(
                                        (scrollController.offset + 160).clamp(
                                          0.0,
                                          scrollController.position.maxScrollExtent,
                                        ),
                                        duration: const Duration(milliseconds: 300),
                                        curve: Curves.easeOutCubic,
                                      );
                                    }
                                  },
                                  child: Container(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 10,
                                      vertical: 3,
                                    ),
                                    decoration: BoxDecoration(
                                      color: isLight
                                          ? Colors.black.withValues(alpha: 0.08)
                                          : Colors.white.withValues(alpha: 0.15),
                                      borderRadius: BorderRadius.circular(12),
                                      border: Border.all(
                                        color: isLight
                                            ? Colors.black12
                                            : Colors.white12,
                                      ),
                                    ),
                                    child: Icon(
                                      Icons.keyboard_arrow_down_rounded,
                                      size: 16,
                                      color: isLight
                                          ? Colors.black54
                                          : Colors.white70,
                                    ),
                                  ),
                                ),
                              ),
                            );
                          },
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      );
    },
  );
},
).whenComplete(() {
  scrollController.removeListener(checkScroll);
  scrollController.dispose();
  canScrollMore.dispose();
});
}

  void _showScopedStorageFallbackDialog(BuildContext ctx, Track track) {
    final isLight = isAppLight;
    showDialog(
      context: ctx,
      builder: (dialogContext) {
        return AlertDialog(
          backgroundColor: isLight
              ? const Color(0xFFF0F0F3)
              : const Color(0xFF161616),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          title: Text(
            AppLocalizations.of(ctx).permissionDenied,
            style: TextStyle(
              color: isLight ? const Color(0xFF1A1A1A) : Colors.white,
              fontWeight: FontWeight.bold,
              fontFamily: getFontFamily(_activeFont),
            ),
          ),
          content: Text(
            AppLocalizations.of(ctx).scopedStorageWarning,
            style: TextStyle(
              color: isLight ? Colors.black54 : Colors.white70,
              height: 1.4,
              fontFamily: getFontFamily(_activeFont),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext),
              child: Text(
                AppLocalizations.of(ctx).cancel,
                style: TextStyle(
                  color: isLight ? Colors.black45 : Colors.white54,
                  fontFamily: getFontFamily(_activeFont),
                ),
              ),
            ),
            TextButton(
              onPressed: () async {
                Navigator.pop(dialogContext);
                final prefs = await SharedPreferences.getInstance();
                _hiddenTrackIds.add(track.id);
                await prefs.setStringList(
                  'hidden_track_ids',
                  _hiddenTrackIds.toList(),
                );
                setState(() {
                  _allTracks.removeWhere((t) => t.id == track.id);
                  _cachedDetailKey = null;
                });
                _MainScreenState.mainScreenState!
                    ._removeFromQueueAndPlayer(track.id);
                final serialized =
                    _allTracks.map((t) => t.toMap()).toList();
                await prefs.setString(
                  'cached_tracks_list',
                  jsonEncode(serialized),
                );
                showFleyToast(
                  lookupAppLocalizations(
                    Locale(FleyStrings.currentLang),
                  ).trackDeleted,
                );
              },
              child: Text(
                AppLocalizations.of(ctx).hideTrack,
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

  Future<void> _downloadYtmTrack(Track track) async {
    final loc = lookupAppLocalizations(Locale(FleyStrings.currentLang));
    final videoId = track.path.isNotEmpty
        ? track.path
        : track.id.replaceFirst('ytm_', '');

    if (videoId.isEmpty) {
      showFleyToast(loc.invalidVideoId);
      return;
    }

    final dir = await getFleyDownloadsDirectory();
    final safeTitle =
        track.title.replaceAll(RegExp(r'[\\/:*?"<>|]'), '_').trim();
    final safeArtist = (track.artist.isNotEmpty && track.artist != '<unknown>')
        ? track.artist.replaceAll(RegExp(r'[\\/:*?"<>|]'), '_').trim()
        : '';
    String fileBaseName =
        safeArtist.isNotEmpty ? '$safeArtist - $safeTitle' : safeTitle;
    if (fileBaseName.isEmpty) {
      fileBaseName = 'ytm_$videoId';
    }
    final audioFileM4a = File('${dir.path}/$fileBaseName.m4a');
    final audioFileOpus = File('${dir.path}/$fileBaseName.opus');

    if ((await audioFileM4a.exists() && (await audioFileM4a.length()) > 0) ||
        (await audioFileOpus.exists() && (await audioFileOpus.length()) > 0)) {
      showFleyToast(loc.songAlreadyDownloaded(track.title));
      return;
    }

    showFleyToast(loc.addedToDownloads(track.title));

    DownloadService.instance.downloadTrack(track);
  }
}
