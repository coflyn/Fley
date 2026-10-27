// ignore_for_file: invalid_use_of_protected_member
part of '../main.dart';

extension _DetailViewsUI on _MainScreenState {
  Widget _getActiveDetailView() {
    String? baseName =
        _selectedPlaylistDetail ??
        _selectedArtistDetail ??
        _selectedAlbumDetail;
    String? type = _selectedPlaylistDetail != null
        ? 'Playlist'
        : _selectedArtistDetail != null
        ? AppLocalizations.of(context).artist
        : _selectedAlbumDetail != null
        ? AppLocalizations.of(context).album
        : null;

    if (baseName == null || type == null) {
      return _lastDetailView ?? const SizedBox.shrink();
    }

    String dynamicKeyPart = '';
    if (baseName == AppLocalizations.of(context).favourites) {
      dynamicKeyPart = _favoriteTrackIds.length.toString();
    } else if (baseName == AppLocalizations.of(context).lastPlayed) {
      dynamicKeyPart = _allPlayedTrackIdsOrdered.join(',').hashCode.toString();
    } else if (baseName == AppLocalizations.of(context).mostPlayed) {
      dynamicKeyPart = _playCounts.values
          .fold<int>(0, (a, b) => a + b)
          .toString();
    } else if (baseName == AppLocalizations.of(context).forgottenGems) {
      dynamicKeyPart = _allTracks.reversed
          .where((t) => (_playCounts[t.id] ?? 0) <= 1)
          .map((t) => t.id)
          .join(',')
          .hashCode
          .toString();
    } else if (_userPlaylists.containsKey(baseName)) {
      dynamicKeyPart = _userPlaylists[baseName]?.length.toString() ?? '0';
    }

    final coverKeyPart = _playlistCovers[baseName] ?? '';
    String baseKey = "${baseName}_${_searchQuery}_${type}_${dynamicKeyPart}_$coverKeyPart";

    if (_cachedDetailKey != baseKey ||
        _cachedDetailSongs == null ||
        _cachedDetailImage == null) {
      _cachedDetailKey = baseKey;

      if (_cachedDetailBaseKey != baseKey) {
        _cachedDetailBaseKey = baseKey;
        _detailScrollOffsetNotifier.value = 0.0;

        if (_detailScrollController.hasClients) {
          _detailScrollController.jumpTo(0);
        }
      }
      List<Track> pSongs = [];
      Widget? imageWidget;

      if (type == 'Playlist') {
        if (baseName == AppLocalizations.of(context).favourites) {
          pSongs = _allTracks
              .where((t) => _favoriteTrackIds.contains(t.id))
              .toList();
        } else if (baseName == AppLocalizations.of(context).recentlyAdded) {
          pSongs = List.from(_allTracks);
        } else if (baseName == AppLocalizations.of(context).lastPlayed) {
          final trackMap = {for (var t in _allTracks) t.id: t};
          pSongs = _allPlayedTrackIdsOrdered
              .where((id) => trackMap.containsKey(id))
              .map((id) => trackMap[id]!)
              .toList();
        } else if (baseName == AppLocalizations.of(context).mostPlayed) {
          pSongs = List.from(_allTracks);
          pSongs.sort(
            (a, b) =>
                (_playCounts[b.id] ?? 0).compareTo(_playCounts[a.id] ?? 0),
          );
          pSongs = pSongs.where((t) => (_playCounts[t.id] ?? 0) > 0).toList();
        } else if (baseName == AppLocalizations.of(context).forgottenGems) {
          pSongs = _allTracks.reversed
              .where((t) => (_playCounts[t.id] ?? 0) <= 1)
              .toList();
        } else if (_userPlaylists.containsKey(baseName)) {
          final trackIds = _userPlaylists[baseName]!.toSet();
          pSongs = _allTracks.where((t) => trackIds.contains(t.id)).toList();
        }

        if (_playlistCovers.containsKey(baseName)) {
          imageWidget = ClipRRect(
            borderRadius: BorderRadius.circular(16),
            child: Image(
              image: ResizeImage(
                FileImage(File(_playlistCovers[baseName]!)),
                width: 600,
              ),
              fit: BoxFit.cover,
              width: 220,
              height: 220,
            ),
          );
        } else {
          Color color = Colors.grey;
          IconData icon = Icons.queue_music;
          if (baseName == AppLocalizations.of(context).favourites) {
            color = const Color(0xFFE91E63);
            icon = Icons.favorite;
          } else if (baseName == AppLocalizations.of(context).recentlyAdded) {
            color = const Color(0xFF2196F3);
            icon = Icons.new_releases;
          } else if (baseName == AppLocalizations.of(context).lastPlayed) {
            color = const Color(0xFFFF9800);
            icon = Icons.history;
          } else if (baseName == AppLocalizations.of(context).mostPlayed) {
            color = const Color(0xFFF44336);
            icon = Icons.local_fire_department;
          } else if (baseName == AppLocalizations.of(context).forgottenGems) {
            color = const Color(0xFF9C27B0);
            icon = Icons.diamond_outlined;
          } else if (_userPlaylists.containsKey(baseName)) {
            color = const Color(0xFF673AB7);
            icon = Icons.queue_music;
          }

          List<Track> distinctCovers = [];
          Set<String> seenAlbums = {};
          for (var t in pSongs) {
            if (!seenAlbums.contains(t.album)) {
              seenAlbums.add(t.album);
              distinctCovers.add(t);
            }
          }

          if (distinctCovers.length >= 4) {
            imageWidget = Container(
              width: 300,
              height: 300,
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(12),
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(12),
                child: Column(
                  children: [
                    Row(
                      children: [
                        _buildTrackArtwork(
                          distinctCovers[0],
                          size: 150,
                          radius: 0,
                        ),
                        _buildTrackArtwork(
                          distinctCovers[1],
                          size: 150,
                          radius: 0,
                        ),
                      ],
                    ),
                    Row(
                      children: [
                        _buildTrackArtwork(
                          distinctCovers[2],
                          size: 150,
                          radius: 0,
                        ),
                        _buildTrackArtwork(
                          distinctCovers[3],
                          size: 150,
                          radius: 0,
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            );
          } else {
            imageWidget = Container(
              width: 300,
              height: 300,
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(12),
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(12),
                child: pSongs.isNotEmpty
                    ? _buildTrackArtwork(pSongs.first, size: 300, radius: 0)
                    : Icon(icon, size: 90, color: color),
              ),
            );
          }
        }
      } else if (type == AppLocalizations.of(context).artist) {
        pSongs = _allTracks.where((t) => t.artist == baseName).toList();
        imageWidget = pSongs.isNotEmpty
            ? _buildTrackArtwork(pSongs.first, size: 300, radius: 12)
            : const SizedBox(width: 300, height: 300);
      } else if (type == AppLocalizations.of(context).album) {
        pSongs = _allTracks.where((t) => t.album == baseName).toList();
        imageWidget = pSongs.isNotEmpty
            ? _buildTrackArtwork(pSongs.first, size: 300, radius: 12)
            : const SizedBox(width: 300, height: 300);
      }

      if (_searchQuery.isNotEmpty) {
        pSongs = pSongs
            .where(
              (t) => t.title.toLowerCase().contains(_searchQuery.toLowerCase()),
            )
            .toList();
      }

      if (_detailSortBy == 'title') {
        pSongs.sort(
          (a, b) => a.title.toLowerCase().compareTo(b.title.toLowerCase()),
        );
      } else if (_detailSortBy == 'artist') {
        pSongs.sort(
          (a, b) => a.artist.toLowerCase().compareTo(b.artist.toLowerCase()),
        );
      } else if (_detailSortBy == 'duration_longest') {
        pSongs.sort((a, b) => b.duration.compareTo(a.duration));
      } else if (_detailSortBy == 'duration_shortest') {
        pSongs.sort((a, b) => a.duration.compareTo(b.duration));
      }

      _cachedDetailSongs = pSongs;
      _cachedDetailImage = imageWidget;
    }

    final totalMs = _cachedDetailSongs!.fold<int>(
      0,
      (sum, t) => sum + t.duration,
    );
    final durationStr = _formatTotalDuration(totalMs);

    _lastDetailView = _buildDetailView(
      title: baseName,
      subtitle:
          '${_cachedDetailSongs!.length} ${AppLocalizations.of(context).songsCount} • $durationStr',
      type: type,
      tracks: _cachedDetailSongs!,
      imageWidget: _cachedDetailImage!,
    );

    return _lastDetailView!;
  }

  Widget _buildDetailView({
    required String title,
    required String subtitle,
    required String type,
    required Widget imageWidget,
    required List<Track> tracks,
  }) {
    final isLight = isAppLight;
    final scaffoldBgColor =
        (themeModeNotifier.value == 'custom' &&
            customThemeBgNotifier.value == 'custom_image')
        ? (isLight ? const Color(0xFFF6F8FA) : const Color(0xFF0A0A0A))
        : getAppBackgroundColor(
            themeMode: themeModeNotifier.value,
            customBg: customThemeBgNotifier.value,
            artworkColor: dominantColorNotifier.value,
          );

    final header = GestureDetector(
      onVerticalDragUpdate: (details) {
        if (details.primaryDelta! > 0) {
          _isDraggingDetailNotifier.value = true;
          _detailDragOffsetNotifier.value +=
              details.primaryDelta! / MediaQuery.of(context).size.height;
        } else if (details.primaryDelta! < 0) {
          if (_detailScrollController.hasClients) {
            _detailScrollController.jumpTo(
              (_detailScrollController.offset - details.primaryDelta!).clamp(
                0.0,
                _detailScrollController.position.maxScrollExtent,
              ),
            );
          }
        }
      },
      onVerticalDragEnd: (details) {
        final offset = _detailDragOffsetNotifier.value;
        _isDraggingDetailNotifier.value = false;
        if (offset > 0.2 ||
            (details.primaryVelocity != null &&
                details.primaryVelocity! > 300)) {
          setState(() {
            _selectedPlaylistDetail = null;
            _selectedArtistDetail = null;
            _selectedAlbumDetail = null;
          });
        } else {
          _detailDragOffsetNotifier.value = 0.0;
        }
      },
      child: Container(
        color: Colors.transparent,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            SafeArea(
              bottom: false,
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16.0),
                child: Column(
                  children: [
                    const SizedBox(height: 8),
                    Container(
                      width: 40,
                      height: 4,
                      decoration: BoxDecoration(
                        color: isLight
                            ? Colors.black.withValues(alpha: 0.08)
                            : Colors.white.withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(10),
                      ),
                    ),
                    const SizedBox(height: 0),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        IconButton(
                          padding: EdgeInsets.zero,
                          alignment: Alignment.centerLeft,
                          icon: Icon(
                            Icons.keyboard_arrow_down,
                            color: isLight
                                ? const Color(
                                    0xFF1A1A1A,
                                  ).withValues(alpha: 0.5)
                                : Colors.white.withValues(alpha: 0.5),
                            size: 28,
                          ),
                          onPressed: () {
                            setState(() {
                              _selectedPlaylistDetail = null;
                              _selectedArtistDetail = null;
                              _selectedAlbumDetail = null;
                            });
                          },
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),
            Container(
              width: 300,
              height: 300,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(12),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: isLight ? 0.15 : 0.4),
                    blurRadius: 30,
                    offset: const Offset(0, 15),
                  ),
                ],
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(12),
                child: imageWidget,
              ),
            ),
            const SizedBox(height: 24),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: TextStyle(
                      fontSize: 32,
                      fontWeight: FontWeight.bold,
                      color: isLight ? const Color(0xFF1A1A1A) : Colors.white,
                      height: 1.1,
                    ),
                  ),
                  const SizedBox(height: 10),
                  // User Profile Row (Avatar + Name)
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      ValueListenableBuilder<String?>(
                        valueListenable: userProfileImageNotifier,
                        builder: (context, imagePath, child) {
                          final hasImage =
                              imagePath != null && File(imagePath).existsSync();

                          return Container(
                            width: 24,
                            height: 24,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              color: _activeAccentColor.withValues(alpha: 0.2),
                              border: Border.all(
                                color: _activeAccentColor.withValues(alpha: 0.3),
                                width: 1,
                              ),
                            ),
                            child: ClipOval(
                              child: hasImage
                                  ? Image.file(
                                      File(imagePath),
                                      width: 24,
                                      height: 24,
                                      fit: BoxFit.cover,
                                    )
                                  : Icon(
                                      Icons.person_rounded,
                                      size: 14,
                                      color: _activeAccentColor,
                                    ),
                            ),
                          );
                        },
                      ),
                      const SizedBox(width: 8),
                      ValueListenableBuilder<String>(
                        valueListenable: userProfileNameNotifier,
                        builder: (context, name, child) {
                          return Text(
                            name,
                            style: TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w700,
                              color: isLight
                                  ? const Color(0xFF1A1A1A)
                                  : Colors.white,
                              fontFamily:
                                  getFontFamily(activeFontNotifier.value),
                            ),
                          );
                        },
                      ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  Row(
                    children: [
                      Icon(
                        Icons.public,
                        size: 14,
                        color: isLight ? Colors.black45 : Colors.white60,
                      ),
                      const SizedBox(width: 4),
                      Text(
                        subtitle,
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w400,
                          color: isLight ? Colors.black45 : Colors.white60,
                          fontFamily: getFontFamily(activeFontNotifier.value),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      Row(
                        mainAxisSize: MainAxisSize.min,
                        crossAxisAlignment: CrossAxisAlignment.center,
                        children: [
                          GestureDetector(
                            onTap: () {
                              if (type == AppLocalizations.of(context).album) {
                                _showCoverSourceSelector(context).then(
                                  (imagePath) async {
                                    if (imagePath != null) {
                                      setState(() {
                                        for (final track in tracks) {
                                          if (imagePath == 'reset') {
                                            _metadataOverrides[track.id]
                                                ?.remove('coverPath');
                                          } else {
                                            _metadataOverrides[track.id] ??= {
                                              'title': track.title,
                                              'artist': track.artist,
                                              'album': track.album,
                                            };
                                            _metadataOverrides[track.id]![
                                                    'coverPath'] =
                                                imagePath;
                                          }
                                        }
                                        _cachedDetailKey = null;
                                      });
                                      await _saveMetadataOverrides();
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
                                );
                              } else if (type == 'Playlist' &&
                                  _userPlaylists.containsKey(title)) {
                                _showEditPlaylistSongsModal(context, title);
                              } else {
                                _showDetailOptions(title, type, tracks);
                              }
                            },
                            child: Container(
                              width: 32,
                              height: 32,
                              decoration: BoxDecoration(
                                borderRadius: BorderRadius.circular(6),
                                border: Border.all(
                                  color: isLight
                                      ? Colors.black26
                                      : Colors.white24,
                                  width: 1.5,
                                ),
                              ),
                              child: ClipRRect(
                                borderRadius: BorderRadius.circular(4.5),
                                child: _playlistCovers.containsKey(title) &&
                                        File(_playlistCovers[title]!).existsSync()
                                    ? Image(
                                        image: ResizeImage(
                                          FileImage(File(_playlistCovers[title]!)),
                                          width: 100,
                                        ),
                                        fit: BoxFit.cover,
                                      )
                                    : (tracks.isNotEmpty
                                        ? _buildTrackArtwork(
                                            tracks.first,
                                            size: 32,
                                            radius: 0,
                                          )
                                        : Icon(
                                            Icons.music_note,
                                            size: 18,
                                            color: isLight
                                                ? Colors.black45
                                                : Colors.white54,
                                          )),
                              ),
                            ),
                          ),
                          const SizedBox(width: 18),
                          Builder(
                            builder: (context) {
                              final isAllFavorited = tracks.isNotEmpty &&
                                  tracks.every(
                                    (t) => _favoriteTrackIds.contains(t.id),
                                  );
                              final iconColor =
                                  _activeAccentColor.computeLuminance() > 0.35
                                      ? Colors.black
                                      : Colors.white;

                              return GestureDetector(
                                onTap: () {
                                  setState(() {
                                    if (isAllFavorited) {
                                      for (final t in tracks) {
                                        _favoriteTrackIds.remove(t.id);
                                      }
                                    } else {
                                      for (final t in tracks) {
                                        _favoriteTrackIds.add(t.id);
                                      }
                                    }
                                  });
                                  SharedPreferences.getInstance().then((prefs) {
                                    prefs.setStringList(
                                      'favorite_track_ids',
                                      _favoriteTrackIds.toList(),
                                    );
                                  });
                                  showFleyToast(
                                    isAllFavorited
                                        ? 'Removed from Favourites'
                                        : 'Added to Favourites',
                                  );
                                },
                                child: isAllFavorited
                                    ? Container(
                                        width: 26,
                                        height: 26,
                                        decoration: BoxDecoration(
                                          color: _activeAccentColor,
                                          shape: BoxShape.circle,
                                        ),
                                        child: Icon(
                                          Icons.check,
                                          size: 16,
                                          color: iconColor,
                                        ),
                                      )
                                    : Icon(
                                        Icons.add_circle_outline_rounded,
                                        size: 26,
                                        color: isLight
                                            ? Colors.black45
                                            : Colors.white60,
                                      ),
                              );
                            },
                          ),
                          const SizedBox(width: 18),
                          GestureDetector(
                            onTap: () {
                              if (tracks.isNotEmpty) {
                                for (final track in tracks) {
                                  _moveTrackInQueue(
                                    track,
                                    _playbackQueue.length,
                                  );
                                }
                                showFleyToast(
                                  "Added ${tracks.length} tracks to queue",
                                );
                              }
                            },
                            child: Icon(
                              Icons.arrow_circle_down_outlined,
                              size: 26,
                              color: isLight
                                  ? Colors.black45
                                  : Colors.white60,
                            ),
                          ),
                          const SizedBox(width: 18),
                          GestureDetector(
                            onTap: () =>
                                _showDetailOptions(title, type, tracks),
                            child: Icon(
                              Icons.more_vert,
                              size: 24,
                              color: isLight
                                  ? Colors.black45
                                  : Colors.white60,
                            ),
                          ),
                        ],
                      ),
                      Row(
                        mainAxisSize: MainAxisSize.min,
                        crossAxisAlignment: CrossAxisAlignment.center,
                        children: [
                          GestureDetector(
                            onTap: () {
                              if (tracks.isNotEmpty) {
                                _updatePlayingFrom();
                                final shuffledTracks =
                                    List<Track>.from(tracks)..shuffle();
                                setState(() {
                                  _isShuffle = true;
                                  _playbackQueue = List.from(tracks);
                                  _shuffledIndices = List.generate(
                                    _playbackQueue.length,
                                    (i) => i,
                                  )..shuffle();
                                });
                                _playTrack(0, sourceList: shuffledTracks);
                              }
                            },
                            child: SizedBox(
                              width: 36,
                              height: 36,
                              child: Stack(
                                alignment: Alignment.center,
                                children: [
                                  Icon(
                                    Icons.shuffle_rounded,
                                    color: _isShuffle
                                        ? _activeAccentColor
                                        : (isLight
                                            ? Colors.black45
                                            : Colors.white60),
                                    size: 24,
                                  ),
                                  if (_isShuffle)
                                    Positioned(
                                      bottom: 2,
                                      child: Container(
                                        width: 4,
                                        height: 4,
                                        decoration: BoxDecoration(
                                          color: _activeAccentColor,
                                          shape: BoxShape.circle,
                                        ),
                                      ),
                                    ),
                                ],
                              ),
                            ),
                          ),
                          const SizedBox(width: 16),
                          Builder(
                            builder: (context) {
                              final isCurrentDetailPlaying = _isPlaying &&
                                  _playingFromName == title;
                              final playIconColor =
                                  _activeAccentColor.computeLuminance() > 0.35
                                      ? Colors.black
                                      : Colors.white;

                              return Container(
                                width: 52,
                                height: 52,
                                decoration: BoxDecoration(
                                  color: _activeAccentColor,
                                  shape: BoxShape.circle,
                                  boxShadow: [
                                    BoxShadow(
                                      color: _activeAccentColor.withValues(
                                        alpha: 0.35,
                                      ),
                                      blurRadius: 12,
                                      offset: const Offset(0, 4),
                                    ),
                                  ],
                                ),
                                child: Material(
                                  color: Colors.transparent,
                                  child: InkWell(
                                    customBorder: const CircleBorder(),
                                    onTap: () {
                                      if (tracks.isNotEmpty) {
                                        if (isCurrentDetailPlaying) {
                                          _pauseWithFade();
                                        } else if (!_isPlaying &&
                                            _playingFromName == title &&
                                            _playingTrack != null) {
                                          _playWithFade();
                                        } else {
                                          _updatePlayingFrom();
                                          setState(() {
                                            _playbackQueue =
                                                List.from(tracks);
                                            _shuffledIndices.clear();
                                            if (_isShuffle) {
                                              _shuffledIndices =
                                                  List.generate(
                                                _playbackQueue.length,
                                                (i) => i,
                                              );
                                              _shuffledIndices.shuffle();
                                            }
                                          });
                                          _playTrack(0);
                                        }
                                      }
                                    },
                                    child: Center(
                                      child: Icon(
                                        isCurrentDetailPlaying
                                            ? Icons.pause_rounded
                                            : Icons.play_arrow_rounded,
                                        color: playIconColor,
                                        size: 32,
                                      ),
                                    ),
                                  ),
                                ),
                              );
                            },
                          ),
                        ],
                      ),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),
          ],
        ),
      ),
    );

    final detailStack = Container(
      color: scaffoldBgColor,
      child: Stack(
        children: [
          Positioned.fill(
            child: ValueListenableBuilder<String>(
              valueListenable: detailViewBackgroundStyleNotifier,
              builder: (context, style, child) {
                if (style == 'amoled') {
                  return Container(
                    color: isLight ? scaffoldBgColor : const Color(0xFF000000),
                  );
                } else if (style == 'blur') {
                  final firstTrack = tracks.isNotEmpty ? tracks.first : null;
                  return Stack(
                    children: [
                      Container(
                        color: isLight
                            ? scaffoldBgColor
                            : const Color(0xFF0A0A0A),
                      ),
                      if (firstTrack != null)
                        Positioned.fill(
                          child: RepaintBoundary(
                            child: ClipRect(
                              child: ImageFiltered(
                                imageFilter: ImageFilter.blur(
                                  sigmaX: 45.0,
                                  sigmaY: 45.0,
                                ),
                                child: Opacity(
                                  opacity: isLight ? 0.3 : 0.55,
                                  child: Transform.scale(
                                    scale: 2.2,
                                    child: _buildTrackArtwork(
                                      firstTrack,
                                      size: 400,
                                      radius: 0,
                                      cacheWidthOverride: 144,
                                    ),
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ),
                      Positioned.fill(
                        child: Container(
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              begin: Alignment.topCenter,
                              end: Alignment.bottomCenter,
                              colors: [
                                (isLight ? Colors.white : Colors.black)
                                    .withValues(alpha: 0.35),
                                (isLight ? Colors.white : Colors.black)
                                    .withValues(alpha: 0.75),
                                (isLight ? Colors.white : Colors.black)
                                    .withValues(alpha: 0.95),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ],
                  );
                } else if (style == 'custom') {
                  return ValueListenableBuilder<String?>(
                    valueListenable: playerCustomBgPathNotifier,
                    builder: (context, customPath, child) {
                      return ValueListenableBuilder<double>(
                        valueListenable: playerCustomBgBlurNotifier,
                        builder: (context, blurVal, child) {
                          return ValueListenableBuilder<double>(
                            valueListenable: playerCustomBgDimNotifier,
                            builder: (context, dimVal, child) {
                              return AnimatedBuilder(
                                animation: Listenable.merge([
                                  playerCustomBgScaleNotifier,
                                  playerCustomBgOffsetXNotifier,
                                  playerCustomBgOffsetYNotifier,
                                ]),
                                builder: (context, child) {
                                  final dimColor = isLight
                                      ? Colors.white
                                      : Colors.black;
                                  return Stack(
                                    children: [
                                      Container(
                                        color: isLight
                                            ? scaffoldBgColor
                                            : const Color(0xFF0A0A0A),
                                      ),
                                      if (customPath != null &&
                                          File(customPath).existsSync())
                                        Positioned.fill(
                                          child: RepaintBoundary(
                                            child: ClipRect(
                                              child: ImageFiltered(
                                                imageFilter: ImageFilter.blur(
                                                  sigmaX: blurVal,
                                                  sigmaY: blurVal,
                                                ),
                                                child: Transform.scale(
                                                  scale:
                                                      playerCustomBgScaleNotifier
                                                          .value,
                                                  alignment: Alignment(
                                                    playerCustomBgOffsetXNotifier
                                                        .value,
                                                    playerCustomBgOffsetYNotifier
                                                        .value,
                                                  ),
                                                  child: Image.file(
                                                    File(customPath),
                                                    fit: BoxFit.cover,
                                                  ),
                                                ),
                                              ),
                                            ),
                                          ),
                                        ),
                                      Positioned.fill(
                                        child: Container(
                                          decoration: BoxDecoration(
                                            gradient: LinearGradient(
                                              begin: Alignment.topCenter,
                                              end: Alignment.bottomCenter,
                                              colors: [
                                                dimColor.withValues(
                                                  alpha: dimVal * 0.5,
                                                ),
                                                dimColor.withValues(
                                                  alpha: dimVal * 1.2 > 1.0
                                                      ? 1.0
                                                      : dimVal * 1.2,
                                                ),
                                                dimColor.withValues(
                                                  alpha: dimVal * 1.8 > 1.0
                                                      ? 1.0
                                                      : dimVal * 1.8,
                                                ),
                                              ],
                                            ),
                                          ),
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
                    },
                  );
                } else {
                  return FutureBuilder<Color?>(
                    future: _detailColorFuture,
                    builder: (context, snapshot) {
                      final color = snapshot.data ?? const Color(0xFF161616);
                      return Stack(
                        children: [
                          Positioned(
                            top: 0,
                            left: 0,
                            right: 0,
                            height: 400,
                            child: Container(
                              decoration: BoxDecoration(
                                gradient: LinearGradient(
                                  begin: Alignment.topCenter,
                                  end: Alignment.bottomCenter,
                                  colors: [
                                    color.withValues(
                                      alpha: isLight ? 0.15 : 0.4,
                                    ),
                                    scaffoldBgColor,
                                  ],
                                ),
                              ),
                            ),
                          ),
                        ],
                      );
                    },
                  );
                }
              },
            ),
          ),
          NotificationListener<ScrollNotification>(
            onNotification: (scrollNotification) {
              if (scrollNotification.metrics.axis == Axis.vertical) {
                _detailScrollOffsetNotifier.value =
                    scrollNotification.metrics.pixels;
              }
              return false;
            },
            child: _buildSongList(
              tracks,
              header: header,
              isMostPlayed: title == AppLocalizations.of(context).mostPlayed,
              controller: _detailScrollController,
              playlistContext: type == 'Playlist' ? title : null,
            ),
          ),
          ValueListenableBuilder<double>(
            valueListenable: _detailScrollOffsetNotifier,
            builder: (context, scrollOffset, child) {
              final double progress = ((scrollOffset - 120.0) / 100.0).clamp(
                0.0,
                1.0,
              );
              if (progress <= 0) return const SizedBox.shrink();

              final navBgColor = isLight
                  ? const Color(0xFFF6F8FA).withValues(alpha: progress * 0.96)
                  : const Color(0xFF0A0A0A).withValues(alpha: progress * 0.96);

              final textColor = isLight
                  ? const Color(0xFF1A1A1A)
                  : Colors.white;

              return Positioned(
                top: 0,
                left: 0,
                right: 0,
                child: Container(
                  color: navBgColor,
                  child: SafeArea(
                    bottom: false,
                    child: Container(
                      height: 54,
                      padding: const EdgeInsets.symmetric(horizontal: 12.0),
                      decoration: BoxDecoration(
                        border: Border(
                          bottom: BorderSide(
                            color: (isLight ? Colors.black : Colors.white)
                                .withValues(alpha: progress * 0.08),
                          ),
                        ),
                      ),
                      child: Row(
                        children: [
                          IconButton(
                            icon: Icon(
                              Icons.arrow_back,
                              color: textColor,
                              size: 24,
                            ),
                            onPressed: () {
                              setState(() {
                                _selectedPlaylistDetail = null;
                                _selectedArtistDetail = null;
                                _selectedAlbumDetail = null;
                              });
                            },
                          ),
                          const SizedBox(width: 4),
                          Expanded(
                            child: Opacity(
                              opacity: progress,
                              child: Text(
                                title,
                                style: TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.bold,
                                  color: textColor,
                                  fontFamily: getFontFamily(
                                    activeFontNotifier.value,
                                  ),
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          ),
                          IconButton(
                            icon: Icon(
                              Icons.more_vert,
                              color: textColor,
                              size: 24,
                            ),
                            onPressed: () =>
                                _showDetailOptions(title, type, tracks),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              );
            },
          ),
        ],
      ),
    );

    return GestureDetector(
      onVerticalDragUpdate: (details) {
        if (details.primaryDelta! > 0) {
          _isDraggingDetailNotifier.value = true;
          _detailDragOffsetNotifier.value +=
              details.primaryDelta! / MediaQuery.of(context).size.height;
        }
      },
      onVerticalDragEnd: (details) {
        final offset = _detailDragOffsetNotifier.value;
        _isDraggingDetailNotifier.value = false;
        if (offset > 0.2 ||
            (details.primaryVelocity != null &&
                details.primaryVelocity! > 300)) {
          setState(() {
            _selectedPlaylistDetail = null;
            _selectedArtistDetail = null;
            _selectedAlbumDetail = null;
          });
        } else {
          _detailDragOffsetNotifier.value = 0.0;
        }
      },
      child: detailStack,
    );
  }

  String _formatTotalDuration(int ms) {
    final seconds = ms ~/ 1000;
    final minutes = seconds ~/ 60;
    final remainingSeconds = seconds % 60;

    if (minutes < 60) {
      if (minutes == 0) {
        return '$remainingSeconds sec';
      }
      return '$minutes min $remainingSeconds sec';
    } else {
      final hours = minutes ~/ 60;
      final remainingMinutes = minutes % 60;
      if (remainingMinutes == 0) {
        return '$hours hr';
      }
      return '$hours hr $remainingMinutes min';
    }
  }
}
