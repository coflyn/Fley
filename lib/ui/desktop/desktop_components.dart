part of 'desktop_layout_shell.dart';

class _DesktopSongRow extends StatefulWidget {
  final int index;
  final Track track;
  final bool isCurrentTrack;
  final bool isPlaying;
  final bool isFavorite;
  final Color activeAccentColor;
  final Color textColor;
  final Color secondaryTextColor;
  final bool isLight;
  final VoidCallback onTap;
  final VoidCallback onToggleFavorite;
  final void Function(String)? onArtistTap;
  final void Function(String)? onAlbumTap;
  final VoidCallback? onPlayNext;
  final VoidCallback? onAddToQueue;
  final void Function(Track)? onAddToPlaylist;
  final void Function(Track)? onRemoveFromPlaylist;
  final void Function(Track)? onShowDetails;
  final void Function(Track)? onEditTags;
  final void Function(Track)? onChangeArtwork;
  final void Function(String)? onGoToAlbum;
  final void Function(String)? onGoToArtist;
  final void Function(Track)? onHideTrack;
  final void Function(Track)? onDeletePermanently;

  const _DesktopSongRow({
    required this.index,
    required this.track,
    required this.isCurrentTrack,
    required this.isPlaying,
    required this.isFavorite,
    required this.activeAccentColor,
    required this.textColor,
    required this.secondaryTextColor,
    required this.isLight,
    required this.onTap,
    required this.onToggleFavorite,
    this.onArtistTap,
    this.onAlbumTap,
    this.onPlayNext,
    this.onAddToQueue,
    this.onAddToPlaylist,
    this.onRemoveFromPlaylist,
    this.onShowDetails,
    this.onEditTags,
    this.onChangeArtwork,
    this.onGoToAlbum,
    this.onGoToArtist,
    this.onHideTrack,
    this.onDeletePermanently,
  });

  @override
  State<_DesktopSongRow> createState() => _DesktopSongRowState();
}

class _DesktopSongRowState extends State<_DesktopSongRow> {
  bool _isHovered = false;

  Future<void> _revealFileInOS(String filePath) async {
    if (filePath.isEmpty) return;
    try {
      if (Platform.isMacOS) {
        await Process.run('open', ['-R', filePath]);
      } else if (Platform.isWindows) {
        await Process.run('explorer.exe', ['/select,', filePath]);
      } else if (Platform.isLinux) {
        await Process.run('xdg-open', [File(filePath).parent.path]);
      }
    } catch (_) {}
  }

