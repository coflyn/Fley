import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:math' as math;
import 'dart:ui';
import 'package:file_selector/file_selector.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:just_audio/just_audio.dart';
import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../models/lyrics_line.dart';
import '../../models/track.dart';
import '../../services/desktop_audio_scanner.dart';
import '../../utils/artwork_cache.dart';
import '../../utils/globals.dart';
import '../../widgets/desktop_title_bar.dart';
import '../../l10n/app_localizations.dart';

part 'desktop_components.dart';
part 'desktop_sidebar.dart';
part 'desktop_home_view.dart';
part 'desktop_songs_view.dart';
part 'desktop_albums_artists_views.dart';
part 'desktop_queue_drawer.dart';
part 'desktop_bottom_player.dart';
part 'desktop_fullscreen_player.dart';
part 'desktop_profile_settings_views.dart';

enum DesktopNavSection {
  home,
  songs,
  albums,
  artists,
  playlists,
  folders,
  profile,
  hiddenTracks,
}

enum SongFilter {
  all,
  mostPlayed,
  favorites,
  recentlyAdded,
  lastPlayed,
  forgottenGems,
}

class DesktopLayoutShell extends StatefulWidget {
  final List<Track> allTracks;
  final List<Track> playbackQueue;
  final Track? playingTrack;
  final AudioPlayer player;
  final Set<String> favoriteTrackIds;
  final Color activeAccentColor;
  final Color backgroundColor;
  final Color cardColor;
  final bool isLight;
  final Function(Track track, List<Track> queue, int index) onPlayTrack;
  final VoidCallback onTogglePlayPause;
  final VoidCallback onPlayNext;
  final VoidCallback onPlayPrevious;
  final Function(String trackId) onToggleFavorite;
  final VoidCallback onOpenSettings;
  final VoidCallback onRescan;
  final Map<String, List<String>> userPlaylists;
  final Function(String name, Track track)? onAddToPlaylist;
  final Map<String, int> playCounts;
  final List<String> allPlayedTrackIdsOrdered;
  final Map<String, String> playlistCovers;
  final String? lastPlaybackTrackId;
  final int lastPlaybackPositionMs;

  // Ported Features & Lyrics
  final String? currentLyricsPlain;
  final List<LyricsLine> currentLyricsSynced;
  final bool isLyricsLoading;
  final bool isLyricsSynced;
  final VoidCallback? onRefreshLyrics;
  final void Function(Track track)? onPlayNextInQueue;
  final void Function(Track track)? onAddToQueue;
  final void Function(String name)? onCreatePlaylist;
  final void Function(String name)? onDeletePlaylist;
  final void Function(String oldName, String newName)? onRenamePlaylist;
  final void Function(String name, String? coverPath)? onChangePlaylistCover;
  final void Function(String name, String trackId)? onRemoveFromPlaylist;
  final void Function(Track track)? onHideTrack;
  final VoidCallback? onLibraryUpdated;
  final VoidCallback? onOpenSleepTimer;
  final VoidCallback? onOpenEqualizer;
  final void Function(Track track, String text)? onSaveManualLyrics;
  final Set<String> hiddenTrackIds;
  final void Function(String trackId)? onUnhideTrack;
  final void Function(String trackId)? onRemoveFromQueue;
  final void Function(Track track, int targetIndex)? onReorderQueue;
  final void Function(Track track)? onDeletePermanently;

  const DesktopLayoutShell({
    super.key,
    required this.allTracks,
    required this.playbackQueue,
    required this.playingTrack,
    required this.player,
    required this.favoriteTrackIds,
    required this.activeAccentColor,
    required this.backgroundColor,
    required this.cardColor,
    required this.isLight,
    required this.onPlayTrack,
    required this.onTogglePlayPause,
    required this.onPlayNext,
    required this.onPlayPrevious,
    required this.onToggleFavorite,
    required this.onOpenSettings,
    required this.onRescan,
    this.userPlaylists = const {},
    this.onAddToPlaylist,
    this.playCounts = const {},
    this.allPlayedTrackIdsOrdered = const [],
    this.playlistCovers = const {},
    this.lastPlaybackTrackId,
    this.lastPlaybackPositionMs = 0,
    this.currentLyricsPlain,
    this.currentLyricsSynced = const [],
    this.isLyricsLoading = false,
    this.isLyricsSynced = false,
    this.onRefreshLyrics,
    this.onPlayNextInQueue,
    this.onAddToQueue,
    this.onCreatePlaylist,
    this.onDeletePlaylist,
    this.onRenamePlaylist,
    this.onChangePlaylistCover,
    this.onRemoveFromPlaylist,
    this.onHideTrack,
    this.onLibraryUpdated,
    this.onOpenSleepTimer,
    this.onOpenEqualizer,
    this.onSaveManualLyrics,
    this.hiddenTrackIds = const {},
    this.onUnhideTrack,
    this.onRemoveFromQueue,
    this.onReorderQueue,
    this.onDeletePermanently,
  });

  @override
  State<DesktopLayoutShell> createState() => _DesktopLayoutShellState();
}

class _DesktopLayoutShellState extends State<DesktopLayoutShell> {
  DesktopNavSection _activeSection = DesktopNavSection.home;
  SongFilter _activeSongFilter = SongFilter.all;
  String _searchQuery = '';
  final TextEditingController _searchController = TextEditingController();
  List<String> _customFolders = [];
  bool _isQueueOpen = false;
  String? _selectedAlbumName;
  String? _selectedArtistName;
  String? _selectedPlaylistName;
  bool _isFullscreenPlayerOpen = false;
  bool _isLyricsViewOpen = false;
  double _volume = 1.0;
  bool _isMuted = false;
  double _lastUnmutedVolume = 1.0;

