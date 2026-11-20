part of '../main.dart';

class MyAudioHandler extends BaseAudioHandler {
  final player = AudioPlayer(handleInterruptions: false);

  MyAudioHandler() {
    player.playbackEventStream.listen((event) {
      if (_MainScreenState.mainScreenState != null &&
          _MainScreenState.mainScreenState!._isYtmPlaying) {
        // Do not let stopped local player overwrite YTM playback state
        return;
      }
      playbackState.add(_transformEvent(event));
    });

    player.sequenceStateStream.listen((sequenceState) {
      if (_MainScreenState.mainScreenState != null &&
          _MainScreenState.mainScreenState!._isYtmPlaying) {
        // Do not let stopped local player overwrite YTM media item or queue
        return;
      }
      final queueItems = sequenceState.sequence
          .map((source) => source.tag as MediaItem)
          .toList();
      queue.add(queueItems);

      final currentSource = sequenceState.currentSource;
      if (currentSource != null) {
        var item = currentSource.tag as MediaItem?;
        if (item != null) {
          if (item.artUri == null &&
              mediaItem.value?.id == item.id &&
              mediaItem.value?.artUri != null) {
            item = item.copyWith(artUri: mediaItem.value!.artUri);
          }
          mediaItem.add(item);
        }
      }
    });
  }

  @override
  Future<void> play() async {
    if (_MainScreenState.mainScreenState != null) {
      await _MainScreenState.mainScreenState!._playWithFade();
    } else {
      await player.play();
    }
  }

  @override
  Future<void> pause() async {
    if (_MainScreenState.mainScreenState != null) {
      await _MainScreenState.mainScreenState!._pauseWithFade();
    } else {
      await player.pause();
    }
  }

  void updateYtmMediaItem(MediaItem item) {
    mediaItem.add(item);
  }

  void updateYtmPlaybackState({required bool isPlaying}) {
    playbackState.add(
      PlaybackState(
        controls: [
          MediaControl.skipToPrevious,
          isPlaying ? MediaControl.pause : MediaControl.play,
          MediaControl.skipToNext,
        ],
        systemActions: const {
          MediaAction.seek,
          MediaAction.seekForward,
          MediaAction.seekBackward,
          MediaAction.play,
          MediaAction.pause,
          MediaAction.skipToNext,
          MediaAction.skipToPrevious,
        },
        androidCompactActionIndices: const [0, 1, 2],
        processingState: AudioProcessingState.ready,
        playing: isPlaying,
        speed: 1.0,
      ),
    );
  }

  @override
  Future<void> onTaskRemoved() async {
    try {
      YtPlayerService.instance.stop();
      await stop();
    } catch (_) {}
    await super.onTaskRemoved();
  }

  @override
  Future<void> stop() async {
    YtPlayerService.instance.stop();
    await player.stop();
    playbackState.add(
      playbackState.value.copyWith(
        playing: false,
        processingState: AudioProcessingState.idle,
        controls: [],
      ),
    );
    await super.stop();
  }

  @override
  Future<void> seek(Duration position) {
    if (_MainScreenState.mainScreenState != null &&
        _MainScreenState.mainScreenState!._isYtmPlaying) {
      _MainScreenState.mainScreenState!._smoothSeek(position);
      return Future.value();
    }
    return player.seek(position);
  }

  @override
  Future<void> skipToNext() async {
    if (_MainScreenState.mainScreenState != null) {
      _MainScreenState.mainScreenState!._playNext();
    }
  }

  @override
  Future<void> skipToPrevious() async {
    if (_MainScreenState.mainScreenState != null) {
      _MainScreenState.mainScreenState!._playPrevious();
    }
  }

  @override
  Future<dynamic> customAction(
    String name, [
    Map<String, dynamic>? extras,
  ]) async {
    if (name == 'close') {
      await stop();
    } else if (name == 'favorite') {
      final currentId = mediaItem.value?.id;
      if (currentId != null && _MainScreenState.mainScreenState != null) {
        _MainScreenState.mainScreenState!._toggleFavorite(currentId);
        refreshPlaybackState();
      }
    }
  }

  void refreshPlaybackState() {
    playbackState.add(
      playbackState.value.copyWith(
        controls: [
          MediaControl.skipToPrevious,
          if (player.playing) MediaControl.pause else MediaControl.play,
          MediaControl.skipToNext,
        ],
        systemActions: const {
          MediaAction.seek,
          MediaAction.seekForward,
          MediaAction.seekBackward,
          MediaAction.play,
          MediaAction.pause,
          MediaAction.skipToNext,
          MediaAction.skipToPrevious,
        },
      ),
    );
  }

  PlaybackState _transformEvent(PlaybackEvent event) {
    return PlaybackState(
      controls: [
        MediaControl.skipToPrevious,
        if (player.playing) MediaControl.pause else MediaControl.play,
        MediaControl.skipToNext,
      ],
      systemActions: const {
        MediaAction.seek,
        MediaAction.seekForward,
        MediaAction.seekBackward,
        MediaAction.play,
        MediaAction.pause,
        MediaAction.skipToNext,
        MediaAction.skipToPrevious,
      },

      androidCompactActionIndices: const [0, 1, 2],
      processingState:
          const {
            ProcessingState.idle: AudioProcessingState.idle,
            ProcessingState.loading: AudioProcessingState.loading,
            ProcessingState.buffering: AudioProcessingState.buffering,
            ProcessingState.ready: AudioProcessingState.ready,
            ProcessingState.completed: AudioProcessingState.completed,
          }[player.processingState] ??
          AudioProcessingState.idle,
      playing: player.playing,
      updatePosition: event.updatePosition,
      updateTime: event.updateTime,
      bufferedPosition: player.bufferedPosition,
      speed: player.speed,
      queueIndex: event.currentIndex,
    );
  }
}

Future<void> configureAudioSession(bool playTogether) async {
  if (!Platform.isAndroid && !Platform.isIOS) return;
  final session = await AudioSession.instance;
  if (playTogether) {
    await session.configure(
      const AudioSessionConfiguration(
        avAudioSessionCategory: AVAudioSessionCategory.playback,
        avAudioSessionCategoryOptions:
            AVAudioSessionCategoryOptions.mixWithOthers,
        avAudioSessionMode: AVAudioSessionMode.defaultMode,
        avAudioSessionRouteSharingPolicy:
            AVAudioSessionRouteSharingPolicy.defaultPolicy,
        avAudioSessionSetActiveOptions: AVAudioSessionSetActiveOptions.none,
        androidAudioAttributes: AndroidAudioAttributes(
          contentType: AndroidAudioContentType.music,
          usage: AndroidAudioUsage.media,
        ),
        androidAudioFocusGainType:
            AndroidAudioFocusGainType.gainTransientMayDuck,
        androidWillPauseWhenDucked: true,
      ),
    );
  } else {
    await session.configure(
      const AudioSessionConfiguration(
        avAudioSessionCategory: AVAudioSessionCategory.playback,
        avAudioSessionMode: AVAudioSessionMode.defaultMode,
        androidAudioAttributes: AndroidAudioAttributes(
          contentType: AndroidAudioContentType.music,
          usage: AndroidAudioUsage.media,
        ),
        androidAudioFocusGainType: AndroidAudioFocusGainType.gain,
        androidWillPauseWhenDucked: true,
      ),
    );
  }
}
