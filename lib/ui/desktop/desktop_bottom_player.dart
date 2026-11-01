// ignore_for_file: invalid_use_of_protected_member
part of 'desktop_layout_shell.dart';

extension _DesktopBottomPlayerUI on _DesktopLayoutShellState {
  Widget _buildPersistentBottomPlayer(
    Color textColor,
    Color secondaryTextColor,
    Color borderColor,
  ) {
    final track = widget.playingTrack;

    final isFullscreen = _isFullscreenPlayerOpen;
    return Container(
      height: 88,
      padding: const EdgeInsets.symmetric(horizontal: 20),
      decoration: BoxDecoration(
        color: isFullscreen
            ? const Color(0xFF101013)
            : (widget.isLight
                ? Colors.white.withValues(alpha: 0.98)
                : const Color(0xFF161618)),
        border: isFullscreen
            ? null
            : Border(top: BorderSide(color: borderColor)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.20),
            blurRadius: 12,
            offset: const Offset(0, -2),
          ),
        ],
      ),
      child: Row(
        children: [
          // Left: Track Info & Artwork (Equal flex with Right for perfect dead-center alignment)
          Expanded(
            child: Align(
              alignment: Alignment.centerLeft,
              child: track != null
                  ? Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        InkWell(
                          borderRadius: BorderRadius.circular(8),
                          onTap: () => setState(() {
                            _isFullscreenPlayerOpen = !_isFullscreenPlayerOpen;
                            if (_isLyricsViewOpen) _isLyricsViewOpen = false;
                          }),
                          child: _DesktopTrackArtwork(
                            track: track,
                            size: 52,
                            radius: 8,
                          ),
                        ),
                        const SizedBox(width: 14),
                        Flexible(
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            crossAxisAlignment: CrossAxisAlignment.start,
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              InkWell(
                                borderRadius: BorderRadius.circular(4),
                                onTap: () => setState(() {
                                  _isFullscreenPlayerOpen = !_isFullscreenPlayerOpen;
                                  if (_isLyricsViewOpen) _isLyricsViewOpen = false;
                                }),
                                child: Text(
                                  track.title,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: TextStyle(
                                    fontSize: 13.5,
                                    fontWeight: FontWeight.w600,
                                    color: textColor,
                                  ),
                                ),
                              ),
                              const SizedBox(height: 2),
                              InkWell(
                                borderRadius: BorderRadius.circular(4),
                                onTap: () {
                                  setState(() {
                                    _isFullscreenPlayerOpen = false;
                                    _selectedArtistName = track.artist;
                                    _activeSection = DesktopNavSection.artists;
                                  });
                                },
                                child: Text(
                                  track.artist,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: TextStyle(
                                    fontSize: 12,
                                    color: secondaryTextColor,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(width: 6),
                        IconButton(
                          icon: Icon(
                            widget.favoriteTrackIds.contains(track.id)
                                ? Icons.favorite_rounded
                                : Icons.favorite_border_rounded,
                            size: 20,
                            color: widget.favoriteTrackIds.contains(track.id)
                                ? Colors.redAccent
                                : secondaryTextColor,
                          ),
                          onPressed: () => widget.onToggleFavorite(track.id),
                        ),
                      ],
                    )
                  : const SizedBox.shrink(),
            ),
          ),

          // Center: Playback Controls & Progress Bar (Guaranteed dead center!)
          ConstrainedBox(
            constraints: const BoxConstraints(
              minWidth: 400,
              maxWidth: 580,
            ),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                // Buttons
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    // Shuffle
                    StreamBuilder<bool>(
                      stream: widget.player.shuffleModeEnabledStream,
                      builder: (context, snapshot) {
                        final isShuffle = snapshot.data ?? false;
                        return IconButton(
                          icon: Icon(
                            Icons.shuffle_rounded,
                            size: 19,
                            color: isShuffle
                                ? widget.activeAccentColor
                                : secondaryTextColor,
                          ),
                          onPressed: () async {
                            final next = !isShuffle;
                            await widget.player.setShuffleModeEnabled(next);
                          },
                        );
                      },
                    ),
                    IconButton(
                      icon: const Icon(Icons.skip_previous_rounded, size: 24),
                      color: textColor,
                      onPressed: widget.onPlayPrevious,
                    ),
                    const SizedBox(width: 10),
                    // Large Play/Pause with Glow
                    StreamBuilder<PlayerState>(
                      stream: widget.player.playerStateStream,
                      builder: (context, snapshot) {
                        final isPlaying = snapshot.data?.playing ?? false;
                        return GestureDetector(
                          onTap: widget.onTogglePlayPause,
                          child: Container(
                            width: 40,
                            height: 40,
                            decoration: BoxDecoration(
                              color: widget.activeAccentColor,
                              shape: BoxShape.circle,
                              boxShadow: [
                                BoxShadow(
                                  color: widget.activeAccentColor.withValues(
                                    alpha: 0.4,
                                  ),
                                  blurRadius: 8,
                                  offset: const Offset(0, 2),
                                ),
                              ],
                            ),
                            child: Icon(
                              isPlaying
                                  ? Icons.pause_rounded
                                  : Icons.play_arrow_rounded,
                              size: 26,
                              color: Colors.black,
                            ),
                          ),
                        );
                      },
                    ),
                    const SizedBox(width: 10),
                    IconButton(
                      icon: const Icon(Icons.skip_next_rounded, size: 24),
                      color: textColor,
                      onPressed: widget.onPlayNext,
                    ),
                    // Repeat
                    StreamBuilder<LoopMode>(
                      stream: widget.player.loopModeStream,
                      builder: (context, snapshot) {
                        final loopMode = snapshot.data ?? LoopMode.off;
                        final isRepeat = loopMode != LoopMode.off;
                        return IconButton(
                          icon: Icon(
                            loopMode == LoopMode.one
                                ? Icons.repeat_one_rounded
                                : Icons.repeat_rounded,
                            size: 19,
                            color: isRepeat
                                ? widget.activeAccentColor
                                : secondaryTextColor,
                          ),
                          onPressed: () async {
                            final next = loopMode == LoopMode.off
                                ? LoopMode.all
                                : loopMode == LoopMode.all
                                    ? LoopMode.one
                                    : LoopMode.off;
                            await widget.player.setLoopMode(next);
                          },
                        );
                      },
                    ),
                  ],
                ),

                // Seek Bar Slider
                StreamBuilder<Duration>(
                  stream: widget.player.positionStream,
                  builder: (context, posSnapshot) {
                    final position = posSnapshot.data ?? Duration.zero;
                    final totalDuration = widget.player.duration ??
                        Duration(milliseconds: track?.duration ?? 0);

                    final maxMs = totalDuration.inMilliseconds.toDouble();
                    final posMs = position.inMilliseconds
                        .toDouble()
                        .clamp(0.0, maxMs > 0 ? maxMs : 1.0);

                    return SizedBox(
                      height: 20,
                      child: Row(
                        children: [
                          SizedBox(
                            width: 38,
                            child: Text(
                              _formatDuration(position.inMilliseconds),
                              textAlign: TextAlign.right,
                              style: TextStyle(
                                fontSize: 11,
                                color: secondaryTextColor,
                              ),
                            ),
                          ),
                          Expanded(
                            child: SliderTheme(
                              data: SliderThemeData(
                                trackHeight: 3.5,
                                thumbShape: const RoundSliderThumbShape(
                                  enabledThumbRadius: 5,
                                ),
                                overlayShape: const RoundSliderOverlayShape(
                                  overlayRadius: 10,
                                ),
                                activeTrackColor: widget.activeAccentColor,
                                inactiveTrackColor: widget.isLight
                                    ? Colors.black.withValues(alpha: 0.1)
                                    : Colors.white.withValues(alpha: 0.1),
                                thumbColor: textColor,
                              ),
                              child: Slider(
                                value: posMs,
                                min: 0.0,
                                max: maxMs > 0 ? maxMs : 1.0,
                                onChanged: (val) {
                                  widget.player.seek(
                                    Duration(milliseconds: val.round()),
                                  );
                                },
                              ),
                            ),
                          ),
                          SizedBox(
                            width: 38,
                            child: Text(
                              _formatDuration(totalDuration.inMilliseconds),
                              textAlign: TextAlign.left,
                              style: TextStyle(
                                fontSize: 11,
                                color: secondaryTextColor,
                              ),
                            ),
                          ),
                        ],
                      ),
                    );
                  },
                ),
              ],
            ),
          ),