  void _showContextMenu(BuildContext context, Offset position) async {
    final loc = AppLocalizations.of(context);
    final RenderBox overlay =
        Overlay.of(context).context.findRenderObject() as RenderBox;
    final value = await showMenu<String>(
      context: context,
      position: RelativeRect.fromRect(
        position & const Size(40, 40),
        Offset.zero & overlay.size,
      ),
      color: widget.isLight
          ? const Color(0xFFFAFAFD)
          : const Color(0xFF222228),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      elevation: 8,
      items: [
        PopupMenuItem(
          value: 'play_next',
          child: Row(
            children: [
              Icon(Icons.playlist_play_rounded, size: 20, color: widget.activeAccentColor),
              const SizedBox(width: 12),
              Text(loc.playNext, style: TextStyle(color: widget.textColor, fontSize: 13)),
            ],
          ),
        ),
        PopupMenuItem(
          value: 'add_queue',
          child: Row(
            children: [
              const Icon(Icons.queue_music_rounded, size: 20),
              const SizedBox(width: 12),
              Text(loc.addToQueue, style: TextStyle(color: widget.textColor, fontSize: 13)),
            ],
          ),
        ),
        PopupMenuItem(
          value: 'add_playlist',
          child: Row(
            children: [
              const Icon(Icons.playlist_add_rounded, size: 20),
              const SizedBox(width: 12),
              Text(loc.addToPlaylist, style: TextStyle(color: widget.textColor, fontSize: 13)),
            ],
          ),
        ),
        if (widget.onRemoveFromPlaylist != null)
          PopupMenuItem(
            value: 'remove_playlist',
            child: Row(
              children: [
                const Icon(Icons.playlist_remove_rounded, size: 20, color: Colors.redAccent),
                const SizedBox(width: 12),
                Text(loc.removeFromPlaylist, style: const TextStyle(color: Colors.redAccent, fontSize: 13)),
              ],
            ),
          ),
        if (widget.onGoToArtist != null && widget.track.artist.isNotEmpty && widget.track.artist != 'Unknown Artist')
          PopupMenuItem(
            value: 'go_artist',
            child: Row(
              children: [
                const Icon(Icons.person_outline_rounded, size: 20),
                const SizedBox(width: 12),
                Text(loc.goToArtist, style: TextStyle(color: widget.textColor, fontSize: 13)),
              ],
            ),
          ),
        if (widget.onGoToAlbum != null && widget.track.album.isNotEmpty && widget.track.album != 'Unknown Album')
          PopupMenuItem(
            value: 'go_album',
            child: Row(
              children: [
                const Icon(Icons.album_outlined, size: 20),
                const SizedBox(width: 12),
                Text(loc.goToAlbum, style: TextStyle(color: widget.textColor, fontSize: 13)),
              ],
            ),
          ),
        if (widget.track.path.isNotEmpty)
          PopupMenuItem(
            value: 'reveal_file',
            child: Row(
              children: [
                const Icon(Icons.folder_open_rounded, size: 20),
                const SizedBox(width: 12),
                Text(
                  Platform.isMacOS
                      ? 'Show in Finder'
                      : (Platform.isWindows ? 'Show in File Explorer' : 'Show in Folder'),
                  style: TextStyle(color: widget.textColor, fontSize: 13),
                ),
              ],
            ),
          ),
        PopupMenuItem(
          value: 'details',
          child: Row(
            children: [
              const Icon(Icons.info_outline_rounded, size: 20),
              const SizedBox(width: 12),
              Text(loc.songInfo, style: TextStyle(color: widget.textColor, fontSize: 13)),
            ],
          ),
        ),
        PopupMenuItem(
          value: 'edit_tags',
          child: Row(
            children: [
              const Icon(Icons.edit_outlined, size: 20),
              const SizedBox(width: 12),
              Text(loc.editMetadata, style: TextStyle(color: widget.textColor, fontSize: 13)),
            ],
          ),
        ),
        if (widget.onChangeArtwork != null)
          PopupMenuItem(
            value: 'change_artwork',
            child: Row(
              children: [
                const Icon(Icons.image_outlined, size: 20),
                const SizedBox(width: 12),
                Text(loc.editCover, style: TextStyle(color: widget.textColor, fontSize: 13)),
              ],
            ),
          ),
        if (widget.onHideTrack != null)
          PopupMenuItem(
            value: 'hide_track',
            child: Row(
              children: [
                const Icon(Icons.visibility_off_outlined, size: 20, color: Colors.redAccent),
                const SizedBox(width: 12),
                Text(loc.hideTrack, style: const TextStyle(color: Colors.redAccent, fontSize: 13)),
              ],
            ),
          ),
        if (widget.onDeletePermanently != null)
          PopupMenuItem(
            value: 'delete_permanently',
            child: Row(
              children: [
                const Icon(Icons.delete_outline_rounded, size: 20, color: Colors.redAccent),
                const SizedBox(width: 12),
                Text(loc.deleteFromDevice, style: const TextStyle(color: Colors.redAccent, fontSize: 13)),
              ],
            ),
          ),
      ],
    );

    if (value == 'play_next' && widget.onPlayNext != null) {
      widget.onPlayNext!();
    } else if (value == 'add_queue' && widget.onAddToQueue != null) {
      widget.onAddToQueue!();
    } else if (value == 'add_playlist' && widget.onAddToPlaylist != null) {
      widget.onAddToPlaylist!(widget.track);
    } else if (value == 'remove_playlist' && widget.onRemoveFromPlaylist != null) {
      widget.onRemoveFromPlaylist!(widget.track);
    } else if (value == 'go_artist' && widget.onGoToArtist != null) {
      widget.onGoToArtist!(widget.track.artist);
    } else if (value == 'go_album' && widget.onGoToAlbum != null) {
      widget.onGoToAlbum!(widget.track.album);
    } else if (value == 'reveal_file') {
      _revealFileInOS(widget.track.path);
    } else if (value == 'details' && widget.onShowDetails != null) {
      widget.onShowDetails!(widget.track);
    } else if (value == 'edit_tags' && widget.onEditTags != null) {
      widget.onEditTags!(widget.track);
    } else if (value == 'change_artwork' && widget.onChangeArtwork != null) {
      widget.onChangeArtwork!(widget.track);
    } else if (value == 'hide_track' && widget.onHideTrack != null) {
      widget.onHideTrack!(widget.track);
    } else if (value == 'delete_permanently' && widget.onDeletePermanently != null) {
      widget.onDeletePermanently!(widget.track);
    }
  }

