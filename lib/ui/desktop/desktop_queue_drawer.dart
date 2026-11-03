// ignore_for_file: invalid_use_of_protected_member
part of 'desktop_layout_shell.dart';

extension _DesktopQueueDrawerUI on _DesktopLayoutShellState {
  Widget _buildQueueSidePanel(
    Color textColor,
    Color secondaryTextColor,
    Color borderColor, {
    bool isFloatingInFullscreen = false,
  }) {
    final loc = AppLocalizations.of(context);
    final currentTrack = widget.playingTrack;
    final queue = widget.playbackQueue;

    final currentIndex = currentTrack != null
        ? queue.indexWhere((t) => t.id == currentTrack.id)
        : -1;

    final upcomingTracks = currentIndex != -1
        ? queue.sublist(currentIndex + 1)
        : queue;
    final previousTracks = currentIndex > 0
        ? queue.sublist(0, currentIndex)
        : <Track>[];

    final panelBg = isFloatingInFullscreen
        ? const Color(0xFF121216).withValues(alpha: 0.82)
        : (widget.isLight
            ? widget.cardColor.withValues(alpha: 0.94)
            : Color.alphaBlend(
                Colors.white.withValues(alpha: 0.04),
                widget.cardColor,
              ).withValues(alpha: 0.94));

    return ClipRect(
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
        child: Container(
          width: 340,
          decoration: BoxDecoration(
            color: panelBg,
            border: Border(left: BorderSide(color: borderColor)),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(
                  alpha: widget.isLight ? 0.08 : 0.35,
                ),
                blurRadius: 24,
                offset: const Offset(-4, 0),
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Queue Header (height 56 - exact pixel alignment with search header)
              Container(
                height: 56,
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Row(
                  children: [
                    Icon(
                      Icons.queue_music_rounded,
                      size: 20,
                      color: widget.activeAccentColor,
                    ),
                    const SizedBox(width: 10),
                    Text(
                      loc.upNext,
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w700,
                        color: textColor,
                        letterSpacing: -0.2,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 7,
                        vertical: 2,
                      ),
                      decoration: BoxDecoration(
                        color: widget.activeAccentColor.withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Text(
                        '${queue.length}',
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                          color: widget.activeAccentColor,
                        ),
                      ),
                    ),
                    const Spacer(),
                    IconButton(
                      icon: const Icon(Icons.close_rounded, size: 18),
                      tooltip: 'Close Queue',
                      onPressed: () => setState(() => _isQueueOpen = false),
                      color: secondaryTextColor,
                    ),
                  ],
                ),
              ),
              Divider(color: borderColor, height: 1),

              // Scrollable Queue Content
              Expanded(
                child: ListView(
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  children: [
                    // Now Playing Section Card
                    if (currentTrack != null) ...[
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 16),
                        child: Text(
                          loc.nowPlaying.toUpperCase(),
                          style: TextStyle(
                            fontSize: 10.5,
                            fontWeight: FontWeight.w700,
                            letterSpacing: 0.8,
                            color: widget.activeAccentColor,
                          ),
                        ),
                      ),
                      const SizedBox(height: 6),
                      Container(
                        margin: const EdgeInsets.symmetric(horizontal: 14),
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          color: widget.activeAccentColor.withValues(alpha: 0.08),
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(
                            color: widget.activeAccentColor.withValues(alpha: 0.25),
                          ),
                        ),
                        child: Row(
                          children: [
                            _DesktopTrackArtwork(
                              track: currentTrack,
                              size: 42,
                              radius: 6,
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    currentTrack.title,
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: TextStyle(
                                      fontSize: 13,
                                      fontWeight: FontWeight.w700,
                                      color: textColor,
                                    ),
                                  ),
                                  const SizedBox(height: 2),
                                  Text(
                                    currentTrack.artist,
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: TextStyle(
                                      fontSize: 11.5,
                                      color: secondaryTextColor,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            Icon(
                              Icons.volume_up_rounded,
                              color: widget.activeAccentColor,
                              size: 18,
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 16),
                    ],

                    // Next In Queue Header
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            '${loc.upNext.toUpperCase()} (${upcomingTracks.length})',
                            style: TextStyle(
                              fontSize: 10.5,
                              fontWeight: FontWeight.w700,
                              letterSpacing: 0.8,
                              color: secondaryTextColor,
                            ),
                          ),
                          if (upcomingTracks.isNotEmpty)
                            Text(
                              '${upcomingTracks.length} ${loc.songsCount}',
                              style: TextStyle(
                                fontSize: 11,
                                color: secondaryTextColor.withValues(alpha: 0.7),
                              ),
                            ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 6),

                    if (upcomingTracks.isEmpty)
                      Padding(
                        padding: const EdgeInsets.symmetric(vertical: 32),
                        child: Center(
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(
                                Icons.queue_music_rounded,
                                size: 36,
                                color: secondaryTextColor.withValues(alpha: 0.4),
                              ),
                              const SizedBox(height: 8),
                              Text(
                                loc.noMatchingSongs,
                                style: TextStyle(
                                  fontSize: 12.5,
                                  fontWeight: FontWeight.w500,
                                  color: secondaryTextColor,
                                ),
                              ),
                            ],
                          ),
                        ),
                      )
                    else
                      ReorderableListView.builder(
                        shrinkWrap: true,
                        physics: const NeverScrollableScrollPhysics(),
                        buildDefaultDragHandles: false,
                        itemCount: upcomingTracks.length,
                        // ignore: deprecated_member_use
                        onReorder: (oldIndex, newIndex) {
                          if (widget.onReorderQueue == null) return;
                          final track = upcomingTracks[oldIndex];
                          int target = currentIndex != -1
                              ? currentIndex + 1 + newIndex
                              : newIndex;
                          if (newIndex > oldIndex) {
                            target--;
                          }
                          widget.onReorderQueue!(track, target);
                        },
                        itemBuilder: (context, uIndex) {
                          final track = upcomingTracks[uIndex];
                          final queueIndex = currentIndex != -1
                              ? currentIndex + 1 + uIndex
                              : uIndex;

                          return Padding(
                            key: ValueKey('queue_${track.id}_$uIndex'),
                            padding: const EdgeInsets.symmetric(
                              horizontal: 10,
                              vertical: 2,
                            ),
                            child: InkWell(
                              borderRadius: BorderRadius.circular(8),
                              onTap: () => widget.onPlayTrack(
                                track,
                                queue,
                                queueIndex,
                              ),
                              child: Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 8,
                                  vertical: 6,
                                ),
                                decoration: BoxDecoration(
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: Row(
                                  children: [
                                    SizedBox(
                                      width: 22,
                                      child: Text(
                                        '${uIndex + 1}',
                                        style: TextStyle(
                                          fontSize: 11.5,
                                          fontWeight: FontWeight.w500,
                                          color: secondaryTextColor
                                              .withValues(alpha: 0.6),
                                        ),
                                      ),
                                    ),
                                    _DesktopTrackArtwork(
                                      track: track,
                                      size: 36,
                                      radius: 5,
                                    ),
                                    const SizedBox(width: 10),
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: [
                                          Text(
                                            track.title,
                                            maxLines: 1,
                                            overflow: TextOverflow.ellipsis,
                                            style: TextStyle(
                                              fontSize: 12.5,
                                              fontWeight: FontWeight.w500,
                                              color: textColor,
                                            ),
                                          ),
                                          const SizedBox(height: 2),
                                          Text(
                                            track.artist,
                                            maxLines: 1,
                                            overflow: TextOverflow.ellipsis,
                                            style: TextStyle(
                                              fontSize: 11,
                                              color: secondaryTextColor,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                    if (widget.onRemoveFromQueue != null)
                                      IconButton(
                                        icon: const Icon(
                                          Icons.close_rounded,
                                          size: 16,
                                        ),
                                        tooltip: loc.remove,
                                        color: secondaryTextColor
                                            .withValues(alpha: 0.6),
                                        splashRadius: 14,
                                        padding: EdgeInsets.zero,
                                        constraints: const BoxConstraints(
                                          minWidth: 26,
                                          minHeight: 26,
                                        ),
                                        onPressed: () =>
                                            widget.onRemoveFromQueue!(track.id),
                                      ),
                                    if (widget.onReorderQueue != null)
                                      ReorderableDragStartListener(
                                        index: uIndex,
                                        child: Padding(
                                          padding:
                                              const EdgeInsets.only(left: 4),
                                          child: Icon(
                                            Icons.drag_handle_rounded,
                                            size: 16,
                                            color: secondaryTextColor
                                                .withValues(alpha: 0.5),
                                          ),
                                        ),
                                      ),
                                  ],
                                ),
                              ),
                            ),
                          );
                        },
                      ),

                    // Previously Played Section
                    if (previousTracks.isNotEmpty) ...[
                      const SizedBox(height: 20),
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 16),
                        child: Text(
                          'PREVIOUSLY PLAYED (${previousTracks.length})',
                          style: TextStyle(
                            fontSize: 10.5,
                            fontWeight: FontWeight.w700,
                            letterSpacing: 0.8,
                            color: secondaryTextColor.withValues(alpha: 0.7),
                          ),
                        ),
                      ),
                      const SizedBox(height: 6),
                      ...List.generate(previousTracks.length, (pIndex) {
                        final track = previousTracks[pIndex];

                        return Padding(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 10,
                            vertical: 2,
                          ),
                          child: InkWell(
                            borderRadius: BorderRadius.circular(8),
                            onTap: () => widget.onPlayTrack(track, queue, pIndex),
                            child: Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 8,
                                vertical: 6,
                              ),
                              child: Row(
                                children: [
                                  SizedBox(
                                    width: 22,
                                    child: Icon(
                                      Icons.history_rounded,
                                      size: 14,
                                      color: secondaryTextColor.withValues(alpha: 0.4),
                                    ),
                                  ),
                                  Opacity(
                                    opacity: 0.7,
                                    child: _DesktopTrackArtwork(
                                      track: track,
                                      size: 34,
                                      radius: 5,
                                    ),
                                  ),
                                  const SizedBox(width: 10),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          track.title,
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                          style: TextStyle(
                                            fontSize: 12,
                                            color: textColor.withValues(alpha: 0.75),
                                          ),
                                        ),
                                        const SizedBox(height: 2),
                                        Text(
                                          track.artist,
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                          style: TextStyle(
                                            fontSize: 10.5,
                                            color: secondaryTextColor.withValues(alpha: 0.6),
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                  const SizedBox(width: 8),
                                  Text(
                                    _formatDuration(track.duration),
                                    style: TextStyle(
                                      fontSize: 10.5,
                                      color: secondaryTextColor.withValues(alpha: 0.5),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        );
                      }),
                    ],
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
