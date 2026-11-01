// ignore_for_file: invalid_use_of_protected_member
part of 'desktop_layout_shell.dart';

extension _DesktopSidebarUI on _DesktopLayoutShellState {
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
                    setState(() => _isFullscreenPlayerOpen = false);
                    _setActiveSection(DesktopNavSection.profile);
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
                      border: Border.all(
                        color: isProfileSelected
                            ? widget.activeAccentColor.withValues(alpha: 0.5)
                            : Colors.transparent,
                        width: 1,
                      ),
                    ),
                    child: Row(
                      children: [
                        ValueListenableBuilder<String?>(
                          valueListenable: userProfileImageNotifier,
                          builder: (context, imagePath, _) {
                            final hasImage = _isSafeImage(imagePath);
                            return CircleAvatar(
                              radius: 14,
                              backgroundColor: widget.activeAccentColor
                                  .withValues(alpha: 0.2),
                              backgroundImage:
                                  hasImage ? FileImage(File(imagePath!)) : null,
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
                        _selectedPlaylistName = null;
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

                  const SizedBox(height: 12),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 18),
                    child: Divider(color: borderColor, height: 1),
                  ),
                  const SizedBox(height: 8),
                  Padding(
                    padding: const EdgeInsets.only(left: 18, right: 8),
                    child: Row(
                      children: [
                        Expanded(
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
                        IconButton(
                          icon: const Icon(Icons.add_rounded, size: 18),
                          color: secondaryTextColor,
                          tooltip: 'Create Playlist',
                          onPressed: _showCreatePlaylistDialog,
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 4),
                  if (widget.userPlaylists.isEmpty)
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 8),
                      child: Text(
                        'No playlists yet',
                        style: TextStyle(
                          fontSize: 12,
                          color: secondaryTextColor.withValues(alpha: 0.6),
                        ),
                      ),
                    )
                  else
                    ...widget.userPlaylists.keys.map(
                      (name) => _buildNavItem(
                        icon: Icons.queue_music_rounded,
                        label: name,
                        count: widget.userPlaylists[name]?.length,
                        section: DesktopNavSection.songs,
                        isSelectedOverride: _selectedPlaylistName == name &&
                            _activeSection == DesktopNavSection.songs,
                        textColor: textColor,
                        onSecondaryTapDown: (details) =>
                            _showPlaylistSidebarContextMenu(
                          context,
                          name,
                          details.globalPosition,
                        ),
                        trailing: PopupMenuButton<String>(
                          padding: EdgeInsets.zero,
                          iconSize: 16,
                          tooltip: 'Playlist options',
                          icon: Icon(
                            Icons.more_vert_rounded,
                            size: 16,
                            color: secondaryTextColor,
                          ),
                          onSelected: (val) {
                            if (val == 'rename') {
                              _renamePlaylistDialog(name);
                            } else if (val == 'cover') {
                              _changePlaylistCoverDialog(name);
                            } else if (val == 'delete') {
                              _confirmDeletePlaylist(name);
                            }
                          },
                          itemBuilder: (context) => [
                            const PopupMenuItem(
                              value: 'rename',
                              child: Row(
                                children: [
                                  Icon(Icons.edit_outlined, size: 18),
                                  SizedBox(width: 10),
                                  Text('Rename',
                                      style: TextStyle(fontSize: 13)),
                                ],
                              ),
                            ),
                            const PopupMenuItem(
                              value: 'cover',
                              child: Row(
                                children: [
                                  Icon(Icons.image_outlined, size: 18),
                                  SizedBox(width: 10),
                                  Text('Change Cover',
                                      style: TextStyle(fontSize: 13)),
                                ],
                              ),
                            ),
                            const PopupMenuItem(
                              value: 'delete',
                              child: Row(
                                children: [
                                  Icon(Icons.delete_outline_rounded,
                                      size: 18, color: Colors.redAccent),
                                  SizedBox(width: 10),
                                  Text('Delete',
                                      style: TextStyle(
                                          fontSize: 13,
                                          color: Colors.redAccent)),
                                ],
                              ),
                            ),
                          ],
                        ),
                        onCustomTap: () {
                          setState(() {
                            _selectedPlaylistName = name;
                            _searchQuery = '';
                            _searchController.clear();
                            _activeSection = DesktopNavSection.songs;
                            _isLyricsViewOpen = false;
                          });
                        },
                      ),
                    ),
                  const SizedBox(height: 8),
                ],
              ),
            ),
          ),

          // Bottom Settings, Equalizer, Sleep Timer & Rescan
          Padding(
            padding: const EdgeInsets.all(14),
            child: Column(
              children: [
                if (widget.onOpenEqualizer != null) ...[
                  _buildSidebarActionBtn(
                    icon: Icons.equalizer_rounded,
                    label: 'Equalizer',
                    onTap: widget.onOpenEqualizer!,
                    textColor: secondaryTextColor,
                  ),
                  const SizedBox(height: 4),
                ],
                _buildSidebarActionBtn(
                  icon: Icons.bedtime_outlined,
                  label: _desktopSleepTimerMinutes != null
                      ? (_desktopSleepTimerMinutes == -1
                          ? 'Sleep Timer (End of track)'
                          : 'Sleep Timer (${_desktopSleepTimerMinutes}m)')
                      : 'Sleep Timer',
                  onTap: _showSleepTimerDialog,
                  textColor: _desktopSleepTimerMinutes != null
                      ? widget.activeAccentColor
                      : secondaryTextColor,
                ),
                const SizedBox(height: 4),
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

  void _showPlaylistSidebarContextMenu(
    BuildContext context,
    String name,
    Offset position,
  ) async {
    final RenderBox overlay =
        Overlay.of(context).context.findRenderObject() as RenderBox;
    final value = await showMenu<String>(
      context: context,
      position: RelativeRect.fromRect(
        position & const Size(40, 40),
        Offset.zero & overlay.size,
      ),
      items: [
        PopupMenuItem(
          value: 'rename',
          child: Row(
            children: [
              const Icon(Icons.edit_outlined, size: 18),
              const SizedBox(width: 10),
              const Text('Rename Playlist', style: TextStyle(fontSize: 13)),
            ],
          ),
        ),
        PopupMenuItem(
          value: 'cover',
          child: Row(
            children: [
              const Icon(Icons.image_outlined, size: 18),
              const SizedBox(width: 10),
              const Text('Change Cover Art', style: TextStyle(fontSize: 13)),
            ],
          ),
        ),
        PopupMenuItem(
          value: 'delete',
          child: Row(
            children: [
              const Icon(Icons.delete_outline_rounded,
                  size: 18, color: Colors.redAccent),
              const SizedBox(width: 10),
              const Text('Delete Playlist',
                  style: TextStyle(fontSize: 13, color: Colors.redAccent)),
            ],
          ),
        ),
      ],
    );

    if (value == 'rename') {
      _renamePlaylistDialog(name);
    } else if (value == 'cover') {
      _changePlaylistCoverDialog(name);
    } else if (value == 'delete') {
      _confirmDeletePlaylist(name);
    }
  }

  void _confirmDeletePlaylist(String name) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: widget.isLight
            ? const Color(0xFFFAFAFD)
            : const Color(0xFF1E1E24),
        title: const Text('Delete Playlist'),
        content: Text('Are you sure you want to delete "$name"?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () {
              Navigator.pop(context);
              widget.onDeletePlaylist?.call(name);
              if (_selectedPlaylistName == name) {
                setState(() => _selectedPlaylistName = null);
              }
            },
            style: FilledButton.styleFrom(backgroundColor: Colors.redAccent),
            child: const Text('Delete'),
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
    Widget? trailing,
    void Function(TapDownDetails)? onSecondaryTapDown,
  }) {
    final isSelected = isSelectedOverride ?? (_activeSection == section);
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 2),
      child: GestureDetector(
        onSecondaryTapDown: onSecondaryTapDown,
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
                _setActiveSection(section);
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
                if (trailing != null)
                  trailing
                else if (count != null)
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
}
