// ignore_for_file: invalid_use_of_protected_member
part of '../main.dart';

extension _PlayerUI on _MainScreenState {
  Widget _buildMiniPlayer(Track currentTrack) {
    final double bottomInset = MediaQuery.of(context).padding.bottom;
    final isDetailView =
        _selectedPlaylistDetail != null ||
        _selectedArtistDetail != null ||
        _selectedAlbumDetail != null;
    final double navBarHeight = isDetailView ? 0.0 : 60.0;

    return Positioned(
      bottom: 0,
      left: 0,
      right: 0,
      child: GestureDetector(
        onTap: () => setState(() {
          _isPlayerOpen = true;
          _playerDragOffsetNotifier.value = 0.0;
        }),
        onVerticalDragStart: (details) {
          setState(() => _isPlayerOpen = true);
          _isDraggingPlayerNotifier.value = true;
          _playerDragOffsetNotifier.value = 1.0;
        },
        onVerticalDragUpdate: (details) {
          if (details.primaryDelta != null) {
            final newVal =
                _playerDragOffsetNotifier.value +
                details.primaryDelta! / MediaQuery.of(context).size.height;
            _playerDragOffsetNotifier.value = newVal.clamp(0.0, 1.0);
          }
        },
        onVerticalDragEnd: (details) {
          final offset = _playerDragOffsetNotifier.value;
          _isDraggingPlayerNotifier.value = false;
          if (offset < 0.85 || (details.primaryVelocity ?? 0) < -300) {
            _playerDragOffsetNotifier.value = 0.0;
            // already open, just snap to open position
          } else {
            _playerDragOffsetNotifier.value = 0.0;
            setState(() => _isPlayerOpen = false);
          }
        },
        onVerticalDragCancel: () {
          _isDraggingPlayerNotifier.value = false;
          _playerDragOffsetNotifier.value = 0.0;
          setState(() => _isPlayerOpen = false);
        },
        child: TweenAnimationBuilder<Color?>(
          tween: ColorTween(
            begin: const Color(0xFF161616),
            end: _dominantColor != null
                ? Color.lerp(const Color(0xFF161616), _dominantColor, 0.4)
                : const Color(0xFF161616),
          ),
          duration: const Duration(milliseconds: 500),
          builder: (context, Color? color, child) {
            return Container(
              height: 68,
              margin: EdgeInsets.only(
                left: 12,
                right: 12,
                bottom: navBarHeight + (bottomInset > 0 ? bottomInset + 4 : 12),
              ),
              decoration: BoxDecoration(
                color: color,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: Colors.white.withValues(alpha: 0.05)),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.25),
                    blurRadius: 16,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(14),
                child: Stack(
                  children: [
                    child!,
                    Positioned(
                      left: 0,
                      right: 0,
                      bottom: 0,
                      child: StreamBuilder<Duration>(
                        stream: _audioPlayer.positionStream,
                        builder: (context, snapshot) {
                          final pos = snapshot.data ?? _audioPlayer.position;
                          final total = currentTrack.duration > 0
                              ? currentTrack.duration
                              : (_audioPlayer.duration?.inMilliseconds ?? 1);
                          final progress =
                              (pos.inMilliseconds / total).clamp(0.0, 1.0);

                          return LinearProgressIndicator(
                            value: progress,
                            minHeight: 2.5,
                            backgroundColor: Colors.white.withValues(alpha: 0.08),
                            valueColor: AlwaysStoppedAnimation<Color>(_activeAccentColor),
                          );
                        },
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
          child: Row(
            children: [
              const SizedBox(width: 10),
              _buildTrackArtwork(
                currentTrack,
                size: 48,
                radius: 8,
                heroTag: "mini_to_full_player_artwork",
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      currentTrack.title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontWeight: FontWeight.w600,
                        fontSize: 14,
                        color: Colors.white,
                        fontFamily: getFontFamily(activeFontNotifier.value),
                      ),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      currentTrack.artist,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: Colors.white.withValues(alpha: 0.55),
                        fontSize: 12,
                        fontFamily: getFontFamily(activeFontNotifier.value),
                      ),
                    ),
                  ],
                ),
              ),
              IconButton(
                icon: const Icon(
                  Icons.skip_previous,
                  color: Colors.white,
                  size: 22,
                ),
                onPressed: () => _playPrevious(),
              ),
              _processingState == ProcessingState.loading
                  ? Padding(
                      padding: EdgeInsets.symmetric(horizontal: 12),
                      child: SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: _activeAccentColor,
                        ),
                      ),
                    )
                  : IconButton(
                      icon: Icon(
                        _isPlaying ? Icons.pause : Icons.play_arrow,
                        color: Colors.white,
                        size: 24,
                      ),
                      onPressed: () {
                        if (_isPlaying) {
                          _pauseWithFade();
                        } else {
                          _playWithFade();
                        }
                      },
                    ),
              IconButton(
                icon: const Icon(
                  Icons.skip_next,
                  color: Colors.white,
                  size: 22,
                ),
                onPressed: () => _playNext(),
              ),
              const SizedBox(width: 8),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildLyricsContent(Track currentTrack) {
    return _isLyricsLoading
        ? Center(child: CircularProgressIndicator(color: _activeAccentColor))
        : (_isLyricsSynced
              ? _buildSyncedLyricsList(currentTrack)
              : _buildPlainLyricsView(currentTrack));
  }

  Widget _buildSyncedLyricsList(Track currentTrack) {
    return ValueListenableBuilder<bool>(
      valueListenable: lyricsHidePastNotifier,
      builder: (context, hidePast, _) {
        return ValueListenableBuilder<bool>(
          valueListenable: lyricsAutoFollowNotifier,
          builder: (context, autoFollow, _) {
            return LayoutBuilder(
              builder: (context, constraints) {
                final double viewportHeight = constraints.maxHeight;
                final double itemHeight = 125.0;
                final double verticalPadding =
                    (viewportHeight / 2) - (itemHeight / 2);

                return NotificationListener<UserScrollNotification>(
                  onNotification: (notification) {
                    if (autoFollow &&
                        notification.direction != ScrollDirection.idle) {
                      if (!_lyricsUserScrolling) {
                        setState(() => _lyricsUserScrolling = true);
                      }
                      _lyricsResumeTimer?.cancel();
                      _lyricsResumeTimer = Timer(
                        const Duration(seconds: 4),
                        () {
                          if (!mounted) return;
                          setState(() {
                            _lyricsUserScrolling = false;
                          });
                        },
                      );
                    }
                    return false;
                  },
                  child: StreamBuilder<Duration>(
                    stream: _audioPlayer.positionStream,
                    builder: (context, snapshot) {
                      final position = snapshot.data ?? Duration.zero;

                      // Find activeIndex
                      int activeIndex = -1;
                      for (int i = 0; i < _currentLyricsSynced.length; i++) {
                        if (position >= _currentLyricsSynced[i].time) {
                          activeIndex = i;
                        } else {
                          break;
                        }
                      }

                      if (!_lyricsUserScrolling && autoFollow) {
                        WidgetsBinding.instance.addPostFrameCallback((_) {
                          if (_lyricsScrollController.hasClients &&
                              activeIndex != -1 &&
                              activeIndex != _lastActiveLyricsIndex) {
                            final bool isInitial = _lastActiveLyricsIndex == -1;
                            _lastActiveLyricsIndex = activeIndex;
                            final targetOffset = activeIndex * itemHeight;
                            final clampedOffset = targetOffset.clamp(
                              0.0,
                              _lyricsScrollController.position.maxScrollExtent,
                            );
                            if (isInitial) {
                              _lyricsScrollController.animateTo(
                                clampedOffset,
                                duration: const Duration(milliseconds: 900),
                                curve: Curves.easeOutCubic,
                              );
                            } else {
                              _lyricsScrollController.animateTo(
                                clampedOffset,
                                duration: const Duration(milliseconds: 600),
                                curve: Curves.easeOutCubic,
                              );
                            }
                          }
                        });
                      }

                      return ListView.builder(
                        controller: _lyricsScrollController,
                        physics: const BouncingScrollPhysics(),
                        padding: EdgeInsets.symmetric(
                          vertical: verticalPadding,
                        ),
                        itemCount: _currentLyricsSynced.length,
                        itemBuilder: (context, index) {
                          final line = _currentLyricsSynced[index];
                          final isHighlighted = index == activeIndex;
                          final rawText = line.text.trim();
                          final isEmptyLine =
                              rawText.isEmpty ||
                              rawText == '♪' ||
                              rawText.toLowerCase() == '[music]' ||
                              rawText.toLowerCase() == 'instrumental' ||
                              rawText.toLowerCase() == '(instrumental)';

                          // Past lines hidden while auto-following,
                          // all lines visible once the user scrolls manually.
                          double alpha;
                          if (_lyricsUserScrolling) {
                            alpha = isHighlighted ? 1.0 : 0.4;
                          } else if (hidePast && index < activeIndex) {
                            alpha = 0.0;
                          } else {
                            alpha = isHighlighted ? 1.0 : 0.4;
                          }
                          final Color textColor = Colors.white.withValues(
                            alpha: alpha,
                          );

                          return GestureDetector(
                            onTap: () {
                              if (_lyricsOpenedTime != null &&
                                  DateTime.now()
                                          .difference(_lyricsOpenedTime!)
                                          .inMilliseconds <
                                      350) {
                                return;
                              }
                              _smoothSeek(line.time);
                            },
                            child: SizedBox(
                              height: itemHeight,
                              child: Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 24.0,
                                  vertical: 6.0,
                                ),
                                alignment: Alignment.center,
                                color: Colors.transparent,
                                width: double.infinity,
                                child: AnimatedDefaultTextStyle(
                                  duration: const Duration(milliseconds: 350),
                                  curve: Curves.easeOutCubic,
                                  style: GoogleFonts.getFont(
                                    activeFontNotifier.value == 'Spotify Style'
                                        ? 'Figtree'
                                        : activeFontNotifier.value ==
                                              'Apple Music Style'
                                        ? 'Inter'
                                        : 'Plus Jakarta Sans',
                                    fontSize: _lyricFontSize,
                                    fontWeight: FontWeight.bold,
                                    color: textColor,
                                    height: 1.3,
                                  ),
                                  child: isEmptyLine
                                      ? AnimatedOpacity(
                                          opacity: alpha,
                                          duration: const Duration(
                                            milliseconds: 350,
                                          ),
                                          child: _WaveDots(
                                            isHighlighted: isHighlighted,
                                          ),
                                        )
                                      : Text(
                                          line.text,
                                          textAlign: TextAlign.center,
                                          maxLines: 3,
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                ),
                              ),
                            ),
                          );
                        },
                      );
                    },
                  ),
                );
              },
            );
          },
        );
      },
    );
  }

  Widget _buildPlainLyricsView(Track currentTrack) {
    final loc = AppLocalizations.of(context);
    if (_currentLyricsPlain == null || _currentLyricsPlain!.trim().isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.lyrics_outlined, color: Colors.white30, size: 48),
            const SizedBox(height: 12),
            Text(
              loc.noLyrics,
              style: const TextStyle(color: Colors.white54, fontSize: 14),
            ),
            const SizedBox(height: 16),
            ElevatedButton.icon(
              onPressed: () => _showManualLyricsEditor(currentTrack),
              icon: const Icon(Icons.add, size: 16),
              label: Text(loc.addLyricsManually),
              style: ElevatedButton.styleFrom(
                backgroundColor: _activeAccentColor,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
            ),
          ],
        ),
      );
    }

    return SingleChildScrollView(
      physics: const BouncingScrollPhysics(),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 24.0, horizontal: 24.0),
        child: Text(
          _currentLyricsPlain!,
          textAlign: TextAlign.center,
          style: GoogleFonts.getFont(
            activeFontNotifier.value == 'Spotify Style'
                ? 'Figtree'
                : activeFontNotifier.value == 'Apple Music Style'
                ? 'Inter'
                : 'Plus Jakarta Sans',
            fontSize: 20,
            height: 1.8,
            color: Colors.white.withValues(alpha: 0.85),
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
    );
  }

  void _showManualLyricsEditor(Track currentTrack) {
    final isLight = isAppLight;
    final loc = AppLocalizations.of(context);
    final textController = TextEditingController(
      text: _currentLyricsPlain ?? '',
    );
    double currentOffset = _lyricsOffsetSec;
    bool currentAutoWave = _lyricsAutoWave;

    SharedPreferences.getInstance().then((prefs) {
      final manualKey = 'lyrics_manual_${currentTrack.id}';
      if (prefs.containsKey(manualKey)) {
        textController.text = prefs.getString(manualKey) ?? '';
      } else {
        final cacheKey = 'lyrics_cache_${currentTrack.id}';
        if (prefs.containsKey(cacheKey)) {
          try {
            final data = jsonDecode(prefs.getString(cacheKey) ?? '');
            if (data['syncedLyrics'] != null) {
              textController.text = data['syncedLyrics'];
            } else if (data['plainLyrics'] != null) {
              textController.text = data['plainLyrics'];
            }
          } catch (_) {}
        }
      }
      final autoWaveKey = 'lyrics_autowave_${currentTrack.id}';
      if (prefs.containsKey(autoWaveKey)) {
        currentAutoWave = prefs.getBool(autoWaveKey) ?? lyricsAutoWaveNotifier.value;
      }
    });

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: isLight ? const Color(0xFFF6F8FA) : const Color(0xFF161616),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (sheetContext) {
        return StatefulBuilder(
          builder: (context, setModalState) {
            final isSynced = textController.text.contains(RegExp(r'\[\d{2}:\d{2}'));
            return SafeArea(
              child: Padding(
                padding: EdgeInsets.only(
                  left: 20.0,
                  right: 20.0,
                  top: 14.0,
                  bottom: MediaQuery.of(sheetContext).viewInsets.bottom + 16.0,
                ),
                child: SingleChildScrollView(
                  physics: const BouncingScrollPhysics(),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Center(
                        child: Container(
                          width: 40,
                          height: 4,
                          decoration: BoxDecoration(
                            color: isLight ? Colors.black12 : Colors.white24,
                            borderRadius: BorderRadius.circular(2),
                          ),
                        ),
                      ),
                      const SizedBox(height: 14),
                      Row(
                        children: [
                          _buildTrackArtwork(currentTrack, size: 40, radius: 8),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  loc.editLyrics,
                                  style: TextStyle(
                                    color: isLight ? const Color(0xFF1A1A1A) : Colors.white,
                                    fontSize: 17,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                                Text(
                                  '${currentTrack.title} • ${currentTrack.artist}',
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: TextStyle(
                                    color: isLight ? Colors.black54 : Colors.white54,
                                    fontSize: 12,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          FilledButton.icon(
                            onPressed: () async {
                              final navigator = Navigator.of(context);
                              final prefs = await SharedPreferences.getInstance();
                              final manualKey = 'lyrics_manual_${currentTrack.id}';
                              final text = textController.text.trim();
                              if (text.isEmpty) {
                                await prefs.remove(manualKey);
                              } else {
                                await prefs.setString(manualKey, text);
                              }
                              final offsetKey = 'lyrics_offset_${currentTrack.id}';
                              if (currentOffset == 0.0) {
                                await prefs.remove(offsetKey);
                              } else {
                                await prefs.setDouble(offsetKey, currentOffset);
                              }
                              final autoWaveKey = 'lyrics_autowave_${currentTrack.id}';
                              await prefs.setBool(autoWaveKey, currentAutoWave);
                              navigator.pop();
                              _loadLyricsForTrack(currentTrack);
                              showFleyToast(
                                lookupAppLocalizations(
                                  Locale(FleyStrings.currentLang),
                                ).toastLyricsUpdated,
                              );
                            },
                            icon: const Icon(Icons.check_rounded, size: 18),
                            label: Text(loc.save),
                            style: FilledButton.styleFrom(
                              backgroundColor: _activeAccentColor,
                              foregroundColor: Colors.white,
                              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 14),
                      SingleChildScrollView(
                        scrollDirection: Axis.horizontal,
                        physics: const BouncingScrollPhysics(),
                        child: Row(
                          children: [
                            OutlinedButton.icon(
                              onPressed: () async {
                                try {
                                  final result = await const MethodChannel(
                                    'com.fley.audio/equalizer',
                                  ).invokeMethod<String>('pickLyricsFile');
                                  if (result != null && result.isNotEmpty) {
                                    textController.text = result;
                                    setModalState(() {});
                                    showFleyToast(loc.toastLyricsUpdated);
                                  }
                                } catch (_) {}
                              },
                              icon: const Icon(Icons.file_open_rounded, size: 16),
                              label: Text(loc.importLrcFile),
                              style: OutlinedButton.styleFrom(
                                foregroundColor: _activeAccentColor,
                                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                                side: BorderSide(
                                  color: isLight ? Colors.black12 : Colors.white12,
                                ),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(10),
                                ),
                              ),
                            ),
                            const SizedBox(width: 8),
                            OutlinedButton.icon(
                              onPressed: () async {
                                final data = await Clipboard.getData(Clipboard.kTextPlain);
                                if (data?.text != null && data!.text!.isNotEmpty) {
                                  textController.text = data.text!;
                                  setModalState(() {});
                                }
                              },
                              icon: const Icon(Icons.content_paste_rounded, size: 16),
                              label: Text(loc.pasteFromClipboard),
                              style: OutlinedButton.styleFrom(
                                foregroundColor: _activeAccentColor,
                                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                                side: BorderSide(
                                  color: isLight ? Colors.black12 : Colors.white12,
                                ),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(10),
                                ),
                              ),
                            ),
                            const SizedBox(width: 8),
                            OutlinedButton.icon(
                              onPressed: () {
                                textController.clear();
                                setModalState(() {});
                              },
                              icon: const Icon(Icons.clear_all_rounded, size: 16),
                              label: Text(loc.clearLyrics),
                              style: OutlinedButton.styleFrom(
                                foregroundColor: _activeAccentColor,
                                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                                side: BorderSide(
                                  color: isLight ? Colors.black12 : Colors.white12,
                                ),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(10),
                                ),
                              ),
                            ),
                            const SizedBox(width: 8),
                            OutlinedButton.icon(
                              onPressed: () async {
                                final cleanTitle = currentTrack.title;
                                final cleanArtist = (currentTrack.artist.trim().isEmpty ||
                                        currentTrack.artist == '<unknown>' ||
                                        currentTrack.artist == loc.unknownArtist)
                                    ? ''
                                    : currentTrack.artist.trim();
                                final queryText = cleanArtist.isNotEmpty
                                    ? '$cleanArtist $cleanTitle lrc'
                                    : '$cleanTitle lrc';
                                final url = Uri.parse(
                                  'https://www.google.com/search?q=${Uri.encodeComponent(queryText)}',
                                );
                                if (await canLaunchUrl(url)) {
                                  await launchUrl(url, mode: LaunchMode.externalApplication);
                                }
                              },
                              icon: const Icon(Icons.travel_explore_rounded, size: 16),
                              label: Text(loc.searchLyricsOnline),
                              style: OutlinedButton.styleFrom(
                                foregroundColor: _activeAccentColor,
                                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                                side: BorderSide(
                                  color: isLight ? Colors.black12 : Colors.white12,
                                ),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(10),
                                ),
                              ),
                            ),
                            const SizedBox(width: 8),
                            OutlinedButton.icon(
                              onPressed: () {
                                setModalState(() {
                                  currentAutoWave = !currentAutoWave;
                                });
                              },
                              icon: Icon(
                                currentAutoWave
                                    ? Icons.more_horiz_rounded
                                    : Icons.do_not_disturb_on_outlined,
                                size: 16,
                                color: currentAutoWave
                                    ? _activeAccentColor
                                    : (isLight ? Colors.black45 : Colors.white38),
                              ),
                              label: Text(
                                currentAutoWave ? 'Auto 3-Dots: ON' : 'Auto 3-Dots: OFF',
                              ),
                              style: OutlinedButton.styleFrom(
                                foregroundColor: currentAutoWave
                                    ? _activeAccentColor
                                    : (isLight ? Colors.black54 : Colors.white60),
                                backgroundColor: currentAutoWave
                                    ? _activeAccentColor.withValues(alpha: 0.12)
                                    : Colors.transparent,
                                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                                side: BorderSide(
                                  color: currentAutoWave
                                      ? _activeAccentColor.withValues(alpha: 0.4)
                                      : (isLight ? Colors.black12 : Colors.white12),
                                ),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(10),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 12),
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: isLight
                              ? Colors.black.withValues(alpha: 0.04)
                              : Colors.white.withValues(alpha: 0.04),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                            color: isLight ? Colors.black12 : Colors.white10,
                          ),
                        ),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Row(
                              children: [
                                Icon(
                                  Icons.timer_outlined,
                                  size: 16,
                                  color: isLight ? Colors.black54 : Colors.white60,
                                ),
                                const SizedBox(width: 8),
                                Text(
                                  loc.lyricsOffsetLabel.replaceAll(':', '').trim(),
                                  style: TextStyle(
                                    color: isLight ? Colors.black87 : Colors.white70,
                                    fontSize: 13,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                                const Spacer(),
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                  decoration: BoxDecoration(
                                    color: _activeAccentColor.withValues(alpha: 0.15),
                                    borderRadius: BorderRadius.circular(6),
                                  ),
                                  child: Text(
                                    '${currentOffset >= 0 ? '+' : ''}${currentOffset.toStringAsFixed(1)}s',
                                    style: TextStyle(
                                      color: _activeAccentColor,
                                      fontSize: 12,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ),
                                if (currentOffset != 0.0) ...[
                                  const SizedBox(width: 6),
                                  InkWell(
                                    borderRadius: BorderRadius.circular(6),
                                    onTap: () => setModalState(() => currentOffset = 0.0),
                                    child: Tooltip(
                                      message: loc.resetOffset,
                                      child: Padding(
                                        padding: const EdgeInsets.all(2.0),
                                        child: Icon(
                                          Icons.refresh_rounded,
                                          size: 16,
                                          color: isLight ? Colors.black54 : Colors.white60,
                                        ),
                                      ),
                                    ),
                                  ),
                                ],
                              ],
                            ),
                            const SizedBox(height: 10),
                            Row(
                              children: [
                                for (final step in [-0.5, -0.1, 0.1, 0.5]) ...[
                                  if (step != -0.5) const SizedBox(width: 8),
                                  Expanded(
                                    child: InkWell(
                                      borderRadius: BorderRadius.circular(8),
                                      onTap: () {
                                        setModalState(() {
                                          currentOffset = double.parse(
                                            (currentOffset + step).toStringAsFixed(1),
                                          );
                                        });
                                      },
                                      child: Container(
                                        padding: const EdgeInsets.symmetric(vertical: 6),
                                        alignment: Alignment.center,
                                        decoration: BoxDecoration(
                                          color: isLight
                                              ? Colors.black.withValues(alpha: 0.06)
                                              : Colors.white.withValues(alpha: 0.08),
                                          borderRadius: BorderRadius.circular(8),
                                        ),
                                        child: Text(
                                          step > 0 ? '+${step.toStringAsFixed(1)}s' : '${step.toStringAsFixed(1)}s',
                                          style: TextStyle(
                                            color: isLight ? Colors.black87 : Colors.white,
                                            fontSize: 12,
                                            fontWeight: FontWeight.w600,
                                          ),
                                        ),
                                      ),
                                    ),
                                  ),
                                ],
                              ],
                            ),
                            const SizedBox(height: 12),
                            Divider(
                              height: 1,
                              color: isLight ? Colors.black12 : Colors.white10,
                            ),
                            const SizedBox(height: 10),
                            Row(
                              children: [
                                Icon(
                                  Icons.more_horiz_rounded,
                                  size: 18,
                                  color: isLight ? Colors.black54 : Colors.white60,
                                ),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        loc.lyricsAutoWave,
                                        style: TextStyle(
                                          color: isLight ? const Color(0xFF1A1A1A) : Colors.white,
                                          fontSize: 13,
                                          fontWeight: FontWeight.w600,
                                        ),
                                      ),
                                      Text(
                                        loc.lyricsAutoWaveSubtitle,
                                        style: TextStyle(
                                          color: isLight ? Colors.black54 : Colors.white38,
                                          fontSize: 11,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                InkWell(
                                  borderRadius: BorderRadius.circular(16),
                                  onTap: () {
                                    setModalState(() {
                                      currentAutoWave = !currentAutoWave;
                                    });
                                  },
                                  child: AnimatedContainer(
                                    duration: const Duration(milliseconds: 200),
                                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                                    decoration: BoxDecoration(
                                      color: currentAutoWave
                                          ? _activeAccentColor.withValues(alpha: 0.15)
                                          : (isLight ? Colors.black.withValues(alpha: 0.05) : Colors.white.withValues(alpha: 0.08)),
                                      borderRadius: BorderRadius.circular(16),
                                      border: Border.all(
                                        color: currentAutoWave
                                            ? _activeAccentColor.withValues(alpha: 0.5)
                                            : (isLight ? Colors.black12 : Colors.white12),
                                      ),
                                    ),
                                    child: Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        Icon(
                                          currentAutoWave ? Icons.check_circle_rounded : Icons.do_not_disturb_on_outlined,
                                          size: 13,
                                          color: currentAutoWave ? _activeAccentColor : (isLight ? Colors.black45 : Colors.white38),
                                        ),
                                        const SizedBox(width: 4),
                                        Text(
                                          currentAutoWave ? 'ON' : 'OFF',
                                          style: TextStyle(
                                            color: currentAutoWave ? _activeAccentColor : (isLight ? Colors.black54 : Colors.white60),
                                            fontSize: 11.5,
                                            fontWeight: FontWeight.bold,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 12),
                      TextField(
                        controller: textController,
                        maxLines: 9,
                        style: TextStyle(
                          color: isLight ? Colors.black87 : Colors.white,
                          fontSize: 13,
                          height: 1.4,
                          fontFamily: 'monospace',
                        ),
                        onChanged: (_) => setModalState(() {}),
                        decoration: InputDecoration(
                          hintText: loc.lyricsPasteHint,
                          hintStyle: TextStyle(
                            color: isLight ? Colors.black26 : Colors.white24,
                            fontSize: 12,
                          ),
                          filled: true,
                          fillColor: isLight
                              ? Colors.black.withValues(alpha: 0.03)
                              : Colors.white.withValues(alpha: 0.04),
                          contentPadding: const EdgeInsets.all(14),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(14),
                            borderSide: BorderSide(
                              color: isLight ? Colors.black12 : Colors.white10,
                            ),
                          ),
                          enabledBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(14),
                            borderSide: BorderSide(
                              color: isLight ? Colors.black12 : Colors.white10,
                            ),
                          ),
                          focusedBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(14),
                            borderSide: BorderSide(
                              color: _activeAccentColor,
                              width: 1.5,
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(height: 8),
                      Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                            decoration: BoxDecoration(
                              color: (isSynced ? _activeAccentColor : Colors.blueGrey)
                                  .withValues(alpha: 0.15),
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(
                                  isSynced ? Icons.sync_rounded : Icons.notes_rounded,
                                  size: 13,
                                  color: isSynced ? _activeAccentColor : Colors.blueGrey,
                                ),
                                const SizedBox(width: 4),
                                Text(
                                  isSynced ? loc.lrcSynced : loc.plainText,
                                  style: TextStyle(
                                    fontSize: 11,
                                    fontWeight: FontWeight.bold,
                                    color: isSynced ? _activeAccentColor : Colors.blueGrey,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const Spacer(),
                          Text(
                            '${textController.text.split('\n').where((l) => l.trim().isNotEmpty).length} ${loc.linesCountSuffix}',
                            style: TextStyle(
                              color: isLight ? Colors.black38 : Colors.white30,
                              fontSize: 11,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            );
          },
        );
      },
    );
  }

  String _formatDuration(Duration d) {
    String twoDigits(int n) => n.toString().padLeft(2, '0');
    final minutes = twoDigits(d.inMinutes.remainder(60));
    final seconds = twoDigits(d.inSeconds.remainder(60));
    return '$minutes:$seconds';
  }

  Widget _buildTrackArtwork(
    Track track, {
    double size = 48,
    double radius = 8,
    int? cacheWidthOverride,
    String? heroTag,
  }) {
    final customPath = _metadataOverrides[track.id]?['coverPath'];
    final artwork = CachedTrackArtwork(
      key: ValueKey("cached_artwork_${track.id}_$size"),
      trackId: track.id,
      size: size,
      radius: radius,
      customPath: customPath,
      cacheWidthOverride: cacheWidthOverride,
    );

    if (heroTag != null && heroTag.isNotEmpty) {
      return Hero(tag: heroTag, child: artwork);
    }
    return artwork;
  }

  Widget _buildFullScreenPlayer(Track currentTrack) {
    return Material(
      color: Colors.transparent,
      child: GestureDetector(
        onVerticalDragStart: (details) {
          _isDraggingPlayerNotifier.value = true;
        },
        onVerticalDragUpdate: (details) {
          if (details.primaryDelta != null) {
            final newVal =
                _playerDragOffsetNotifier.value +
                details.primaryDelta! / MediaQuery.of(context).size.height;
            _playerDragOffsetNotifier.value = newVal < 0 ? 0.0 : newVal;
          }
        },
        onVerticalDragEnd: (details) {
          final offset = _playerDragOffsetNotifier.value;
          _isDraggingPlayerNotifier.value = false;
          if (offset > 0.15 || (details.primaryVelocity ?? 0) > 300) {
            setState(() {
              _isPlayerOpen = false;
              _showLyrics = false;
            });
          } else {
            _playerDragOffsetNotifier.value = 0.0;
          }
        },
        onVerticalDragCancel: () {
          _isDraggingPlayerNotifier.value = false;
          _playerDragOffsetNotifier.value = 0.0;
        },
        child: Stack(
          children: [
            ValueListenableBuilder<String>(
              valueListenable: playerBackgroundStyleNotifier,
              builder: (context, style, child) {
                if (style == 'amoled') {
                  return Positioned.fill(
                    child: Container(color: const Color(0xFF000000)),
                  );
                } else if (style == 'blur') {
                  return Stack(
                    children: [
                      Positioned.fill(
                        child: Container(color: const Color(0xFF0A0A0A)),
                      ),
                      Positioned.fill(
                        child: ClipRect(
                          child: ImageFiltered(
                            imageFilter: ImageFilter.blur(
                              sigmaX: 45.0,
                              sigmaY: 45.0,
                            ),
                            child: Opacity(
                              opacity: 0.55,
                              child: Transform.scale(
                                scale: 2.2,
                                child: _buildTrackArtwork(
                                  currentTrack,
                                  size: 400,
                                  radius: 0,
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
                                Colors.black.withValues(alpha: 0.35),
                                Colors.black.withValues(alpha: 0.75),
                                Colors.black.withValues(alpha: 0.95),
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
                                  return Stack(
                                    children: [
                                      Positioned.fill(
                                        child: Container(
                                          color: const Color(0xFF0A0A0A),
                                        ),
                                      ),
                                      if (customPath != null &&
                                          File(customPath).existsSync())
                                        Positioned.fill(
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
                                      Positioned.fill(
                                        child: Container(
                                          decoration: BoxDecoration(
                                            gradient: LinearGradient(
                                              begin: Alignment.topCenter,
                                              end: Alignment.bottomCenter,
                                              colors: [
                                                Colors.black.withValues(
                                                  alpha: dimVal * 0.5,
                                                ),
                                                Colors.black.withValues(
                                                  alpha: dimVal * 1.2 > 1.0
                                                      ? 1.0
                                                      : dimVal * 1.2,
                                                ),
                                                Colors.black.withValues(
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
                  return Positioned.fill(
                    child: TweenAnimationBuilder<Color?>(
                      tween: ColorTween(
                        begin: const Color(0xFF1E1E1E),
                        end: _dominantColor ?? const Color(0xFF1E1E1E),
                      ),
                      duration: const Duration(milliseconds: 800),
                      builder: (context, Color? color, child) {
                        return Container(
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              begin: Alignment.topCenter,
                              end: Alignment.bottomCenter,
                              colors: [
                                color ?? const Color(0xFF1E1E1E),
                                color != null
                                    ? Color.lerp(color, Colors.black, 0.85)!
                                    : const Color(0xFF0A0A0A),
                              ],
                            ),
                          ),
                        );
                      },
                    ),
                  );
                }
              },
            ),

            SafeArea(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 24.0),
                child: Column(
                  children: [
                    const SizedBox(height: 8),
                    Container(
                      width: 40,
                      height: 4,
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(10),
                      ),
                    ),
                    const SizedBox(height: 16),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        IconButton(
                          icon: const Icon(
                            Icons.keyboard_arrow_down,
                            color: Colors.white54,
                            size: 28,
                          ),
                          onPressed: () => setState(() {
                            _isPlayerOpen = false;
                            _showLyrics = false;
                          }),
                        ),
                        Expanded(
                          child: AnimatedSwitcher(
                            duration: const Duration(milliseconds: 300),
                            child: _showLyrics
                                ? Column(
                                    key: const ValueKey('lyrics_header'),
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Text(
                                        AppLocalizations.of(
                                          context,
                                        ).lyrics.toUpperCase(),
                                        textAlign: TextAlign.center,
                                        style: const TextStyle(
                                          fontWeight: FontWeight.w600,
                                          fontSize: 10,
                                          color: Colors.white38,
                                          letterSpacing: 1.5,
                                        ),
                                      ),
                                      const SizedBox(height: 2),
                                      Text(
                                        currentTrack.title,
                                        textAlign: TextAlign.center,
                                        style: const TextStyle(
                                          fontWeight: FontWeight.bold,
                                          fontSize: 14,
                                          color: Colors.white,
                                        ),
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                    ],
                                  )
                                : ValueListenableBuilder<int>(
                                    key: const ValueKey('player_header'),
                                    valueListenable: _sleepTimerNotifier,
                                    builder: (context, remaining, child) {
                                      if (remaining > 0) {
                                        final mins = (remaining / 60)
                                            .floor()
                                            .toString()
                                            .padLeft(2, '0');
                                        final secs = (remaining % 60)
                                            .toString()
                                            .padLeft(2, '0');
                                        return Text(
                                          '${AppLocalizations.of(context).stopsIn.toUpperCase()} $mins:$secs',
                                          textAlign: TextAlign.center,
                                          style: TextStyle(
                                            fontWeight: FontWeight.w600,
                                            fontSize: 13,
                                            color: _activeAccentColor,
                                            letterSpacing: 1.5,
                                          ),
                                        );
                                      }
                                      String typeLabel;
                                      if (_playingFromType == 'PLAYLIST') {
                                        typeLabel = AppLocalizations.of(
                                          context,
                                        ).playlists;
                                      } else if (_playingFromType == 'ARTIST') {
                                        typeLabel = AppLocalizations.of(
                                          context,
                                        ).artists;
                                      } else if (_playingFromType == 'ALBUM') {
                                        typeLabel = AppLocalizations.of(
                                          context,
                                        ).albums;
                                      } else {
                                        typeLabel = AppLocalizations.of(
                                          context,
                                        ).library;
                                      }

                                      String displayName = _playingFromName;
                                      if (_playingFromName == 'All Songs' ||
                                          _playingFromName == 'All Tracks') {
                                        displayName = AppLocalizations.of(
                                          context,
                                        ).allSongs;
                                      } else if (_playingFromName ==
                                              'Favourites' ||
                                          _playingFromName ==
                                              'Favorite Songs') {
                                        displayName = AppLocalizations.of(
                                          context,
                                        ).favourites;
                                      } else if (_playingFromName ==
                                          'Recently Added') {
                                        displayName = AppLocalizations.of(
                                          context,
                                        ).recentlyAdded;
                                      } else if (_playingFromName ==
                                          'Most Played') {
                                        displayName = AppLocalizations.of(
                                          context,
                                        ).mostPlayed;
                                      } else if (_playingFromName ==
                                          'Forgotten Gems') {
                                        displayName = AppLocalizations.of(
                                          context,
                                        ).forgottenGems;
                                      } else if (_playingFromName ==
                                          'Last Played') {
                                        displayName = AppLocalizations.of(
                                          context,
                                        ).lastPlayed;
                                      }

                                      return Column(
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          Text(
                                            '${AppLocalizations.of(context).playingFrom.toUpperCase()} ${typeLabel.toUpperCase()}',
                                            textAlign: TextAlign.center,
                                            style: const TextStyle(
                                              fontWeight: FontWeight.w600,
                                              fontSize: 10,
                                              color: Colors.white38,
                                              letterSpacing: 1.5,
                                            ),
                                          ),
                                          const SizedBox(height: 2),
                                          Text(
                                            displayName,
                                            textAlign: TextAlign.center,
                                            style: const TextStyle(
                                              fontWeight: FontWeight.bold,
                                              fontSize: 14,
                                              color: Colors.white,
                                            ),
                                            maxLines: 1,
                                            overflow: TextOverflow.ellipsis,
                                          ),
                                        ],
                                      );
                                    },
                                  ),
                          ),
                        ),
                        AnimatedSwitcher(
                          duration: const Duration(milliseconds: 200),
                          child: _showLyrics
                              ? IconButton(
                                  key: const ValueKey('edit_lyrics_btn'),
                                  icon: const Icon(
                                    Icons.edit_note_rounded,
                                    color: Colors.white70,
                                    size: 26,
                                  ),
                                  tooltip: 'Edit Lyrics',
                                  onPressed: () =>
                                      _showManualLyricsEditor(currentTrack),
                                )
                              : IconButton(
                                  key: const ValueKey('more_vert_btn'),
                                  icon: const Icon(
                                    Icons.more_vert,
                                    color: Colors.white54,
                                  ),
                                  onPressed: () => _showTrackOptions(
                                    context,
                                    currentTrack,
                                    isFromPlayer: true,
                                  ),
                                ),
                        ),
                      ],
                    ),

                    Expanded(
                      child: Stack(
                        children: [
                          AnimatedOpacity(
                            opacity: _showLyrics ? 0.0 : 1.0,
                            duration: const Duration(milliseconds: 350),
                            curve: Curves.easeInOut,
                            child: IgnorePointer(
                              ignoring: _showLyrics,
                              child: GestureDetector(
                                onTap: () {
                                  setState(() {
                                    _showLyrics = true;
                                    _lastActiveLyricsIndex = -1;
                                    _lyricsUserScrolling = false;
                                    _lyricsOpenedTime = DateTime.now();
                                  });
                                  _loadLyricsForTrack(currentTrack);
                                },
                                child: AnimatedScale(
                                  scale: _isPlayerOpen ? 1.0 : 0.35,
                                  duration: const Duration(milliseconds: 380),
                                  curve: Curves.easeOutQuint,
                                  alignment: const Alignment(-0.85, 0.95),
                                  child: Center(
                                    child: Padding(
                                      padding: const EdgeInsets.symmetric(
                                        vertical: 12.0,
                                      ),
                                      child: AspectRatio(
                                        aspectRatio: 1.0,
                                        child: Container(
                                          decoration: BoxDecoration(
                                            borderRadius: BorderRadius.circular(
                                              24,
                                            ),
                                            boxShadow: [
                                              BoxShadow(
                                                color: Colors.black.withValues(
                                                  alpha: 0.45,
                                                ),
                                                blurRadius: 35,
                                                offset: const Offset(0, 12),
                                              ),
                                            ],
                                          ),
                                          child: ClipRRect(
                                            borderRadius: BorderRadius.circular(
                                              24,
                                            ),
                                            child: _buildTrackArtwork(
                                              currentTrack,
                                              size:
                                                  MediaQuery.of(
                                                    context,
                                                  ).size.width *
                                                  0.85,
                                              radius: 24,
                                            ),
                                          ),
                                        ),
                                      ),
                                    ),
                                  ),
                                ),
                              ),
                            ),
                          ),

                          AnimatedOpacity(
                            opacity: _showLyrics ? 1.0 : 0.0,
                            duration: const Duration(milliseconds: 350),
                            curve: Curves.easeInOut,
                            child: IgnorePointer(
                              ignoring: !_showLyrics,
                              child: Padding(
                                padding: const EdgeInsets.symmetric(
                                  vertical: 12.0,
                                ),
                                child: _buildLyricsContent(currentTrack),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),

                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                currentTrack.title,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(
                                  fontSize: 20,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.white,
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                currentTrack.artist,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(
                                  fontSize: 15,
                                  color: Colors.white.withValues(alpha: 0.4),
                                ),
                              ),
                            ],
                          ),
                        ),
                        IconButton(
                          icon: Icon(
                            _favoriteTrackIds.contains(currentTrack.id)
                                ? Icons.favorite
                                : Icons.favorite_border,
                            color: _favoriteTrackIds.contains(currentTrack.id)
                                ? _activeAccentColor
                                : Colors.white60,
                            size: 26,
                          ),
                          onPressed: () {
                            final wasFavorited = _favoriteTrackIds.contains(
                              currentTrack.id,
                            );
                            _toggleFavorite(currentTrack.id);
                            if (wasFavorited) {
                              final loc = lookupAppLocalizations(
                                Locale(FleyStrings.currentLang),
                              );
                              if (_playingFromName == loc.favourites) {
                                _removeFromQueueAndPlayer(currentTrack.id);
                              }
                            }
                          },
                        ),
                      ],
                    ),
                    const SizedBox(height: 18),

                    StreamBuilder<Duration>(
                      stream: _audioPlayer.positionStream,
                      builder: (context, snapshot) {
                        final duration = _audioPlayer.duration ?? Duration.zero;
                        final currentPosition = snapshot.data ?? Duration.zero;

                        return StatefulBuilder(
                          builder: (context, setLocalState) {
                            final displayValue =
                                _dragValue ??
                                (duration.inMilliseconds > 0
                                    ? (currentPosition.inMilliseconds /
                                              duration.inMilliseconds)
                                          .clamp(0.0, 1.0)
                                    : 0.0);

                            final displayPosition = Duration(
                              milliseconds:
                                  (displayValue * duration.inMilliseconds)
                                      .toInt(),
                            );

                            return Column(
                              children: [
                                SliderTheme(
                                  data: SliderTheme.of(context).copyWith(
                                    trackShape: const CustomTrackShape(),
                                    trackHeight: 2.5,
                                    thumbShape: const RoundSliderThumbShape(
                                      enabledThumbRadius: 3,
                                    ),
                                    activeTrackColor: Colors.white70,
                                    inactiveTrackColor: Colors.white.withValues(
                                      alpha: 0.1,
                                    ),
                                    overlayColor: Colors.transparent,
                                    thumbColor: Colors.white,
                                  ),
                                  child: Slider(
                                    value: displayValue,
                                    onChangeStart: (val) {
                                      setLocalState(() {
                                        _dragValue = val;
                                      });
                                    },
                                    onChanged: (val) {
                                      setLocalState(() {
                                        _dragValue = val;
                                      });
                                    },
                                    onChangeEnd: (val) {
                                      final newPosition = Duration(
                                        milliseconds:
                                            (val * duration.inMilliseconds)
                                                .toInt(),
                                      );
                                      _smoothSeek(newPosition);
                                      _dragValue = null;
                                    },
                                  ),
                                ),
                                Padding(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 4.0,
                                  ),
                                  child: Row(
                                    mainAxisAlignment:
                                        MainAxisAlignment.spaceBetween,
                                    children: [
                                      Text(
                                        _formatDuration(displayPosition),
                                        style: TextStyle(
                                          color: Colors.white.withValues(
                                            alpha: 0.3,
                                          ),
                                          fontSize: 11,
                                        ),
                                      ),
                                      Text(
                                        '-${_formatDuration(duration - displayPosition)}',
                                        style: TextStyle(
                                          color: Colors.white.withValues(
                                            alpha: 0.3,
                                          ),
                                          fontSize: 11,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            );
                          },
                        );
                      },
                    ),
                    const SizedBox(height: 8),

                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                      children: [
                        IconButton(
                          icon: const Icon(
                            Icons.fast_rewind,
                            color: Colors.white,
                            size: 30,
                          ),
                          onPressed: () {
                            _playPrevious();
                          },
                        ),
                        GestureDetector(
                          onTap: () {
                            if (_processingState == ProcessingState.loading) {
                              return;
                            }
                            if (_isPlaying) {
                              _pauseWithFade();
                            } else {
                              _playWithFade();
                            }
                          },
                          child: Container(
                            width: 64,
                            height: 64,
                            decoration: const BoxDecoration(
                              color: Colors.white,
                              shape: BoxShape.circle,
                            ),
                            child: _processingState == ProcessingState.loading
                                ? const Center(
                                    child: SizedBox(
                                      width: 24,
                                      height: 24,
                                      child: CircularProgressIndicator(
                                        strokeWidth: 2.5,
                                        color: Colors.black,
                                      ),
                                    ),
                                  )
                                : Icon(
                                    _isPlaying ? Icons.pause : Icons.play_arrow,
                                    color: Colors.black,
                                    size: 32,
                                  ),
                          ),
                        ),
                        IconButton(
                          icon: const Icon(
                            Icons.fast_forward,
                            color: Colors.white,
                            size: 30,
                          ),
                          onPressed: () {
                            _playNext();
                          },
                        ),
                      ],
                    ),

                    const SizedBox(height: 16),

                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Stack(
                          alignment: Alignment.center,
                          children: [
                            IconButton(
                              icon: Icon(
                                Icons.lyrics_outlined,
                                color: _showLyrics
                                    ? _activeAccentColor
                                    : Colors.white54,
                                size: 20,
                              ),
                              onPressed: () {
                                setState(() {
                                  _showLyrics = !_showLyrics;
                                  if (_showLyrics) {
                                    _lastActiveLyricsIndex = -1;
                                    _lyricsUserScrolling = false;
                                    _lyricsOpenedTime = DateTime.now();
                                  }
                                });
                                if (_showLyrics) {
                                  _loadLyricsForTrack(currentTrack);
                                }
                              },
                            ),
                            if (_showLyrics)
                              Positioned(
                                bottom: 10,
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
                        Stack(
                          alignment: Alignment.center,
                          children: [
                            IconButton(
                              icon: Icon(
                                Icons.shuffle,
                                color: _isShuffle
                                    ? _activeAccentColor
                                    : Colors.white54,
                                size: 20,
                              ),
                              onPressed: () {
                                setState(() {
                                  _isShuffle = !_isShuffle;
                                  if (_isShuffle) {
                                    _shuffledIndices = List.generate(
                                      _playbackQueue.length,
                                      (i) => i,
                                    );
                                    _shuffledIndices.shuffle();
                                    _shuffledIndices.remove(_currentIndex);
                                    _shuffledIndices.insert(0, _currentIndex);
                                  }
                                });
                                _refreshAudioSourceWindow();
                              },
                            ),
                            if (_isShuffle)
                              Positioned(
                                bottom: 10,
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
                        Stack(
                          alignment: Alignment.center,
                          children: [
                            IconButton(
                              icon: Icon(
                                _repeatMode == 2
                                    ? Icons.repeat_one
                                    : Icons.repeat,
                                color: _repeatMode != 0
                                    ? _activeAccentColor
                                    : Colors.white54,
                                size: 20,
                              ),
                              onPressed: _toggleRepeatMode,
                            ),
                            if (_repeatMode != 0)
                              Positioned(
                                bottom: 10,
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
                        IconButton(
                          icon: const Icon(
                            Icons.playlist_play,
                            color: Colors.white54,
                            size: 20,
                          ),
                          onPressed: () => _showQueueBottomSheet(),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _WaveDots extends StatefulWidget {
  final bool isHighlighted;

  const _WaveDots({required this.isHighlighted});

  @override
  _WaveDotsState createState() => _WaveDotsState();
}

class _WaveDotsState extends State<_WaveDots>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    );
    if (widget.isHighlighted) {
      _controller.repeat();
    }
  }

  @override
  void didUpdateWidget(covariant _WaveDots oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.isHighlighted && !oldWidget.isHighlighted) {
      _controller.repeat();
    } else if (!widget.isHighlighted && oldWidget.isHighlighted) {
      _controller.stop();
      _controller.animateTo(0, duration: const Duration(milliseconds: 300));
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
      builder: (context, child) {
        return Row(
          mainAxisSize: MainAxisSize.min,
          children: List.generate(3, (index) {
            final delay = index * (pi / 2.5);
            final t = (_controller.value * 2 * pi) + delay;
            final offset = widget.isHighlighted ? sin(t) * 6.0 : 0.0;

            return Transform.translate(
              offset: Offset(0, offset),
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 4.0),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 350),
                  width: widget.isHighlighted ? 10.0 : 8.0,
                  height: widget.isHighlighted ? 10.0 : 8.0,
                  decoration: BoxDecoration(
                    color: widget.isHighlighted
                        ? Colors.white
                        : Colors.white.withValues(alpha: 0.35),
                    shape: BoxShape.circle,
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

class CachedTrackArtwork extends StatefulWidget {
  final String trackId;
  final double size;
  final double radius;
  final String? customPath;
  final int? cacheWidthOverride;

  const CachedTrackArtwork({
    super.key,
    required this.trackId,
    this.size = 48,
    this.radius = 8,
    this.customPath,
    this.cacheWidthOverride,
  });

  @override
  State<CachedTrackArtwork> createState() => _CachedTrackArtworkState();
}

class _CachedTrackArtworkState extends State<CachedTrackArtwork> {
  Uint8List? _bytes;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void didUpdateWidget(CachedTrackArtwork oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.trackId != oldWidget.trackId ||
        widget.customPath != oldWidget.customPath) {
      _load();
    }
  }

  void _load() {
    if (widget.size > 200) {
      return;
    }

    if (widget.customPath != null && widget.customPath!.isNotEmpty) {
      _bytes = null;
      return;
    }

    final cached = ArtworkCacheManager.getCachedArtwork(widget.trackId);
    if (cached != null) {
      _bytes = cached;
      return;
    }

    ArtworkCacheManager.fetchAndCacheNativeArtwork(widget.trackId).then((
      bytes,
    ) {
      if (mounted && bytes != null) {
        setState(() {
          _bytes = bytes;
        });
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    if (_bytes != null) {
      return Container(
        width: widget.size,
        height: widget.size,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(widget.radius),
          image: DecorationImage(
            image: MemoryImage(_bytes!),
            fit: BoxFit.cover,
          ),
        ),
      );
    }

    if (widget.customPath != null && widget.customPath!.isNotEmpty) {
      final ImageProvider customImageProvider = widget.size > 100
          ? FileImage(File(widget.customPath!))
          : (widget.cacheWidthOverride != null
                ? ResizeImage(
                    FileImage(File(widget.customPath!)),
                    width: widget.cacheWidthOverride!,
                  )
                : ResizeImage(FileImage(File(widget.customPath!)), width: 300));
      return Container(
        width: widget.size,
        height: widget.size,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(widget.radius),
          image: DecorationImage(
            image: customImageProvider,
            fit: BoxFit.cover,
            filterQuality: FilterQuality.high,
          ),
        ),
      );
    }

    if (widget.size <= 200) {
      return Container(
        width: widget.size,
        height: widget.size,
        decoration: BoxDecoration(
          color: Colors.white10,
          borderRadius: BorderRadius.circular(widget.radius),
        ),
        child: const Icon(Icons.music_note, color: Colors.white54),
      );
    }

    final trackIdInt = int.tryParse(widget.trackId);
    if (trackIdInt == null) {
      return Container(
        width: widget.size,
        height: widget.size,
        decoration: BoxDecoration(
          color: Colors.white10,
          borderRadius: BorderRadius.circular(widget.radius),
        ),
        child: const Icon(Icons.music_note, color: Colors.white54),
      );
    }

    return ClipRRect(
      borderRadius: BorderRadius.circular(widget.radius),
      child: QueryArtworkWidget(
        id: trackIdInt,
        type: ArtworkType.AUDIO,
        artworkWidth: widget.size,
        artworkHeight: widget.size,
        artworkBorder: BorderRadius.circular(widget.radius),
        artworkFit: BoxFit.cover,
        keepOldArtwork: true,
        size: 500,
        quality: 70,
        artworkQuality: FilterQuality.low,
        nullArtworkWidget: Container(
          width: widget.size,
          height: widget.size,
          decoration: BoxDecoration(
            color: Colors.white10,
            borderRadius: BorderRadius.circular(widget.radius),
          ),
          child: const Icon(Icons.music_note, color: Colors.white54),
        ),
      ),
    );
  }
}
