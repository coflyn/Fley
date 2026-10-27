// ignore_for_file: invalid_use_of_protected_member, deprecated_member_use
part of '../main.dart';

extension _AudioPlaybackLogic on _MainScreenState {
  void _moveTrackInQueue(Track track, int targetIndex) {
    setState(() {
      final existingIndex = _playbackQueue.indexWhere((t) => t.id == track.id);
      int adjustedTargetIndex = targetIndex;

      if (existingIndex != -1) {
        if (existingIndex == _currentIndex) {
          return;
        }

        _playbackQueue.removeAt(existingIndex);

        _shuffledIndices.remove(existingIndex);
        for (int i = 0; i < _shuffledIndices.length; i++) {
          if (_shuffledIndices[i] > existingIndex) {
            _shuffledIndices[i]--;
          }
        }

        if (existingIndex < _currentIndex) {
          _currentIndex--;
        }

        if (adjustedTargetIndex > existingIndex) {
          adjustedTargetIndex--;
        }
      }

      if (adjustedTargetIndex > _playbackQueue.length) {
        adjustedTargetIndex = _playbackQueue.length;
      }
      if (adjustedTargetIndex < 0) {
        adjustedTargetIndex = 0;
      }

      _playbackQueue.insert(adjustedTargetIndex, track);

      for (int i = 0; i < _shuffledIndices.length; i++) {
        if (_shuffledIndices[i] >= adjustedTargetIndex) {
          _shuffledIndices[i]++;
        }
      }

      if (_isShuffle && _shuffledIndices.isNotEmpty) {
        final currentShuffledPos = _shuffledIndices.indexOf(_currentIndex);
        if (currentShuffledPos != -1) {
          _shuffledIndices.insert(currentShuffledPos + 1, adjustedTargetIndex);
        } else {
          _shuffledIndices.add(adjustedTargetIndex);
        }
      } else {
        _shuffledIndices = List.generate(_playbackQueue.length, (i) => i);
      }
    });

    _updateCurrentSourceSilently();
  }

  void _removeFromQueueAndPlayer(String trackId) {
    setState(() {
      final actualRemoveIndex = _playbackQueue.indexWhere(
        (t) => t.id == trackId,
      );
      if (actualRemoveIndex == -1) return;

      if (actualRemoveIndex == _currentIndex) {
        if (_playbackQueue.length <= 1) {
          _playbackQueue.clear();
          _shuffledIndices.clear();
          _audioPlayer.stop();
          _playingTrack = null;
          return;
        } else {
          // We are removing the currently playing track.
          // First, remove it from the queue and shuffle indices.
          _playbackQueue.removeAt(actualRemoveIndex);

          _shuffledIndices.remove(actualRemoveIndex);
          for (int i = 0; i < _shuffledIndices.length; i++) {
            if (_shuffledIndices[i] > actualRemoveIndex) {
              _shuffledIndices[i]--;
            }
          }

          // The next track will now naturally fall into the same index (actualRemoveIndex)
          // unless it was the very last track in the queue.
          if (actualRemoveIndex >= _playbackQueue.length) {
            _currentIndex = 0;
          } else {
            _currentIndex = actualRemoveIndex;
          }

          // Now play the new track at _currentIndex. This handles updating the player.
          _playTrack(_currentIndex, playImmediately: _isPlaying);
          return; // Return early because _playTrack will build the audio source.
        }
      }

      // If we are removing a track that is NOT currently playing:
      _playbackQueue.removeAt(actualRemoveIndex);

      if (actualRemoveIndex < _currentIndex) {
        _currentIndex--;
      }

      _shuffledIndices.remove(actualRemoveIndex);
      for (int i = 0; i < _shuffledIndices.length; i++) {
        if (_shuffledIndices[i] > actualRemoveIndex) {
          _shuffledIndices[i]--;
        }
      }
    });

    // Refresh the window around the current track since queue changed
    _refreshAudioSourceWindow();
  }

  void reorderUpNext(List<int> newEffectiveIndices) {
    setState(() {
      if (_isShuffle && _shuffledIndices.length == _playbackQueue.length) {
        int pos = _shuffledIndices.indexOf(_currentIndex);
        if (pos != -1) {
          final prefix = _shuffledIndices.sublist(0, pos);
          _shuffledIndices = [...prefix, ...newEffectiveIndices];
        }
      } else {
        List<Track> newQueue = [];
        if (_repeatMode == 1) {
          for (int idx in newEffectiveIndices) {
            newQueue.add(_playbackQueue[idx]);
          }
          _playbackQueue = newQueue;
          _currentIndex = 0;
        } else {
          for (int i = 0; i < _currentIndex; i++) {
            newQueue.add(_playbackQueue[i]);
          }
          for (int idx in newEffectiveIndices) {
            newQueue.add(_playbackQueue[idx]);
          }
          _playbackQueue = newQueue;
        }
      }
      _refreshAudioSourceWindow();
    });
  }

