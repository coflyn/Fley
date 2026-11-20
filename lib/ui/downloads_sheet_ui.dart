// ignore_for_file: invalid_use_of_protected_member, deprecated_member_use
part of '../main.dart';

extension _DownloadsUI on _MainScreenState {
  void _openDownloads() {
    _showDownloadsModal(context);
  }

  void _showDownloadsModal(BuildContext context) {
    final isLight = isAppLight;
    final bgColor = isLight ? const Color(0xFFF7F7F9) : const Color(0xFF141416);
    final cardBg = isLight ? Colors.white : const Color(0xFF1F1F23);
    final borderColor = isLight
        ? Colors.black.withValues(alpha: 0.06)
        : Colors.white.withValues(alpha: 0.08);
    final textColor = isLight ? const Color(0xFF18181B) : Colors.white;
    final subtextColor =
        isLight ? const Color(0xFF71717A) : const Color(0xFFA1A1AA);

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: bgColor,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      builder: (ctx) {
        return StatefulBuilder(
          builder: (context, setSheetState) {
            final downloadedTracks = _allTracks.where((t) {
              return t.id.startsWith('local_ytm_') ||
                  t.path.contains('FleyDownloads');
            }).toList();

            return SafeArea(
              child: SizedBox(
                height: MediaQuery.of(context).size.height * 0.85,
                child: Column(
                  children: [
                    const SizedBox(height: 12),
                    // Drag Handle
                    Center(
                      child: Container(
                        width: 44,
                        height: 5,
                        decoration: BoxDecoration(
                          color: isLight
                              ? Colors.black.withValues(alpha: 0.15)
                              : Colors.white.withValues(alpha: 0.2),
                          borderRadius: BorderRadius.circular(3),
                        ),
                      ),
                    ),
                    const SizedBox(height: 14),

                    // Header
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 20),
                      child: Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.all(10),
                            decoration: BoxDecoration(
                              color: _activeAccentColor.withValues(alpha: 0.14),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Icon(
                              Icons.download_rounded,
                              color: _activeAccentColor,
                              size: 22,
                            ),
                          ),
                          const SizedBox(width: 14),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'Downloads',
                                  style: TextStyle(
                                    fontSize: 20,
                                    fontWeight: FontWeight.bold,
                                    color: textColor,
                                    fontFamily: getFontFamily(_activeFont),
                                  ),
                                ),
                                const SizedBox(height: 3),
                                FutureBuilder<int>(
                                  future: DownloadService.instance
                                      .getTotalDownloadBytes(),
                                  builder: (context, snapshot) {
                                    final bytes = snapshot.data ?? 0;
                                    final mb =
                                        (bytes / (1024 * 1024)).toStringAsFixed(1);
                                    final count = downloadedTracks.length;
                                    return Container(
                                      padding: const EdgeInsets.symmetric(
                                          horizontal: 8, vertical: 2),
                                      decoration: BoxDecoration(
                                        color: isLight
                                            ? Colors.black.withValues(alpha: 0.05)
                                            : Colors.white.withValues(alpha: 0.08),
                                        borderRadius: BorderRadius.circular(12),
                                      ),
                                      child: Text(
                                        '$count ${count == 1 ? 'song' : 'songs'} • $mb MB',
                                        style: TextStyle(
                                          fontSize: 11,
                                          fontWeight: FontWeight.w500,
                                          color: subtextColor,
                                        ),
                                      ),
                                    );
                                  },
                                ),
                              ],
                            ),
                          ),
                          if (downloadedTracks.isNotEmpty)
                            IconButton(
                              icon: Icon(
                                Icons.delete_sweep_rounded,
                                color: subtextColor,
                                size: 22,
                              ),
                              tooltip: 'Clear All Downloads',
                              onPressed: () {
                                _confirmClearAllDownloads(ctx, setSheetState);
                              },
                            ),
                          IconButton(
                            icon: Icon(Icons.close_rounded,
                                color: subtextColor, size: 22),
                            tooltip: 'Close',
                            onPressed: () => Navigator.pop(ctx),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 8),
                    Divider(
                      height: 16,
                      thickness: 0.5,
                      color: borderColor,
                    ),

                    // Content
                    Expanded(
                      child: ValueListenableBuilder<List<DownloadTask>>(
                        valueListenable:
                            DownloadService.instance.activeTasksNotifier,
                        builder: (context, activeTasks, _) {
                          final downloadingTasks = activeTasks
                              .where((t) =>
                                  t.status == DownloadStatus.downloading ||
                                  t.status == DownloadStatus.pending ||
                                  t.status == DownloadStatus.failed)
                              .toList();

                          if (downloadingTasks.isEmpty &&
                              downloadedTracks.isEmpty) {
                            return _buildDownloadsEmptyState(
                                isLight, textColor, subtextColor);
                          }

                          return ListView(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 16, vertical: 8),
                            children: [
                              // Active Downloads Section
                              if (downloadingTasks.isNotEmpty) ...[
                                Padding(
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 4, vertical: 6),
                                  child: Row(
                                    children: [
                                      Text(
                                        'DOWNLOADING (${downloadingTasks.length})',
                                        style: TextStyle(
                                          fontSize: 12,
                                          fontWeight: FontWeight.bold,
                                          color: _activeAccentColor,
                                          letterSpacing: 0.8,
                                        ),
                                      ),
                                      const Spacer(),
                                      SizedBox(
                                        width: 14,
                                        height: 14,
                                        child: CircularProgressIndicator(
                                          strokeWidth: 2,
                                          valueColor:
                                              AlwaysStoppedAnimation<Color>(
                                                  _activeAccentColor),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                ...downloadingTasks.map((task) =>
                                    _buildDownloadingTile(
                                      task,
                                      isLight,
                                      cardBg,
                                      borderColor,
                                      textColor,
                                      subtextColor,
                                      setSheetState,
                                    )),
                                const SizedBox(height: 16),
                              ],

                              // Downloaded Tracks Section
                              if (downloadedTracks.isNotEmpty) ...[
                                Padding(
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 4, vertical: 6),
                                  child: Text(
                                    'DOWNLOADED OFFLINE (${downloadedTracks.length})',
                                    style: TextStyle(
                                      fontSize: 12,
                                      fontWeight: FontWeight.bold,
                                      color: subtextColor,
                                      letterSpacing: 0.8,
                                    ),
                                  ),
                                ),
                                ...List.generate(downloadedTracks.length,
                                    (index) {
                                  final track = downloadedTracks[index];
                                  final isPlaying =
                                      _playingTrack?.id == track.id;
                                  return _buildDownloadedTrackTile(
                                    track,
                                    index,
                                    downloadedTracks,
                                    isPlaying,
                                    isLight,
                                    cardBg,
                                    borderColor,
                                    textColor,
                                    subtextColor,
                                    setSheetState,
                                  );
                                }),
                              ],
                            ],
                          );
                        },
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  Widget _buildDownloadingTile(
    DownloadTask task,
    bool isLight,
    Color cardBg,
    Color borderColor,
    Color textColor,
    Color subtextColor,
    StateSetter setSheetState,
  ) {
    final isFailed = task.status == DownloadStatus.failed;
    final mbReceived =
        (task.bytesReceived / (1024 * 1024)).toStringAsFixed(1);
    final mbTotal = (task.totalBytes / (1024 * 1024)).toStringAsFixed(1);

    String progressSubtitle;
    if (isFailed) {
      progressSubtitle = task.error ?? 'Download failed. Tap retry.';
    } else if (task.totalBytes > 0) {
      final pct = (task.progress * 100).toInt();
      progressSubtitle = '$pct% • $mbReceived MB of $mbTotal MB';
    } else {
      progressSubtitle = 'Connecting & buffering audio...';
    }

    return Container(
      margin: const EdgeInsets.symmetric(vertical: 4),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: cardBg,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isFailed
              ? Colors.redAccent.withValues(alpha: 0.35)
              : borderColor,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Stack(
                alignment: Alignment.center,
                children: [
                  _buildTrackArtwork(task.track, size: 46, radius: 10),
                  if (isFailed)
                    Container(
                      width: 46,
                      height: 46,
                      decoration: BoxDecoration(
                        color: Colors.black54,
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: const Icon(
                        Icons.error_outline_rounded,
                        color: Colors.redAccent,
                        size: 22,
                      ),
                    ),
                ],
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      task.track.title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: textColor,
                      ),
                    ),
                    const SizedBox(height: 3),
                    Row(
                      children: [
                        if (!isFailed && task.totalBytes > 0) ...[
                          Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 6, vertical: 1.5),
                            decoration: BoxDecoration(
                              color: _activeAccentColor.withValues(alpha: 0.15),
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: Text(
                              'AAC 128k',
                              style: TextStyle(
                                fontSize: 9.5,
                                fontWeight: FontWeight.bold,
                                color: _activeAccentColor,
                              ),
                            ),
                          ),
                          const SizedBox(width: 6),
                        ],
                        Expanded(
                          child: Text(
                            progressSubtitle,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              fontSize: 11,
                              color: isFailed ? Colors.redAccent : subtextColor,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              if (isFailed)
                Container(
                  decoration: BoxDecoration(
                    color: _activeAccentColor.withValues(alpha: 0.12),
                    shape: BoxShape.circle,
                  ),
                  child: IconButton(
                    icon: const Icon(Icons.refresh_rounded, size: 20),
                    color: _activeAccentColor,
                    tooltip: 'Retry',
                    onPressed: () {
                      DownloadService.instance.downloadTrack(task.track);
                      setSheetState(() {});
                    },
                  ),
                )
              else
                Container(
                  decoration: BoxDecoration(
                    color: isLight
                        ? Colors.black.withValues(alpha: 0.05)
                        : Colors.white.withValues(alpha: 0.08),
                    shape: BoxShape.circle,
                  ),
                  child: IconButton(
                    icon: const Icon(Icons.close_rounded, size: 18),
                    color: subtextColor,
                    tooltip: 'Cancel',
                    onPressed: () {
                      DownloadService.instance.cancelDownload(task.id);
                      setSheetState(() {});
                    },
                  ),
                ),
            ],
          ),
          if (!isFailed) ...[
            const SizedBox(height: 10),
            ClipRRect(
              borderRadius: BorderRadius.circular(4),
              child: LinearProgressIndicator(
                value: task.progress > 0 ? task.progress : null,
                minHeight: 5,
                backgroundColor: isLight
                    ? Colors.black.withValues(alpha: 0.06)
                    : Colors.white.withValues(alpha: 0.08),
                valueColor: AlwaysStoppedAnimation<Color>(_activeAccentColor),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildDownloadedTrackTile(
    Track track,
    int index,
    List<Track> downloadedList,
    bool isPlaying,
    bool isLight,
    Color cardBg,
    Color borderColor,
    Color textColor,
    Color subtextColor,
    StateSetter setSheetState,
  ) {
    // Format duration string
    final durSec = track.duration > 1000 ? track.duration ~/ 1000 : track.duration;
    final durMinutes = durSec ~/ 60;
    final durRemainder = durSec % 60;
    final durStr = durSec > 0
        ? '$durMinutes:${durRemainder.toString().padLeft(2, '0')}'
        : '';

    return Container(
      margin: const EdgeInsets.symmetric(vertical: 3),
      decoration: BoxDecoration(
        color: cardBg,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: borderColor),
      ),
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 2),
        leading: Stack(
          alignment: Alignment.center,
          children: [
            _buildTrackArtwork(track, size: 46, radius: 10),
            if (isPlaying)
              Container(
                width: 46,
                height: 46,
                decoration: BoxDecoration(
                  color: Colors.black54,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(
                  Icons.equalizer_rounded,
                  color: _activeAccentColor,
                  size: 24,
                ),
              ),
          ],
        ),
        title: Text(
          track.title,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w600,
            color: isPlaying ? _activeAccentColor : textColor,
          ),
        ),
        subtitle: Row(
          children: [
            Icon(
              Icons.check_circle_rounded,
              size: 13,
              color: _activeAccentColor,
            ),
            const SizedBox(width: 4),
            Expanded(
              child: Text(
                [
                  if (track.artist.isNotEmpty && track.artist != '<unknown>')
                    track.artist
                  else
                    'YouTube Music',
                  if (durStr.isNotEmpty) durStr,
                ].join(' • '),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(fontSize: 12, color: subtextColor),
              ),
            ),
          ],
        ),
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 36,
              height: 36,
              decoration: BoxDecoration(
                color: isPlaying
                    ? _activeAccentColor.withValues(alpha: 0.15)
                    : (isLight
                        ? Colors.black.withValues(alpha: 0.04)
                        : Colors.white.withValues(alpha: 0.06)),
                shape: BoxShape.circle,
              ),
              child: IconButton(
                padding: EdgeInsets.zero,
                icon: Icon(
                  isPlaying ? Icons.pause_rounded : Icons.play_arrow_rounded,
                  color: isPlaying ? _activeAccentColor : subtextColor,
                  size: 22,
                ),
                onPressed: () {
                  if (isPlaying) {
                    if (player.playing) {
                      _pauseWithFade();
                    } else {
                      _playWithFade();
                    }
                  } else {
                    _playTrack(index, sourceList: downloadedList);
                  }
                  setSheetState(() {});
                },
              ),
            ),
            IconButton(
              icon: Icon(Icons.more_vert_rounded, color: subtextColor, size: 20),
              tooltip: 'Options',
              onPressed: () {
                _showTrackOptions(context, track);
              },
            ),
          ],
        ),
        onTap: () {
          _playTrack(index, sourceList: downloadedList);
          setSheetState(() {});
        },
      ),
    );
  }

  Widget _buildDownloadsEmptyState(
      bool isLight, Color textColor, Color subtextColor) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 36),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(26),
              decoration: BoxDecoration(
                color: _activeAccentColor.withValues(alpha: 0.12),
                shape: BoxShape.circle,
              ),
              child: Icon(
                Icons.cloud_download_outlined,
                size: 56,
                color: _activeAccentColor,
              ),
            ),
            const SizedBox(height: 22),
            Text(
              'No Downloads Yet',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: textColor,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Download your favorite songs from YouTube Music to listen offline anytime without using cellular data.',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 13,
                color: subtextColor,
                height: 1.45,
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _confirmClearAllDownloads(
      BuildContext ctx, StateSetter setSheetState) {
    final isLight = isAppLight;
    showDialog(
      context: ctx,
      builder: (dialogCtx) => AlertDialog(
        backgroundColor:
            isLight ? const Color(0xFFF7F7F9) : const Color(0xFF1F1F23),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(22)),
        title: Text(
          'Clear All Downloads?',
          style: TextStyle(
            color: isLight ? const Color(0xFF18181B) : Colors.white,
            fontWeight: FontWeight.bold,
          ),
        ),
        content: Text(
          'All downloaded song files and offline cached artwork will be permanently deleted from your device storage.',
          style: TextStyle(
            color: isLight ? Colors.black87 : Colors.white70,
            fontSize: 13.5,
            height: 1.4,
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogCtx),
            child: Text(
              'Cancel',
              style: TextStyle(
                color: isLight ? Colors.black54 : Colors.white54,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.redAccent,
              foregroundColor: Colors.white,
              elevation: 0,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
            onPressed: () async {
              Navigator.pop(dialogCtx);
              await DownloadService.instance.clearAllDownloads();
              setState(() {
                _allTracks.removeWhere((t) =>
                    t.id.startsWith('local_ytm_') ||
                    t.path.contains('FleyDownloads'));
                _cachedDetailKey = null;
              });
              final prefs = await SharedPreferences.getInstance();
              final serialized = _allTracks.map((t) => t.toMap()).toList();
              await prefs.setString('cached_tracks_list', jsonEncode(serialized));
              setSheetState(() {});
              showFleyToast('All downloads cleared');
            },
            child: const Text('Delete', style: TextStyle(fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }
}
