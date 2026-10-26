// ignore_for_file: invalid_use_of_protected_member, deprecated_member_use
part of '../main.dart';

extension _SongInfoUI on _MainScreenState {
  void _showSongInfoModal(BuildContext context, Track track) {
    final isLight = isAppLight;
    final format = track.path.split('.').last.toUpperCase();
    final fileName = track.path.split('/').last;

    String formatDuration(int ms) {
      final minutes = (ms / 60000).floor();
      final seconds = ((ms % 60000) / 1000).floor();
      return '${minutes.toString().padLeft(2, '0')}:${seconds.toString().padLeft(2, '0')}';
    }

    Future<String> getFileSize() async {
      try {
        final file = File(track.path);
        if (await file.exists()) {
          final bytes = await file.length();
          if (bytes < 1024) return '$bytes B';
          final kb = bytes / 1024;
          if (kb < 1024) return '${kb.toStringAsFixed(2)} KB';
          final mb = kb / 1024;
          return '${mb.toStringAsFixed(2)} MB';
        }
      } catch (_) {}
      return lookupAppLocalizations(
        Locale(FleyStrings.currentLang),
      ).unknownLiteral;
    }

    showModalBottomSheet(
      context: context,
      backgroundColor: isLight
          ? const Color(0xFFF0F0F3)
          : const Color(0xFF161616),
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (context) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.symmetric(
              horizontal: 24.0,
              vertical: 20.0,
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      AppLocalizations.of(context).songInfo,
                      style: TextStyle(
                        color: isLight ? const Color(0xFF1A1A1A) : Colors.white,
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        fontFamily: getFontFamily(_activeFont),
                      ),
                    ),
                    IconButton(
                      icon: Icon(
                        Icons.close,
                        color: isLight ? Colors.black54 : Colors.white54,
                      ),
                      onPressed: () => Navigator.pop(context),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: isLight
                        ? Colors.white
                        : Colors.white.withValues(alpha: 0.04),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(
                      color: isLight
                          ? Colors.black.withValues(alpha: 0.05)
                          : Colors.white.withValues(alpha: 0.05),
                    ),
                  ),
                  child: Row(
                    children: [
                      _buildTrackArtwork(track, size: 54, radius: 10),
                      const SizedBox(width: 16),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              track.title,
                              style: TextStyle(
                                color: isLight
                                    ? const Color(0xFF1A1A1A)
                                    : Colors.white,
                                fontSize: 15,
                                fontWeight: FontWeight.bold,
                                fontFamily: getFontFamily(_activeFont),
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                            const SizedBox(height: 4),
                            Text(
                              track.artist,
                              style: TextStyle(
                                color: isLight
                                    ? Colors.black54
                                    : Colors.white54,
                                fontSize: 13,
                                fontFamily: getFontFamily(_activeFont),
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                            const SizedBox(height: 2),
                            Text(
                              track.album,
                              style: TextStyle(
                                color: isLight
                                    ? Colors.black38
                                    : Colors.white38,
                                fontSize: 12,
                                fontFamily: getFontFamily(_activeFont),
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 20),
                _buildInfoRow(
                  context,
                  AppLocalizations.of(context).fileName,
                  fileName,
                  isLight,
                ),
                _buildInfoRow(
                  context,
                  AppLocalizations.of(context).format,
                  format,
                  isLight,
                  isBadge: true,
                ),
                _buildInfoRow(
                  context,
                  AppLocalizations.of(context).sortDuration,
                  formatDuration(track.duration),
                  isLight,
                ),
                FutureBuilder<String>(
                  future: getFileSize(),
                  builder: (context, snapshot) {
                    return _buildInfoRow(
                      context,
                      AppLocalizations.of(context).size,
                      snapshot.data ?? AppLocalizations.of(context).loading,
                      isLight,
                    );
                  },
                ),
                const SizedBox(height: 8),
                Text(
                  AppLocalizations.of(context).filePath,
                  style: TextStyle(
                    color: isLight ? Colors.black38 : Colors.white38,
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                    fontFamily: getFontFamily(_activeFont),
                  ),
                ),
                const SizedBox(height: 6),
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: isLight
                        ? Colors.black.withValues(alpha: 0.03)
                        : Colors.white.withValues(alpha: 0.02),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: isLight
                          ? Colors.black.withValues(alpha: 0.04)
                          : Colors.white.withValues(alpha: 0.04),
                    ),
                  ),
                  child: Row(
                    children: [
                      Expanded(
                        child: Text(
                          track.path,
                          style: TextStyle(
                            color: isLight ? Colors.black87 : Colors.white70,
                            fontSize: 12,
                            fontFamily: 'monospace',
                          ),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      const SizedBox(width: 8),
                      IconButton(
                        icon: Icon(
                          Icons.copy_rounded,
                          size: 18,
                          color: _activeAccentColor,
                        ),
                        onPressed: () {
                          Clipboard.setData(ClipboardData(text: track.path));
                          showFleyToast(
                            lookupAppLocalizations(
                              Locale(FleyStrings.currentLang),
                            ).pathCopied,
                          );
                        },
                        tooltip: AppLocalizations.of(context).copyPath,
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 24),
                Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    OutlinedButton.icon(
                      style: OutlinedButton.styleFrom(
                        side: BorderSide(
                          color:
                              isLight
                                  ? Colors.black.withValues(alpha: 0.1)
                                  : Colors.white.withValues(alpha: 0.12),
                        ),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        padding: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 12,
                        ),
                      ),
                      onPressed: () {
                        Navigator.pop(context);
                        _showEditMetadataModal(context, track);
                      },
                      icon: Icon(
                        Icons.edit_outlined,
                        size: 16,
                        color: isLight ? Colors.black87 : Colors.white,
                      ),
                      label: Text(
                        AppLocalizations.of(context).editMetadata,
                        style: TextStyle(
                          color: isLight ? Colors.black87 : Colors.white,
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                          fontFamily: getFontFamily(_activeFont),
                        ),
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
  }

  Widget _buildInfoRow(
    BuildContext context,
    String label,
    String value,
    bool isLight, {
    bool isBadge = false,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8.0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: TextStyle(
              color: isLight ? Colors.black54 : Colors.white54,
              fontSize: 13,
              fontFamily: getFontFamily(_activeFont),
            ),
          ),
          const SizedBox(width: 12),
          if (isBadge)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: BoxDecoration(
                color: _activeAccentColor.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(
                value,
                style: TextStyle(
                  color: _activeAccentColor,
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                  fontFamily: getFontFamily(_activeFont),
                ),
              ),
            )
          else
            Expanded(
              child: Text(
                value,
                textAlign: TextAlign.end,
                style: TextStyle(
                  color: isLight ? const Color(0xFF1A1A1A) : Colors.white70,
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  fontFamily: getFontFamily(_activeFont),
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
        ],
      ),
    );
  }
}
