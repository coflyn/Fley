// ignore_for_file: invalid_use_of_protected_member, deprecated_member_use
part of '../main.dart';

extension _SongCoverPickerUI on _MainScreenState {
  Future<String?> _showSongCoverPicker(BuildContext context) async {
    final isLight = isAppLight;
    String searchQuery = '';
    return await showModalBottomSheet<String?>(
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
            final filteredTracks = _allTracks
                .where(
                  (t) =>
                      t.title.toLowerCase().contains(
                        searchQuery.toLowerCase(),
                      ) ||
                      t.artist.toLowerCase().contains(
                        searchQuery.toLowerCase(),
                      ),
                )
                .toList();

            return DraggableScrollableSheet(
              initialChildSize: 0.9,
              minChildSize: 0.5,
              maxChildSize: 0.9,
              expand: false,
              builder: (_, scrollController) {
                return Column(
                  children: [
                    const SizedBox(height: 16),
                    Container(
                      width: 40,
                      height: 4,
                      decoration: BoxDecoration(
                        color: isLight ? Colors.black12 : Colors.white24,
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                    const SizedBox(height: 16),
                    Text(
                      'Select Song Cover',
                      style: TextStyle(
                        color: isLight ? const Color(0xFF1A1A1A) : Colors.white,
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        fontFamily: getFontFamily(_activeFont),
                      ),
                    ),
                    const SizedBox(height: 16),
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16.0),
                      child: TextField(
                        onChanged: (val) =>
                            setModalState(() => searchQuery = val),
                        style: TextStyle(
                          color: isLight
                              ? const Color(0xFF1A1A1A)
                              : Colors.white,
                          fontFamily: getFontFamily(_activeFont),
                        ),
                        decoration: InputDecoration(
                          hintText: 'Search songs...',
                          hintStyle: TextStyle(
                            color: isLight ? Colors.black54 : Colors.white54,
                            fontFamily: getFontFamily(_activeFont),
                          ),
                          prefixIcon: Icon(
                            Icons.search,
                            color: isLight ? Colors.black54 : Colors.white54,
                          ),
                          filled: true,
                          fillColor: isLight
                              ? Colors.white
                              : Colors.white.withValues(alpha: 0.05),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(16),
                            borderSide: BorderSide.none,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 8),
                    Expanded(
                      child: ListView.builder(
                        controller: scrollController,
                        itemCount: filteredTracks.length,
                        itemBuilder: (context, index) {
                          final track = filteredTracks[index];
                          return ListTile(
                            leading: _buildTrackArtwork(
                              track,
                              size: 40,
                              radius: 8,
                            ),
                            title: Text(
                              track.title,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                color: isLight
                                    ? const Color(0xFF1A1A1A)
                                    : Colors.white,
                                fontFamily: getFontFamily(_activeFont),
                                fontSize: 14,
                              ),
                            ),
                            subtitle: Text(
                              track.artist,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                color: isLight
                                    ? Colors.black54
                                    : Colors.white54,
                                fontFamily: getFontFamily(_activeFont),
                                fontSize: 12,
                              ),
                            ),
                            onTap: () async {
                              showDialog(
                                context: context,
                                barrierDismissible: false,
                                builder: (_) => const Center(
                                  child: CircularProgressIndicator(),
                                ),
                              );
                              final coverUri = await _getCoverUriForTrack(
                                track,
                              );
                              if (!context.mounted) return;
                              Navigator.pop(context); // pop loading
                              if (coverUri != null &&
                                  coverUri.isScheme('file')) {
                                if (!context.mounted) return;
                                Navigator.pop(context, coverUri.toFilePath());
                              } else {
                                showFleyToast(
                                  "No cover available for this song",
                                );
                              }
                            },
                          );
                        },
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
  }
}
