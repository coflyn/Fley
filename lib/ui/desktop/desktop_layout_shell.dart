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
  final void Function(String name, String trackId)? onRemoveFromPlaylist;
  final VoidCallback? onOpenSleepTimer;
  final VoidCallback? onOpenEqualizer;
  final void Function(Track track, String text)? onSaveManualLyrics;

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
    this.onRemoveFromPlaylist,
    this.onOpenSleepTimer,
    this.onOpenEqualizer,
    this.onSaveManualLyrics,
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
  int? _desktopSleepTimerMinutes;

  @override
  void initState() {
    super.initState();
    _loadCustomFolders();
    _loadSavedActiveSection();
    _volume = widget.player.volume;
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
    setState(() => _activeSection = section);
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

  // --- Modal Helpers for Ported Features ---

  void _showSongDetailsDialog(Track track) {
    showDialog(
      context: context,
      builder: (context) {
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
              const Text('Song Details', style: TextStyle(fontWeight: FontWeight.w700)),
            ],
          ),
          content: SizedBox(
            width: 440,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                infoRow('Title', track.title),
                infoRow('Artist', track.artist),
                infoRow('Album', track.album.isNotEmpty ? track.album : 'Unknown'),
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
              child: const Text('Close'),
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
        final isLight = widget.isLight;
        return AlertDialog(
          backgroundColor: isLight ? const Color(0xFFFAFAFD) : const Color(0xFF1E1E24),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: Row(
            children: [
              Icon(Icons.edit_note_rounded, color: widget.activeAccentColor),
              const SizedBox(width: 10),
              const Text('Edit Metadata', style: TextStyle(fontWeight: FontWeight.w700)),
            ],
          ),
          content: SizedBox(
            width: 400,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: titleCtrl,
                  decoration: const InputDecoration(labelText: 'Title'),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: artistCtrl,
                  decoration: const InputDecoration(labelText: 'Artist'),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: albumCtrl,
                  decoration: const InputDecoration(labelText: 'Album'),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancel'),
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
              child: const Text('Save'),
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
        final isLight = widget.isLight;
        final textColor = isLight ? const Color(0xFF1A1A1A) : Colors.white;

        return AlertDialog(
          backgroundColor: isLight ? const Color(0xFFFAFAFD) : const Color(0xFF1E1E24),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: const Text('Add to Playlist', style: TextStyle(fontWeight: FontWeight.w700)),
          content: SizedBox(
            width: 360,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                ListTile(
                  leading: Icon(Icons.add_circle_outline_rounded, color: widget.activeAccentColor),
                  title: Text(
                    'New Playlist',
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
                  const Padding(
                    padding: EdgeInsets.symmetric(vertical: 16),
                    child: Text('No custom playlists yet', style: TextStyle(color: Colors.white54)),
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
              child: const Text('Close'),
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
        final isLight = widget.isLight;
        return AlertDialog(
          backgroundColor: isLight ? const Color(0xFFFAFAFD) : const Color(0xFF1E1E24),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: const Text('Create New Playlist', style: TextStyle(fontWeight: FontWeight.w700)),
          content: TextField(
            controller: ctrl,
            autofocus: true,
            decoration: const InputDecoration(
              labelText: 'Playlist Name',
              hintText: 'e.g. Chill Vibes',
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancel'),
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
              child: const Text('Create'),
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
              const Text('Sleep Timer', style: TextStyle(fontWeight: FontWeight.w700)),
            ],
          ),
          content: SizedBox(
            width: 320,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                timerTile('15 minutes', 15),
                timerTile('30 minutes', 30),
                timerTile('45 minutes', 45),
                timerTile('60 minutes (1 hour)', 60),
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

  void _setDesktopSleepTimer(int minutes) {
    _desktopSleepTimer?.cancel();
    setState(() {
      _desktopSleepTimerMinutes = minutes > 0 ? minutes : null;
    });
    if (minutes > 0) {
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

  @override
  Widget build(BuildContext context) {
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

    return Scaffold(
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
    );
  }

  Widget _buildTopHeader(
    Color textColor,
    Color secondaryTextColor,
    Color borderColor,
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
                if (_activeSection != DesktopNavSection.songs) {
                  setState(() => _activeSection = DesktopNavSection.songs);
                }
              },
              onChanged: (val) {
                setState(() {
                  _searchQuery = val;
                  if (_activeSection != DesktopNavSection.songs) {
                    _activeSection = DesktopNavSection.songs;
                  }
                });
              },
              style: TextStyle(fontSize: 13.5, color: textColor),
              decoration: InputDecoration(
                hintText: 'Search songs, albums, artists...',
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
            '${_filteredTracks.length} tracks available',
            style: TextStyle(fontSize: 12.5, color: secondaryTextColor),
          ),
        ],
      ),
    );
  }

  Widget _buildMainContent(Color textColor, Color secondaryTextColor) {
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
      case DesktopNavSection.profile:
        return _buildProfileDesktopView(textColor, secondaryTextColor);
      default:
        return _buildSongsTableView(textColor, secondaryTextColor);
    }
  }
}