  String _formatDuration(int ms) {
    if (ms <= 0) return '--:--';
    final sec = (ms / 1000).floor();
    final m = sec ~/ 60;
    final s = sec % 60;
    return '$m:${s.toString().padLeft(2, '0')}';
  }

  @override
  Widget build(BuildContext context) {
    final hoverBg = widget.isLight
        ? Colors.black.withValues(alpha: 0.035)
        : Colors.white.withValues(alpha: 0.045);

    return MouseRegion(
      onEnter: (_) => setState(() => _isHovered = true),
      onExit: (_) => setState(() => _isHovered = false),
      child: GestureDetector(
        behavior: HitTestBehavior.translucent,
        onSecondaryTapDown: (details) =>
            _showContextMenu(context, details.globalPosition),
        child: InkWell(
          onTap: widget.onTap,
        child: Container(
          height: 54,
          padding: const EdgeInsets.symmetric(horizontal: 24),
          color: _isHovered ? hoverBg : Colors.transparent,
          child: Row(
            children: [
              // Index or Visualizer or Pause Icon or Play Icon
              SizedBox(
                width: 36,
                child: widget.isPlaying
                    ? Center(
                        child: _DesktopEqualizerVisualizer(
                          color: widget.activeAccentColor,
                          animate: true,
                        ),
                      )
                    : widget.isCurrentTrack
                        ? Center(
                            child: Icon(
                              Icons.pause_rounded,
                              size: 18,
                              color: widget.activeAccentColor,
                            ),
                          )
                        : _isHovered
                            ? Icon(
                                Icons.play_arrow_rounded,
                                size: 20,
                                color: widget.textColor,
                              )
                            : Center(
                                child: Text(
                                  '${widget.index}',
                                  textAlign: TextAlign.center,
                                  style: TextStyle(
                                    fontSize: 12.5,
                                    color: widget.secondaryTextColor,
                                  ),
                                ),
                              ),
              ),

              const SizedBox(width: 14),

              // Artwork + Title + Artist
              Expanded(
                flex: 4,
                child: Row(
                  children: [
                    _DesktopTrackArtwork(
                      track: widget.track,
                      size: 40,
                      radius: 6,
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            widget.track.title,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              fontSize: 13.5,
                              fontWeight: widget.isCurrentTrack
                                  ? FontWeight.w700
                                  : FontWeight.w500,
                              color: widget.isCurrentTrack
                                  ? widget.activeAccentColor
                                  : widget.textColor,
                            ),
                          ),
                          const SizedBox(height: 2),
                          widget.onArtistTap != null
                              ? InkWell(
                                  borderRadius: BorderRadius.circular(4),
                                  onTap: () => widget.onArtistTap!(widget.track.artist),
                                  child: Text(
                                    widget.track.artist,
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: TextStyle(
                                      fontSize: 12,
                                      color: widget.secondaryTextColor,
                                    ),
                                  ),
                                )
                              : Text(
                                  widget.track.artist,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: TextStyle(
                                    fontSize: 12,
                                    color: widget.secondaryTextColor,
                                  ),
                                ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),

              // Album
              Expanded(
                flex: 3,
                child: widget.onAlbumTap != null
                    ? InkWell(
                        borderRadius: BorderRadius.circular(4),
                        onTap: () => widget.onAlbumTap!(widget.track.album),
                        child: Text(
                          widget.track.album,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontSize: 13,
                            color: widget.secondaryTextColor,
                          ),
                        ),
                      )
                    : Text(
                        widget.track.album,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: 13,
                          color: widget.secondaryTextColor,
                        ),
                      ),
              ),

              // Duration
              SizedBox(
                width: 70,
                child: Text(
                  _formatDuration(widget.track.duration),
                  textAlign: TextAlign.right,
                  style: TextStyle(
                    fontSize: 12.5,
                    color: widget.secondaryTextColor,
                  ),
                ),
              ),

              // Favorite button
              SizedBox(
                width: 40,
                child: IconButton(
                  icon: Icon(
                    widget.isFavorite
                        ? Icons.favorite_rounded
                        : Icons.favorite_border_rounded,
                    size: 18,
                    color: widget.isFavorite
                        ? Colors.redAccent
                        : (_isHovered
                            ? widget.secondaryTextColor
                            : Colors.transparent),
                  ),
                  onPressed: widget.onToggleFavorite,
                ),
              ),

              // 3-dot more options button
              SizedBox(
                width: 36,
                child: _isHovered
                    ? IconButton(
                        icon: Icon(
                          Icons.more_vert_rounded,
                          size: 18,
                          color: widget.secondaryTextColor,
                        ),
                        onPressed: () {
                          final RenderBox box =
                              context.findRenderObject() as RenderBox;
                          final Offset position =
                              box.localToGlobal(Offset.zero);
                          _showContextMenu(
                            context,
                            position +
                                Offset(box.size.width - 40, box.size.height / 2),
                          );
                        },
                      )
                    : null,
              ),
            ],
          ),
        ),
      ),
    ),
  );
}
}

