// ignore_for_file: invalid_use_of_protected_member
part of 'desktop_layout_shell.dart';

extension _DesktopProfileSettingsUI on _DesktopLayoutShellState {
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
              IconButton(
                icon: const Icon(Icons.arrow_back_rounded),
                tooltip: 'Back to Profile & Settings',
                onPressed: () => _setActiveSection(DesktopNavSection.profile),
              ),
              const SizedBox(width: 8),
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

  Future<void> _pickDesktopProfilePhoto() async {
    try {
      const typeGroup = XTypeGroup(
        label: 'images',
        extensions: ['jpg', 'png', 'jpeg', 'webp'],
      );
      final file = await openFile(acceptedTypeGroups: [typeGroup]);
      if (file != null && mounted) {
        final appDir = await getApplicationSupportDirectory();
        final profileDir = Directory('${appDir.path}/profile');
        if (!profileDir.existsSync()) {
          profileDir.createSync(recursive: true);
        }
        final ext = file.name.contains('.') ? file.name.split('.').last : 'png';
        final targetPath = '${profileDir.path}/profile_avatar.$ext';
        final bytes = await file.readAsBytes();
        final targetFile = File(targetPath);
        await targetFile.writeAsBytes(bytes);

        final prefs = await SharedPreferences.getInstance();
        await prefs.setString('userProfileImage', targetPath);
        userProfileImageNotifier.value = targetPath;
      }
    } catch (e) {
      debugPrint('Error picking profile image: $e');
    }
  }

  Future<void> _removeDesktopProfilePhoto() async {
    try {
      final current = userProfileImageNotifier.value;
      if (current != null && current.isNotEmpty) {
        final f = File(current);
        if (f.existsSync()) {
          f.deleteSync();
        }
      }
    } catch (_) {}
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('userProfileImage');
    userProfileImageNotifier.value = null;
  }

  void _showDesktopPhotoOptions() {
    if (_isSafeImage(userProfileImageNotifier.value)) {
      showDialog(
        context: context,
        builder: (ctx) => AlertDialog(
          backgroundColor: widget.isLight
              ? const Color(0xFFFAFAFD)
              : const Color(0xFF1E1E24),
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: const Text('Profile Photo',
              style: TextStyle(fontWeight: FontWeight.w700)),
          content: const Text('Change or remove your profile photo.'),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.pop(ctx);
                _removeDesktopProfilePhoto();
              },
              child: const Text('Remove Photo',
                  style: TextStyle(color: Colors.redAccent)),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: widget.activeAccentColor,
                foregroundColor:
                    widget.activeAccentColor.computeLuminance() > 0.35
                        ? Colors.black
                        : Colors.white,
              ),
              onPressed: () {
                Navigator.pop(ctx);
                _pickDesktopProfilePhoto();
              },
              child: const Text('Change Photo'),
            ),
          ],
        ),
      );
    } else {
      _pickDesktopProfilePhoto();
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
                final resolvedName =
                    newName.isNotEmpty ? newName : 'Fley User';
                final prefs = await SharedPreferences.getInstance();
                await prefs.setString('userProfileName', resolvedName);
                await prefs.setString('userProfileBio', newBio);
                userProfileNameNotifier.value = resolvedName;
                userProfileBioNotifier.value = newBio;
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
                            final hasImage = _isSafeImage(imagePath);
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
                                        File(imagePath!),
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
                          onTap: _showDesktopPhotoOptions,
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
