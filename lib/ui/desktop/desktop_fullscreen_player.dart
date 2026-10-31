// ignore_for_file: invalid_use_of_protected_member
part of 'desktop_layout_shell.dart';

extension _DesktopFullscreenPlayerUI on _DesktopLayoutShellState {
  Widget _buildFullscreenNowPlayingView(
    Color textColor,
    Color secondaryTextColor,
  ) {
    final track = widget.playingTrack;
    if (track == null) return const SizedBox.shrink();

    return ValueListenableBuilder<Color?>(
      valueListenable: dominantColorNotifier,
      builder: (context, dominantColor, _) {
        final themeColor = dominantColor ?? widget.activeAccentColor;

        return Focus(
          autofocus: true,
          onKeyEvent: (node, event) {
            if (event is KeyDownEvent &&
                event.logicalKey == LogicalKeyboardKey.escape) {
              setState(() => _isFullscreenPlayerOpen = false);
              return KeyEventResult.handled;
            }
            return KeyEventResult.ignored;
          },
          child: Stack(
            fit: StackFit.expand,
            children: [
              // 1. APPLE MUSIC FLUID AMBIENT BACKGROUND: Heavy Blurred Artwork
              Positioned.fill(
                child: ImageFiltered(
                  imageFilter: ImageFilter.blur(
                    sigmaX: 75,
                    sigmaY: 75,
                    tileMode: TileMode.mirror,
                  ),
                  child: Transform.scale(
                    scale: 1.55,
                    child: _DesktopTrackArtwork(
                      track: track,
                      size: 900,
                      radius: 0,
                    ),
                  ),
                ),
              ),

              // 2. AMBIENT RADIAL COLOR BLOOMS (Adds vivid saturation & depth)
              Positioned.fill(
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    gradient: RadialGradient(
                      center: const Alignment(-0.55, -0.30),
                      radius: 1.15,
                      colors: [
                        themeColor.withValues(alpha: 0.50),
                        Colors.transparent,
                      ],
                    ),
                  ),
                ),
              ),
              Positioned.fill(
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    gradient: RadialGradient(
                      center: const Alignment(0.65, 0.25),
                      radius: 1.25,
                      colors: [
                        themeColor.withValues(alpha: 0.38),
                        Colors.transparent,
                      ],
                    ),
                  ),
                ),
              ),

              // 3. DARK VIGNETTE & CONTRAST OVERLAY (Ensures maximum text legibility)
              Positioned.fill(
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: [
                        Colors.black.withValues(alpha: 0.30),
                        Colors.black.withValues(alpha: 0.52),
                        Colors.black.withValues(alpha: 0.80),
                      ],
                      stops: const [0.0, 0.55, 1.0],
                    ),
                  ),
                ),
              ),

              // 4. FOREGROUND CONTENT
              Column(
                children: [
                  // Top Title Bar
                  DesktopTitleBar(
                    backgroundColor: Colors.transparent,
                    isLight: false,
                    leading: Text(
                      track.album.isNotEmpty
                          ? track.album
                          : (track.artist.isNotEmpty
                              ? track.artist
                              : 'Now Playing'),
                      style: const TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: Colors.white,
                      ),
                    ),
                    trailing: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        // Toggle Lyrics Mode (Apple Music / Spotify split screen)
                        IconButton(
                          icon: Icon(
                            _showLyricsInFullscreen
                                ? Icons.lyrics_rounded
                                : Icons.lyrics_outlined,
                            size: 20,
                            color: _showLyricsInFullscreen
                                ? widget.activeAccentColor
                                : Colors.white70,
                          ),
                          tooltip: _showLyricsInFullscreen
                              ? 'Hide Lyrics (Cover Only)'
                              : 'Show Lyrics (Split View)',
                          onPressed: () => setState(
                            () => _showLyricsInFullscreen =
                                !_showLyricsInFullscreen,
                          ),
                        ),
                        IconButton(
                          icon: const Icon(
                            Icons.edit_note_rounded,
                            size: 22,
                            color: Colors.white70,
                          ),
                          tooltip: 'Input / Import .lrc Lyrics',
                          onPressed: () => _showManualLyricsDialog(track),
                        ),
                        IconButton(
                          icon: Icon(
                            widget.favoriteTrackIds.contains(track.id)
                                ? Icons.favorite_rounded
                                : Icons.favorite_border_rounded,
                            size: 20,
                            color: widget.favoriteTrackIds.contains(track.id)
                                ? Colors.redAccent
                                : Colors.white70,
                          ),
                          tooltip: 'Favorite',
                          onPressed: () => widget.onToggleFavorite(track.id),
                        ),
                        IconButton(
                          icon: const Icon(
                            Icons.queue_music_rounded,
                            size: 20,
                            color: Colors.white70,
                          ),
                          tooltip: 'Queue',
                          onPressed: () =>
                              setState(() => _isQueueOpen = !_isQueueOpen),
                        ),
                        IconButton(
                          icon: const Icon(
                            Icons.fullscreen_exit_rounded,
                            size: 22,
                            color: Colors.white70,
                          ),
                          tooltip: 'Exit Full Screen (Esc)',
                          onPressed: () =>
                              setState(() => _isFullscreenPlayerOpen = false),
                        ),
                      ],
                    ),
                  ),

                  // Main Viewport
                  Expanded(
                    child: Stack(
                      children: [
                        LayoutBuilder(
                          builder: (context, constraints) {
                            if (_showLyricsInFullscreen) {
                              return _buildAppleMusicLyricsLayout(
                                track,
                                constraints,
                                themeColor,
                              );
                            }
                            return _buildClassicCenteredCoverLayout(
                              track,
                              constraints,
                            );
                          },
                        ),
                        if (_isQueueOpen) ...[
                          Positioned.fill(
                            child: GestureDetector(
                              behavior: HitTestBehavior.translucent,
                              onTap: () => setState(() => _isQueueOpen = false),
                              child: Container(
                                color: Colors.black.withValues(alpha: 0.35),
                              ),
                            ),
                          ),
                          Positioned(
                            top: 0,
                            right: 0,
                            bottom: 0,
                            width: 340,
                            child: _buildQueueSidePanel(
                              Colors.white,
                              Colors.white70,
                              Colors.white.withValues(alpha: 0.15),
                              isFloatingInFullscreen: true,
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                ],
              ),
            ],
          ),
        );
      },
    );
  }

  /// Apple Music / Spotify Style Split Layout:
  /// Left: Artwork + Title + Artist (Vertically centered)
  /// Right: Transparent, Fluid, Auto-scrolling Lyrics
  Widget _buildAppleMusicLyricsLayout(
    Track track,
    BoxConstraints constraints,
    Color themeColor,
  ) {
    final isCompact = constraints.maxWidth < 900;
    final leftWidth = math
        .min(constraints.maxWidth * (isCompact ? 0.40 : 0.44), 520.0)
        .clamp(280.0, 520.0);
    final maxCoverSize =
        math.min(leftWidth - 64, constraints.maxHeight - 180);
    final coverSize = maxCoverSize.clamp(220.0, 420.0);

    return Row(
      children: [
        // LEFT COLUMN: Artwork + Title + Artist + Favorite Star
        Container(
          width: leftWidth,
          padding: const EdgeInsets.symmetric(horizontal: 36, vertical: 20),
          child: Center(
            child: SizedBox(
              width: coverSize,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    width: coverSize,
                    height: coverSize,
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(18),
                      border: Border.all(
                        color: Colors.white.withValues(alpha: 0.12),
                        width: 1,
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.55),
                          blurRadius: 40,
                          spreadRadius: 2,
                          offset: const Offset(0, 16),
                        ),
                      ],
                    ),
                    child: _DesktopTrackArtwork(
                      track: track,
                      size: coverSize,
                      radius: 18,
                    ),
                  ),
                  const SizedBox(height: 20),

                  // Title & Artist
                  Text(
                    track.title,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontSize: 23,
                      fontWeight: FontWeight.w800,
                      color: Colors.white,
                      letterSpacing: -0.4,
                      height: 1.2,
                    ),
                  ),
                  const SizedBox(height: 6),
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
                      track.album.isNotEmpty
                          ? '${track.artist} — ${track.album}'
                          : track.artist,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w600,
                        color: Colors.white.withValues(alpha: 0.70),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),

        // RIGHT COLUMN: Transparent Fluid Lyrics with Top/Bottom Gradient Mask
        Expanded(
          child: Container(
            margin: const EdgeInsets.only(left: 16, right: 48, top: 10, bottom: 20),
            child: _buildRightLyricsColumn(track, themeColor),
          ),
        ),
      ],
    );
  }

  /// Apple Music / Spotify Lyrics Engine with Top/Bottom Fade & Active Line Zoom
  Widget _buildRightLyricsColumn(Track track, Color themeColor) {
    if (widget.isLyricsLoading) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            CircularProgressIndicator(
              color: widget.activeAccentColor,
              strokeWidth: 3,
            ),
            const SizedBox(height: 18),
            const Text(
              'Loading lyrics...',
              style: TextStyle(
                color: Colors.white70,
                fontSize: 15,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
      );
    }

    if (widget.isLyricsSynced && widget.currentLyricsSynced.isNotEmpty) {
      final count = widget.currentLyricsSynced.length;
      while (_lyricKeys.length < count) {
        _lyricKeys.add(GlobalKey());
      }
      while (_lyricKeys.length > count) {
        _lyricKeys.removeLast();
      }

      return LayoutBuilder(
        builder: (context, constraints) {
          final double viewportHeight = constraints.maxHeight;
          final double verticalPadding = (viewportHeight / 2) - 40.0;

          return NotificationListener<UserScrollNotification>(
            onNotification: (notification) {
              if (notification.direction != ScrollDirection.idle) {
                if (!_userScrollingLyrics) {
                  setState(() => _userScrollingLyrics = true);
                }
                _lyricsUserScrollTimer?.cancel();
                _lyricsUserScrollTimer = Timer(const Duration(seconds: 4), () {
                  if (mounted) {
                    setState(() => _userScrollingLyrics = false);
                  }
                });
              }
              return false;
            },
            child: StreamBuilder<Duration>(
              stream: widget.player.positionStream,
              builder: (context, snapshot) {
                final position = snapshot.data ?? Duration.zero;

                // Find active index
                int activeIndex = -1;
                for (int i = 0; i < count; i++) {
                  if (position >= widget.currentLyricsSynced[i].time) {
                    activeIndex = i;
                  } else {
                    break;
                  }
                }

                // Keep active line locked in the exact vertical center (alignment: 0.5)
                if (!_userScrollingLyrics &&
                    activeIndex >= 0 &&
                    activeIndex < _lyricKeys.length &&
                    activeIndex != _lastActiveLyricsIndex) {
                  _lastActiveLyricsIndex = activeIndex;
                  WidgetsBinding.instance.addPostFrameCallback((_) {
                    final keyContext = _lyricKeys[activeIndex].currentContext;
                    if (keyContext != null && keyContext.mounted) {
                      Scrollable.ensureVisible(
                        keyContext,
                        alignment: 0.5,
                        duration: const Duration(milliseconds: 420),
                        curve: Curves.easeOutCubic,
                      );
                    }
                  });
                }

                // Apple Music Signature Top & Bottom Fade Mask
                return ShaderMask(
                  shaderCallback: (Rect bounds) {
                    return const LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: [
                        Colors.transparent,
                        Colors.white,
                        Colors.white,
                        Colors.transparent,
                      ],
                      stops: [0.0, 0.12, 0.88, 1.0],
                    ).createShader(bounds);
                  },
                  blendMode: BlendMode.dstIn,
                  child: SingleChildScrollView(
                    controller: _fullscreenLyricsController,
                    physics: const BouncingScrollPhysics(),
                    padding: EdgeInsets.symmetric(
                      vertical: verticalPadding,
                      horizontal: 16,
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: List.generate(count, (index) {
                        final line = widget.currentLyricsSynced[index];
                        final isActive = index == activeIndex;
                        final isPast = index < activeIndex;

                        return _AppleMusicLyricItem(
                          key: _lyricKeys[index],
                          line: line,
                          isActive: isActive,
                          isPast: isPast,
                          onTap: () {
                            widget.player.seek(line.time);
                            final keyContext =
                                _lyricKeys[index].currentContext;
                            if (keyContext != null && keyContext.mounted) {
                              Scrollable.ensureVisible(
                                keyContext,
                                alignment: 0.5,
                                duration: const Duration(milliseconds: 380),
                                curve: Curves.easeOutCubic,
                              );
                            }
                          },
                        );
                      }),
                    ),
                  ),
                );
              },
            ),
          );
        },
      );
    }

    if (widget.currentLyricsPlain != null &&
        widget.currentLyricsPlain!.trim().isNotEmpty) {
      return ShaderMask(
        shaderCallback: (Rect bounds) {
          return const LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              Colors.transparent,
              Colors.white,
              Colors.white,
              Colors.transparent,
            ],
            stops: [0.0, 0.10, 0.90, 1.0],
          ).createShader(bounds);
        },
        blendMode: BlendMode.dstIn,
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 48),
          child: SelectableText(
            widget.currentLyricsPlain!,
            style: const TextStyle(
              fontSize: 26,
              height: 1.8,
              fontWeight: FontWeight.w600,
              color: Colors.white,
              letterSpacing: -0.2,
            ),
          ),
        ),
      );
    }

    // EMPTY LYRICS STATE: Frosted Glass Card with Action Buttons
    return Center(
      child: ClipRRect(
        borderRadius: BorderRadius.circular(20),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 16, sigmaY: 16),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 40, vertical: 34),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.08),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(
                color: Colors.white.withValues(alpha: 0.14),
              ),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  Icons.lyrics_rounded,
                  size: 64,
                  color: Colors.white.withValues(alpha: 0.40),
                ),
                const SizedBox(height: 16),
                const Text(
                  'No lyrics available for this song',
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.w700,
                    color: Colors.white,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  'Lirik belum tersedia untuk lagu ini',
                  style: TextStyle(
                    fontSize: 14,
                    color: Colors.white.withValues(alpha: 0.60),
                  ),
                ),
                const SizedBox(height: 24),
                Wrap(
                  spacing: 14,
                  runSpacing: 10,
                  alignment: WrapAlignment.center,
                  children: [
                    if (widget.onRefreshLyrics != null)
                      OutlinedButton.icon(
                        icon: const Icon(Icons.refresh_rounded, size: 18),
                        label: const Text('Check Online (LRCLIB & OvH)'),
                        style: OutlinedButton.styleFrom(
                          foregroundColor: Colors.white,
                          side: BorderSide(
                            color: Colors.white.withValues(alpha: 0.35),
                          ),
                          padding: const EdgeInsets.symmetric(
                            horizontal: 18,
                            vertical: 12,
                          ),
                        ),
                        onPressed: widget.onRefreshLyrics,
                      ),
                    FilledButton.icon(
                      icon: const Icon(Icons.edit_note_rounded, size: 18),
                      label: const Text('Input / Import .lrc'),
                      style: FilledButton.styleFrom(
                        backgroundColor: widget.activeAccentColor,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(
                          horizontal: 18,
                          vertical: 12,
                        ),
                      ),
                      onPressed: () => _showManualLyricsDialog(track),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  /// Classic Centered Cover Layout
  Widget _buildClassicCenteredCoverLayout(
    Track track,
    BoxConstraints constraints,
  ) {
    final available = math.min(
      constraints.maxWidth - 64,
      constraints.maxHeight - 64,
    );
    final coverSize = available.clamp(280.0, 560.0);

    return Center(
      child: Container(
        width: coverSize,
        height: coverSize,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(20),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.65),
              blurRadius: 48,
              spreadRadius: 4,
              offset: const Offset(0, 20),
            ),
          ],
        ),
        child: _DesktopTrackArtwork(
          track: track,
          size: coverSize,
          radius: 20,
        ),
      ),
    );
  }
}