          // Right: Controls & Volume Slider (Equal flex with Left for perfect centering)
          Expanded(
            child: Align(
              alignment: Alignment.centerRight,
              child: Row(
                mainAxisSize: MainAxisSize.min,
              children: [
                // Quick Lyrics Button
                IconButton(
                  icon: Icon(
                    _isLyricsViewOpen
                        ? Icons.lyrics_rounded
                        : Icons.lyrics_outlined,
                    size: 20,
                    color: _isLyricsViewOpen
                        ? widget.activeAccentColor
                        : secondaryTextColor,
                  ),
                  tooltip: _isLyricsViewOpen ? 'Hide Lyrics' : 'Lyrics',
                  onPressed: () {
                    setState(() {
                      _isLyricsViewOpen = !_isLyricsViewOpen;
                    });
                  },
                ),

                // Playback speed selector
                StreamBuilder<double>(
                  stream: widget.player.speedStream,
                  builder: (context, snapshot) {
                    final speed = snapshot.data ?? widget.player.speed;
                    final label = speed % 1 == 0
                        ? '${speed.toInt()}x'
                        : '${speed.toStringAsFixed(2)}x';
                    return PopupMenuButton<double>(
                      tooltip: 'Playback speed',
                      initialValue: speed,
                      onSelected: (newSpeed) =>
                          widget.player.setSpeed(newSpeed),
                      child: Padding(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 6,
                          vertical: 4,
                        ),
                        child: Text(
                          label,
                          style: TextStyle(
                            fontSize: 11.5,
                            fontWeight: FontWeight.w700,
                            color: speed != 1.0
                                ? widget.activeAccentColor
                                : secondaryTextColor,
                          ),
                        ),
                      ),
                      itemBuilder: (context) => [
                        for (final s in [0.5, 0.75, 1.0, 1.25, 1.5, 2.0])
                          PopupMenuItem<double>(
                            value: s,
                            child: Text(
                              '${s}x',
                              style: TextStyle(
                                color: textColor,
                                fontSize: 13,
                              ),
                            ),
                          ),
                      ],
                    );
                  },
                ),

                // Sleep Timer
                IconButton(
                  icon: Icon(
                    _desktopSleepTimerMinutes != null
                        ? Icons.bedtime_rounded
                        : Icons.bedtime_outlined,
                    size: 19,
                    color: _desktopSleepTimerMinutes != null
                        ? widget.activeAccentColor
                        : secondaryTextColor,
                  ),
                  tooltip: _desktopSleepTimerMinutes != null
                      ? (_desktopSleepTimerMinutes == -1
                          ? 'Sleep timer (End of track)'
                          : 'Sleep timer ($_desktopSleepTimerMinutes min)')
                      : 'Sleep timer',
                  onPressed: _showSleepTimerDialog,
                ),

                // Equalizer button
                if (widget.onOpenEqualizer != null)
                  IconButton(
                    icon: Icon(
                      Icons.equalizer_rounded,
                      size: 20,
                      color: secondaryTextColor,
                    ),
                    tooltip: 'Equalizer',
                    onPressed: widget.onOpenEqualizer,
                  ),

                // Queue Toggle
                IconButton(
                  icon: Icon(
                    _isQueueOpen
                        ? Icons.queue_music_rounded
                        : Icons.queue_music_outlined,
                    size: 20,
                    color: _isQueueOpen
                        ? widget.activeAccentColor
                        : secondaryTextColor,
                  ),
                  tooltip: 'Queue',
                  onPressed: () =>
                      setState(() => _isQueueOpen = !_isQueueOpen),
                ),

                // Fullscreen Player Toggle
                IconButton(
                  icon: Icon(
                    _isFullscreenPlayerOpen
                        ? Icons.fullscreen_exit_rounded
                        : Icons.fullscreen_rounded,
                    size: 22,
                  ),
                  tooltip: _isFullscreenPlayerOpen
                      ? 'Exit Full Screen'
                      : 'Full Screen',
                  color: _isFullscreenPlayerOpen
                      ? widget.activeAccentColor
                      : secondaryTextColor,
                  onPressed: () => setState(() {
                    _isFullscreenPlayerOpen = !_isFullscreenPlayerOpen;
                    if (_isLyricsViewOpen) _isLyricsViewOpen = false;
                  }),
                ),
                IconButton(
                  icon: Icon(
                    _isMuted || _volume == 0
                        ? Icons.volume_off_rounded
                        : _volume < 0.5
                            ? Icons.volume_down_rounded
                            : Icons.volume_up_rounded,
                    size: 20,
                    color: secondaryTextColor,
                  ),
                  onPressed: () {
                    if (_isMuted) {
                      widget.player.setVolume(_lastUnmutedVolume);
                      setState(() {
                        _volume = _lastUnmutedVolume;
                        _isMuted = false;
                      });
                    } else {
                      _lastUnmutedVolume = _volume > 0 ? _volume : 1.0;
                      widget.player.setVolume(0);
                      setState(() {
                        _volume = 0;
                        _isMuted = true;
                      });
                    }
                  },
                ),
                SizedBox(
                  width: 90,
                  child: SliderTheme(
                    data: SliderThemeData(
                      trackHeight: 3.5,
                      thumbShape: const RoundSliderThumbShape(
                        enabledThumbRadius: 4,
                      ),
                      overlayShape: const RoundSliderOverlayShape(
                        overlayRadius: 8,
                      ),
                      activeTrackColor: widget.activeAccentColor,
                      inactiveTrackColor: widget.isLight
                          ? Colors.black.withValues(alpha: 0.1)
                          : Colors.white.withValues(alpha: 0.1),
                      thumbColor: textColor,
                    ),
                    child: Slider(
                      value: _volume,
                      min: 0.0,
                      max: 1.0,
                      onChanged: (val) {
                        widget.player.setVolume(val);
                        setState(() {
                          _volume = val;
                          _isMuted = val == 0;
                        });
                      },
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
      ),
    );
  }
}