  // Fullscreen Spotify-Style Lyrics State
  bool _showLyricsInFullscreen = true;
  final ScrollController _fullscreenLyricsController = ScrollController();
  bool _userScrollingLyrics = false;
  Timer? _lyricsUserScrollTimer;
  int _lastActiveLyricsIndex = -1;
  final List<GlobalKey> _lyricKeys = [];

  // Sorting
  String _songSortKey = 'title_asc';

  // Desktop Sleep Timer
  Timer? _desktopSleepTimer;
  StreamSubscription? _sleepTimerSubscription;
  int? _desktopSleepTimerMinutes;

  @override
  void initState() {
    super.initState();
    _loadCustomFolders();
    _loadCustomArtworks();
    _loadSavedActiveSection();
    _volume = widget.player.volume;
  }

  Future<void> _loadCustomArtworks() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString('metadata_overrides');
      if (raw != null) {
        final Map<String, dynamic> overrides = jsonDecode(raw);
        for (final entry in overrides.entries) {
          final coverPath = entry.value['coverPath'] as String?;
          if (coverPath != null && coverPath.isNotEmpty) {
            final f = File(coverPath);
            if (f.existsSync()) {
              final bytes = f.readAsBytesSync();
              ArtworkCacheManager.setCachedArtwork(entry.key, bytes);
            }
          }
        }
      }
    } catch (_) {}
  }

  Future<void> _loadSavedActiveSection() async {
    final prefs = await SharedPreferences.getInstance();
    final saved = prefs.getString('desktop_active_section');
    if (saved != null && mounted) {
      final section = DesktopNavSection.values.firstWhere(
        (s) => s.name == saved,
        orElse: () => DesktopNavSection.home,
      );
      if (_activeSection != section) {
        setState(() => _activeSection = section);
      }
    }
  }

  void _setActiveSection(DesktopNavSection section) {
    setState(() {
      _activeSection = section;
      _isLyricsViewOpen = false;
    });
    SharedPreferences.getInstance().then((prefs) {
      prefs.setString('desktop_active_section', section.name);
    });
  }

  @override
  void didUpdateWidget(DesktopLayoutShell oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.playingTrack?.id != widget.playingTrack?.id) {
      _lastActiveLyricsIndex = -1;
      _lyricKeys.clear();
      _userScrollingLyrics = false;
    }
  }

  @override
  void dispose() {
    _lyricsUserScrollTimer?.cancel();
    _desktopSleepTimer?.cancel();
    _sleepTimerSubscription?.cancel();
    _fullscreenLyricsController.dispose();
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _loadCustomFolders() async {
    final folders = await DesktopAudioScanner.getCustomDirectories();
    if (mounted) {
      setState(() => _customFolders = folders);
    }
  }

  String _formatDuration(int ms) {
    if (ms <= 0) return '--:--';
    final sec = (ms / 1000).floor();
    final m = sec ~/ 60;
    final s = sec % 60;
    return '$m:${s.toString().padLeft(2, '0')}';
  }

  bool _isSafeImage(String? path) {
    if (path == null || path.isEmpty) return false;
    try {
      return File(path).existsSync();
    } catch (_) {
      return false;
    }
  }

  List<Track> get _mostPlayedTracks {
    final list = widget.allTracks
        .where((t) => (widget.playCounts[t.id] ?? 0) > 0)
        .toList();
    list.sort((a, b) => (widget.playCounts[b.id] ?? 0)
        .compareTo(widget.playCounts[a.id] ?? 0));
    return list;
  }

  List<Track> get _favoriteTracks {
    return widget.allTracks
        .where((t) => widget.favoriteTrackIds.contains(t.id))
        .toList();
  }

  List<Track> get _recentlyAddedTracks {
    return List<Track>.from(widget.allTracks);
  }

  List<Track> get _lastPlayedTracks {
    final trackMap = {for (var t in widget.allTracks) t.id: t};
    return widget.allPlayedTrackIdsOrdered
        .where((id) => trackMap.containsKey(id))
        .map((id) => trackMap[id]!)
        .toList();
  }

  List<Track> get _forgottenGemsTracks {
    return widget.allTracks.reversed
        .where((t) => (widget.playCounts[t.id] ?? 0) <= 1)
        .toList();
  }

  List<Track> get _playlistTracks {
    if (_selectedPlaylistName == null) return [];
    final ids = widget.userPlaylists[_selectedPlaylistName] ?? [];
    final trackMap = {for (var t in widget.allTracks) t.id: t};
    return ids
        .where((id) => trackMap.containsKey(id))
        .map((id) => trackMap[id]!)
        .toList();
  }

  List<Track> get _currentFilterBaseTracks {
    if (_selectedPlaylistName != null) {
      return _playlistTracks;
    }
    switch (_activeSongFilter) {
      case SongFilter.all:
        return widget.allTracks;
      case SongFilter.mostPlayed:
        return _mostPlayedTracks;
      case SongFilter.favorites:
        return _favoriteTracks;
      case SongFilter.recentlyAdded:
        return _recentlyAddedTracks;
      case SongFilter.lastPlayed:
        return _lastPlayedTracks;
      case SongFilter.forgottenGems:
        return _forgottenGemsTracks;
    }
  }

  List<Track> get _filteredTracks {
    final base = List<Track>.from(_currentFilterBaseTracks);
    List<Track> filtered;
    if (_searchQuery.trim().isEmpty) {
      filtered = base;
    } else {
      final q = _searchQuery.toLowerCase();
      filtered = base.where((t) {
        return t.title.toLowerCase().contains(q) ||
            t.artist.toLowerCase().contains(q) ||
            t.album.toLowerCase().contains(q);
      }).toList();
    }

    switch (_songSortKey) {
      case 'title_desc':
        filtered.sort((a, b) => b.title.toLowerCase().compareTo(a.title.toLowerCase()));
        break;
      case 'artist':
        filtered.sort((a, b) => a.artist.toLowerCase().compareTo(b.artist.toLowerCase()));
        break;
      case 'album':
        filtered.sort((a, b) => a.album.toLowerCase().compareTo(b.album.toLowerCase()));
        break;
      case 'duration_desc':
        filtered.sort((a, b) => b.duration.compareTo(a.duration));
        break;
      case 'duration_asc':
        filtered.sort((a, b) => a.duration.compareTo(b.duration));
        break;
      case 'title_asc':
      default:
        filtered.sort((a, b) => a.title.toLowerCase().compareTo(b.title.toLowerCase()));
        break;
    }
    return filtered;
  }

  int get _filteredAlbumsCount {
    final query = _searchQuery.trim().toLowerCase();
    final Map<String, List<Track>> albumGroups = {};
    for (final track in widget.allTracks) {
      albumGroups.putIfAbsent(track.album, () => []).add(track);
    }
    if (query.isEmpty) return albumGroups.length;
    return albumGroups.keys.where((a) {
      if (a.toLowerCase().contains(query)) return true;
      final tracks = albumGroups[a] ?? [];
      return tracks.any((t) => t.artist.toLowerCase().contains(query));
    }).length;
  }

  int get _filteredArtistsCount {
    final query = _searchQuery.trim().toLowerCase();
    final artists = <String>{};
    for (final track in widget.allTracks) {
      artists.add(track.artist);
    }
    if (query.isEmpty) return artists.length;
    return artists.where((a) => a.toLowerCase().contains(query)).length;
  }

  // --- Modal Helpers for Ported Features ---

  void _showDeletePermanentlyDialog(Track track) {
    final loc = AppLocalizations.of(context);
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: widget.isLight
            ? const Color(0xFFFAFAFD)
            : const Color(0xFF1E1E24),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text(loc.confirmDelete),
        content: Text(
          '${loc.confirmDeleteBody}\n\n"${track.title}" - ${track.artist}',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(loc.cancel),
          ),
          FilledButton(
            onPressed: () {
              Navigator.pop(context);
              widget.onDeletePermanently?.call(track);
            },
            style: FilledButton.styleFrom(
              backgroundColor: Colors.redAccent,
            ),
            child: Text(loc.delete),
          ),
        ],
      ),
    );
  }

  void _showSongDetailsDialog(Track track) {
    showDialog(
      context: context,
      builder: (context) {
        final loc = AppLocalizations.of(context);
        final isLight = widget.isLight;
        final textColor = isLight ? const Color(0xFF1A1A1A) : Colors.white;
        final secondaryTextColor = isLight ? const Color(0xFF6E6E73) : Colors.white60;

        Widget infoRow(String label, String value) {
          return Padding(
            padding: const EdgeInsets.symmetric(vertical: 6),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                SizedBox(
                  width: 100,
                  child: Text(
                    label,
                    style: TextStyle(
                      fontSize: 12.5,
                      fontWeight: FontWeight.w600,
                      color: secondaryTextColor,
                    ),
                  ),
                ),
                Expanded(
                  child: SelectableText(
                    value,
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w500,
                      color: textColor,
                    ),
                  ),
                ),
              ],
            ),
          );
        }

        final file = File(track.path);
        String sizeStr = 'Unknown';
        if (file.existsSync()) {
          final bytes = file.lengthSync();
          final mb = (bytes / (1024 * 1024)).toStringAsFixed(2);
          sizeStr = '$mb MB';
        }

        return AlertDialog(
          backgroundColor: isLight ? const Color(0xFFFAFAFD) : const Color(0xFF1E1E24),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: Row(
            children: [
              Icon(Icons.info_outline_rounded, color: widget.activeAccentColor),
              const SizedBox(width: 10),
              Text(loc.songInfo, style: const TextStyle(fontWeight: FontWeight.w700)),
            ],
          ),
          content: SizedBox(
            width: 440,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                infoRow(loc.title, track.title),
                infoRow(loc.artist, track.artist),
                infoRow(loc.album, track.album.isNotEmpty ? track.album : 'Unknown'),
                infoRow('Duration', _formatDuration(track.duration)),
                infoRow('File Size', sizeStr),
                infoRow('File Path', track.path),
              ],
            ),
          ),
          actions: [
            FilledButton(
              onPressed: () => Navigator.pop(context),
              style: FilledButton.styleFrom(
                backgroundColor: widget.activeAccentColor,
                foregroundColor: Colors.black,
              ),
              child: Text(loc.close),
            ),
          ],
        );
      },
    );
  }

  void _showEditSongTagsDialog(Track track) {
    final titleCtrl = TextEditingController(text: track.title);
    final artistCtrl = TextEditingController(text: track.artist);
    final albumCtrl = TextEditingController(text: track.album);

    showDialog(
      context: context,
      builder: (context) {
        final loc = AppLocalizations.of(context);
        final isLight = widget.isLight;
        return AlertDialog(
          backgroundColor: isLight ? const Color(0xFFFAFAFD) : const Color(0xFF1E1E24),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: Row(
            children: [
              Icon(Icons.edit_note_rounded, color: widget.activeAccentColor),
              const SizedBox(width: 10),
              Text(loc.editMetadata, style: const TextStyle(fontWeight: FontWeight.w700)),
            ],
          ),
          content: SizedBox(
            width: 400,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: titleCtrl,
                  decoration: InputDecoration(labelText: loc.title),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: artistCtrl,
                  decoration: InputDecoration(labelText: loc.artist),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: albumCtrl,
                  decoration: InputDecoration(labelText: loc.album),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: Text(loc.cancel),
            ),
            FilledButton(
              onPressed: () async {
                final nav = Navigator.of(context);
                final newTitle = titleCtrl.text.trim();
                final newArtist = artistCtrl.text.trim();
                final newAlbum = albumCtrl.text.trim();
                if (newTitle.isNotEmpty) {
                  final prefs = await SharedPreferences.getInstance();
                  final raw = prefs.getString('metadata_overrides');
                  Map<String, dynamic> overrides = {};
                  if (raw != null) {
                    try {
                      overrides = jsonDecode(raw);
                    } catch (_) {}
                  }
                  overrides[track.id] = {
                    'title': newTitle,
                    'artist': newArtist.isNotEmpty ? newArtist : track.artist,
                    'album': newAlbum,
                  };
                  await prefs.setString(
                    'metadata_overrides',
                    jsonEncode(overrides),
                  );
                  widget.onRescan();
                }
                nav.pop();
              },
              style: FilledButton.styleFrom(
                backgroundColor: widget.activeAccentColor,
                foregroundColor: Colors.black,
              ),
              child: Text(loc.save),
            ),
          ],
        );
      },
    );
  }

  void _showAddToPlaylistDialog(Track track) {
    showDialog(
      context: context,
      builder: (context) {
        final loc = AppLocalizations.of(context);
        final isLight = widget.isLight;
        final textColor = isLight ? const Color(0xFF1A1A1A) : Colors.white;

        return AlertDialog(
          backgroundColor: isLight ? const Color(0xFFFAFAFD) : const Color(0xFF1E1E24),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: Text(loc.addToPlaylist, style: const TextStyle(fontWeight: FontWeight.w700)),
          content: SizedBox(
            width: 360,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                ListTile(
                  leading: Icon(Icons.add_circle_outline_rounded, color: widget.activeAccentColor),
                  title: Text(
                    loc.newPlaylist,
                    style: TextStyle(
                      fontWeight: FontWeight.w600,
                      color: widget.activeAccentColor,
                    ),
                  ),
                  onTap: () {
                    Navigator.pop(context);
                    _showCreatePlaylistDialog(trackToAdd: track);
                  },
                ),
                const Divider(),
                if (widget.userPlaylists.isEmpty)
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    child: Text(loc.noResults, style: const TextStyle(color: Colors.white54)),
                  )
                else
                  ConstrainedBox(
                    constraints: const BoxConstraints(maxHeight: 240),
                    child: ListView(
                      shrinkWrap: true,
                      children: widget.userPlaylists.keys.map((pName) {
                        final contains = widget.userPlaylists[pName]?.contains(track.id) ?? false;
                        return ListTile(
                          leading: const Icon(Icons.queue_music_rounded, size: 20),
                          title: Text(pName, style: TextStyle(color: textColor, fontSize: 13.5)),
                          trailing: contains
                              ? Icon(Icons.check_rounded, color: widget.activeAccentColor, size: 18)
                              : null,
                          onTap: () {
                            if (widget.onAddToPlaylist != null) {
                              widget.onAddToPlaylist!(pName, track);
                            }
                            Navigator.pop(context);
                          },
                        );
                      }).toList(),
                    ),
                  ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: Text(loc.close),
            ),
          ],
        );
      },
    );
  }

  void _showCreatePlaylistDialog({Track? trackToAdd}) {
    final ctrl = TextEditingController();
    showDialog(
      context: context,
      builder: (context) {
        final loc = AppLocalizations.of(context);
        final isLight = widget.isLight;
        return AlertDialog(
          backgroundColor: isLight ? const Color(0xFFFAFAFD) : const Color(0xFF1E1E24),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: Text(loc.createPlaylist, style: const TextStyle(fontWeight: FontWeight.w700)),
          content: TextField(
            controller: ctrl,
            autofocus: true,
            decoration: InputDecoration(
              labelText: loc.playlistName,
              hintText: 'e.g. Chill Vibes',
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: Text(loc.cancel),
            ),
            FilledButton(
              onPressed: () {
                final name = ctrl.text.trim();
                if (name.isNotEmpty) {
                  if (widget.onCreatePlaylist != null) {
                    widget.onCreatePlaylist!(name);
                  }
                  if (trackToAdd != null && widget.onAddToPlaylist != null) {
                    widget.onAddToPlaylist!(name, trackToAdd);
                  }
                }
                Navigator.pop(context);
              },
              style: FilledButton.styleFrom(
                backgroundColor: widget.activeAccentColor,
                foregroundColor: Colors.black,
              ),
              child: Text(loc.save),
            ),
          ],
        );
      },
    );
  }

  void _showSleepTimerDialog() {
    showDialog(
      context: context,
      builder: (context) {
        final loc = AppLocalizations.of(context);
        final isLight = widget.isLight;
        final textColor = isLight ? const Color(0xFF1A1A1A) : Colors.white;

        Widget timerTile(String label, int minutes) {
          final isSelected = _desktopSleepTimerMinutes == minutes;
          return ListTile(
            leading: Icon(
              Icons.timer_outlined,
              color: isSelected ? widget.activeAccentColor : Colors.white60,
              size: 20,
            ),
            title: Text(
              label,
              style: TextStyle(
                color: isSelected ? widget.activeAccentColor : textColor,
                fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
                fontSize: 13.5,
              ),
            ),
            trailing: isSelected
                ? Icon(Icons.check_rounded, color: widget.activeAccentColor, size: 20)
                : null,
            onTap: () {
              _setDesktopSleepTimer(minutes);
              Navigator.pop(context);
            },
          );
        }

        return AlertDialog(
          backgroundColor: isLight ? const Color(0xFFFAFAFD) : const Color(0xFF1E1E24),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: Row(
            children: [
              Icon(Icons.bedtime_rounded, color: widget.activeAccentColor),
              const SizedBox(width: 10),
              Text(loc.sleepTimer, style: const TextStyle(fontWeight: FontWeight.w700)),
            ],
          ),
          content: SizedBox(
            width: 320,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                timerTile('End of Current Track', -1),
                timerTile('15 minutes', 15),
                timerTile('30 minutes', 30),
                timerTile('45 minutes', 45),
                timerTile('60 minutes (1 hour)', 60),
                ListTile(
                  leading: Icon(
                    Icons.tune_rounded,
                    color: Colors.white60,
                    size: 20,
                  ),
                  title: Text(
                    'Custom...',
                    style: TextStyle(
                      color: textColor,
                      fontWeight: FontWeight.w500,
                      fontSize: 13.5,
                    ),
                  ),
                  onTap: () {
                    Navigator.pop(context);
                    _showCustomSleepTimerPrompt();
                  },
                ),
                if (_desktopSleepTimerMinutes != null) ...[
                  const Divider(),
                  ListTile(
                    leading: const Icon(Icons.timer_off_outlined, color: Colors.redAccent, size: 20),
                    title: const Text(
                      'Turn Off Sleep Timer',
                      style: TextStyle(color: Colors.redAccent, fontWeight: FontWeight.w600, fontSize: 13.5),
                    ),
                    onTap: () {
                      _setDesktopSleepTimer(0);
                      Navigator.pop(context);
                    },
                  ),
                ],
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Close'),
            ),
          ],
        );
      },
    );
  }

  void _showManualLyricsDialog(Track track) async {
    final prefs = await SharedPreferences.getInstance();
    final manualKey = 'lyrics_manual_${track.id}';
    final existingManual = prefs.getString(manualKey) ?? '';
    final initialText = existingManual.isNotEmpty
        ? existingManual
        : (widget.currentLyricsPlain ?? '');

    final controller = TextEditingController(text: initialText);

    if (!mounted) return;
    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          backgroundColor: widget.isLight
              ? const Color(0xFFFAFAFD)
              : const Color(0xFF1E1E24),
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: Row(
            children: [
              Icon(Icons.edit_note_rounded, color: widget.activeAccentColor),
              const SizedBox(width: 10),
              const Text('Input / Import LRC Lyrics',
                  style:
                      TextStyle(fontWeight: FontWeight.w700, fontSize: 17)),
            ],
          ),
          content: SizedBox(
            width: 520,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        'Tempel lirik (format LRC [mm:ss.xx] atau teks) atau impor file .lrc:',
                        style: TextStyle(
                          fontSize: 12.5,
                          color: widget.isLight
                              ? Colors.black54
                              : Colors.white60,
                        ),
                      ),
                    ),
                    OutlinedButton.icon(
                      icon: const Icon(Icons.file_open_outlined, size: 16),
                      label: const Text('Buka .lrc File'),
                      style: OutlinedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 12, vertical: 8),
                      ),
                      onPressed: () async {
                        const typeGroup = XTypeGroup(
                          label: 'LRC or TXT file',
                          extensions: ['lrc', 'txt'],
                        );
                        final file =
                            await openFile(acceptedTypeGroups: [typeGroup]);
                        if (file != null) {
                          final content = await file.readAsString();
                          controller.text = content;
                        }
                      },
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: controller,
                  maxLines: 12,
                  style: const TextStyle(
                      fontSize: 13, fontFamily: 'monospace'),
                  decoration: InputDecoration(
                    hintText:
                        '[00:12.34] Lirik lagu disini...\n[00:15.67] Baris berikutnya...',
                    hintStyle: TextStyle(
                      fontSize: 12.5,
                      color: widget.isLight
                          ? Colors.black26
                          : Colors.white30,
                    ),
                    filled: true,
                    fillColor: widget.isLight
                        ? Colors.black.withValues(alpha: 0.03)
                        : Colors.white.withValues(alpha: 0.04),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(10),
                      borderSide: BorderSide(
                        color: widget.isLight
                            ? Colors.black12
                            : Colors.white12,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
          actions: [
            if (existingManual.isNotEmpty)
              TextButton(
                onPressed: () {
                  Navigator.pop(context);
                  widget.onSaveManualLyrics?.call(track, '');
                },
                child: const Text('Hapus Manual',
                    style: TextStyle(color: Colors.redAccent)),
              ),
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Batal'),
            ),
            FilledButton(
              onPressed: () {
                final text = controller.text.trim();
                Navigator.pop(context);
                widget.onSaveManualLyrics?.call(track, text);
              },
              style: FilledButton.styleFrom(
                backgroundColor: widget.activeAccentColor,
                foregroundColor: Colors.black,
              ),
              child: const Text('Simpan Lirik'),
            ),
          ],
        );
      },
    );
  }

  void _showCustomSleepTimerPrompt() {
    final ctrl = TextEditingController();
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: widget.isLight
            ? const Color(0xFFFAFAFD)
            : const Color(0xFF1E1E24),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text('Custom Sleep Timer'),
        content: TextField(
          controller: ctrl,
          keyboardType: TextInputType.number,
          autofocus: true,
          decoration: const InputDecoration(
            labelText: 'Duration (minutes)',
            hintText: 'e.g. 20',
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () {
              final val = int.tryParse(ctrl.text.trim());
              if (val != null && val > 0) {
                _setDesktopSleepTimer(val);
              }
              Navigator.pop(context);
            },
            style: FilledButton.styleFrom(
              backgroundColor: widget.activeAccentColor,
              foregroundColor: Colors.black,
            ),
            child: const Text('Set Timer'),
          ),
        ],
      ),
    );
  }

  void _setDesktopSleepTimer(int minutes) {
    _desktopSleepTimer?.cancel();
    _sleepTimerSubscription?.cancel();
    setState(() {
      _desktopSleepTimerMinutes = minutes != 0 ? minutes : null;
    });

    if (minutes == -1) {
      final startingTrackId = widget.playingTrack?.id;
      _sleepTimerSubscription = widget.player.playerStateStream.listen((state) {
        if (state.processingState == ProcessingState.completed ||
            (startingTrackId != null && widget.playingTrack?.id != startingTrackId)) {
          widget.player.pause();
          _setDesktopSleepTimer(0);
        }
      });
    } else if (minutes > 0) {
      _desktopSleepTimer = Timer(Duration(minutes: minutes), () {
        widget.player.pause();
        if (mounted) {
          setState(() {
            _desktopSleepTimerMinutes = null;
          });
        }
      });
    }
  }

  void _setVolume(double newVol) {
    setState(() {
      _volume = newVol;
      _isMuted = newVol == 0.0;
      widget.player.setVolume(newVol);
    });
  }

  void _toggleMute() {
    setState(() {
      if (_isMuted) {
        _isMuted = false;
        _volume = _lastUnmutedVolume > 0 ? _lastUnmutedVolume : 1.0;
        widget.player.setVolume(_volume);
      } else {
        _lastUnmutedVolume = _volume > 0 ? _volume : 1.0;
        _isMuted = true;
        _volume = 0.0;
        widget.player.setVolume(0.0);
      }
    });
  }

  KeyEventResult _handleGlobalKeyEvent(FocusNode node, KeyEvent event) {
    final primaryFocus = FocusManager.instance.primaryFocus;
    if (primaryFocus?.context?.widget is EditableText) {
      return KeyEventResult.ignored;
    }

    if (event is KeyDownEvent) {
      final key = event.logicalKey;
      final isMetaOrCtrl = HardwareKeyboard.instance.isMetaPressed ||
          HardwareKeyboard.instance.isControlPressed;

      if (key == LogicalKeyboardKey.space) {
        widget.onTogglePlayPause();
        return KeyEventResult.handled;
      } else if (key == LogicalKeyboardKey.arrowLeft) {
        if (isMetaOrCtrl) {
          widget.onPlayPrevious();
        } else {
          final cur = widget.player.position;
          final target = cur - const Duration(seconds: 5);
          widget.player.seek(target < Duration.zero ? Duration.zero : target);
        }
        return KeyEventResult.handled;
      } else if (key == LogicalKeyboardKey.arrowRight) {
        if (isMetaOrCtrl) {
          widget.onPlayNext();
        } else {
          final cur = widget.player.position;
          final total = widget.player.duration ?? Duration.zero;
          final target = cur + const Duration(seconds: 5);
          widget.player.seek(target > total ? total : target);
        }
        return KeyEventResult.handled;
      } else if (key == LogicalKeyboardKey.arrowUp) {
        final newVol = (_volume + 0.05).clamp(0.0, 1.0);
        _setVolume(newVol);
        return KeyEventResult.handled;
      } else if (key == LogicalKeyboardKey.arrowDown) {
        final newVol = (_volume - 0.05).clamp(0.0, 1.0);
        _setVolume(newVol);
        return KeyEventResult.handled;
      } else if (key == LogicalKeyboardKey.keyM) {
        _toggleMute();
        return KeyEventResult.handled;
      } else if (key == LogicalKeyboardKey.keyF) {
        if (widget.playingTrack != null) {
          setState(() {
            _isFullscreenPlayerOpen = !_isFullscreenPlayerOpen;
            if (_isLyricsViewOpen) _isLyricsViewOpen = false;
          });
        }
        return KeyEventResult.handled;
      } else if (key == LogicalKeyboardKey.keyL) {
        if (_isFullscreenPlayerOpen) {
          setState(() {
            _showLyricsInFullscreen = !_showLyricsInFullscreen;
          });
          return KeyEventResult.handled;
        } else if (widget.playingTrack != null) {
          setState(() {
            _isLyricsViewOpen = !_isLyricsViewOpen;
          });
          return KeyEventResult.handled;
        }
      } else if (key == LogicalKeyboardKey.escape) {
        if (_isFullscreenPlayerOpen) {
          setState(() => _isFullscreenPlayerOpen = false);
          return KeyEventResult.handled;
        } else if (_isLyricsViewOpen) {
          setState(() => _isLyricsViewOpen = false);
          return KeyEventResult.handled;
        } else if (_isQueueOpen) {
          setState(() => _isQueueOpen = false);
          return KeyEventResult.handled;
        }
      }
    }
    return KeyEventResult.ignored;
  }

  Future<void> _changeTrackArtwork(Track track) async {
    const typeGroup = XTypeGroup(
      label: 'Images',
      extensions: ['jpg', 'jpeg', 'png', 'webp'],
    );
    final file = await openFile(acceptedTypeGroups: [typeGroup]);
    if (file == null) return;

    try {
      final bytes = await file.readAsBytes();
      final appSupportDir = await getApplicationSupportDirectory();
      final artworkDir = Directory('${appSupportDir.path}/custom_artworks');
      if (!artworkDir.existsSync()) {
        artworkDir.createSync(recursive: true);
      }
      final ext = file.name.split('.').last;
      final targetFile = File('${artworkDir.path}/track_${track.id}.$ext');
      await targetFile.writeAsBytes(bytes);

      ArtworkCacheManager.setCachedArtwork(track.id, bytes);

      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString('metadata_overrides');
      final Map<String, dynamic> overrides = raw != null ? jsonDecode(raw) : {};
      final existing = overrides[track.id] as Map<String, dynamic>? ?? {};
      existing['coverPath'] = targetFile.path;
      overrides[track.id] = existing;
      await prefs.setString('metadata_overrides', jsonEncode(overrides));

      if (mounted) {
        setState(() {});
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Cover art updated successfully'),
            duration: Duration(seconds: 2),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to update artwork: $e'),
            backgroundColor: Colors.redAccent,
          ),
        );
      }
    }
  }

  void _hideTrack(Track track) {
    final loc = AppLocalizations.of(context);
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: widget.isLight
            ? const Color(0xFFFAFAFD)
            : const Color(0xFF1E1E24),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text(loc.hideTrack),
        content: Text(
          '${track.title}\n\n${loc.hiddenTracksDesc}',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(loc.cancel),
          ),
          FilledButton(
            onPressed: () {
              Navigator.pop(context);
              widget.onHideTrack?.call(track);
            },
            style: FilledButton.styleFrom(
              backgroundColor: Colors.redAccent,
            ),
            child: Text(loc.hideTrack),
          ),
        ],
      ),
    );
  }

  void _renamePlaylistDialog(String oldName) {
    final loc = AppLocalizations.of(context);
    final ctrl = TextEditingController(text: oldName);
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: widget.isLight
            ? const Color(0xFFFAFAFD)
            : const Color(0xFF1E1E24),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text(loc.renamePlaylist),
        content: TextField(
          controller: ctrl,
          autofocus: true,
          decoration: InputDecoration(
            labelText: loc.playlistName,
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(loc.cancel),
          ),
          FilledButton(
            onPressed: () {
              final newName = ctrl.text.trim();
              if (newName.isNotEmpty && newName != oldName) {
                widget.onRenamePlaylist?.call(oldName, newName);
                if (_selectedPlaylistName == oldName) {
                  setState(() => _selectedPlaylistName = newName);
                }
              }
              Navigator.pop(context);
            },
            style: FilledButton.styleFrom(
              backgroundColor: widget.activeAccentColor,
              foregroundColor: Colors.black,
            ),
            child: Text(loc.save),
          ),
        ],
      ),
    );
  }

  Future<void> _changePlaylistCoverDialog(String playlistName) async {
    const typeGroup = XTypeGroup(
      label: 'Images',
      extensions: ['jpg', 'jpeg', 'png', 'webp'],
    );
    final file = await openFile(acceptedTypeGroups: [typeGroup]);
    if (file == null) return;

    try {
      final bytes = await file.readAsBytes();
      final appSupportDir = await getApplicationSupportDirectory();
      final playlistDir = Directory('${appSupportDir.path}/playlists');
      if (!playlistDir.existsSync()) {
        playlistDir.createSync(recursive: true);
      }
      final safeName = playlistName.replaceAll(RegExp(r'[^\w\s]+'), '_');
      final ext = file.name.split('.').last;
      final targetFile = File('${playlistDir.path}/playlist_${safeName}_cover.$ext');
      await targetFile.writeAsBytes(bytes);

      widget.onChangePlaylistCover?.call(playlistName, targetFile.path);
      if (mounted) {
        setState(() {});
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Playlist cover updated successfully'),
            duration: Duration(seconds: 2),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to update playlist cover: $e'),
            backgroundColor: Colors.redAccent,
          ),
        );
      }
    }
  }



  @override
  Widget build(BuildContext context) {
    final loc = AppLocalizations.of(context);
    final textColor = widget.isLight
        ? const Color(0xFF1A1A1A)
        : Colors.white.withValues(alpha: 0.95);
    final secondaryTextColor = widget.isLight
        ? const Color(0xFF6E6E73)
        : Colors.white.withValues(alpha: 0.55);
    final borderColor = widget.isLight
        ? Colors.black.withValues(alpha: 0.08)
        : Colors.white.withValues(alpha: 0.08);

    final isNowPlayingOpen =
        _isFullscreenPlayerOpen && widget.playingTrack != null;

    return ValueListenableBuilder<String>(
      valueListenable: activeFontNotifier,
      builder: (context, activeFont, _) {
        final font = getFontFamily(activeFont);
        return Theme(
          data: Theme.of(context).copyWith(
            textTheme: Theme.of(context).textTheme.apply(fontFamily: font),
          ),
          child: Focus(
            autofocus: true,
            onKeyEvent: _handleGlobalKeyEvent,
            child: Scaffold(
              backgroundColor: widget.backgroundColor,
              body: Column(
                children: [
                  // Main desktop body OR Fullscreen Now Playing View
                  Expanded(
                    child: isNowPlayingOpen
                        ? _buildFullscreenNowPlayingView(
                            textColor,
                            secondaryTextColor,
                          )
                        : Column(
                            children: [
                              // Custom borderless title bar (window controls + drag)
                              DesktopTitleBar(
                                backgroundColor: widget.backgroundColor,
                                isLight: widget.isLight,
                              ),

                              // Main desktop body (Sidebar + Content Viewport + Optional Right Queue)
                              Expanded(
                                child: Row(
                                  children: [
                                    // Left Navigation Sidebar
                                    _buildSidebar(
                                      textColor,
                                      secondaryTextColor,
                                      borderColor,
                                    ),

                                    // Center Content Area (with floating Queue Overlay)
                                    Expanded(
                                      child: Stack(
                                        children: [
                                          Container(
                                            color: widget.backgroundColor,
                                            child: Column(
                                              children: [
                                                // Header Search & Actions
                                                _buildTopHeader(
                                                  textColor,
                                                  secondaryTextColor,
                                                  borderColor,
                                                  loc,
                                                ),
                                                Divider(
                                                  color: borderColor,
                                                  height: 1,
                                                  thickness: 1,
                                                ),
                                                // Main Viewport
                                                Expanded(
                                                  child: _buildMainContent(
                                                    textColor,
                                                    secondaryTextColor,
                                                  ),
                                                ),
                                              ],
                                            ),
                                          ),

                                          // Click-outside backdrop to dismiss queue cleanly
                                          if (_isQueueOpen)
                                            Positioned.fill(
                                              child: GestureDetector(
                                                behavior: HitTestBehavior.translucent,
                                                onTap: () => setState(() => _isQueueOpen = false),
                                                child: Container(
                                                  color: Colors.black.withValues(
                                                    alpha: widget.isLight ? 0.08 : 0.25,
                                                  ),
                                                ),
                                              ),
                                            ),

                                          // Floating Playback Queue Overlay (slides smoothly from right)
                                          AnimatedPositioned(
                                            duration: const Duration(milliseconds: 260),
                                            curve: Curves.easeOutCubic,
                                            top: 0,
                                            right: _isQueueOpen ? 0 : -360,
                                            bottom: 0,
                                            width: 340,
                                            child: _buildQueueSidePanel(
                                              textColor,
                                              secondaryTextColor,
                                              borderColor,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                  ),

                  // Bottom Audio Player Bar (only visible when a track is active)
                  if (widget.playingTrack != null)
                    _buildPersistentBottomPlayer(
                      textColor,
                      secondaryTextColor,
                      borderColor,
                    ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildTopHeader(
    Color textColor,
    Color secondaryTextColor,
    Color borderColor,
    AppLocalizations loc,
  ) {
    return Container(
      height: 56,
      padding: const EdgeInsets.symmetric(horizontal: 24),
      child: Row(
        children: [
          // Search Bar
          SizedBox(
            width: 320,
            height: 38,
            child: TextField(
              controller: _searchController,
              onTap: () {
                if (_isLyricsViewOpen) {
                  setState(() => _isLyricsViewOpen = false);
                }
                if (_activeSection != DesktopNavSection.songs &&
                    _activeSection != DesktopNavSection.albums &&
                    _activeSection != DesktopNavSection.artists) {
                  setState(() => _activeSection = DesktopNavSection.songs);
                }
              },
              onChanged: (val) {
                setState(() {
                  _isLyricsViewOpen = false;
                  _searchQuery = val;
                  if (_activeSection != DesktopNavSection.songs &&
                      _activeSection != DesktopNavSection.albums &&
                      _activeSection != DesktopNavSection.artists) {
                    _activeSection = DesktopNavSection.songs;
                  }
                });
              },
              style: TextStyle(fontSize: 13.5, color: textColor),
              decoration: InputDecoration(
                hintText: _activeSection == DesktopNavSection.albums
                    ? '${loc.search} ${loc.albums}...'
                    : (_activeSection == DesktopNavSection.artists
                        ? '${loc.search} ${loc.artists}...'
                        : loc.searchSongs),
                hintStyle: TextStyle(
                  fontSize: 13,
                  color: secondaryTextColor,
                ),
                prefixIcon: Icon(
                  Icons.search,
                  size: 18,
                  color: secondaryTextColor,
                ),
                suffixIcon: _searchQuery.isNotEmpty
                    ? IconButton(
                        icon: const Icon(Icons.clear, size: 16),
                        onPressed: () {
                          _searchController.clear();
                          setState(() => _searchQuery = '');
                        },
                      )
                    : null,
                filled: true,
                fillColor: widget.isLight
                    ? Colors.black.withValues(alpha: 0.04)
                    : Colors.white.withValues(alpha: 0.06),
                contentPadding: const EdgeInsets.symmetric(horizontal: 12),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                  borderSide: BorderSide.none,
                ),
              ),
            ),
          ),
          const Spacer(),
          // Stats or current status
          Text(
            _activeSection == DesktopNavSection.albums
                ? (_selectedAlbumName != null
                    ? '${widget.allTracks.where((t) => t.album.toLowerCase() == _selectedAlbumName!.toLowerCase() && (_searchQuery.trim().isEmpty || t.title.toLowerCase().contains(_searchQuery.trim().toLowerCase()) || t.artist.toLowerCase().contains(_searchQuery.trim().toLowerCase()))).length} ${loc.songsCount}'
                    : '$_filteredAlbumsCount ${loc.albumsCount}')
                : (_activeSection == DesktopNavSection.artists
                    ? (_selectedArtistName != null
                        ? '${widget.allTracks.where((t) => t.artist.toLowerCase() == _selectedArtistName!.toLowerCase() && (_searchQuery.trim().isEmpty || t.title.toLowerCase().contains(_searchQuery.trim().toLowerCase()) || t.album.toLowerCase().contains(_searchQuery.trim().toLowerCase()))).length} ${loc.songsCount}'
                        : '$_filteredArtistsCount ${loc.artistsCount}')
                    : '${_filteredTracks.length} ${loc.songsCount}'),
            style: TextStyle(fontSize: 12.5, color: secondaryTextColor),
          ),
        ],
      ),
    );
  }

  Widget _buildMainContent(Color textColor, Color secondaryTextColor) {
    if (_isLyricsViewOpen && widget.playingTrack != null) {
      return _buildInShellLyricsView(textColor, secondaryTextColor);
    }
    switch (_activeSection) {
      case DesktopNavSection.home:
        return _buildDesktopHomeScreen(textColor, secondaryTextColor);
      case DesktopNavSection.songs:
        return _buildSongsTableView(textColor, secondaryTextColor);
      case DesktopNavSection.albums:
        if (_selectedAlbumName != null) {
          return _buildAlbumDetailView(_selectedAlbumName!, textColor, secondaryTextColor);
        }
        return _buildAlbumsGridView(textColor, secondaryTextColor);
      case DesktopNavSection.artists:
        if (_selectedArtistName != null) {
          return _buildArtistDetailView(_selectedArtistName!, textColor, secondaryTextColor);
        }
        return _buildArtistsGridView(textColor, secondaryTextColor);
      case DesktopNavSection.folders:
        return _buildFoldersManagementView(textColor, secondaryTextColor);
      case DesktopNavSection.hiddenTracks:
        return _buildHiddenTracksView(textColor, secondaryTextColor);
      case DesktopNavSection.profile:
        return _buildProfileDesktopView(textColor, secondaryTextColor);
      default:
        return _buildSongsTableView(textColor, secondaryTextColor);
    }
  }
}