  void _toggleRepeatMode() {
    setState(() {
      _repeatMode = (_repeatMode + 1) % 3;
      _audioPlayer.setLoopMode(_repeatMode == 2 ? LoopMode.one : LoopMode.off);
    });
  }

  Future<void> _playTrack(
    int index, {
    bool playImmediately = true,
    List<Track>? sourceList,
    Duration? initialPosition,
  }) async {
    final int requestId = ++_playRequestId;
    final listToPlay = sourceList ?? _playbackQueue;
    if (listToPlay.isEmpty || index < 0 || index >= listToPlay.length) return;

    bool queueMatches = _playbackQueue.length == listToPlay.length;
    if (queueMatches && sourceList != null) {
      for (int i = 0; i < _playbackQueue.length; i++) {
        if (_playbackQueue[i].id != listToPlay[i].id) {
          queueMatches = false;
          break;
        }
      }
    }

    if (!queueMatches && sourceList != null) {
      setState(() {
        _playbackQueue = List.from(listToPlay);
        if (_isShuffle) {
          _shuffledIndices = List.generate(_playbackQueue.length, (i) => i);
          _shuffledIndices.shuffle();
        }
      });
    }

    final track = _playbackQueue[index];

    setState(() {
      _currentIndex = index;
      _playingTrack = track;
      _lastIncrementedTrackId = null;
      _hasResetPosition = false;
      _isNaturalFadingOut = false;
      _lastActiveLyricsIndex = -1;
      if (_isShuffle && !queueMatches && sourceList != null) {
        _shuffledIndices.remove(_currentIndex);
        _shuffledIndices.insert(0, _currentIndex);
      }

      if (playImmediately) {
        _lastPlayedTrackIds.remove(track.id);
        _lastPlayedTrackIds.insert(0, track.id);
      }
    });

    _loadLyricsForTrack(track);

    _updateDominantColor(track);

    final startPosMs = initialPosition?.inMilliseconds ?? 0;
    _lastPlaybackPositionMs = startPosMs;
    _lastPlaybackTrackId = track.id;
    SharedPreferences.getInstance().then((prefs) {
      prefs.setString('last_playing_track_id', track.id);
      prefs.setString('last_playback_track_id', track.id);
      prefs.setInt('last_playback_position_ms', startPosMs);
      if (playImmediately) {
        prefs.setStringList('last_played_track_ids', _lastPlayedTrackIds);
      }
    });

    _isProgrammaticLoading = true;
    try {
      final currentUri = track.url.startsWith('/')
          ? Uri.file(track.url)
          : (Uri.tryParse(track.url) ?? Uri.parse(''));
      final currentCover = await _getCoverUriForTrack(
        track,
        fetchNativeIfMissing: true,
      );
      if (requestId != _playRequestId) return;

      if (currentCover == null) {
        Future.microtask(() async {
          final fullCover = await _getCoverUriForTrack(
            track,
            fetchNativeIfMissing: true,
          );
          if (fullCover != null && requestId == _playRequestId) {
            final cur = audioHandler.mediaItem.value;
            if (cur != null && cur.id == track.id) {
              audioHandler.updateMediaItem(cur.copyWith(artUri: fullCover));
            }
          }
        });
      }

      final currentSource = AudioSource.uri(
        currentUri,
        tag: MediaItem(
          id: track.id,
          album: track.album.trim().isEmpty ? 'Unknown Album' : track.album,
          title: track.title.trim().isEmpty ? 'Unknown Title' : track.title,
          artist: (track.artist.trim().isEmpty || track.artist == '<unknown>')
              ? lookupAppLocalizations(
                  Locale(FleyStrings.currentLang),
                ).unknownArtist
              : track.artist,
          artUri: currentCover,
          duration: Duration(milliseconds: track.duration),
        ),
      );

      AudioSource source;
      int initialIndex = 0;

      if (_playbackQueue.length <= 1) {
        source = currentSource;
      } else {
        final List<AudioSource> children = [];

        int prevIndex = -1;
        int nextIndex = -1;

        if (_isShuffle && _shuffledIndices.isNotEmpty) {
          int currentShuffledPos = _shuffledIndices.indexOf(index);
          if (currentShuffledPos > 0) {
            prevIndex = _shuffledIndices[currentShuffledPos - 1];
          } else if (_repeatMode == 1) {
            prevIndex = _shuffledIndices.last;
          }
          if (currentShuffledPos != -1 &&
              currentShuffledPos < _shuffledIndices.length - 1) {
            nextIndex = _shuffledIndices[currentShuffledPos + 1];
          } else if (_repeatMode == 1 && _shuffledIndices.isNotEmpty) {
            nextIndex = _shuffledIndices.first;
          }
        } else {
          if (index > 0) {
            prevIndex = index - 1;
          } else if (_repeatMode == 1) {
            prevIndex = _playbackQueue.length - 1;
          }
          if (index < _playbackQueue.length - 1) {
            nextIndex = index + 1;
          } else if (_repeatMode == 1) {
            nextIndex = 0;
          }
        }

        // Previous track
        if (prevIndex != -1) {
          final prevTrack = _playbackQueue[prevIndex];
          final prevUri = prevTrack.url.startsWith('/')
              ? Uri.file(prevTrack.url)
              : (Uri.tryParse(prevTrack.url) ?? Uri.parse(''));
          final prevCover = await _getCoverUriForTrack(
            prevTrack,
            fetchNativeIfMissing: false,
          );
          if (requestId != _playRequestId) return;
          children.add(
            AudioSource.uri(
              prevUri,
              tag: MediaItem(
                id: prevTrack.id,
                album: prevTrack.album.trim().isEmpty
                    ? 'Unknown Album'
                    : prevTrack.album,
                title: prevTrack.title.trim().isEmpty
                    ? 'Unknown Title'
                    : prevTrack.title,
                artist:
                    (prevTrack.artist.trim().isEmpty ||
                        prevTrack.artist == '<unknown>')
                    ? lookupAppLocalizations(
                        Locale(FleyStrings.currentLang),
                      ).unknownArtist
                    : prevTrack.artist,
                artUri: prevCover,
                duration: Duration(milliseconds: prevTrack.duration),
              ),
            ),
          );
          initialIndex = 1;
        }

        // Current track
        children.add(currentSource);

        // Next track
        if (nextIndex != -1) {
          final nextTrack = _playbackQueue[nextIndex];
          final nextUri = nextTrack.url.startsWith('/')
              ? Uri.file(nextTrack.url)
              : (Uri.tryParse(nextTrack.url) ?? Uri.parse(''));
          final nextCover = await _getCoverUriForTrack(
            nextTrack,
            fetchNativeIfMissing: false,
          );
          if (requestId != _playRequestId) return;
          children.add(
            AudioSource.uri(
              nextUri,
              tag: MediaItem(
                id: nextTrack.id,
                album: nextTrack.album.trim().isEmpty
                    ? 'Unknown Album'
                    : nextTrack.album,
                title: nextTrack.title.trim().isEmpty
                    ? 'Unknown Title'
                    : nextTrack.title,
                artist:
                    (nextTrack.artist.trim().isEmpty ||
                        nextTrack.artist == '<unknown>')
                    ? lookupAppLocalizations(
                        Locale(FleyStrings.currentLang),
                      ).unknownArtist
                    : nextTrack.artist,
                artUri: nextCover,
                duration: Duration(milliseconds: nextTrack.duration),
              ),
            ),
          );
        }

        source = ConcatenatingAudioSource(
          children: children,
          useLazyPreparation: true,
        );
      }

      final double targetVol = _volume > 0 ? _volume : 1.0;

      if (_audioPlayer.playing && _crossfadeDuration > 0) {
        // Smooth fade out
        final int steps = 6;
        final int stepDelay = (_crossfadeDuration / steps).round();
        for (int i = steps; i >= 0; i--) {
          if (requestId != _playRequestId) break;
          await _audioPlayer.setVolume(targetVol * (i / steps.toDouble()));
          if (stepDelay > 0) {
            await Future.delayed(Duration(milliseconds: stepDelay));
          }
        }
      }

      if (requestId != _playRequestId) return;
      await _audioPlayer.setAudioSource(
        source,
        initialIndex: initialIndex,
        initialPosition: initialPosition,
      );

      if (requestId != _playRequestId) return;

      if (playImmediately) {
        await _audioPlayer.setVolume(targetVol);
        _audioPlayer.play();
        if (_crossfadeDuration > 0) {
          // Smooth fade in
          final int steps = 6;
          final int stepDelay = (_crossfadeDuration / steps).round();
          for (int i = 1; i <= steps; i++) {
            if (requestId != _playRequestId) break;
            await _audioPlayer.setVolume(targetVol * (i / steps.toDouble()));
            if (stepDelay > 0) {
              await Future.delayed(Duration(milliseconds: stepDelay));
            }
          }
        }
      }
      await _audioPlayer.setVolume(targetVol);
    } catch (e) {
      if (e.toString().toLowerCase().contains('abort')) return;

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error playing song: $e'),
            backgroundColor: Colors.red,
            duration: const Duration(seconds: 3),
          ),
        );
      }

      // Resync UI if a real error occurred
      final currentTag =
          _audioPlayer.sequenceState.currentSource?.tag as MediaItem?;
      setState(() {
        _processingState = ProcessingState.idle;
        if (currentTag != null) {
          final index = _playbackQueue.indexWhere((t) => t.id == currentTag.id);
          if (index != -1) {
            _currentIndex = index;
            _playingTrack = _playbackQueue[index];
            _updateDominantColor(_playingTrack!);
          }
        }
      });
    } finally {
      if (requestId == _playRequestId) {
        _isProgrammaticLoading = false;
        final double targetVol = _volume > 0 ? _volume : 1.0;
        _audioPlayer.setVolume(targetVol).catchError((_) {});
      }
    }
  }

  Future<void> _refreshAudioSourceWindow() async {
    if (_playbackQueue.isEmpty || _playingTrack == null) return;
    if (_playbackQueue.length <= 1) return;
    if (_audioPlayer.audioSource is! ConcatenatingAudioSource) return;

    _isProgrammaticLoading = true;
    try {
      final concatenating =
          _audioPlayer.audioSource as ConcatenatingAudioSource;
      final index = _currentIndex;

      int prevIndex = -1;
      int nextIndex = -1;

      if (_isShuffle && _shuffledIndices.isNotEmpty) {
        int currentShuffledPos = _shuffledIndices.indexOf(index);
        if (currentShuffledPos > 0) {
          prevIndex = _shuffledIndices[currentShuffledPos - 1];
        } else if (_repeatMode == 1) {
          prevIndex = _shuffledIndices.last;
        }
        if (currentShuffledPos != -1 &&
            currentShuffledPos < _shuffledIndices.length - 1) {
          nextIndex = _shuffledIndices[currentShuffledPos + 1];
        } else if (_repeatMode == 1 && _shuffledIndices.isNotEmpty) {
          nextIndex = _shuffledIndices.first;
        }
      } else {
        if (index > 0) {
          prevIndex = index - 1;
        } else if (_repeatMode == 1) {
          prevIndex = _playbackQueue.length - 1;
        }
        if (index < _playbackQueue.length - 1) {
          nextIndex = index + 1;
        } else if (_repeatMode == 1) {
          nextIndex = 0;
        }
      }

      int playerCurrentIndex = _audioPlayer.currentIndex ?? 0;
      while (playerCurrentIndex > 0) {
        await concatenating.removeAt(0);
        playerCurrentIndex--;
      }
      while (concatenating.length > 1) {
        await concatenating.removeAt(1);
      }

      // Now insert the new adjacent tracks
      if (prevIndex != -1) {
        final prevTrack = _playbackQueue[prevIndex];
        final prevUri = prevTrack.url.startsWith('/')
            ? Uri.file(prevTrack.url)
            : (Uri.tryParse(prevTrack.url) ?? Uri.parse(''));
        final prevCover = await _getCoverUriForTrack(
          prevTrack,
          fetchNativeIfMissing: false,
        );
        await concatenating.insert(
          0,
          AudioSource.uri(
            prevUri,
            tag: MediaItem(
              id: prevTrack.id,
              album: prevTrack.album.trim().isEmpty
                  ? 'Unknown Album'
                  : prevTrack.album,
              title: prevTrack.title.trim().isEmpty
                  ? 'Unknown Title'
                  : prevTrack.title,
              artist:
                  (prevTrack.artist.trim().isEmpty ||
                      prevTrack.artist == '<unknown>')
                  ? lookupAppLocalizations(
                      Locale(FleyStrings.currentLang),
                    ).unknownArtist
                  : prevTrack.artist,
              artUri: prevCover,
              duration: Duration(milliseconds: prevTrack.duration),
            ),
          ),
        );
      }

      if (nextIndex != -1) {
        final nextTrack = _playbackQueue[nextIndex];
        final nextUri = nextTrack.url.startsWith('/')
            ? Uri.file(nextTrack.url)
            : (Uri.tryParse(nextTrack.url) ?? Uri.parse(''));
        final nextCover = await _getCoverUriForTrack(
          nextTrack,
          fetchNativeIfMissing: false,
        );
        await concatenating.add(
          AudioSource.uri(
            nextUri,
            tag: MediaItem(
              id: nextTrack.id,
              album: nextTrack.album.trim().isEmpty
                  ? 'Unknown Album'
                  : nextTrack.album,
              title: nextTrack.title.trim().isEmpty
                  ? 'Unknown Title'
                  : nextTrack.title,
              artist:
                  (nextTrack.artist.trim().isEmpty ||
                      nextTrack.artist == '<unknown>')
                  ? lookupAppLocalizations(
                      Locale(FleyStrings.currentLang),
                    ).unknownArtist
                  : nextTrack.artist,
              artUri: nextCover,
              duration: Duration(milliseconds: nextTrack.duration),
            ),
          ),
        );
      }
    } finally {
      _isProgrammaticLoading = false;
    }
  }

  Future<void> _slideWindowInPlace(int newQueueIndex, int direction) async {
    _isProgrammaticLoading = true;
    try {
      final track = _playbackQueue[newQueueIndex];
      setState(() {
        _currentIndex = newQueueIndex;
        _playingTrack = track;
        _lastIncrementedTrackId = null;
        _hasResetPosition = false;
        _isNaturalFadingOut = false; // Reset the natural fade variable
        _lastActiveLyricsIndex = -1;
      });
      _loadLyricsForTrack(track);
      _updateDominantColor(track);

      final double targetVol = _volume > 0 ? _volume : 1.0;
      if (_crossfadeDuration > 0) {
        final int sessionId = ++_fadeSessionId;
        final int steps = 6;
        final int stepDelay = (_crossfadeDuration / steps).round();
        Future.delayed(Duration.zero, () async {
          try {
            await _audioPlayer.setVolume(0.0);
            for (int i = 1; i <= steps; i++) {
              if (_fadeSessionId != sessionId) break;
              await _audioPlayer.setVolume(targetVol * (i / steps.toDouble()));
              if (stepDelay > 0) {
                await Future.delayed(Duration(milliseconds: stepDelay));
              }
            }
          } finally {
            if (_fadeSessionId == sessionId) {
              await _audioPlayer.setVolume(targetVol).catchError((_) {});
            }
          }
        });
      } else {
        await _audioPlayer.setVolume(targetVol);
      }

      SharedPreferences.getInstance().then((prefs) {
        prefs.setString('last_playing_track_id', track.id);
        _lastPlayedTrackIds.remove(track.id);
        _lastPlayedTrackIds.insert(0, track.id);
        prefs.setStringList('last_played_track_ids', _lastPlayedTrackIds);
      });

      if (_audioPlayer.audioSource is ConcatenatingAudioSource) {
        final concatenating =
            _audioPlayer.audioSource as ConcatenatingAudioSource;
        int prevIndex = -1;
        int nextIndex = -1;

        if (_isShuffle && _shuffledIndices.isNotEmpty) {
          int currentShuffledPos = _shuffledIndices.indexOf(newQueueIndex);
          if (currentShuffledPos > 0) {
            prevIndex = _shuffledIndices[currentShuffledPos - 1];
          } else if (_repeatMode == 1) {
            prevIndex = _shuffledIndices.last;
          }
          if (currentShuffledPos != -1 &&
              currentShuffledPos < _shuffledIndices.length - 1) {
            nextIndex = _shuffledIndices[currentShuffledPos + 1];
          } else if (_repeatMode == 1 && _shuffledIndices.isNotEmpty) {
            nextIndex = _shuffledIndices.first;
          }
        } else {
          if (newQueueIndex > 0) {
            prevIndex = newQueueIndex - 1;
          } else if (_repeatMode == 1) {
            prevIndex = _playbackQueue.length - 1;
          }
          if (newQueueIndex < _playbackQueue.length - 1) {
            nextIndex = newQueueIndex + 1;
          } else if (_repeatMode == 1) {
            nextIndex = 0;
          }
        }

        if (direction > 0) {
          // Slide forward: remove index 0, add new next at end
          if (concatenating.sequence.isNotEmpty) {
            await concatenating.removeAt(0);
          }
          if (nextIndex != -1) {
            final nextTrack = _playbackQueue[nextIndex];
            final nextUri = nextTrack.url.startsWith('/')
                ? Uri.file(nextTrack.url)
                : (Uri.tryParse(nextTrack.url) ?? Uri.parse(''));
            final nextCover = await _getCoverUriForTrack(
              nextTrack,
              fetchNativeIfMissing: false,
            );
            await concatenating.add(
              AudioSource.uri(
                nextUri,
                tag: MediaItem(
                  id: nextTrack.id,
                  album: nextTrack.album.trim().isEmpty
                      ? 'Unknown Album'
                      : nextTrack.album,
                  title: nextTrack.title.trim().isEmpty
                      ? 'Unknown Title'
                      : nextTrack.title,
                  artist:
                      (nextTrack.artist.trim().isEmpty ||
                          nextTrack.artist == '<unknown>')
                      ? lookupAppLocalizations(
                          Locale(FleyStrings.currentLang),
                        ).unknownArtist
                      : nextTrack.artist,
                  artUri: nextCover,
                  duration: Duration(milliseconds: nextTrack.duration),
                ),
              ),
            );
          }
        } else if (direction < 0) {
          // Slide backward: remove last index, insert new prev at index 0
          if (concatenating.sequence.length > 1) {
            await concatenating.removeAt(concatenating.sequence.length - 1);
          }
          if (prevIndex != -1) {
            final prevTrack = _playbackQueue[prevIndex];
            final prevUri = prevTrack.url.startsWith('/')
                ? Uri.file(prevTrack.url)
                : (Uri.tryParse(prevTrack.url) ?? Uri.parse(''));
            final prevCover = await _getCoverUriForTrack(
              prevTrack,
              fetchNativeIfMissing: false,
            );
            await concatenating.insert(
              0,
              AudioSource.uri(
                prevUri,
                tag: MediaItem(
                  id: prevTrack.id,
                  album: prevTrack.album.trim().isEmpty
                      ? 'Unknown Album'
                      : prevTrack.album,
                  title: prevTrack.title.trim().isEmpty
                      ? 'Unknown Title'
                      : prevTrack.title,
                  artist:
                      (prevTrack.artist.trim().isEmpty ||
                          prevTrack.artist == '<unknown>')
                      ? lookupAppLocalizations(
                          Locale(FleyStrings.currentLang),
                        ).unknownArtist
                      : prevTrack.artist,
                  artUri: prevCover,
                  duration: Duration(milliseconds: prevTrack.duration),
                ),
              ),
            );
          }
        }
      }
    } catch (_) {
      // Fallback if mutation fails
      _playTrack(newQueueIndex, playImmediately: true);
    } finally {
      _isProgrammaticLoading = false;
    }
  }

  void _playNext() {
    if (_playbackQueue.isEmpty) return;

    int nextIndex;
    if (_isShuffle && _shuffledIndices.isNotEmpty) {
      int currentShuffledPos = _shuffledIndices.indexOf(_currentIndex);
      if (currentShuffledPos + 1 < _shuffledIndices.length) {
        nextIndex = _shuffledIndices[currentShuffledPos + 1];
      } else {
        if (_repeatMode == 1) {
          nextIndex = _shuffledIndices[0];
        } else {
          return;
        }
      }
    } else {
      nextIndex = _currentIndex + 1;
      if (nextIndex >= _playbackQueue.length) {
        if (_repeatMode == 1) {
          nextIndex = 0;
        } else {
          return;
        }
      }
    }
    _playTrack(nextIndex);
  }

  void _playPrevious() {
    if (_playbackQueue.isEmpty) return;

    if (_audioPlayer.position.inSeconds > 3) {
      _audioPlayer.seek(Duration.zero);
      return;
    }

    int prevIndex;
    if (_isShuffle && _shuffledIndices.isNotEmpty) {
      int currentShuffledPos = _shuffledIndices.indexOf(_currentIndex);
      if (currentShuffledPos - 1 >= 0) {
        prevIndex = _shuffledIndices[currentShuffledPos - 1];
      } else {
        if (_repeatMode == 1) {
          prevIndex = _shuffledIndices.last;
        } else {
          prevIndex = _shuffledIndices.first;
        }
      }
    } else {
      prevIndex = _currentIndex - 1;
      if (prevIndex < 0) {
        if (_repeatMode == 1) {
          prevIndex = _playbackQueue.length - 1;
        } else {
          prevIndex = 0;
        }
      }
    }
    _playTrack(prevIndex);
  }

  List<LyricsLine> _parseLrc(String lrcContent, {double offsetSec = 0.0}) {
    final List<LyricsLine> lines = [];
    final offset = Duration(milliseconds: (offsetSec * 1000).round());
    final RegExp regExp = RegExp(r'\[(\d+):(\d+)(?:\.(\d+))?\](.*)');
    for (final line in lrcContent.split('\n')) {
      final match = regExp.firstMatch(line.trim());
      if (match != null) {
        final int minutes = int.parse(match.group(1)!);
        final int seconds = int.parse(match.group(2)!);
        final int milliseconds = match.group(3) != null
            ? int.parse(match.group(3)!.padRight(3, '0').substring(0, 3))
            : 0;
        final String text = match.group(4)?.trim() ?? '';
        final baseDuration = Duration(
          minutes: minutes,
          seconds: seconds,
          milliseconds: milliseconds,
        );
        final shifted = baseDuration + offset;
        lines.add(
          LyricsLine(
            time: shifted < Duration.zero ? Duration.zero : shifted,
            text: text,
          ),
        );
      }
    }
    lines.sort((a, b) => a.time.compareTo(b.time));

    if (lines.isEmpty) return lines;

    final List<LyricsLine> processedLines = [];

    bool isWaveLine(LyricsLine line) {
      final t = line.text.trim().toLowerCase();
      return t.isEmpty ||
          t == '♪' ||
          t == '[music]' ||
          t == 'instrumental' ||
          t == '(instrumental)';
    }

    // Auto-insert 3-dots wave for intro melody if first lyric starts after >= 4s and first line is not already wave
    if (lines.first.time >= const Duration(seconds: 4) &&
        !isWaveLine(lines.first)) {
      processedLines.add(LyricsLine(time: Duration.zero, text: '♪'));
    }

    for (int i = 0; i < lines.length; i++) {
      final currentLine = lines[i];
      processedLines.add(currentLine);

      // Skip if currentLine or nextLine is already an explicit empty/instrumental line in LRC
      if (i < lines.length - 1) {
        final nextLine = lines[i + 1];
        if (!isWaveLine(currentLine) && !isWaveLine(nextLine)) {
          final gap = nextLine.time - currentLine.time;
          if (gap >= const Duration(seconds: 8)) {
            final instTime =
                currentLine.time + const Duration(milliseconds: 6000);
            if (nextLine.time - instTime >= const Duration(seconds: 2)) {
              processedLines.add(LyricsLine(time: instTime, text: '♪'));
            }
          }
        }
      }
    }

    return processedLines;
  }

  Future<void> _loadLyricsForTrack(Track track) async {
    _lyricsResumeTimer?.cancel();
    _lyricsUserScrolling = false;
    if (_lyricsScrollController.hasClients) {
      _lyricsScrollController.jumpTo(0);
    }
    _lastActiveLyricsIndex = -1;
    _lyricsOffsetSec = 0.0;
    final offsetKey = 'lyrics_offset_${track.id}';
    final prefs = await SharedPreferences.getInstance();
    if (prefs.containsKey(offsetKey)) {
      _lyricsOffsetSec = prefs.getDouble(offsetKey) ?? 0.0;
    }
    setState(() {
      _isLyricsLoading = true;
      _currentLyricsPlain = null;
      _currentLyricsSynced = [];
      _isLyricsSynced = false;
    });
    final manualKey = 'lyrics_manual_${track.id}';

    if (prefs.containsKey(manualKey)) {
      final manualText = prefs.getString(manualKey) ?? '';
      _parsePlainOrLrcLyrics(manualText);
      setState(() {
        _isLyricsLoading = false;
      });
      return;
    }

    final cacheKey = 'lyrics_cache_${track.id}';
    if (prefs.containsKey(cacheKey)) {
      final cachedJson = prefs.getString(cacheKey) ?? '';
      try {
        final data = jsonDecode(cachedJson);
        _applyFetchedLyrics(data);
        setState(() {
          _isLyricsLoading = false;
        });
        return;
      } catch (_) {}
    }

    try {
      final cleanTitle = track.title;
      final cleanArtist =
          (track.artist.trim().isEmpty || track.artist == '<unknown>')
          ? lookupAppLocalizations(
              Locale(FleyStrings.currentLang),
            ).unknownArtist
          : track.artist;

      final client = HttpClient();
      client.connectionTimeout = const Duration(seconds: 5);
      final uri = Uri.parse('https://lrclib.net/api/get').replace(
        queryParameters: {'artist_name': cleanArtist, 'track_name': cleanTitle},
      );

      final request = await client.getUrl(uri);
      final response = await request.close();

      if (response.statusCode == 200) {
        final body = await response.transform(utf8.decoder).join();
        final data = jsonDecode(body);

        await prefs.setString(cacheKey, body);
        _applyFetchedLyrics(data);
      } else {
        _currentLyricsPlain = null;
        _currentLyricsSynced = [];
        _isLyricsSynced = false;
      }
    } catch (_) {
      _currentLyricsPlain = null;
      _currentLyricsSynced = [];
      _isLyricsSynced = false;
    } finally {
      if (mounted) {
        setState(() {
          _isLyricsLoading = false;
        });
      }
    }
  }

  void _applyFetchedLyrics(dynamic data) {
    final synced = data['syncedLyrics'] as String?;
    final plain = data['plainLyrics'] as String?;

    if (synced != null && synced.trim().isNotEmpty) {
      _currentLyricsSynced = _parseLrc(synced, offsetSec: _lyricsOffsetSec);
      _currentLyricsPlain = plain ?? _stripLrcTimestamps(synced);
      _isLyricsSynced = _currentLyricsSynced.isNotEmpty;
    } else if (plain != null && plain.trim().isNotEmpty) {
      _currentLyricsPlain = plain;
      _currentLyricsSynced = [];
      _isLyricsSynced = false;
    } else {
      _currentLyricsPlain = null;
      _currentLyricsSynced = [];
      _isLyricsSynced = false;
    }
  }

  void _parsePlainOrLrcLyrics(String text) {
    if (text.contains(RegExp(r'\[\d+:\d+'))) {
      _currentLyricsSynced = _parseLrc(text, offsetSec: _lyricsOffsetSec);
      _currentLyricsPlain = _stripLrcTimestamps(text);
      _isLyricsSynced = _currentLyricsSynced.isNotEmpty;
    } else {
      _currentLyricsPlain = text;
      _currentLyricsSynced = [];
      _isLyricsSynced = false;
    }
  }

  String _stripLrcTimestamps(String text) {
    return text.replaceAll(RegExp(r'\[\d+:\d+(?:\.\d+)?\]'), '').trim();
  }

  Future<void> _pauseWithFade() async {
    if (_isFading || !_isPlaying) return;
    _isFading = true;
    final currentVol = _volume;
    if (_crossfadeDuration > 0) {
      final int steps = 10;
      final int stepDelay = (_crossfadeDuration / steps).round();
      for (int i = steps; i >= 0; i--) {
        if (!mounted) break;
        await _audioPlayer.setVolume(currentVol * (i / steps.toDouble()));
        if (stepDelay > 0) {
          await Future.delayed(Duration(milliseconds: stepDelay));
        }
      }
    }
    await _audioPlayer.pause();
    if (_playingTrack != null) {
      final posMs = _audioPlayer.position.inMilliseconds;
      _lastPlaybackPositionMs = posMs;
      _lastPlaybackTrackId = _playingTrack!.id;
      SharedPreferences.getInstance().then((prefs) {
        prefs.setString('last_playback_track_id', _playingTrack!.id);
        prefs.setInt('last_playback_position_ms', posMs);
      });
    }
    await _audioPlayer.setVolume(currentVol);
    _isFading = false;
  }

  Future<void> _playWithFade() async {
    if (_isFading || _isPlaying) return;
    _isFading = true;
    final currentVol = _volume;
    await _audioPlayer.setVolume(0.0);
    _audioPlayer.play();
    if (_crossfadeDuration > 0) {
      final int steps = 10;
      final int stepDelay = (_crossfadeDuration / steps).round();
      for (int i = 0; i <= steps; i++) {
        if (!mounted) break;
        await _audioPlayer.setVolume(currentVol * (i / steps.toDouble()));
        if (stepDelay > 0) {
          await Future.delayed(Duration(milliseconds: stepDelay));
        }
      }
    }
    await _audioPlayer.setVolume(currentVol);
    _isFading = false;
  }

  Future<void> _smoothSeek(Duration position) async {
    final double originalVolume = _volume;
    final int steps = 5;
    final int stepDelay = 15; // Total fade out = 75ms

    try {
      for (int i = steps; i >= 0; i--) {
        if (!mounted) break;
        await _audioPlayer.setVolume(originalVolume * (i / steps.toDouble()));
        await Future.delayed(Duration(milliseconds: stepDelay));
      }

      await _audioPlayer.seek(position);

      for (int i = 0; i <= steps; i++) {
        if (!mounted) break;
        await _audioPlayer.setVolume(originalVolume * (i / steps.toDouble()));
        await Future.delayed(Duration(milliseconds: stepDelay));
      }
    } catch (_) {
      await _audioPlayer.seek(position);
      await _audioPlayer.setVolume(originalVolume);
    }
  }

  void _addTrackToQueueDynamically(String trackId) {
    if (_playbackQueue.any((t) => t.id == trackId)) return;

    try {
      final track = _allTracks.firstWhere((t) => t.id == trackId);
      setState(() {
        _playbackQueue.add(track);
        if (_isShuffle && _shuffledIndices.isNotEmpty) {
          // Insert at random position, but maybe at the end is fine for newly added
          _shuffledIndices.add(_playbackQueue.length - 1);
        }
      });
      _refreshAudioSourceWindow();
    } catch (e) {
      // Track not found in _allTracks, ignore
    }
  }

  void _toggleFavorite(String trackId) {
    setState(() {
      if (_favoriteTrackIds.contains(trackId)) {
        _favoriteTrackIds.remove(trackId);
      } else {
        _favoriteTrackIds.add(trackId);
        final loc = lookupAppLocalizations(Locale(FleyStrings.currentLang));
        if (_playingFromName == loc.favourites) {
          _addTrackToQueueDynamically(trackId);
        }
      }
    });
    SharedPreferences.getInstance().then((prefs) {
      prefs.setStringList('favorite_track_ids', _favoriteTrackIds.toList());
    });
  }

  void _saveUserPlaylists() {
    SharedPreferences.getInstance().then((prefs) {
      prefs.setString('user_playlists', jsonEncode(_userPlaylists));
    });
  }

  void _savePlaylistCovers() {
    SharedPreferences.getInstance().then((prefs) {
      prefs.setString('playlist_covers', jsonEncode(_playlistCovers));
    });
  }

  Future<void> _saveMetadataOverrides() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('metadata_overrides', jsonEncode(_metadataOverrides));
  }

  Widget _buildOptionItem(
    IconData icon,
    String title,
    VoidCallback onTap, {
    Color? iconColor,
  }) {
    final isLight = isAppLight;
    final resolvedIconColor =
        iconColor ?? (isLight ? Colors.black54 : Colors.white70);
    return ListTile(
      leading: Icon(icon, color: resolvedIconColor),
      title: Text(
        title,
        style: TextStyle(
          color: isLight ? const Color(0xFF1A1A1A) : Colors.white,
          fontSize: 16,
          fontFamily: getFontFamily(_activeFont),
        ),
      ),
      onTap: onTap,
    );
  }
}
