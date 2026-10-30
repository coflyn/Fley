import 'dart:io';
import 'dart:math' as math;
import 'dart:ui';
import 'package:file_selector/file_selector.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:just_audio/just_audio.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../models/track.dart';
import '../../services/desktop_audio_scanner.dart';
import '../../utils/artwork_cache.dart';
import '../../utils/globals.dart';
import '../../widgets/desktop_title_bar.dart';

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
  bool _isFullscreenPlayerOpen = false;
  double _volume = 1.0;
  bool _isMuted = false;
  double _lastUnmutedVolume = 1.0;

  @override
  void initState() {
    super.initState();
    _loadCustomFolders();
    _volume = widget.player.volume;
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

  List<Track> get _currentFilterBaseTracks {
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
    final base = _currentFilterBaseTracks;
    if (_searchQuery.trim().isEmpty) return base;
    final q = _searchQuery.toLowerCase();
    return base.where((t) {
      return t.title.toLowerCase().contains(q) ||
          t.artist.toLowerCase().contains(q) ||
          t.album.toLowerCase().contains(q);
    }).toList();
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

  Widget _buildSidebar(
    Color textColor,
    Color secondaryTextColor,
    Color borderColor,
  ) {
    return Container(
      width: 240,
      decoration: BoxDecoration(
        color: widget.isLight
            ? Colors.black.withValues(alpha: 0.02)
            : Colors.white.withValues(alpha: 0.02),
        border: Border(right: BorderSide(color: borderColor)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SizedBox(height: 14),

          // App Branding with real logo
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 18),
            child: Row(
              children: [
                ClipRRect(
                  borderRadius: BorderRadius.circular(8),
                  child: Image.asset(
                    'assets/app_logo.png',
                    width: 30,
                    height: 30,
                    errorBuilder: (context, error, stackTrace) => Container(
                      width: 30,
                      height: 30,
                      decoration: BoxDecoration(
                        color: widget.activeAccentColor,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: const Icon(
                        Icons.music_note_rounded,
                        color: Colors.black,
                        size: 20,
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                Text(
                  'Fley',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w800,
                    color: textColor,
                    fontFamily: getFontFamily(),
                    letterSpacing: -0.4,
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(height: 20),

          // User Profile Card
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 14),
            child: ValueListenableBuilder<String>(
              valueListenable: userProfileNameNotifier,
              builder: (context, userName, _) {
                final isProfileSelected =
                    _activeSection == DesktopNavSection.profile;
                return InkWell(
                  borderRadius: BorderRadius.circular(10),
                  onTap: () {
                    setState(() {
                      _isFullscreenPlayerOpen = false;
                      _activeSection = DesktopNavSection.profile;
                    });
                  },
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 8,
                    ),
                    decoration: BoxDecoration(
                      color: isProfileSelected
                          ? widget.activeAccentColor.withValues(alpha: 0.15)
                          : (widget.isLight
                              ? Colors.black.withValues(alpha: 0.03)
                              : Colors.white.withValues(alpha: 0.04)),
                      borderRadius: BorderRadius.circular(10),
                      border: isProfileSelected
                          ? Border.all(
                              color: widget.activeAccentColor
                                  .withValues(alpha: 0.5),
                            )
                          : null,
                    ),
                    child: Row(
                      children: [
                        ValueListenableBuilder<String?>(
                          valueListenable: userProfileImageNotifier,
                          builder: (context, imagePath, _) {
                            final hasImage = imagePath != null &&
                                File(imagePath).existsSync();
                            return CircleAvatar(
                              radius: 14,
                              backgroundColor: widget.activeAccentColor
                                  .withValues(alpha: 0.2),
                              backgroundImage:
                                  hasImage ? FileImage(File(imagePath)) : null,
                              child: !hasImage
                                  ? Icon(
                                      Icons.person_rounded,
                                      size: 16,
                                      color: widget.activeAccentColor,
                                    )
                                  : null,
                            );
                          },
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Text(
                            userName.isNotEmpty ? userName : 'Fley User',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              fontSize: 12.5,
                              fontWeight: isProfileSelected
                                  ? FontWeight.w700
                                  : FontWeight.w600,
                              color: isProfileSelected
                                  ? widget.activeAccentColor
                                  : textColor,
                            ),
                          ),
                        ),
                        Icon(
                          Icons.chevron_right_rounded,
                          size: 16,
                          color: isProfileSelected
                              ? widget.activeAccentColor
                              : secondaryTextColor,
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
          ),

          const SizedBox(height: 16),

          // Scrollable Navigation & Library Items
          Expanded(
            child: SingleChildScrollView(
              physics: const BouncingScrollPhysics(),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Main Navigation Items
                  _buildNavItem(
                    icon: Icons.home_rounded,
                    label: 'Home',
                    section: DesktopNavSection.home,
                    textColor: textColor,
                  ),
                  _buildNavItem(
                    icon: Icons.music_note_rounded,
                    label: 'All Songs',
                    count: widget.allTracks.length,
                    section: DesktopNavSection.songs,
                    isSelectedOverride:
                        _activeSection == DesktopNavSection.songs &&
                            _activeSongFilter == SongFilter.all &&
                            _searchQuery.isEmpty,
                    textColor: textColor,
                    onCustomTap: () {
                      setState(() {
                        _searchQuery = '';
                        _searchController.clear();
                        _activeSongFilter = SongFilter.all;
                        _activeSection = DesktopNavSection.songs;
                      });
                    },
                  ),
                  _buildNavItem(
                    icon: Icons.album_outlined,
                    label: 'Albums',
                    section: DesktopNavSection.albums,
                    textColor: textColor,
                  ),
                  _buildNavItem(
                    icon: Icons.person_outline_rounded,
                    label: 'Artists',
                    section: DesktopNavSection.artists,
                    textColor: textColor,
                  ),
                  _buildNavItem(
                    icon: Icons.folder_open_rounded,
                    label: 'Music Folders',
                    section: DesktopNavSection.folders,
                    textColor: textColor,
                  ),

                  const SizedBox(height: 12),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 18),
                    child: Divider(color: borderColor, height: 1),
                  ),
                  const SizedBox(height: 12),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 18),
                    child: Text(
                      'COLLECTIONS',
                      style: TextStyle(
                        fontSize: 10.5,
                        fontWeight: FontWeight.w700,
                        color: secondaryTextColor,
                        letterSpacing: 1.2,
                      ),
                    ),
                  ),
                  const SizedBox(height: 6),
                  _buildNavItem(
                    icon: Icons.favorite_rounded,
                    label: 'Favourites',
                    count: _favoriteTracks.length,
                    section: DesktopNavSection.songs,
                    isSelectedOverride:
                        _activeSection == DesktopNavSection.songs &&
                            _activeSongFilter == SongFilter.favorites,
                    textColor: textColor,
                    onCustomTap: () {
                      setState(() {
                        _searchQuery = '';
                        _searchController.clear();
                        _activeSongFilter = SongFilter.favorites;
                        _activeSection = DesktopNavSection.songs;
                      });
                    },
                  ),
                  _buildNavItem(
                    icon: Icons.local_fire_department_rounded,
                    label: 'Most Played',
                    count: _mostPlayedTracks.length,
                    section: DesktopNavSection.songs,
                    isSelectedOverride:
                        _activeSection == DesktopNavSection.songs &&
                            _activeSongFilter == SongFilter.mostPlayed,
                    textColor: textColor,
                    onCustomTap: () {
                      setState(() {
                        _searchQuery = '';
                        _searchController.clear();
                        _activeSongFilter = SongFilter.mostPlayed;
                        _activeSection = DesktopNavSection.songs;
                      });
                    },
                  ),
                  _buildNavItem(
                    icon: Icons.new_releases_rounded,
                    label: 'Recently Added',
                    count: _recentlyAddedTracks.length,
                    section: DesktopNavSection.songs,
                    isSelectedOverride:
                        _activeSection == DesktopNavSection.songs &&
                            _activeSongFilter == SongFilter.recentlyAdded,
                    textColor: textColor,
                    onCustomTap: () {
                      setState(() {
                        _searchQuery = '';
                        _searchController.clear();
                        _activeSongFilter = SongFilter.recentlyAdded;
                        _activeSection = DesktopNavSection.songs;
                      });
                    },
                  ),
                  _buildNavItem(
                    icon: Icons.history_rounded,
                    label: 'Last Played',
                    count: _lastPlayedTracks.length,
                    section: DesktopNavSection.songs,
                    isSelectedOverride:
                        _activeSection == DesktopNavSection.songs &&
                            _activeSongFilter == SongFilter.lastPlayed,
                    textColor: textColor,
                    onCustomTap: () {
                      setState(() {
                        _searchQuery = '';
                        _searchController.clear();
                        _activeSongFilter = SongFilter.lastPlayed;
                        _activeSection = DesktopNavSection.songs;
                      });
                    },
                  ),
                  _buildNavItem(
                    icon: Icons.diamond_outlined,
                    label: 'Forgotten Gems',
                    count: _forgottenGemsTracks.length,
                    section: DesktopNavSection.songs,
                    isSelectedOverride:
                        _activeSection == DesktopNavSection.songs &&
                            _activeSongFilter == SongFilter.forgottenGems,
                    textColor: textColor,
                    onCustomTap: () {
                      setState(() {
                        _searchQuery = '';
                        _searchController.clear();
                        _activeSongFilter = SongFilter.forgottenGems;
                        _activeSection = DesktopNavSection.songs;
                      });
                    },
                  ),

                  if (widget.userPlaylists.isNotEmpty) ...[
                    const SizedBox(height: 12),
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 18),
                      child: Divider(color: borderColor, height: 1),
                    ),
                    const SizedBox(height: 12),
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 18),
                      child: Text(
                        'PLAYLISTS',
                        style: TextStyle(
                          fontSize: 10.5,
                          fontWeight: FontWeight.w700,
                          color: secondaryTextColor,
                          letterSpacing: 1.2,
                        ),
                      ),
                    ),
                    const SizedBox(height: 6),
                    ...widget.userPlaylists.keys.map(
                      (name) => _buildNavItem(
                        icon: Icons.queue_music_rounded,
                        label: name,
                        count: widget.userPlaylists[name]?.length,
                        section: DesktopNavSection.songs,
                        textColor: textColor,
                        onCustomTap: () {
                          setState(() {
                            _searchQuery = name;
                            _searchController.text = name;
                            _activeSection = DesktopNavSection.songs;
                          });
                        },
                      ),
                    ),
                  ],
                  const SizedBox(height: 8),
                ],
              ),
            ),
          ),

          // Bottom Settings & Rescan
          Padding(
            padding: const EdgeInsets.all(14),
            child: Column(
              children: [
                _buildSidebarActionBtn(
                  icon: Icons.refresh_rounded,
                  label: 'Rescan Library',
                  onTap: widget.onRescan,
                  textColor: secondaryTextColor,
                ),
                const SizedBox(height: 4),
                _buildSidebarActionBtn(
                  icon: Icons.settings_outlined,
                  label: 'Settings',
                  onTap: widget.onOpenSettings,
                  textColor: secondaryTextColor,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildNavItem({
    required IconData icon,
    required String label,
    int? count,
    required DesktopNavSection section,
    required Color textColor,
    bool? isSelectedOverride,
    VoidCallback? onCustomTap,
  }) {
    final isSelected = isSelectedOverride ?? (_activeSection == section);
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 2),
      child: InkWell(
        borderRadius: BorderRadius.circular(8),
        onTap: () {
          if (onCustomTap != null) {
            setState(() => _isFullscreenPlayerOpen = false);
            onCustomTap();
          } else {
            setState(() {
              _isFullscreenPlayerOpen = false;
              if (section == DesktopNavSection.albums) {
                _selectedAlbumName = null;
              }
              if (section == DesktopNavSection.artists) {
                _selectedArtistName = null;
              }
              _activeSection = section;
            });
          }
        },
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
          decoration: BoxDecoration(
            color: isSelected
                ? widget.activeAccentColor.withValues(alpha: 0.15)
                : Colors.transparent,
            borderRadius: BorderRadius.circular(8),
          ),
          child: Row(
            children: [
              Icon(
                icon,
                size: 20,
                color: isSelected ? widget.activeAccentColor : textColor,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  label,
                  style: TextStyle(
                    fontSize: 13.5,
                    fontWeight: isSelected ? FontWeight.w600 : FontWeight.w500,
                    color: isSelected ? widget.activeAccentColor : textColor,
                  ),
                ),
              ),
              if (count != null)
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 7,
                    vertical: 2,
                  ),
                  decoration: BoxDecoration(
                    color: isSelected
                        ? widget.activeAccentColor.withValues(alpha: 0.25)
                        : (widget.isLight
                            ? Colors.black.withValues(alpha: 0.05)
                            : Colors.white.withValues(alpha: 0.07)),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Text(
                    '$count',
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                      color: isSelected
                          ? widget.activeAccentColor
                          : textColor.withValues(alpha: 0.7),
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSidebarActionBtn({
    required IconData icon,
    required String label,
    required VoidCallback onTap,
    required Color textColor,
  }) {
    return InkWell(
      borderRadius: BorderRadius.circular(8),
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        child: Row(
          children: [
            Icon(icon, size: 18, color: textColor),
            const SizedBox(width: 10),
            Text(
              label,
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w500,
                color: textColor,
              ),
            ),
          ],
        ),
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

  /// Fley Signature Desktop Home Screen (Quick Pins + Banner + Rotation + Recents)
  Widget _buildDesktopHomeScreen(Color textColor, Color secondaryTextColor) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(28),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Banner Gif
          ClipRRect(
            borderRadius: BorderRadius.circular(16),
            child: SizedBox(
              height: 180,
              width: double.infinity,
              child: Image.asset(
                'assets/hey.gif',
                fit: BoxFit.cover,
                errorBuilder: (context, error, stackTrace) => Container(
                  color: widget.activeAccentColor.withValues(alpha: 0.2),
                  child: Center(
                    child: Icon(
                      Icons.music_note_rounded,
                      size: 48,
                      color: widget.activeAccentColor,
                    ),
                  ),
                ),
              ),
            ),
          ),

          const SizedBox(height: 28),

          // 4 Quick Pins Cards
          _buildQuickPinsGrid(textColor, secondaryTextColor),

          const SizedBox(height: 32),

          // Your Recent Rotation Section
          _buildRecentRotationSection(textColor, secondaryTextColor),

          const SizedBox(height: 32),

          // Recents Section (Playlists & Albums)
          _buildRecentsCarouselSection(textColor, secondaryTextColor),

          const SizedBox(height: 32),

          // Jump Back In Section
          _buildJumpBackInSection(textColor, secondaryTextColor),
        ],
      ),
    );
  }

  Widget _buildQuickPinsGrid(Color textColor, Color secondaryTextColor) {
    final quickItems = [
      (
        'Most Played',
        Icons.local_fire_department,
        const Color(0xFFF44336),
        _mostPlayedTracks,
        SongFilter.mostPlayed,
      ),
      (
        'Favourites',
        Icons.favorite,
        const Color(0xFFE91E63),
        _favoriteTracks,
        SongFilter.favorites,
      ),
      (
        'Recently Added',
        Icons.new_releases,
        const Color(0xFF2196F3),
        _recentlyAddedTracks,
        SongFilter.recentlyAdded,
      ),
      (
        'Forgotten Gems',
        Icons.diamond_outlined,
        const Color(0xFF9C27B0),
        _forgottenGemsTracks,
        SongFilter.forgottenGems,
      ),
    ];

    return LayoutBuilder(
      builder: (context, constraints) {
        final crossCount = constraints.maxWidth > 900 ? 4 : 2;
        return GridView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: crossCount,
            mainAxisExtent: 64,
            crossAxisSpacing: 14,
            mainAxisSpacing: 14,
          ),
          itemCount: quickItems.length,
          itemBuilder: (context, i) {
            final (title, icon, color, tracks, filter) = quickItems[i];
            final sampleTrack = tracks.firstOrNull;

            return InkWell(
              borderRadius: BorderRadius.circular(8),
              onTap: () {
                setState(() {
                  _activeSongFilter = filter;
                  _activeSection = DesktopNavSection.songs;
                  _searchQuery = '';
                  _searchController.clear();
                });
              },
              child: Container(
                decoration: BoxDecoration(
                  color: widget.isLight
                      ? Colors.black.withValues(alpha: 0.04)
                      : Colors.white.withValues(alpha: 0.06),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  children: [
                    ClipRRect(
                      borderRadius: const BorderRadius.horizontal(
                        left: Radius.circular(8),
                      ),
                      child: sampleTrack != null
                          ? _DesktopTrackArtwork(
                              track: sampleTrack,
                              size: 64,
                              radius: 0,
                            )
                          : Container(
                              width: 64,
                              height: 64,
                              color: color.withValues(alpha: 0.2),
                              child: Icon(icon, color: color, size: 28),
                            ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            title,
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
                            '${tracks.length} songs',
                            style: TextStyle(
                              fontSize: 11.5,
                              color: secondaryTextColor,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 12),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  Widget _buildRecentRotationSection(Color textColor, Color secondaryTextColor) {
    final trackMap = {for (var t in widget.allTracks) t.id: t};

    Track? resumeTrack;
    if (widget.playingTrack == null && widget.allPlayedTrackIdsOrdered.isNotEmpty) {
      for (final id in widget.allPlayedTrackIdsOrdered) {
        if (trackMap.containsKey(id)) {
          resumeTrack = trackMap[id];
          break;
        }
      }
      if (resumeTrack == null && widget.allTracks.isNotEmpty) {
        resumeTrack = widget.allTracks.first;
      }
    }

    final showResumeTile = widget.playingTrack == null && resumeTrack != null;
    final excludedId = showResumeTile ? resumeTrack.id : widget.playingTrack?.id;

    List<Track> recentTracks = widget.allPlayedTrackIdsOrdered
        .where((id) => trackMap.containsKey(id) && (excludedId == null || id != excludedId))
        .map((id) => trackMap[id]!)
        .take(4)
        .toList();

    if (recentTracks.isEmpty && widget.allTracks.isNotEmpty) {
      recentTracks = widget.allTracks
          .where((t) => excludedId == null || t.id != excludedId)
          .take(4)
          .toList();
    }

    if (!showResumeTile && recentTracks.isEmpty) return const SizedBox.shrink();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Your Recent Rotation',
          style: TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.w700,
            color: textColor,
            letterSpacing: -0.5,
          ),
        ),
        const SizedBox(height: 14),

        if (showResumeTile) ...[
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
            margin: const EdgeInsets.only(bottom: 14),
            decoration: BoxDecoration(
              color: widget.activeAccentColor.withValues(alpha: widget.isLight ? 0.08 : 0.12),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(
                color: widget.activeAccentColor.withValues(alpha: 0.25),
              ),
            ),
            child: Row(
              children: [
                _DesktopTrackArtwork(track: resumeTrack, size: 48, radius: 8),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        resumeTrack.title,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: 13.5,
                          fontWeight: FontWeight.w600,
                          color: textColor,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Row(
                        children: [
                          Icon(
                            Icons.history_rounded,
                            size: 13,
                            color: widget.activeAccentColor,
                          ),
                          const SizedBox(width: 4),
                          Text(
                            'Resume Playback Session',
                            style: TextStyle(
                              fontSize: 11.5,
                              fontWeight: FontWeight.w600,
                              color: widget.activeAccentColor,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                IconButton(
                  icon: Icon(
                    Icons.play_circle_filled_rounded,
                    color: widget.activeAccentColor,
                    size: 36,
                  ),
                  onPressed: () {
                    final idx = widget.allTracks.indexWhere((t) => t.id == resumeTrack?.id);
                    if (idx != -1) {
                      widget.onPlayTrack(
                        resumeTrack!,
                        widget.allTracks,
                        idx,
                      );
                    }
                  },
                ),
              ],
            ),
          ),
        ],

        LayoutBuilder(
          builder: (context, constraints) {
            final crossCount = constraints.maxWidth > 900 ? 4 : 2;
            return GridView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: crossCount,
                mainAxisExtent: 68,
                crossAxisSpacing: 12,
                mainAxisSpacing: 12,
              ),
              itemCount: recentTracks.length,
              itemBuilder: (context, i) {
                final track = recentTracks[i];
                final isPlayingThis = widget.playingTrack?.id == track.id;

                return InkWell(
                  borderRadius: BorderRadius.circular(8),
                  onTap: () {
                    final idx = widget.allTracks.indexWhere((t) => t.id == track.id);
                    widget.onPlayTrack(
                      track,
                      widget.allTracks,
                      idx != -1 ? idx : 0,
                    );
                  },
                  child: Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: widget.isLight
                          ? Colors.black.withValues(alpha: 0.03)
                          : Colors.white.withValues(alpha: 0.04),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Row(
                      children: [
                        _DesktopTrackArtwork(track: track, size: 52, radius: 6),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                track.title,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(
                                  fontSize: 12.5,
                                  fontWeight: FontWeight.w600,
                                  color: isPlayingThis
                                      ? widget.activeAccentColor
                                      : textColor,
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
                        Icon(
                          isPlayingThis
                              ? Icons.pause_circle_filled_rounded
                              : Icons.play_circle_filled_rounded,
                          color: widget.activeAccentColor,
                          size: 28,
                        ),
                      ],
                    ),
                  ),
                );
              },
            );
          },
        ),
      ],
    );
  }

  Widget _buildRecentsCarouselSection(Color textColor, Color secondaryTextColor) {
    List<Map<String, dynamic>> items = [];

    items.add({
      'title': 'Favourites',
      'subtitle': 'Playlist • ${_favoriteTracks.length} songs',
      'sampleTrack': _favoriteTracks.firstOrNull,
      'color': const Color(0xFFE91E63),
      'icon': Icons.favorite,
      'filter': SongFilter.favorites,
    });
    items.add({
      'title': 'Most Played',
      'subtitle': 'Playlist • ${_mostPlayedTracks.length} songs',
      'sampleTrack': _mostPlayedTracks.firstOrNull,
      'color': const Color(0xFFF44336),
      'icon': Icons.local_fire_department,
      'filter': SongFilter.mostPlayed,
    });
    items.add({
      'title': 'Recently Added',
      'subtitle': 'Playlist • ${_recentlyAddedTracks.length} songs',
      'sampleTrack': _recentlyAddedTracks.firstOrNull,
      'color': const Color(0xFF2196F3),
      'icon': Icons.new_releases,
      'filter': SongFilter.recentlyAdded,
    });
    items.add({
      'title': 'Last Played',
      'subtitle': 'Playlist • ${_lastPlayedTracks.length} songs',
      'sampleTrack': _lastPlayedTracks.firstOrNull,
      'color': const Color(0xFFFF9800),
      'icon': Icons.history_rounded,
      'filter': SongFilter.lastPlayed,
    });
    items.add({
      'title': 'Forgotten Gems',
      'subtitle': 'Playlist • ${_forgottenGemsTracks.length} songs',
      'sampleTrack': _forgottenGemsTracks.firstOrNull,
      'color': const Color(0xFF9C27B0),
      'icon': Icons.diamond_outlined,
      'filter': SongFilter.forgottenGems,
    });

    for (var entry in widget.userPlaylists.entries) {
      final pSongs = entry.value;
      final sample = pSongs.isNotEmpty
          ? widget.allTracks.firstWhere(
              (t) => t.id == pSongs.first,
              orElse: () => widget.allTracks.first,
            )
          : null;
      items.add({
        'title': entry.key,
        'subtitle': 'Playlist • ${pSongs.length} songs',
        'sampleTrack': sample,
        'color': widget.activeAccentColor,
        'icon': Icons.queue_music,
        'playlistTracks': widget.allTracks.where((t) => pSongs.contains(t.id)).toList(),
      });
    }

    final seenAlbums = <String>{};
    for (var track in widget.allTracks) {
      if (track.album.isNotEmpty && seenAlbums.add(track.album)) {
        items.add({
          'title': track.album,
          'subtitle': 'Album • ${track.artist}',
          'sampleTrack': track,
          'albumName': track.album,
        });
        if (seenAlbums.length >= 6) break;
      }
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Recents',
          style: TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.w700,
            color: textColor,
            letterSpacing: -0.5,
          ),
        ),
        const SizedBox(height: 14),
        SizedBox(
          height: 195,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            itemCount: items.length,
            separatorBuilder: (_, _) => const SizedBox(width: 14),
            itemBuilder: (context, i) {
              final item = items[i];
              final title = item['title'] as String;
              final subtitle = item['subtitle'] as String;
              final Track? sampleTrack = item['sampleTrack'];
              final IconData? icon = item['icon'];
              final Color color = item['color'] ?? widget.activeAccentColor;
              final SongFilter? filter = item['filter'];
              final String? albumName = item['albumName'];
              final List<Track>? pTracks = item['playlistTracks'];

              return SizedBox(
                width: 140,
                child: InkWell(
                  borderRadius: BorderRadius.circular(10),
                  onTap: () {
                    if (filter != null) {
                      setState(() {
                        _activeSongFilter = filter;
                        _activeSection = DesktopNavSection.songs;
                      });
                    } else if (albumName != null) {
                      setState(() {
                        _selectedAlbumName = albumName;
                        _activeSection = DesktopNavSection.albums;
                        _isFullscreenPlayerOpen = false;
                      });
                    } else if (pTracks != null && pTracks.isNotEmpty) {
                      widget.onPlayTrack(pTracks.first, pTracks, 0);
                    }
                  },
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      sampleTrack != null
                          ? _DesktopTrackArtwork(
                              track: sampleTrack,
                              size: 140,
                              radius: 10,
                            )
                          : Container(
                              width: 140,
                              height: 140,
                              decoration: BoxDecoration(
                                color: color.withValues(alpha: 0.15),
                                borderRadius: BorderRadius.circular(10),
                              ),
                              child: Icon(icon ?? Icons.music_note, color: color, size: 48),
                            ),
                      const SizedBox(height: 8),
                      Text(
                        title,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                          color: textColor,
                        ),
                      ),
                      Text(
                        subtitle,
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
              );
            },
          ),
        ),
      ],
    );
  }

  Widget _buildJumpBackInSection(Color textColor, Color secondaryTextColor) {
    if (widget.allTracks.isEmpty) return const SizedBox.shrink();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Jump Back In',
          style: TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.w700,
            color: textColor,
            letterSpacing: -0.5,
          ),
        ),
        const SizedBox(height: 14),
        SizedBox(
          height: 195,
          child: ListView.builder(
            scrollDirection: Axis.horizontal,
            itemCount: widget.allTracks.length > 15
                ? 15
                : widget.allTracks.length,
            itemBuilder: (context, index) {
              final track = widget.allTracks[index];
              return Container(
                width: 140,
                margin: const EdgeInsets.only(right: 14),
                child: InkWell(
                  borderRadius: BorderRadius.circular(10),
                  onTap: () => widget.onPlayTrack(
                    track,
                    widget.allTracks,
                    index,
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _DesktopTrackArtwork(
                        track: track,
                        size: 140,
                        radius: 10,
                      ),
                      const SizedBox(height: 8),
                      Text(
                        track.title,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                          color: textColor,
                        ),
                      ),
                      Text(
                        track.artist,
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
              );
            },
          ),
        ),
      ],
    );
  }

  Widget _buildSongsTableView(Color textColor, Color secondaryTextColor) {
    final tracks = _filteredTracks;
    final totalDurationMs = tracks.fold<int>(0, (sum, t) => sum + t.duration);

    // Metadata & Cover for the Album-View Header
    String categoryName = 'COLLECTION';
    String title = 'All Songs';
    Widget coverWidget;

    if (_searchQuery.isNotEmpty) {
      categoryName = 'SEARCH RESULTS';
      title = '"$_searchQuery"';
      coverWidget = Container(
        width: 170,
        height: 170,
        decoration: BoxDecoration(
          color: widget.activeAccentColor.withValues(alpha: 0.15),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Icon(
          Icons.search_rounded,
          size: 64,
          color: widget.activeAccentColor,
        ),
      );
    } else {
      Widget buildCollectionCover(IconData fallbackIcon, List<Color> fallbackColors) {
        if (tracks.isNotEmpty) {
          return Container(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(12),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.35),
                  blurRadius: 20,
                  offset: const Offset(0, 8),
                ),
              ],
            ),
            child: _DesktopTrackArtwork(
              track: tracks.first,
              size: 170,
              radius: 12,
            ),
          );
        }
        return Container(
          width: 170,
          height: 170,
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: fallbackColors,
            ),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Center(
            child: Icon(fallbackIcon, size: 68, color: Colors.white),
          ),
        );
      }

      switch (_activeSongFilter) {
        case SongFilter.all:
          categoryName = 'COLLECTION';
          title = 'All Songs';
          coverWidget = buildCollectionCover(
            Icons.music_note_rounded,
            [
              widget.activeAccentColor.withValues(alpha: 0.4),
              widget.activeAccentColor,
            ],
          );
          break;
        case SongFilter.favorites:
          categoryName = 'COLLECTION';
          title = 'Favourites';
          coverWidget = buildCollectionCover(
            Icons.favorite_rounded,
            const [Color(0xFFE91E63), Color(0xFF9C27B0)],
          );
          break;
        case SongFilter.mostPlayed:
          categoryName = 'COLLECTION';
          title = 'Most Played';
          coverWidget = buildCollectionCover(
            Icons.local_fire_department_rounded,
            const [Color(0xFFF44336), Color(0xFFFF9800)],
          );
          break;
        case SongFilter.recentlyAdded:
          categoryName = 'COLLECTION';
          title = 'Recently Added';
          coverWidget = buildCollectionCover(
            Icons.new_releases_rounded,
            const [Color(0xFF2196F3), Color(0xFF00BCD4)],
          );
          break;
        case SongFilter.lastPlayed:
          categoryName = 'COLLECTION';
          title = 'Last Played';
          coverWidget = buildCollectionCover(
            Icons.history_rounded,
            const [Color(0xFFFF9800), Color(0xFFFFC107)],
          );
          break;
        case SongFilter.forgottenGems:
          categoryName = 'COLLECTION';
          title = 'Forgotten Gems';
          coverWidget = buildCollectionCover(
            Icons.diamond_outlined,
            const [Color(0xFF9C27B0), Color(0xFF673AB7)],
          );
          break;
      }
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Album/Collection Style Header
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              coverWidget,
              const SizedBox(width: 24),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      categoryName,
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w800,
                        letterSpacing: 1.5,
                        color: widget.activeAccentColor,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      title,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 32,
                        fontWeight: FontWeight.bold,
                        color: textColor,
                        height: 1.15,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      '${tracks.length} songs • ${_formatTotalAlbumDuration(totalDurationMs)}',
                      style: TextStyle(
                        fontSize: 12.5,
                        color: secondaryTextColor,
                      ),
                    ),
                    const SizedBox(height: 18),
                    Row(
                      children: [
                        FilledButton.icon(
                          onPressed: () {
                            if (tracks.isNotEmpty) {
                              widget.onPlayTrack(tracks.first, tracks, 0);
                            }
                          },
                          icon: const Icon(Icons.play_arrow_rounded, size: 20),
                          label: const Text('Play'),
                          style: FilledButton.styleFrom(
                            backgroundColor: widget.activeAccentColor,
                            foregroundColor: Colors.black,
                            padding: const EdgeInsets.symmetric(
                              horizontal: 24,
                              vertical: 12,
                            ),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(24),
                            ),
                          ),
                        ),
                        const SizedBox(width: 12),
                        OutlinedButton.icon(
                          onPressed: () {
                            if (tracks.isNotEmpty) {
                              final shuffled = List<Track>.from(tracks)
                                ..shuffle();
                              widget.onPlayTrack(shuffled.first, shuffled, 0);
                            }
                          },
                          icon: const Icon(Icons.shuffle_rounded, size: 18),
                          label: const Text('Shuffle'),
                          style: OutlinedButton.styleFrom(
                            foregroundColor: textColor,
                            side: BorderSide(
                              color: widget.isLight
                                  ? Colors.black12
                                  : Colors.white24,
                            ),
                            padding: const EdgeInsets.symmetric(
                              horizontal: 20,
                              vertical: 12,
                            ),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(24),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),

        const SizedBox(height: 8),
        Divider(
          color: widget.isLight
              ? Colors.black.withValues(alpha: 0.06)
              : Colors.white.withValues(alpha: 0.06),
          height: 1,
        ),

        if (tracks.isEmpty)
          Expanded(
            child: Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    Icons.music_off_outlined,
                    size: 48,
                    color: secondaryTextColor,
                  ),
                  const SizedBox(height: 12),
                  Text(
                    'No tracks found in this category',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                      color: textColor,
                    ),
                  ),
                ],
              ),
            ),
          )
        else ...[
          // Table Header
          Container(
            height: 38,
            padding: const EdgeInsets.symmetric(horizontal: 24),
          decoration: BoxDecoration(
            border: Border(
              bottom: BorderSide(
                color: widget.isLight
                    ? Colors.black.withValues(alpha: 0.06)
                    : Colors.white.withValues(alpha: 0.06),
              ),
            ),
          ),
          child: Row(
            children: [
              SizedBox(
                width: 36,
                child: Center(
                  child: Text(
                    '#',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: secondaryTextColor,
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                flex: 4,
                child: Text(
                  'TITLE',
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    color: secondaryTextColor,
                    letterSpacing: 0.8,
                  ),
                ),
              ),
              Expanded(
                flex: 3,
                child: Text(
                  'ALBUM',
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    color: secondaryTextColor,
                    letterSpacing: 0.8,
                  ),
                ),
              ),
              SizedBox(
                width: 70,
                child: Text(
                  'TIME',
                  textAlign: TextAlign.right,
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    color: secondaryTextColor,
                    letterSpacing: 0.8,
                  ),
                ),
              ),
              const SizedBox(width: 48),
            ],
          ),
        ),

        // Table Rows
        Expanded(
          child: StreamBuilder<PlayerState>(
            stream: widget.player.playerStateStream,
            builder: (context, snapshot) {
              final isAudioPlaying =
                  snapshot.data?.playing ?? widget.player.playing;

              return ListView.builder(
                itemCount: tracks.length,
                padding: const EdgeInsets.symmetric(vertical: 4),
                itemBuilder: (context, index) {
                  final track = tracks[index];
                  final isCurrentTrack = widget.playingTrack?.id == track.id;
                  final isFav = widget.favoriteTrackIds.contains(track.id);

                  return _DesktopSongRow(
                    index: index + 1,
                    track: track,
                    isCurrentTrack: isCurrentTrack,
                    isPlaying: isCurrentTrack && isAudioPlaying,
                    isFavorite: isFav,
                    activeAccentColor: widget.activeAccentColor,
                    textColor: textColor,
                    secondaryTextColor: secondaryTextColor,
                    isLight: widget.isLight,
                    onTap: () => widget.onPlayTrack(track, tracks, index),
                    onToggleFavorite: () => widget.onToggleFavorite(track.id),
                    onArtistTap: (artist) {
                      setState(() {
                        _selectedArtistName = artist;
                        _activeSection = DesktopNavSection.artists;
                      });
                    },
                    onAlbumTap: (album) {
                      setState(() {
                        _selectedAlbumName = album;
                        _activeSection = DesktopNavSection.albums;
                      });
                    },
                  );
                },
              );
            },
          ),
        ),
      ],
    ],
  );
}

  Widget _buildAlbumsGridView(Color textColor, Color secondaryTextColor) {
    final Map<String, List<Track>> albumGroups = {};
    for (final track in widget.allTracks) {
      albumGroups.putIfAbsent(track.album, () => []).add(track);
    }
    final albums = albumGroups.keys.toList()..sort();

    return GridView.builder(
      padding: const EdgeInsets.all(24),
      gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
        maxCrossAxisExtent: 200,
        mainAxisSpacing: 20,
        crossAxisSpacing: 20,
        childAspectRatio: 0.78,
      ),
      itemCount: albums.length,
      itemBuilder: (context, index) {
        final albumName = albums[index];
        final tracks = albumGroups[albumName] ?? [];
        final firstTrack = tracks.isNotEmpty ? tracks.first : null;

        return InkWell(
          borderRadius: BorderRadius.circular(10),
          onTap: () {
            setState(() {
              _selectedAlbumName = albumName;
            });
          },
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: firstTrack != null
                    ? _DesktopTrackArtwork(
                        track: firstTrack,
                        size: 200,
                        radius: 10,
                      )
                    : Container(
                        decoration: BoxDecoration(
                          color: widget.isLight
                              ? Colors.black.withValues(alpha: 0.05)
                              : Colors.white.withValues(alpha: 0.05),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: const Center(
                          child: Icon(Icons.album_rounded, size: 40),
                        ),
                      ),
              ),
              const SizedBox(height: 10),
              Text(
                albumName,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontSize: 13.5,
                  fontWeight: FontWeight.w600,
                  color: textColor,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                '${tracks.length} songs',
                style: TextStyle(
                  fontSize: 12,
                  color: secondaryTextColor,
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildArtistsGridView(Color textColor, Color secondaryTextColor) {
    final Map<String, List<Track>> artistGroups = {};
    for (final track in widget.allTracks) {
      artistGroups.putIfAbsent(track.artist, () => []).add(track);
    }
    final artists = artistGroups.keys.toList()..sort();

    return GridView.builder(
      padding: const EdgeInsets.all(24),
      gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
        maxCrossAxisExtent: 180,
        mainAxisSpacing: 20,
        crossAxisSpacing: 20,
        childAspectRatio: 0.82,
      ),
      itemCount: artists.length,
      itemBuilder: (context, index) {
        final artistName = artists[index];
        final tracks = artistGroups[artistName] ?? [];
        final firstTrack = tracks.isNotEmpty ? tracks.first : null;

        return InkWell(
          borderRadius: BorderRadius.circular(10),
          onTap: () {
            setState(() {
              _selectedArtistName = artistName;
            });
          },
          child: Column(
            children: [
              Expanded(
                child: firstTrack != null
                    ? Center(
                        child: AspectRatio(
                          aspectRatio: 1,
                          child: ClipOval(
                            child: _DesktopTrackArtwork(
                              track: firstTrack,
                              size: 160,
                              radius: 80,
                            ),
                          ),
                        ),
                      )
                    : CircleAvatar(
                        radius: 70,
                        backgroundColor: widget.isLight
                            ? Colors.black.withValues(alpha: 0.05)
                            : Colors.white.withValues(alpha: 0.05),
                        child: Icon(
                          Icons.person_rounded,
                          size: 48,
                          color: widget.activeAccentColor,
                        ),
                      ),
              ),
              const SizedBox(height: 10),
              Text(
                artistName,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 13.5,
                  fontWeight: FontWeight.w600,
                  color: textColor,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                '${tracks.length} songs',
                style: TextStyle(fontSize: 12, color: secondaryTextColor),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildFoldersManagementView(
    Color textColor,
    Color secondaryTextColor,
  ) {
    final defaultDirs = DesktopAudioScanner.getDefaultMusicDirectories();

    return Padding(
      padding: const EdgeInsets.all(28),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Music Folders',
                    style: TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.w700,
                      color: textColor,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Configure directories scanned for audio files on your computer',
                    style: TextStyle(fontSize: 13.5, color: secondaryTextColor),
                  ),
                ],
              ),
              const Spacer(),
              ElevatedButton.icon(
                style: ElevatedButton.styleFrom(
                  backgroundColor: widget.activeAccentColor,
                  foregroundColor: Colors.black,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 12,
                  ),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
                icon: const Icon(Icons.add_rounded, size: 20),
                label: const Text(
                  'Add Folder',
                  style: TextStyle(fontWeight: FontWeight.w600),
                ),
                onPressed: () async {
                  final added =
                      await DesktopAudioScanner.pickAndAddMusicFolder();
                  if (added != null) {
                    await _loadCustomFolders();
                    widget.onRescan();
                  }
                },
              ),
            ],
          ),
          const SizedBox(height: 24),

          Text(
            'DEFAULT DIRECTORIES',
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w700,
              color: secondaryTextColor,
              letterSpacing: 1.0,
            ),
          ),
          const SizedBox(height: 8),
          ...defaultDirs.map(
            (dir) => Container(
              margin: const EdgeInsets.only(bottom: 8),
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              decoration: BoxDecoration(
                color: widget.isLight
                    ? Colors.black.withValues(alpha: 0.03)
                    : Colors.white.withValues(alpha: 0.04),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Row(
                children: [
                  const Icon(Icons.folder_special_rounded, size: 20),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      dir,
                      style: TextStyle(fontSize: 13.5, color: textColor),
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 2,
                    ),
                    decoration: BoxDecoration(
                      color: widget.isLight
                          ? Colors.black.withValues(alpha: 0.06)
                          : Colors.white.withValues(alpha: 0.08),
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: Text(
                      'System',
                      style: TextStyle(
                        fontSize: 11,
                        color: secondaryTextColor,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),

          const SizedBox(height: 20),
          Text(
            'CUSTOM DIRECTORIES',
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w700,
              color: secondaryTextColor,
              letterSpacing: 1.0,
            ),
          ),
          const SizedBox(height: 8),
          if (_customFolders.isEmpty)
            Text(
              'No custom folders added yet. Click "Add Folder" to add another music directory.',
              style: TextStyle(
                fontSize: 13,
                color: secondaryTextColor,
                fontStyle: FontStyle.italic,
              ),
            )
          else
            ..._customFolders.map(
              (path) => Container(
                margin: const EdgeInsets.only(bottom: 8),
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 8,
                ),
                decoration: BoxDecoration(
                  color: widget.isLight
                      ? Colors.black.withValues(alpha: 0.03)
                      : Colors.white.withValues(alpha: 0.04),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.folder_rounded, size: 20),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        path,
                        style: TextStyle(fontSize: 13.5, color: textColor),
                      ),
                    ),
                    IconButton(
                      icon: const Icon(
                        Icons.delete_outline_rounded,
                        size: 18,
                        color: Colors.redAccent,
                      ),
                      onPressed: () async {
                        await DesktopAudioScanner.removeCustomDirectory(path);
                        await _loadCustomFolders();
                        widget.onRescan();
                      },
                    ),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildQueueSidePanel(
    Color textColor,
    Color secondaryTextColor,
    Color borderColor, {
    bool isFloatingInFullscreen = false,
  }) {
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
                      'Play Queue',
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
                          'NOW PLAYING',
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
                            'NEXT UP (${upcomingTracks.length})',
                            style: TextStyle(
                              fontSize: 10.5,
                              fontWeight: FontWeight.w700,
                              letterSpacing: 0.8,
                              color: secondaryTextColor,
                            ),
                          ),
                          if (upcomingTracks.isNotEmpty)
                            Text(
                              '${upcomingTracks.length} songs',
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
                                'No upcoming songs',
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
                      ...List.generate(upcomingTracks.length, (uIndex) {
                        final track = upcomingTracks[uIndex];
                        final queueIndex = currentIndex != -1
                            ? currentIndex + 1 + uIndex
                            : uIndex;

                        return Padding(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 10,
                            vertical: 2,
                          ),
                          child: InkWell(
                            borderRadius: BorderRadius.circular(8),
                            onTap: () => widget.onPlayTrack(track, queue, queueIndex),
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
                                      crossAxisAlignment: CrossAxisAlignment.start,
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
                                  const SizedBox(width: 8),
                                  Text(
                                    _formatDuration(track.duration),
                                    style: TextStyle(
                                      fontSize: 11,
                                      color: secondaryTextColor
                                          .withValues(alpha: 0.7),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        );
                      }),

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

  Widget _buildPersistentBottomPlayer(
    Color textColor,
    Color secondaryTextColor,
    Color borderColor,
  ) {
    final track = widget.playingTrack;

    return Container(
      height: 88,
      padding: const EdgeInsets.symmetric(horizontal: 20),
      decoration: BoxDecoration(
        color: widget.isLight
            ? Colors.white.withValues(alpha: 0.98)
            : const Color(0xFF161618),
        border: Border(top: BorderSide(color: borderColor)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.15),
            blurRadius: 10,
            offset: const Offset(0, -2),
          ),
        ],
      ),
      child: Row(
        children: [
          // Left: Track Info & Artwork
          Expanded(
            flex: 3,
            child: track != null
                ? Row(
                    children: [
                      InkWell(
                        borderRadius: BorderRadius.circular(8),
                        onTap: () => setState(() => _isFullscreenPlayerOpen = !_isFullscreenPlayerOpen),
                        child: _DesktopTrackArtwork(
                          track: track,
                          size: 52,
                          radius: 8,
                        ),
                      ),
                      const SizedBox(width: 14),
                      Expanded(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            InkWell(
                              borderRadius: BorderRadius.circular(4),
                              onTap: () => setState(() => _isFullscreenPlayerOpen = !_isFullscreenPlayerOpen),
                              child: Text(
                                track.title,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(
                                  fontSize: 13.5,
                                  fontWeight: FontWeight.w600,
                                  color: textColor,
                                ),
                              ),
                            ),
                            const SizedBox(height: 2),
                            InkWell(
                              borderRadius: BorderRadius.circular(4),
                              onTap: () {
                                setState(() {
                                  _isFullscreenPlayerOpen = false;
                                  _selectedArtistName = track.artist;
                                  _activeSection = DesktopNavSection.artists;
                                });
                              },
                              child: Text(
                                track.artist,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(
                                  fontSize: 12,
                                  color: secondaryTextColor,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                      IconButton(
                        icon: Icon(
                          widget.favoriteTrackIds.contains(track.id)
                              ? Icons.favorite_rounded
                              : Icons.favorite_border_rounded,
                          size: 20,
                          color: widget.favoriteTrackIds.contains(track.id)
                              ? Colors.redAccent
                              : secondaryTextColor,
                        ),
                        onPressed: () => widget.onToggleFavorite(track.id),
                      ),
                    ],
                  )
                : const SizedBox.shrink(),
          ),

          // Center: Playback Controls & Progress Bar
          Expanded(
            flex: 5,
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                // Buttons
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    // Shuffle
                    StreamBuilder<bool>(
                      stream: widget.player.shuffleModeEnabledStream,
                      builder: (context, snapshot) {
                        final isShuffle = snapshot.data ?? false;
                        return IconButton(
                          icon: Icon(
                            Icons.shuffle_rounded,
                            size: 19,
                            color: isShuffle
                                ? widget.activeAccentColor
                                : secondaryTextColor,
                          ),
                          onPressed: () async {
                            final next = !isShuffle;
                            await widget.player.setShuffleModeEnabled(next);
                          },
                        );
                      },
                    ),
                    IconButton(
                      icon: const Icon(Icons.skip_previous_rounded, size: 24),
                      color: textColor,
                      onPressed: widget.onPlayPrevious,
                    ),
                    const SizedBox(width: 6),
                    // Large Play/Pause with Glow
                    StreamBuilder<PlayerState>(
                      stream: widget.player.playerStateStream,
                      builder: (context, snapshot) {
                        final isPlaying = snapshot.data?.playing ?? false;
                        return GestureDetector(
                          onTap: widget.onTogglePlayPause,
                          child: Container(
                            width: 40,
                            height: 40,
                            decoration: BoxDecoration(
                              color: widget.activeAccentColor,
                              shape: BoxShape.circle,
                              boxShadow: [
                                BoxShadow(
                                  color: widget.activeAccentColor.withValues(
                                    alpha: 0.4,
                                  ),
                                  blurRadius: 8,
                                  offset: const Offset(0, 2),
                                ),
                              ],
                            ),
                            child: Icon(
                              isPlaying
                                  ? Icons.pause_rounded
                                  : Icons.play_arrow_rounded,
                              size: 26,
                              color: Colors.black,
                            ),
                          ),
                        );
                      },
                    ),
                    const SizedBox(width: 6),
                    IconButton(
                      icon: const Icon(Icons.skip_next_rounded, size: 24),
                      color: textColor,
                      onPressed: widget.onPlayNext,
                    ),
                    // Repeat
                    StreamBuilder<LoopMode>(
                      stream: widget.player.loopModeStream,
                      builder: (context, snapshot) {
                        final loopMode = snapshot.data ?? LoopMode.off;
                        final isRepeat = loopMode != LoopMode.off;
                        return IconButton(
                          icon: Icon(
                            loopMode == LoopMode.one
                                ? Icons.repeat_one_rounded
                                : Icons.repeat_rounded,
                            size: 19,
                            color: isRepeat
                                ? widget.activeAccentColor
                                : secondaryTextColor,
                          ),
                          onPressed: () async {
                            final next = loopMode == LoopMode.off
                                ? LoopMode.all
                                : loopMode == LoopMode.all
                                    ? LoopMode.one
                                    : LoopMode.off;
                            await widget.player.setLoopMode(next);
                          },
                        );
                      },
                    ),
                  ],
                ),

                // Seek Bar Slider
                StreamBuilder<Duration>(
                  stream: widget.player.positionStream,
                  builder: (context, posSnapshot) {
                    final position = posSnapshot.data ?? Duration.zero;
                    final totalDuration = widget.player.duration ??
                        Duration(milliseconds: track?.duration ?? 0);

                    final maxMs = totalDuration.inMilliseconds.toDouble();
                    final posMs = position.inMilliseconds
                        .toDouble()
                        .clamp(0.0, maxMs > 0 ? maxMs : 1.0);

                    return SizedBox(
                      height: 20,
                      child: Row(
                        children: [
                          Text(
                            _formatDuration(position.inMilliseconds),
                            style: TextStyle(
                              fontSize: 11,
                              color: secondaryTextColor,
                            ),
                          ),
                          Expanded(
                            child: SliderTheme(
                              data: SliderThemeData(
                                trackHeight: 3.5,
                                thumbShape: const RoundSliderThumbShape(
                                  enabledThumbRadius: 5,
                                ),
                                overlayShape: const RoundSliderOverlayShape(
                                  overlayRadius: 10,
                                ),
                                activeTrackColor: widget.activeAccentColor,
                                inactiveTrackColor: widget.isLight
                                    ? Colors.black.withValues(alpha: 0.1)
                                    : Colors.white.withValues(alpha: 0.1),
                                thumbColor: textColor,
                              ),
                              child: Slider(
                                value: posMs,
                                min: 0.0,
                                max: maxMs > 0 ? maxMs : 1.0,
                                onChanged: (val) {
                                  widget.player.seek(
                                    Duration(milliseconds: val.round()),
                                  );
                                },
                              ),
                            ),
                          ),
                          Text(
                            _formatDuration(totalDuration.inMilliseconds),
                            style: TextStyle(
                              fontSize: 11,
                              color: secondaryTextColor,
                            ),
                          ),
                        ],
                      ),
                    );
                  },
                ),
              ],
            ),
          ),

          // Right: Volume Slider & Queue Toggle
          Expanded(
            flex: 3,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                IconButton(
                  icon: Icon(
                    _isFullscreenPlayerOpen
                        ? Icons.fullscreen_exit_rounded
                        : Icons.fullscreen_rounded,
                    size: 22,
                  ),
                  tooltip: _isFullscreenPlayerOpen
                      ? 'Exit Full Screen'
                      : 'Full Screen',
                  color: _isFullscreenPlayerOpen
                      ? widget.activeAccentColor
                      : secondaryTextColor,
                  onPressed: () => setState(
                    () => _isFullscreenPlayerOpen = !_isFullscreenPlayerOpen,
                  ),
                ),
                IconButton(
                  icon: Icon(
                    _isQueueOpen
                        ? Icons.queue_music_rounded
                        : Icons.queue_music_outlined,
                    size: 20,
                    color: _isQueueOpen
                        ? widget.activeAccentColor
                        : secondaryTextColor,
                  ),
                  tooltip: 'Queue',
                  onPressed: () =>
                      setState(() => _isQueueOpen = !_isQueueOpen),
                ),
                IconButton(
                  icon: Icon(
                    _isMuted || _volume == 0
                        ? Icons.volume_off_rounded
                        : _volume < 0.5
                            ? Icons.volume_down_rounded
                            : Icons.volume_up_rounded,
                    size: 20,
                    color: secondaryTextColor,
                  ),
                  onPressed: () {
                    if (_isMuted) {
                      widget.player.setVolume(_lastUnmutedVolume);
                      setState(() {
                        _volume = _lastUnmutedVolume;
                        _isMuted = false;
                      });
                    } else {
                      _lastUnmutedVolume = _volume > 0 ? _volume : 1.0;
                      widget.player.setVolume(0);
                      setState(() {
                        _volume = 0;
                        _isMuted = true;
                      });
                    }
                  },
                ),
                SizedBox(
                  width: 90,
                  child: SliderTheme(
                    data: SliderThemeData(
                      trackHeight: 3.5,
                      thumbShape: const RoundSliderThumbShape(
                        enabledThumbRadius: 4,
                      ),
                      overlayShape: const RoundSliderOverlayShape(
                        overlayRadius: 8,
                      ),
                      activeTrackColor: widget.activeAccentColor,
                      inactiveTrackColor: widget.isLight
                          ? Colors.black.withValues(alpha: 0.1)
                          : Colors.white.withValues(alpha: 0.1),
                      thumbColor: textColor,
                    ),
                    child: Slider(
                      value: _volume,
                      min: 0.0,
                      max: 1.0,
                      onChanged: (val) {
                        widget.player.setVolume(val);
                        setState(() {
                          _volume = val;
                          _isMuted = val == 0;
                        });
                      },
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  String _formatTotalAlbumDuration(int ms) {
    if (ms <= 0) return '0 min';
    final duration = Duration(milliseconds: ms);
    final hours = duration.inHours;
    final minutes = duration.inMinutes.remainder(60);
    final seconds = duration.inSeconds.remainder(60);
    if (hours > 0) {
      return '$hours hr $minutes min';
    }
    return '$minutes min $seconds sec';
  }

  Widget _buildAlbumDetailView(
    String albumName,
    Color textColor,
    Color secondaryTextColor,
  ) {
    final albumTracks = widget.allTracks
        .where((t) => t.album.toLowerCase() == albumName.toLowerCase())
        .toList();
    final firstTrack = albumTracks.isNotEmpty ? albumTracks.first : null;
    final totalDurationMs =
        albumTracks.fold<int>(0, (sum, t) => sum + t.duration);
    final artistName = firstTrack?.artist ?? 'Various Artists';

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Top breadcrumb / Back Button
        Padding(
          padding: const EdgeInsets.only(left: 20, top: 16, bottom: 4),
          child: InkWell(
            borderRadius: BorderRadius.circular(8),
            onTap: () => setState(() => _selectedAlbumName = null),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    Icons.arrow_back_rounded,
                    size: 18,
                    color: secondaryTextColor,
                  ),
                  const SizedBox(width: 8),
                  Text(
                    'Albums',
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: secondaryTextColor,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),

        // Album Header
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              if (firstTrack != null)
                _DesktopTrackArtwork(
                  track: firstTrack,
                  size: 180,
                  radius: 12,
                )
              else
                Container(
                  width: 180,
                  height: 180,
                  decoration: BoxDecoration(
                    color: widget.isLight
                        ? Colors.black.withValues(alpha: 0.05)
                        : Colors.white.withValues(alpha: 0.05),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Center(
                    child: Icon(Icons.album_rounded, size: 64),
                  ),
                ),
              const SizedBox(width: 24),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      'ALBUM',
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w800,
                        letterSpacing: 1.5,
                        color: widget.activeAccentColor,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      albumName,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 28,
                        fontWeight: FontWeight.bold,
                        color: textColor,
                        height: 1.15,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      artistName,
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w600,
                        color: textColor.withValues(alpha: 0.85),
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      '${albumTracks.length} songs • ${_formatTotalAlbumDuration(totalDurationMs)}',
                      style: TextStyle(
                        fontSize: 12.5,
                        color: secondaryTextColor,
                      ),
                    ),
                    const SizedBox(height: 18),
                    Row(
                      children: [
                        FilledButton.icon(
                          onPressed: () {
                            if (albumTracks.isNotEmpty) {
                              widget.onPlayTrack(
                                albumTracks.first,
                                albumTracks,
                                0,
                              );
                            }
                          },
                          icon: const Icon(Icons.play_arrow_rounded, size: 20),
                          label: const Text('Play'),
                          style: FilledButton.styleFrom(
                            backgroundColor: widget.activeAccentColor,
                            foregroundColor: Colors.black,
                            padding: const EdgeInsets.symmetric(
                              horizontal: 24,
                              vertical: 12,
                            ),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(24),
                            ),
                          ),
                        ),
                        const SizedBox(width: 12),
                        OutlinedButton.icon(
                          onPressed: () {
                            if (albumTracks.isNotEmpty) {
                              final shuffled = List<Track>.from(albumTracks)
                                ..shuffle();
                              widget.onPlayTrack(
                                shuffled.first,
                                shuffled,
                                0,
                              );
                            }
                          },
                          icon: const Icon(Icons.shuffle_rounded, size: 18),
                          label: const Text('Shuffle'),
                          style: OutlinedButton.styleFrom(
                            foregroundColor: textColor,
                            side: BorderSide(
                              color: widget.isLight
                                  ? Colors.black12
                                  : Colors.white24,
                            ),
                            padding: const EdgeInsets.symmetric(
                              horizontal: 20,
                              vertical: 12,
                            ),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(24),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),

        const SizedBox(height: 12),
        Divider(
          color: widget.isLight
              ? Colors.black.withValues(alpha: 0.06)
              : Colors.white.withValues(alpha: 0.06),
          height: 1,
        ),

        // Table Header
        Container(
          height: 38,
          padding: const EdgeInsets.symmetric(horizontal: 24),
          decoration: BoxDecoration(
            border: Border(
              bottom: BorderSide(
                color: widget.isLight
                    ? Colors.black.withValues(alpha: 0.06)
                    : Colors.white.withValues(alpha: 0.06),
              ),
            ),
          ),
          child: Row(
            children: [
              SizedBox(
                width: 36,
                child: Center(
                  child: Text(
                    '#',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: secondaryTextColor,
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                flex: 4,
                child: Text(
                  'TITLE',
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    color: secondaryTextColor,
                    letterSpacing: 0.8,
                  ),
                ),
              ),
              Expanded(
                flex: 3,
                child: Text(
                  'ARTIST',
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    color: secondaryTextColor,
                    letterSpacing: 0.8,
                  ),
                ),
              ),
              SizedBox(
                width: 70,
                child: Text(
                  'TIME',
                  textAlign: TextAlign.right,
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    color: secondaryTextColor,
                    letterSpacing: 0.8,
                  ),
                ),
              ),
              const SizedBox(width: 48),
            ],
          ),
        ),

        // Song Rows
        Expanded(
          child: StreamBuilder<PlayerState>(
            stream: widget.player.playerStateStream,
            builder: (context, snapshot) {
              final isAudioPlaying =
                  snapshot.data?.playing ?? widget.player.playing;

              return ListView.builder(
                itemCount: albumTracks.length,
                padding: const EdgeInsets.symmetric(vertical: 4),
                itemBuilder: (context, index) {
                  final track = albumTracks[index];
                  final isCurrentTrack = widget.playingTrack?.id == track.id;
                  final isFav = widget.favoriteTrackIds.contains(track.id);

                  return _DesktopSongRow(
                    index: index + 1,
                    track: track,
                    isCurrentTrack: isCurrentTrack,
                    isPlaying: isCurrentTrack && isAudioPlaying,
                    isFavorite: isFav,
                    activeAccentColor: widget.activeAccentColor,
                    textColor: textColor,
                    secondaryTextColor: secondaryTextColor,
                    isLight: widget.isLight,
                    onTap: () => widget.onPlayTrack(
                      track,
                      albumTracks,
                      index,
                    ),
                    onToggleFavorite: () => widget.onToggleFavorite(track.id),
                    onArtistTap: (artist) {
                      setState(() {
                        _selectedArtistName = artist;
                        _activeSection = DesktopNavSection.artists;
                      });
                    },
                  );
                },
              );
            },
          ),
        ),
      ],
    );
  }

  Widget _buildArtistDetailView(
    String artistName,
    Color textColor,
    Color secondaryTextColor,
  ) {
    final artistTracks = widget.allTracks
        .where((t) => t.artist.toLowerCase() == artistName.toLowerCase())
        .toList();
    final firstTrack = artistTracks.isNotEmpty ? artistTracks.first : null;
    final totalDurationMs =
        artistTracks.fold<int>(0, (sum, t) => sum + t.duration);
    final distinctAlbums = artistTracks
        .map((t) => t.album)
        .where((a) => a.isNotEmpty)
        .toSet()
        .toList();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Top breadcrumb / Back Button
        Padding(
          padding: const EdgeInsets.only(left: 20, top: 16, bottom: 4),
          child: InkWell(
            borderRadius: BorderRadius.circular(8),
            onTap: () => setState(() => _selectedArtistName = null),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    Icons.arrow_back_rounded,
                    size: 18,
                    color: secondaryTextColor,
                  ),
                  const SizedBox(width: 8),
                  Text(
                    'Artists',
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: secondaryTextColor,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),

        // Artist Header
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              ClipOval(
                child: firstTrack != null
                    ? _DesktopTrackArtwork(
                        track: firstTrack,
                        size: 170,
                        radius: 85,
                      )
                    : Container(
                        width: 170,
                        height: 170,
                        decoration: BoxDecoration(
                          color: widget.isLight
                              ? Colors.black.withValues(alpha: 0.05)
                              : Colors.white.withValues(alpha: 0.05),
                          shape: BoxShape.circle,
                        ),
                        child: Center(
                          child: Icon(
                            Icons.person_rounded,
                            size: 64,
                            color: widget.activeAccentColor,
                          ),
                        ),
                      ),
              ),
              const SizedBox(width: 24),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      'ARTIST',
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w800,
                        letterSpacing: 1.5,
                        color: widget.activeAccentColor,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      artistName,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 30,
                        fontWeight: FontWeight.bold,
                        color: textColor,
                        height: 1.15,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      '${artistTracks.length} songs • ${distinctAlbums.length} albums • ${_formatTotalAlbumDuration(totalDurationMs)}',
                      style: TextStyle(
                        fontSize: 12.5,
                        color: secondaryTextColor,
                      ),
                    ),
                    const SizedBox(height: 18),
                    Row(
                      children: [
                        FilledButton.icon(
                          onPressed: () {
                            if (artistTracks.isNotEmpty) {
                              widget.onPlayTrack(
                                artistTracks.first,
                                artistTracks,
                                0,
                              );
                            }
                          },
                          icon: const Icon(Icons.play_arrow_rounded, size: 20),
                          label: const Text('Play'),
                          style: FilledButton.styleFrom(
                            backgroundColor: widget.activeAccentColor,
                            foregroundColor: Colors.black,
                            padding: const EdgeInsets.symmetric(
                              horizontal: 24,
                              vertical: 12,
                            ),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(24),
                            ),
                          ),
                        ),
                        const SizedBox(width: 12),
                        OutlinedButton.icon(
                          onPressed: () {
                            if (artistTracks.isNotEmpty) {
                              final shuffled = List<Track>.from(artistTracks)
                                ..shuffle();
                              widget.onPlayTrack(
                                shuffled.first,
                                shuffled,
                                0,
                              );
                            }
                          },
                          icon: const Icon(Icons.shuffle_rounded, size: 18),
                          label: const Text('Shuffle'),
                          style: OutlinedButton.styleFrom(
                            foregroundColor: textColor,
                            side: BorderSide(
                              color: widget.isLight
                                  ? Colors.black12
                                  : Colors.white24,
                            ),
                            padding: const EdgeInsets.symmetric(
                              horizontal: 20,
                              vertical: 12,
                            ),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(24),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),

        const SizedBox(height: 12),
        Divider(
          color: widget.isLight
              ? Colors.black.withValues(alpha: 0.06)
              : Colors.white.withValues(alpha: 0.06),
          height: 1,
        ),

        // Table Header
        Container(
          height: 38,
          padding: const EdgeInsets.symmetric(horizontal: 24),
          decoration: BoxDecoration(
            border: Border(
              bottom: BorderSide(
                color: widget.isLight
                    ? Colors.black.withValues(alpha: 0.06)
                    : Colors.white.withValues(alpha: 0.06),
              ),
            ),
          ),
          child: Row(
            children: [
              SizedBox(
                width: 36,
                child: Center(
                  child: Text(
                    '#',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: secondaryTextColor,
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                flex: 4,
                child: Text(
                  'TITLE',
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    color: secondaryTextColor,
                    letterSpacing: 0.8,
                  ),
                ),
              ),
              Expanded(
                flex: 3,
                child: Text(
                  'ALBUM',
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    color: secondaryTextColor,
                    letterSpacing: 0.8,
                  ),
                ),
              ),
              SizedBox(
                width: 70,
                child: Text(
                  'TIME',
                  textAlign: TextAlign.right,
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    color: secondaryTextColor,
                    letterSpacing: 0.8,
                  ),
                ),
              ),
              const SizedBox(width: 48),
            ],
          ),
        ),

        // Song Rows
        Expanded(
          child: StreamBuilder<PlayerState>(
            stream: widget.player.playerStateStream,
            builder: (context, snapshot) {
              final isAudioPlaying =
                  snapshot.data?.playing ?? widget.player.playing;

              return ListView.builder(
                itemCount: artistTracks.length,
                padding: const EdgeInsets.symmetric(vertical: 4),
                itemBuilder: (context, index) {
                  final track = artistTracks[index];
                  final isCurrentTrack = widget.playingTrack?.id == track.id;
                  final isFav = widget.favoriteTrackIds.contains(track.id);

                  return _DesktopSongRow(
                    index: index + 1,
                    track: track,
                    isCurrentTrack: isCurrentTrack,
                    isPlaying: isCurrentTrack && isAudioPlaying,
                    isFavorite: isFav,
                    activeAccentColor: widget.activeAccentColor,
                    textColor: textColor,
                    secondaryTextColor: secondaryTextColor,
                    isLight: widget.isLight,
                    onTap: () => widget.onPlayTrack(
                      track,
                      artistTracks,
                      index,
                    ),
                    onToggleFavorite: () => widget.onToggleFavorite(track.id),
                    onAlbumTap: (album) {
                      setState(() {
                        _selectedAlbumName = album;
                        _activeSection = DesktopNavSection.albums;
                      });
                    },
                  );
                },
              );
            },
          ),
        ),
      ],
    );
  }

  Widget _buildFullscreenNowPlayingView(
    Color textColor,
    Color secondaryTextColor,
  ) {
    final track = widget.playingTrack;
    if (track == null) return const SizedBox.shrink();

    return ValueListenableBuilder<Color?>(
      valueListenable: dominantColorNotifier,
      builder: (context, dominantColor, _) {
        final themeColor = dominantColor ?? widget.activeAccentColor;

        return Focus(
          autofocus: true,
          onKeyEvent: (node, event) {
            if (event is KeyDownEvent &&
                event.logicalKey == LogicalKeyboardKey.escape) {
              setState(() => _isFullscreenPlayerOpen = false);
              return KeyEventResult.handled;
            }
            return KeyEventResult.ignored;
          },
          child: Container(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [
                  Color.lerp(themeColor, Colors.black, 0.45) ?? themeColor,
                  const Color(0xFF0F0F12),
                ],
                stops: const [0.0, 0.85],
              ),
            ),
            child: Column(
              children: [
                DesktopTitleBar(
                  backgroundColor: Colors.transparent,
                  isLight: false,
                  leading: Text(
                    track.album.isNotEmpty
                        ? track.album
                        : (track.artist.isNotEmpty
                            ? track.artist
                            : 'Now Playing'),
                    style: const TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: Colors.white,
                    ),
                  ),
                  trailing: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      IconButton(
                        icon: Icon(
                          widget.favoriteTrackIds.contains(track.id)
                              ? Icons.favorite_rounded
                              : Icons.favorite_border_rounded,
                          size: 20,
                          color: widget.favoriteTrackIds.contains(track.id)
                              ? Colors.redAccent
                              : Colors.white70,
                        ),
                        tooltip: 'Favorite',
                        onPressed: () => widget.onToggleFavorite(track.id),
                      ),
                      IconButton(
                        icon: const Icon(
                          Icons.queue_music_rounded,
                          size: 20,
                          color: Colors.white70,
                        ),
                        tooltip: 'Queue',
                        onPressed: () =>
                            setState(() => _isQueueOpen = !_isQueueOpen),
                      ),
                      IconButton(
                        icon: const Icon(
                          Icons.fullscreen_exit_rounded,
                          size: 22,
                          color: Colors.white70,
                        ),
                        tooltip: 'Exit Full Screen (Esc)',
                        onPressed: () =>
                            setState(() => _isFullscreenPlayerOpen = false),
                      ),
                    ],
                  ),
                ),
                Expanded(
                  child: Stack(
                    children: [
                      LayoutBuilder(
                        builder: (context, constraints) {
                          final available = math.min(
                            constraints.maxWidth - 64,
                            constraints.maxHeight - 64,
                          );
                          final coverSize = available.clamp(280.0, 560.0);

                          return Center(
                            child: Container(
                              width: coverSize,
                              height: coverSize,
                              decoration: BoxDecoration(
                                borderRadius: BorderRadius.circular(20),
                                boxShadow: [
                                  BoxShadow(
                                    color: Colors.black.withValues(alpha: 0.65),
                                    blurRadius: 48,
                                    spreadRadius: 4,
                                    offset: const Offset(0, 20),
                                  ),
                                ],
                              ),
                              child: _DesktopTrackArtwork(
                                track: track,
                                size: coverSize,
                                radius: 20,
                              ),
                            ),
                          );
                        },
                      ),
                      if (_isQueueOpen) ...[
                        Positioned.fill(
                          child: GestureDetector(
                            behavior: HitTestBehavior.translucent,
                            onTap: () => setState(() => _isQueueOpen = false),
                            child: Container(
                              color: Colors.black.withValues(alpha: 0.35),
                            ),
                          ),
                        ),
                        Positioned(
                          top: 0,
                          right: 0,
                          bottom: 0,
                          width: 340,
                          child: _buildQueueSidePanel(
                            Colors.white,
                            Colors.white70,
                            Colors.white.withValues(alpha: 0.15),
                            isFloatingInFullscreen: true,
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Future<void> _pickDesktopProfilePhoto() async {
    try {
      const typeGroup = XTypeGroup(
        label: 'images',
        extensions: ['jpg', 'png', 'jpeg', 'webp'],
      );
      final file = await openFile(acceptedTypeGroups: [typeGroup]);
      if (file != null && mounted) {
        final prefs = await SharedPreferences.getInstance();
        await prefs.setString('userProfileImage', file.path);
        userProfileImageNotifier.value = file.path;
      }
    } catch (e) {
      debugPrint('Error picking profile image: $e');
    }
  }

  void _showDesktopEditProfileDialog() {
    final nameCtrl = TextEditingController(text: userProfileNameNotifier.value);
    final bioCtrl = TextEditingController(text: userProfileBioNotifier.value);

    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          backgroundColor: widget.isLight
              ? const Color(0xFFFAFAFD)
              : const Color(0xFF1E1E24),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: const Text(
            'Edit Profile',
            style: TextStyle(fontWeight: FontWeight.w700),
          ),
          content: SizedBox(
            width: 400,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: nameCtrl,
                  maxLength: 30,
                  decoration: const InputDecoration(
                    labelText: 'Display Name',
                  ),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: bioCtrl,
                  maxLength: 80,
                  decoration: const InputDecoration(
                    labelText: 'Bio',
                  ),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: widget.activeAccentColor,
                foregroundColor:
                    widget.activeAccentColor.computeLuminance() > 0.35
                        ? Colors.black
                        : Colors.white,
              ),
              onPressed: () async {
                final nav = Navigator.of(context);
                final newName = nameCtrl.text.trim();
                final newBio = bioCtrl.text.trim();
                if (newName.isNotEmpty) {
                  final prefs = await SharedPreferences.getInstance();
                  await prefs.setString('userProfileName', newName);
                  await prefs.setString('userProfileBio', newBio);
                  userProfileNameNotifier.value = newName;
                  userProfileBioNotifier.value = newBio;
                }
                nav.pop();
              },
              child: const Text('Save'),
            ),
          ],
        );
      },
    );
  }

  Widget _buildStatCard({
    required String title,
    required String value,
    required IconData icon,
    required Color color,
    required Color textColor,
    required Color secondaryTextColor,
    required Color borderColor,
  }) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.all(18),
        decoration: BoxDecoration(
          color: widget.isLight
              ? Colors.black.withValues(alpha: 0.02)
              : Colors.white.withValues(alpha: 0.03),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: borderColor),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Icon(icon, color: color, size: 22),
                Text(
                  value,
                  style: TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.w800,
                    color: textColor,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            Text(
              title,
              style: TextStyle(
                fontSize: 12.5,
                fontWeight: FontWeight.w600,
                color: secondaryTextColor,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildProfileDesktopView(
    Color textColor,
    Color secondaryTextColor,
  ) {
    final borderColor = widget.isLight
        ? Colors.black.withValues(alpha: 0.08)
        : Colors.white.withValues(alpha: 0.08);
    final totalAlbums = widget.allTracks
        .map((t) => t.album)
        .where((a) => a.isNotEmpty)
        .toSet()
        .length;

    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(horizontal: 40, vertical: 32),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 860),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header Card
              Container(
                padding: const EdgeInsets.all(28),
                decoration: BoxDecoration(
                  color: widget.isLight
                      ? Colors.black.withValues(alpha: 0.03)
                      : Colors.white.withValues(alpha: 0.04),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: borderColor),
                ),
                child: Row(
                  children: [
                    // Avatar with edit photo button
                    Stack(
                      alignment: Alignment.bottomRight,
                      children: [
                        ValueListenableBuilder<String?>(
                          valueListenable: userProfileImageNotifier,
                          builder: (context, imagePath, _) {
                            final hasImage =
                                imagePath != null && File(imagePath).existsSync();
                            return Container(
                              width: 100,
                              height: 100,
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                color: widget.activeAccentColor.withValues(alpha: 0.15),
                                border: Border.all(
                                  color: widget.activeAccentColor.withValues(alpha: 0.4),
                                  width: 2.5,
                                ),
                              ),
                              child: ClipOval(
                                child: hasImage
                                    ? Image.file(
                                        File(imagePath),
                                        width: 100,
                                        height: 100,
                                        fit: BoxFit.cover,
                                      )
                                    : Icon(
                                        Icons.person_rounded,
                                        size: 52,
                                        color: widget.activeAccentColor,
                                      ),
                              ),
                            );
                          },
                        ),
                        InkWell(
                          onTap: _pickDesktopProfilePhoto,
                          borderRadius: BorderRadius.circular(16),
                          child: Container(
                            width: 32,
                            height: 32,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              color: widget.activeAccentColor,
                              border: Border.all(
                                color: widget.backgroundColor,
                                width: 2,
                              ),
                            ),
                            child: Icon(
                              Icons.camera_alt_rounded,
                              size: 16,
                              color: widget.activeAccentColor.computeLuminance() > 0.35
                                  ? Colors.black
                                  : Colors.white,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(width: 24),
                    // User info
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              ValueListenableBuilder<String>(
                                valueListenable: userProfileNameNotifier,
                                builder: (context, name, _) {
                                  return Text(
                                    name.isNotEmpty ? name : 'Fley User',
                                    style: TextStyle(
                                      fontSize: 26,
                                      fontWeight: FontWeight.w800,
                                      color: textColor,
                                      letterSpacing: -0.5,
                                    ),
                                  );
                                },
                              ),
                              const SizedBox(width: 8),
                              IconButton(
                                icon: const Icon(Icons.edit_outlined, size: 18),
                                tooltip: 'Edit Profile',
                                onPressed: _showDesktopEditProfileDialog,
                                color: secondaryTextColor,
                              ),
                            ],
                          ),
                          const SizedBox(height: 4),
                          ValueListenableBuilder<String>(
                            valueListenable: userProfileBioNotifier,
                            builder: (context, bio, _) {
                              return Text(
                                bio.isNotEmpty
                                    ? bio
                                    : 'Music enthusiast listening on Fley Desktop',
                                style: TextStyle(
                                  fontSize: 13.5,
                                  color: secondaryTextColor,
                                ),
                              );
                            },
                          ),
                          const SizedBox(height: 12),
                          Row(
                            children: [
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 10,
                                  vertical: 4,
                                ),
                                decoration: BoxDecoration(
                                  color: widget.activeAccentColor
                                      .withValues(alpha: 0.15),
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                child: Text(
                                  'Pro Listener',
                                  style: TextStyle(
                                    fontSize: 11.5,
                                    fontWeight: FontWeight.w700,
                                    color: widget.activeAccentColor,
                                  ),
                                ),
                              ),
                              const SizedBox(width: 10),
                              Text(
                                '${widget.allTracks.length} tracks loaded',
                                style: TextStyle(
                                  fontSize: 12,
                                  color: secondaryTextColor,
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 28),

              // Library Stats Grid
              Text(
                'Library Overview',
                style: TextStyle(
                  fontSize: 17,
                  fontWeight: FontWeight.w700,
                  color: textColor,
                ),
              ),
              const SizedBox(height: 14),
              Row(
                children: [
                  _buildStatCard(
                    title: 'Total Songs',
                    value: '${widget.allTracks.length}',
                    icon: Icons.music_note_rounded,
                    color: widget.activeAccentColor,
                    textColor: textColor,
                    secondaryTextColor: secondaryTextColor,
                    borderColor: borderColor,
                  ),
                  const SizedBox(width: 14),
                  _buildStatCard(
                    title: 'Favourites',
                    value: '${_favoriteTracks.length}',
                    icon: Icons.favorite_rounded,
                    color: const Color(0xFFE91E63),
                    textColor: textColor,
                    secondaryTextColor: secondaryTextColor,
                    borderColor: borderColor,
                  ),
                  const SizedBox(width: 14),
                  _buildStatCard(
                    title: 'Playlists',
                    value: '${widget.userPlaylists.length}',
                    icon: Icons.queue_music_rounded,
                    color: const Color(0xFF2196F3),
                    textColor: textColor,
                    secondaryTextColor: secondaryTextColor,
                    borderColor: borderColor,
                  ),
                  const SizedBox(width: 14),
                  _buildStatCard(
                    title: 'Albums',
                    value: '$totalAlbums',
                    icon: Icons.album_rounded,
                    color: const Color(0xFF9C27B0),
                    textColor: textColor,
                    secondaryTextColor: secondaryTextColor,
                    borderColor: borderColor,
                  ),
                ],
              ),

              const SizedBox(height: 28),

              // Quick Actions
              Text(
                'Actions & Preferences',
                style: TextStyle(
                  fontSize: 17,
                  fontWeight: FontWeight.w700,
                  color: textColor,
                ),
              ),
              const SizedBox(height: 14),
              Wrap(
                spacing: 12,
                runSpacing: 12,
                children: [
                  OutlinedButton.icon(
                    style: OutlinedButton.styleFrom(
                      foregroundColor: textColor,
                      side: BorderSide(color: borderColor),
                      padding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 12,
                      ),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10),
                      ),
                    ),
                    icon: const Icon(Icons.edit_rounded, size: 17),
                    label: const Text('Edit Profile Details'),
                    onPressed: _showDesktopEditProfileDialog,
                  ),
                  OutlinedButton.icon(
                    style: OutlinedButton.styleFrom(
                      foregroundColor: textColor,
                      side: BorderSide(color: borderColor),
                      padding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 12,
                      ),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10),
                      ),
                    ),
                    icon: const Icon(Icons.photo_library_outlined, size: 17),
                    label: const Text('Change Avatar'),
                    onPressed: _pickDesktopProfilePhoto,
                  ),
                  OutlinedButton.icon(
                    style: OutlinedButton.styleFrom(
                      foregroundColor: textColor,
                      side: BorderSide(color: borderColor),
                      padding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 12,
                      ),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10),
                      ),
                    ),
                    icon: const Icon(Icons.settings_outlined, size: 17),
                    label: const Text('Audio & App Settings'),
                    onPressed: widget.onOpenSettings,
                  ),
                  OutlinedButton.icon(
                    style: OutlinedButton.styleFrom(
                      foregroundColor: textColor,
                      side: BorderSide(color: borderColor),
                      padding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 12,
                      ),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10),
                      ),
                    ),
                    icon: const Icon(Icons.refresh_rounded, size: 17),
                    label: const Text('Rescan Library'),
                    onPressed: widget.onRescan,
                  ),
                ],
              ),

              const SizedBox(height: 28),

              // Favorites Preview Section
              if (_favoriteTracks.isNotEmpty) ...[
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'Your Favorites',
                      style: TextStyle(
                        fontSize: 17,
                        fontWeight: FontWeight.w700,
                        color: textColor,
                      ),
                    ),
                    TextButton(
                      onPressed: () {
                        setState(() {
                          _activeSongFilter = SongFilter.favorites;
                          _activeSection = DesktopNavSection.songs;
                        });
                      },
                      child: Text(
                        'See all (${_favoriteTracks.length})',
                        style: TextStyle(
                          color: widget.activeAccentColor,
                          fontSize: 13,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                ListView.builder(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  itemCount: math.min(5, _favoriteTracks.length),
                  itemBuilder: (context, idx) {
                    final track = _favoriteTracks[idx];
                    final isCurrent = widget.playingTrack?.id == track.id;
                    return _DesktopSongRow(
                      index: idx + 1,
                      track: track,
                      isCurrentTrack: isCurrent,
                      isPlaying: isCurrent && widget.player.playing,
                      isFavorite: true,
                      activeAccentColor: widget.activeAccentColor,
                      textColor: textColor,
                      secondaryTextColor: secondaryTextColor,
                      isLight: widget.isLight,
                      onTap: () => widget.onPlayTrack(track, _favoriteTracks, idx),
                      onToggleFavorite: () => widget.onToggleFavorite(track.id),
                      onAlbumTap: (alb) {
                        setState(() {
                          _selectedAlbumName = alb;
                          _activeSection = DesktopNavSection.albums;
                        });
                      },
                    );
                  },
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

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
  });

  @override
  State<_DesktopSongRow> createState() => _DesktopSongRowState();
}

class _DesktopSongRowState extends State<_DesktopSongRow> {
  bool _isHovered = false;

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
                width: 48,
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
            ],
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

