// ignore_for_file: library_private_types_in_public_api, deprecated_member_use, invalid_use_of_protected_member
part of 'settings_screen.dart';

extension SettingsHiddenTracksModals on _SettingsScreenState {
  Future<void> _showHiddenTracksSheet(BuildContext context) {
    final isLight = isAppLight;
    return showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: isLight
          ? const Color(0xFFF0F0F3)
          : const Color(0xFF161616),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setModalState) {
            return FutureBuilder<List<SongModel>>(
              future: _songsFuture,
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return SizedBox(
                    height: 400,
                    child: Center(
                      child: CircularProgressIndicator(
                        valueColor: AlwaysStoppedAnimation<Color>(
                          _activeAccentColor,
                        ),
                      ),
                    ),
                  );
                }

                final allSongs = snapshot.data ?? [];
                final List<SongModel> displaySongs =
                    allSongs.where((song) {
                      final bool isManuallyHidden = _hiddenTrackIds.contains(
                        song.id.toString(),
                      );
                      final bool isShortAudio =
                          _filterShortAudio && (song.duration ?? 0) < 30000;
                      return isManuallyHidden || isShortAudio;
                    }).toList()..sort(
                      (a, b) => a.title.toLowerCase().compareTo(
                        b.title.toLowerCase(),
                      ),
                    );

                return Container(
                  height: MediaQuery.of(context).size.height * 0.75,
                  padding: const EdgeInsets.only(
                    top: 12,
                    left: 24,
                    right: 24,
                    bottom: 24,
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
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
                      const SizedBox(height: 20),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            AppLocalizations.of(
                              context,
                            ).hiddenFilteredTracksTitle,
                            style: TextStyle(
                              color: isLight
                                  ? const Color(0xFF1A1A1A)
                                  : Colors.white,
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          Text(
                            '${displaySongs.length}${AppLocalizations.of(context).tracksCountSuffix}',
                            style: TextStyle(
                              color: isLight ? Colors.black45 : Colors.white54,
                              fontSize: 13,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Text(
                        AppLocalizations.of(context).hiddenTracksDesc,
                        style: TextStyle(
                          color: isLight ? Colors.black54 : Colors.white54,
                          fontSize: 12,
                        ),
                      ),
                      const SizedBox(height: 20),
                      Expanded(
                        child: displaySongs.isEmpty
                            ? Center(
                                child: Text(
                                  AppLocalizations.of(context).noHiddenTracks,
                                  style: TextStyle(
                                    color: isLight
                                        ? Colors.black38
                                        : Colors.white38,
                                    fontSize: 14,
                                  ),
                                ),
                              )
                            : ListView.builder(
                                physics: const BouncingScrollPhysics(),
                                itemCount: displaySongs.length,
                                itemBuilder: (context, index) {
                                  final song = displaySongs[index];
                                  final bool isManuallyHidden = _hiddenTrackIds
                                      .contains(song.id.toString());
                                  final bool isShortAudio =
                                      _filterShortAudio &&
                                      (song.duration ?? 0) < 30000;

                                  return Container(
                                    margin: const EdgeInsets.only(bottom: 8),
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 12,
                                      vertical: 8,
                                    ),
                                    decoration: BoxDecoration(
                                      color: isLight
                                          ? Colors.black.withValues(alpha: 0.05)
                                          : const Color(0xFF1F1F1F),
                                      borderRadius: BorderRadius.circular(12),
                                    ),
                                    child: Row(
                                      children: [
                                        ClipRRect(
                                          borderRadius: BorderRadius.circular(
                                            8,
                                          ),
                                          child: QueryArtworkWidget(
                                            id: song.id,
                                            type: ArtworkType.AUDIO,
                                            artworkWidth: 42,
                                            artworkHeight: 42,
                                            artworkBorder:
                                                BorderRadius.circular(8),
                                            artworkFit: BoxFit.cover,
                                            keepOldArtwork: true,
                                            nullArtworkWidget: Container(
                                              width: 42,
                                              height: 42,
                                              decoration: BoxDecoration(
                                                color: isLight
                                                    ? Colors.black.withValues(
                                                        alpha: 0.08,
                                                      )
                                                    : Colors.white10,
                                                borderRadius:
                                                    BorderRadius.circular(8),
                                              ),
                                              child: Icon(
                                                Icons.music_note,
                                                color: isLight
                                                    ? Colors.black38
                                                    : Colors.white38,
                                                size: 22,
                                              ),
                                            ),
                                          ),
                                        ),
                                        const SizedBox(width: 12),
                                        Expanded(
                                          child: Column(
                                            crossAxisAlignment:
                                                CrossAxisAlignment.start,
                                            children: [
                                              Text(
                                                song.title,
                                                maxLines: 1,
                                                overflow: TextOverflow.ellipsis,
                                                style: TextStyle(
                                                  color: isLight
                                                      ? const Color(0xFF1A1A1A)
                                                      : Colors.white,
                                                  fontWeight: FontWeight.w600,
                                                  fontSize: 14,
                                                ),
                                              ),
                                              const SizedBox(height: 4),
                                              Row(
                                                children: [
                                                  Expanded(
                                                    child: Text(
                                                      (song.artist == null ||
                                                              song.artist ==
                                                                  '<unknown>')
                                                          ? AppLocalizations.of(
                                                              context,
                                                            ).unknownArtist
                                                          : song.artist!,
                                                      maxLines: 1,
                                                      overflow:
                                                          TextOverflow.ellipsis,
                                                      style: TextStyle(
                                                        color: isLight
                                                            ? Colors.black45
                                                            : Colors.white38,
                                                        fontSize: 12,
                                                      ),
                                                    ),
                                                  ),
                                                  const SizedBox(width: 8),
                                                  if (isManuallyHidden)
                                                    Container(
                                                      padding:
                                                          const EdgeInsets.symmetric(
                                                            horizontal: 6,
                                                            vertical: 2,
                                                          ),
                                                      decoration: BoxDecoration(
                                                        color: Colors.orange
                                                            .withOpacity(0.1),
                                                        borderRadius:
                                                            BorderRadius.circular(
                                                              4,
                                                            ),
                                                        border: Border.all(
                                                          color: Colors.orange
                                                              .withOpacity(0.3),
                                                          width: 1,
                                                        ),
                                                      ),
                                                      child: Text(
                                                        AppLocalizations.of(
                                                          context,
                                                        ).badgeHidden,
                                                        style: const TextStyle(
                                                          color: Colors.orange,
                                                          fontSize: 8,
                                                          fontWeight:
                                                              FontWeight.bold,
                                                        ),
                                                      ),
                                                    ),
                                                  if (isShortAudio)
                                                    Container(
                                                      padding:
                                                          const EdgeInsets.symmetric(
                                                            horizontal: 6,
                                                            vertical: 2,
                                                          ),
                                                      decoration: BoxDecoration(
                                                        color: Colors.cyan
                                                            .withOpacity(0.1),
                                                        borderRadius:
                                                            BorderRadius.circular(
                                                              4,
                                                            ),
                                                        border: Border.all(
                                                          color: Colors.cyan
                                                              .withOpacity(0.3),
                                                          width: 1,
                                                        ),
                                                      ),
                                                      child: Text(
                                                        AppLocalizations.of(
                                                          context,
                                                        ).badgeShortAudio,
                                                        style: const TextStyle(
                                                          color: Colors.cyan,
                                                          fontSize: 8,
                                                          fontWeight:
                                                              FontWeight.bold,
                                                        ),
                                                      ),
                                                    ),
                                                ],
                                              ),
                                            ],
                                          ),
                                        ),
                                        const SizedBox(width: 8),
                                        if (isManuallyHidden)
                                          IconButton(
                                            icon: Icon(
                                              Icons.visibility_outlined,
                                              color: _activeAccentColor,
                                              size: 20,
                                            ),
                                            tooltip: AppLocalizations.of(
                                              context,
                                            ).unhideTrack,
                                            onPressed: () async {
                                              final prefs =
                                                  await SharedPreferences.getInstance();
                                              setState(() {
                                                _hiddenTrackIds.remove(
                                                  song.id.toString(),
                                                );
                                              });
                                              await prefs.setStringList(
                                                'hidden_track_ids',
                                                _hiddenTrackIds,
                                              );
                                              widget.onRescanLibrary();
                                              setModalState(() {});
                                              showFleyToast(
                                                "${song.title} restored to library",
                                              );
                                            },
                                          )
                                        else
                                          IconButton(
                                            icon: Icon(
                                              Icons.info_outline_rounded,
                                              color: isLight
                                                  ? Colors.black38
                                                  : Colors.white30,
                                              size: 20,
                                            ),
                                            tooltip: AppLocalizations.of(
                                              context,
                                            ).autoHiddenTooltip,
                                            onPressed: () {
                                              showFleyToast(
                                                AppLocalizations.of(
                                                  context,
                                                ).autoHiddenToast,
                                              );
                                            },
                                          ),
                                      ],
                                    ),
                                  );
                                },
                              ),
                      ),
                    ],
                  ),
                );
              },
            );
          },
        );
      },
    );
  }
}
