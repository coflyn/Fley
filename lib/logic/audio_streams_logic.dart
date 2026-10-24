// ignore_for_file: invalid_use_of_protected_member, deprecated_member_use
part of '../main.dart';

extension _AudioStreamsLogic on _MainScreenState {
  void _setupAudioStreams() {
    _audioPlayer.setLoopMode(_repeatMode == 2 ? LoopMode.one : LoopMode.off);
    _audioPlayer.playingStream.listen((playing) {
      if (mounted) setState(() => _isPlaying = playing);
    });

    _audioPlayer.processingStateStream.listen((state) {
      if (mounted) setState(() => _processingState = state);
    });

    _audioPlayer.currentIndexStream.listen((nativeIndex) {
      if (_isProgrammaticLoading) return;
      if (nativeIndex == null) return;
      if (_audioPlayer.audioSource is ConcatenatingAudioSource) {
        final concatenating =
            _audioPlayer.audioSource as ConcatenatingAudioSource;
        if (nativeIndex < concatenating.sequence.length) {
          final mediaItem =
              concatenating.sequence[nativeIndex].tag as MediaItem;
          final trackId = mediaItem.id;
          if (_playingTrack != null && _playingTrack!.id != trackId) {
            final newQueueIndex = _playbackQueue.indexWhere(
              (t) => t.id == trackId,
            );
            if (newQueueIndex != -1) {
              if (nativeIndex == 2) {
                _slideWindowInPlace(newQueueIndex, 1);
              } else if (nativeIndex == 0) {
                _slideWindowInPlace(newQueueIndex, -1);
              } else {
                _playTrack(newQueueIndex, playImmediately: true);
              }
            }
          }
        }
      }
    });

    AudioSession.instance.then((session) {
      session.devicesChangedEventStream.listen((event) {
        if (_autoPlayOnConnect &&
            event.devicesAdded.isNotEmpty &&
            _playingTrack != null &&
            !_audioPlayer.playing) {
          _audioPlayer.play();
        }
      });
    });

    bool isHandlingCompletion = false;
    _audioPlayer.playerStateStream.listen((state) {
      if (state.processingState == ProcessingState.completed) {
        if (isHandlingCompletion) return;
        isHandlingCompletion = true;
        Future.delayed(const Duration(milliseconds: 600), () {
          isHandlingCompletion = false;
        });
        if (_repeatMode == 2) {
          _audioPlayer.seek(Duration.zero);
          _audioPlayer.play();
        } else if (_repeatMode == 1) {
          _playNext();
        } else {
          _audioPlayer.pause();
          _audioPlayer.seek(Duration.zero);
        }
      }
    });

    _audioPlayer.positionStream.listen((pos) {
      if (pos.inSeconds < 2) {
        _hasResetPosition = true;
      }
      if (_playingTrack != null &&
          _hasResetPosition &&
          _lastIncrementedTrackId != _playingTrack!.id) {
        final duration = _audioPlayer.duration ?? Duration.zero;
        final trackDuration = Duration(milliseconds: _playingTrack!.duration);
        final effectiveDuration = duration > Duration.zero
            ? duration
            : trackDuration;

        bool shouldIncrement = false;
        if (_playCountThreshold == -1) {
          if (effectiveDuration > Duration.zero) {
            shouldIncrement =
                pos >= effectiveDuration - const Duration(milliseconds: 500);
          }
        } else {
          shouldIncrement = pos.inSeconds >= _playCountThreshold;
          if (!shouldIncrement && effectiveDuration > Duration.zero) {
            if (effectiveDuration.inSeconds < _playCountThreshold &&
                pos >= effectiveDuration - const Duration(milliseconds: 500)) {
              shouldIncrement = true;
            }
          }
        }

        if (shouldIncrement) {
          _lastIncrementedTrackId = _playingTrack!.id;
          setState(() {
            _playCounts[_playingTrack!.id] =
                (_playCounts[_playingTrack!.id] ?? 0) + 1;
          });
          SharedPreferences.getInstance().then((prefs) {
            prefs.setString('play_counts', jsonEncode(_playCounts));
          });
        }
      }

      if (_sleepAtEndOfTrack && _hasResetPosition) {
        final duration = _audioPlayer.duration ?? Duration.zero;
        if (duration > Duration.zero &&
            pos >= duration - const Duration(milliseconds: 350)) {
          setState(() {
            _sleepAtEndOfTrack = false;
            _sleepTimerNotifier.value = 0;
          });
          _pauseWithFade();
        }
      }

      final currentSource = _audioPlayer.sequenceState.currentSource;
      final mediaItem = currentSource?.tag as MediaItem?;
      final activeTrackId = mediaItem?.id;

      if (activeTrackId != null && pos.inMilliseconds < 1000) {
        _lastCrossfadedTrackId = null;
      }

      bool hasNextTrack = false;
      if (_isShuffle && _shuffledIndices.isNotEmpty) {
        int currentShuffledPos = _shuffledIndices.indexOf(_currentIndex);
        hasNextTrack =
            currentShuffledPos + 1 < _shuffledIndices.length ||
            _repeatMode == 1;
      } else {
        hasNextTrack =
            _currentIndex + 1 < _playbackQueue.length || _repeatMode == 1;
      }

      if (_crossfadeDuration > 0 &&
          _audioPlayer.playing &&
          !_isNaturalFadingOut &&
          _repeatMode != 2 &&
          activeTrackId != null &&
          hasNextTrack &&
          _lastCrossfadedTrackId != activeTrackId) {
        final duration = _audioPlayer.duration ?? Duration.zero;
        if (duration > Duration.zero) {
          final remaining = duration - pos;
          if (remaining.inMilliseconds <= _crossfadeDuration &&
              remaining.inMilliseconds > 0) {
            _isNaturalFadingOut = true;
            _lastCrossfadedTrackId = activeTrackId;
            Future.delayed(Duration.zero, () async {
              final int sessionId = ++_fadeSessionId;
              final int steps = 10;
              final int stepDelay = (_crossfadeDuration / steps).round();
              for (int i = steps; i >= 0; i--) {
                if (_fadeSessionId != sessionId || !_audioPlayer.playing) break;
                await _audioPlayer.setVolume(_volume * (i / steps.toDouble()));
                if (stepDelay > 0) {
                  await Future.delayed(Duration(milliseconds: stepDelay));
                }
              }
            });
          }
        }
      }
    });

    _audioPlayer.androidAudioSessionIdStream.listen((sessionId) {
      if (sessionId != null && sessionId != 0) {
        _applySavedEqualizerSettings(sessionId);
      }
    });
  }
}
