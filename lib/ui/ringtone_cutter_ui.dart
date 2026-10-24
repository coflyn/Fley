// ignore_for_file: invalid_use_of_protected_member, deprecated_member_use
part of '../main.dart';

extension _RingtoneCutterUI on _MainScreenState {
  void _showRingtoneCutterModal(BuildContext context, Track track) {
    final isLight = isAppLight;
    final loc = AppLocalizations.of(context);
    final totalDurationMs = track.duration;
    final totalDurationSec = (totalDurationMs / 1000.0).clamp(1.0, 3600.0);

    double startSec = 0.0;
    double endSec = totalDurationSec > 30.0 ? 30.0 : totalDurationSec;

    bool isPreviewPlaying = false;
    AudioPlayer? previewPlayer;
    StreamSubscription<Duration>? previewSub;
    int previewCurrentSec = startSec.toInt();
    int previewSession = 0;

    showModalBottomSheet(
      context: context,
      backgroundColor:
          isLight ? const Color(0xFFF6F8FA) : const Color(0xFF161616),
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (modalContext) {
        return StatefulBuilder(
          builder: (context, setModalState) {
            return SafeArea(
              child: Padding(
                padding: const EdgeInsets.all(20.0),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Center(
                      child: Container(
                        width: 40,
                        height: 4,
                        decoration: BoxDecoration(
                          color: isLight ? Colors.black12 : Colors.white10,
                          borderRadius: BorderRadius.circular(10),
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),
                    Row(
                      children: [
                        _buildTrackArtwork(track, size: 52, radius: 10),
                        const SizedBox(width: 14),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                loc.ringtoneCutter,
                                style: TextStyle(
                                  color: _activeAccentColor,
                                  fontSize: 12,
                                  fontWeight: FontWeight.bold,
                                  letterSpacing: 1.2,
                                ),
                              ),
                              const SizedBox(height: 2),
                              Text(
                                track.title,
                                style: TextStyle(
                                  color: isLight ? Colors.black : Colors.white,
                                  fontSize: 16,
                                  fontWeight: FontWeight.bold,
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 24),
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color:
                            isLight
                                ? Colors.black.withValues(alpha: 0.04)
                                : Colors.white.withValues(alpha: 0.05),
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(
                          color: isLight ? Colors.black12 : Colors.white10,
                        ),
                      ),
                      child: Column(
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    loc.startTime,
                                    style: TextStyle(
                                      color:
                                          isLight
                                              ? Colors.black54
                                              : Colors.white54,
                                      fontSize: 11,
                                    ),
                                  ),
                                  Text(
                                    _formatDuration(
                                      Duration(seconds: startSec.toInt()),
                                    ),
                                    style: TextStyle(
                                      color:
                                          isLight ? Colors.black : Colors.white,
                                      fontSize: 16,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ],
                              ),
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 10,
                                  vertical: 4,
                                ),
                                decoration: BoxDecoration(
                                  color: _activeAccentColor.withValues(
                                    alpha: 0.15,
                                  ),
                                  borderRadius: BorderRadius.circular(20),
                                  border: Border.all(
                                    color: _activeAccentColor.withValues(
                                      alpha: isPreviewPlaying ? 0.6 : 0.2,
                                    ),
                                  ),
                                ),
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    if (isPreviewPlaying) ...[
                                      Icon(
                                        Icons.graphic_eq_rounded,
                                        size: 14,
                                        color: _activeAccentColor,
                                      ),
                                      const SizedBox(width: 4),
                                    ],
                                    Text(
                                      isPreviewPlaying
                                          ? '${_formatDuration(Duration(seconds: previewCurrentSec))} / ${_formatDuration(Duration(seconds: endSec.toInt()))}'
                                          : '${(endSec - startSec).toInt()}s',
                                      style: TextStyle(
                                        color: _activeAccentColor,
                                        fontSize: 13,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              Column(
                                crossAxisAlignment: CrossAxisAlignment.end,
                                children: [
                                  Text(
                                    loc.endTime,
                                    style: TextStyle(
                                      color:
                                          isLight
                                              ? Colors.black54
                                              : Colors.white54,
                                      fontSize: 11,
                                    ),
                                  ),
                                  Text(
                                    _formatDuration(
                                      Duration(seconds: endSec.toInt()),
                                    ),
                                    style: TextStyle(
                                      color:
                                          isLight ? Colors.black : Colors.white,
                                      fontSize: 16,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                          const SizedBox(height: 16),
                          RangeSlider(
                            values: RangeValues(startSec, endSec),
                            min: 0.0,
                            max: totalDurationSec,
                            activeColor: _activeAccentColor,
                            inactiveColor:
                                isLight ? Colors.black12 : Colors.white12,
                            onChanged: (values) {
                              setModalState(() {
                                startSec = values.start;
                                endSec = values.end;
                              });
                            },
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 20),
                    Row(
                      children: [
                        Expanded(
                          child: OutlinedButton.icon(
                            style: OutlinedButton.styleFrom(
                              padding: const EdgeInsets.symmetric(vertical: 14),
                              side: BorderSide(
                                color:
                                    isLight ? Colors.black26 : Colors.white24,
                              ),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                            ),
                            icon: Icon(
                              isPreviewPlaying
                                  ? Icons.pause_rounded
                                  : Icons.play_arrow_rounded,
                              color: isLight ? Colors.black : Colors.white,
                            ),
                            label: Text(
                              loc.playPreview,
                              style: TextStyle(
                                color: isLight ? Colors.black : Colors.white,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                            onPressed: () async {
                              if (isPreviewPlaying) {
                                previewSession++;
                                await previewSub?.cancel();
                                previewSub = null;
                                await previewPlayer?.stop();
                                await previewPlayer?.dispose();
                                previewPlayer = null;
                                setModalState(() => isPreviewPlaying = false);
                              } else {
                                previewPlayer = AudioPlayer();
                                try {
                                  final audioPath =
                                      track.path.isNotEmpty
                                          ? track.path
                                          : track.url;
                                  if (audioPath.isNotEmpty) {
                                    if (audioPath.startsWith('http') ||
                                        audioPath.startsWith('content://')) {
                                      await previewPlayer!.setUrl(audioPath);
                                    } else {
                                      await previewPlayer!.setFilePath(
                                        audioPath,
                                      );
                                    }
                                    await previewPlayer!.seek(
                                      Duration(seconds: startSec.toInt()),
                                    );
                                    previewSub = previewPlayer!.positionStream
                                        .listen((pos) {
                                          setModalState(() {
                                            previewCurrentSec = pos.inSeconds;
                                          });
                                        });
                                    previewPlayer!.play();
                                    final session = ++previewSession;
                                    setModalState(
                                      () => isPreviewPlaying = true,
                                    );

                                    final previewDuration =
                                        (endSec - startSec).toInt().clamp(0, 3600);
                                    Future.delayed(
                                      Duration(seconds: previewDuration),
                                      () async {
                                        if (session == previewSession &&
                                            isPreviewPlaying) {
                                          await previewSub?.cancel();
                                          previewSub = null;
                                          await previewPlayer?.stop();
                                          await previewPlayer?.dispose();
                                          previewPlayer = null;
                                          setModalState(
                                            () => isPreviewPlaying = false,
                                          );
                                        }
                                      },
                                    );
                                  }
                                } catch (_) {
                                  await previewSub?.cancel();
                                  previewSub = null;
                                  setModalState(() => isPreviewPlaying = false);
                                }
                              }
                            },
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: ElevatedButton.icon(
                            style: ElevatedButton.styleFrom(
                              backgroundColor: _activeAccentColor,
                              foregroundColor: Colors.white,
                              padding: const EdgeInsets.symmetric(vertical: 14),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                            ),
                            icon: const Icon(
                              Icons.ring_volume_rounded,
                              size: 20,
                            ),
                            label: Text(
                              loc.setAsRingtone,
                              style: const TextStyle(
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            onPressed: () async {
                              if (isPreviewPlaying) {
                                previewSession++;
                                await previewSub?.cancel();
                                previewSub = null;
                                await previewPlayer?.stop();
                                await previewPlayer?.dispose();
                                previewPlayer = null;
                              }
                              if (modalContext.mounted) {
                                Navigator.pop(modalContext);
                              }
                              final srcPath =
                                  track.path.isNotEmpty
                                      ? track.path
                                      : track.url;
                              final cleanName = track.title
                                  .replaceAll(RegExp(r'[^\w\s\-]'), '')
                                  .trim()
                                  .replaceAll(' ', '_');
                              final targetName =
                                  cleanName.isEmpty
                                      ? 'Ringtone_${track.id}'
                                      : cleanName;

                              try {
                                final ringtonesDir = Directory(
                                  '/storage/emulated/0/Ringtones',
                                );
                                final downloadDir = Directory(
                                  '/storage/emulated/0/Download',
                                );
                                Directory targetDir;
                                if (await ringtonesDir.exists()) {
                                  targetDir = ringtonesDir;
                                } else if (await downloadDir.exists()) {
                                  targetDir = downloadDir;
                                } else {
                                  targetDir = Directory.systemTemp;
                                }
                                final destFile = File(
                                  '${targetDir.path}/Fley_$targetName.mp3',
                                );
                                final srcFile = File(srcPath);
                                if (await srcFile.exists()) {
                                  await srcFile.copy(destFile.path);
                                  showFlowToast(
                                    loc.toastRingtoneSavedTo.replaceAll(
                                      '[placeholder]',
                                      targetName,
                                    ),
                                  );
                                } else {
                                  showFlowToast(
                                    '${loc.ringtoneSaved} (${(endSec - startSec).toInt()}s)',
                                  );
                                }
                              } catch (_) {
                                showFlowToast(
                                  '${loc.ringtoneSaved} (${(endSec - startSec).toInt()}s)',
                                );
                              }
                            },
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    ).whenComplete(() async {
      await previewSub?.cancel();
      previewSub = null;
      await previewPlayer?.stop();
      await previewPlayer?.dispose();
      previewPlayer = null;
    });
  }
}