class _DesktopTrackArtwork extends StatelessWidget {
  final Track track;
  final double size;
  final double radius;

  const _DesktopTrackArtwork({
    required this.track,
    required this.size,
    this.radius = 6,
  });

  @override
  Widget build(BuildContext context) {
    final cachedBytes = ArtworkCacheManager.getCachedArtwork(track.id);
    if (cachedBytes != null && cachedBytes.isNotEmpty) {
      return ClipRRect(
        borderRadius: BorderRadius.circular(radius),
        child: Image.memory(
          cachedBytes,
          width: size,
          height: size,
          fit: BoxFit.cover,
          errorBuilder: (context, error, stackTrace) => _placeholder(),
        ),
      );
    }
    return _placeholder();
  }

  Widget _placeholder() {
    final hash = track.title.hashCode.abs();
    final hue1 = (hash % 360).toDouble();
    final color1 = HSLColor.fromAHSL(1.0, hue1, 0.45, 0.30).toColor();
    final color2 =
        HSLColor.fromAHSL(1.0, (hue1 + 45) % 360, 0.50, 0.16).toColor();

    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(radius),
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [color1, color2],
        ),
        boxShadow: size > 40
            ? [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.25),
                  blurRadius: 6,
                  offset: const Offset(0, 2),
                ),
              ]
            : null,
      ),
      alignment: Alignment.center,
      child: Icon(
        Icons.music_note_rounded,
        size: size * 0.45,
        color: Colors.white.withValues(alpha: 0.75),
      ),
    );
  }
}

class _DesktopEqualizerVisualizer extends StatefulWidget {
  final Color color;
  final bool animate;

  const _DesktopEqualizerVisualizer({
    required this.color,
    required this.animate,
  });

  @override
  State<_DesktopEqualizerVisualizer> createState() =>
      _DesktopEqualizerVisualizerState();
}

class _DesktopEqualizerVisualizerState extends State<_DesktopEqualizerVisualizer>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 650),
    );
    if (widget.animate) _controller.repeat(reverse: true);
  }

  @override
  void didUpdateWidget(covariant _DesktopEqualizerVisualizer oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.animate && !_controller.isAnimating) {
      _controller.repeat(reverse: true);
    } else if (!widget.animate && _controller.isAnimating) {
      _controller.stop();
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, _) {
        final t = _controller.value;
        final h1 = widget.animate ? 4.0 + 8.0 * ((t + 0.1) % 1.0) : 4.0;
        final h2 = widget.animate ? 4.0 + 10.0 * ((t + 0.5) % 1.0) : 4.0;
        final h3 = widget.animate ? 4.0 + 7.0 * ((t + 0.8) % 1.0) : 4.0;

        return SizedBox(
          width: 18,
          height: 16,
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              _buildBar(h1),
              const SizedBox(width: 2.5),
              _buildBar(h2),
              const SizedBox(width: 2.5),
              _buildBar(h3),
            ],
          ),
        );
      },
    );
  }

  Widget _buildBar(double height) {
    return Container(
      width: 3.5,
      height: height.clamp(3.0, 16.0),
      decoration: BoxDecoration(
        color: widget.color,
        borderRadius: BorderRadius.circular(1.75),
      ),
    );
  }
}