/// Apple Music Style Lyric Line:
/// - Active line: unblurred (0.0), bright white (1.0), bold & large (36px)
/// - Inactive lines (past & upcoming): dimmed & blurred (sigma 2.4)
/// - Hover: unblurs to 0.8 with pointer cursor for easy seeking
class _AppleMusicLyricItem extends StatefulWidget {
  final LyricsLine line;
  final bool isActive;
  final bool isPast;
  final VoidCallback onTap;

  const _AppleMusicLyricItem({
    super.key,
    required this.line,
    required this.isActive,
    required this.isPast,
    required this.onTap,
  });

  @override
  State<_AppleMusicLyricItem> createState() => _AppleMusicLyricItemState();
}

class _AppleMusicLyricItemState extends State<_AppleMusicLyricItem> {
  bool _isHovered = false;

  @override
  Widget build(BuildContext context) {
    final text = widget.line.text.trim();
    final isInstrumental = text.isEmpty ||
        text == '♪' ||
        text.toLowerCase().contains('instrumental');

    final targetBlur = widget.isActive
        ? 0.0
        : (_isHovered ? 0.8 : 2.4);

    final targetOpacity = widget.isActive
        ? 1.0
        : (_isHovered
            ? 0.75
            : (widget.isPast ? 0.25 : 0.32));

    final targetFontSize = widget.isActive ? 36.0 : 26.0;

    return MouseRegion(
      cursor: SystemMouseCursors.click,
      onEnter: (_) => setState(() => _isHovered = true),
      onExit: (_) => setState(() => _isHovered = false),
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: widget.onTap,
        child: Padding(
          padding: EdgeInsets.symmetric(
            vertical: widget.isActive ? 16.0 : 12.0,
            horizontal: 14.0,
          ),
          child: TweenAnimationBuilder<double>(
            tween: Tween<double>(end: targetBlur),
            duration: const Duration(milliseconds: 320),
            curve: Curves.easeOutCubic,
            builder: (context, blurSigma, child) {
              Widget content = child!;
              if (blurSigma > 0.05) {
                content = ImageFiltered(
                  imageFilter: ImageFilter.blur(
                    sigmaX: blurSigma,
                    sigmaY: blurSigma,
                  ),
                  child: content,
                );
              }
              return content;
            },
            child: AnimatedDefaultTextStyle(
              duration: const Duration(milliseconds: 300),
              curve: Curves.easeOutCubic,
              style: TextStyle(
                fontSize: targetFontSize,
                fontWeight: widget.isActive ? FontWeight.w800 : FontWeight.w700,
                color: Colors.white.withValues(alpha: targetOpacity),
                height: 1.28,
                letterSpacing: widget.isActive ? -0.5 : -0.2,
                shadows: widget.isActive
                    ? [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.55),
                          blurRadius: 16,
                          offset: const Offset(0, 4),
                        ),
                      ]
                    : null,
              ),
              child: isInstrumental
                  ? Padding(
                      padding: const EdgeInsets.symmetric(vertical: 6.0),
                      child: _AppleMusicThreeDotsWave(
                        isActive: widget.isActive,
                        color: Colors.white.withValues(alpha: targetOpacity),
                      ),
                    )
                  : Text(
                      widget.line.text,
                      maxLines: 4,
                    ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Apple Music 3-Dots Wave Animation for Instrumental Sections
class _AppleMusicThreeDotsWave extends StatefulWidget {
  final bool isActive;
  final Color color;

  const _AppleMusicThreeDotsWave({
    required this.isActive,
    required this.color,
  });

  @override
  State<_AppleMusicThreeDotsWave> createState() =>
      _AppleMusicThreeDotsWaveState();
}

class _AppleMusicThreeDotsWaveState extends State<_AppleMusicThreeDotsWave>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1400),
    );
    if (widget.isActive) {
      _controller.repeat();
    }
  }

  @override
  void didUpdateWidget(_AppleMusicThreeDotsWave oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.isActive != oldWidget.isActive) {
      if (widget.isActive) {
        _controller.repeat();
      } else {
        _controller.stop();
        _controller.value = 0.0;
      }
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    const double dotSize = 8.5;
    const double spacing = 10.0;

    return AnimatedBuilder(
      animation: _controller,
      builder: (context, _) {
        return Row(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.center,
          children: List.generate(3, (index) {
            final t = (_controller.value - (index * 0.18)) % 1.0;
            final sine = widget.isActive ? math.sin(t * math.pi * 2) : 0.0;
            final yOffset = widget.isActive ? (sine * 5.0) : 0.0;
            final scale = widget.isActive
                ? (1.0 + (sine * 0.25).clamp(0.0, 0.25))
                : 1.0;

            return Padding(
              padding: const EdgeInsets.symmetric(horizontal: spacing / 2),
              child: Transform.translate(
                offset: Offset(0, -yOffset),
                child: Transform.scale(
                  scale: scale,
                  child: Container(
                    width: dotSize,
                    height: dotSize,
                    decoration: BoxDecoration(
                      color: widget.color,
                      shape: BoxShape.circle,
                      boxShadow: widget.isActive
                          ? [
                              BoxShadow(
                                color: widget.color.withValues(alpha: 0.45),
                                blurRadius: 6,
                                offset: const Offset(0, 1),
                              ),
                            ]
                          : null,
                    ),
                  ),
                ),
              ),
            );
          }),
        );
      },
    );
  }
}


