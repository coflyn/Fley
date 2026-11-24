// ignore_for_file: library_private_types_in_public_api, deprecated_member_use, invalid_use_of_protected_member
part of 'settings_screen.dart';

extension SettingsLanguageDensityModals on _SettingsScreenState {
  void _showLanguageSelectionDialog() {
    final isLight = isAppLight;
    showModalBottomSheet(
      context: context,
      backgroundColor: isLight
          ? const Color(0xFFF0F0F3)
          : const Color(0xFF161616),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      isScrollControlled: true,
      builder: (context) {
        return SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const SizedBox(height: 12),
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
              const SizedBox(height: 16),
              Center(
                child: Text(
                  AppLocalizations.of(context).language,
                  style: TextStyle(
                    color: isLight ? const Color(0xFF1A1A1A) : Colors.white,
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
              const SizedBox(height: 16),
              Divider(
                color: isLight ? Colors.black12 : Colors.white10,
                height: 1,
              ),
              _buildLanguageOption('English', 'en', '🇺🇸'),
              _buildLanguageOption('Indonesia', 'id', '🇮🇩'),
              _buildLanguageOption('日本語', 'ja', '🇯🇵'),
              const SizedBox(height: 16),
            ],
          ),
        );
      },
    );
  }

  Widget _buildLanguageOption(String label, String langCode, String flag) {
    final isSelected = _language == langCode;
    final isLight = isAppLight;
    return ListTile(
      contentPadding: const EdgeInsets.symmetric(horizontal: 24, vertical: 4),
      leading: Text(flag, style: const TextStyle(fontSize: 24)),
      title: Text(
        label,
        style: TextStyle(
          color: isSelected
              ? _activeAccentColor
              : (isLight ? const Color(0xFF1A1A1A) : Colors.white),
          fontSize: 16,
          fontWeight: isSelected ? FontWeight.bold : FontWeight.w400,
        ),
      ),
      trailing: isSelected
          ? Icon(Icons.check, color: _activeAccentColor)
          : null,
      onTap: () async {
        final nav = Navigator.of(context);
        final prefs = await SharedPreferences.getInstance();
        await prefs.setString('language', langCode);
        languageNotifier.value = langCode;
        setState(() {
          _language = langCode;
        });
        nav.pop();
        // Force rebuild settings screen to apply new language
        setState(() {});
      },
    );
  }

  void _showLibraryDensityDialog() {
    final isLight = isAppLight;
    showModalBottomSheet(
      context: context,
      backgroundColor: isLight
          ? const Color(0xFFF0F0F3)
          : const Color(0xFF161616),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (context) {
        return SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const SizedBox(height: 12),
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
              const SizedBox(height: 16),
              Center(
                child: Text(
                  AppLocalizations.of(context).libraryDensity,
                  style: TextStyle(
                    color: isLight ? const Color(0xFF1A1A1A) : Colors.white,
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
              const SizedBox(height: 16),
              Divider(
                color: isLight ? Colors.black12 : Colors.white10,
                height: 1,
              ),
              ListTile(
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: 24,
                  vertical: 4,
                ),
                leading: Icon(
                  Icons.reorder_rounded,
                  color: _libraryDensity == 'standard'
                      ? _activeAccentColor
                      : Colors.white54,
                ),
                title: Text(
                  AppLocalizations.of(context).densityStandard,
                  style: TextStyle(
                    color: _libraryDensity == 'standard'
                        ? _activeAccentColor
                        : (isLight ? const Color(0xFF1A1A1A) : Colors.white),
                    fontWeight: _libraryDensity == 'standard'
                        ? FontWeight.bold
                        : FontWeight.w400,
                  ),
                ),
                trailing: _libraryDensity == 'standard'
                    ? Icon(Icons.check, color: _activeAccentColor)
                    : null,
                onTap: () async {
                  final nav = Navigator.of(context);
                  final prefs = await SharedPreferences.getInstance();
                  await prefs.setString('libraryDensity', 'standard');
                  setState(() => _libraryDensity = 'standard');
                  widget.onSettingsChanged();
                  nav.pop();
                },
              ),
              ListTile(
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: 24,
                  vertical: 4,
                ),
                leading: Icon(
                  Icons.density_small_rounded,
                  color: _libraryDensity == 'compact'
                      ? _activeAccentColor
                      : Colors.white54,
                ),
                title: Text(
                  AppLocalizations.of(context).densityCompact,
                  style: TextStyle(
                    color: _libraryDensity == 'compact'
                        ? _activeAccentColor
                        : (isLight ? const Color(0xFF1A1A1A) : Colors.white),
                    fontWeight: _libraryDensity == 'compact'
                        ? FontWeight.bold
                        : FontWeight.w400,
                  ),
                ),
                trailing: _libraryDensity == 'compact'
                    ? Icon(Icons.check, color: _activeAccentColor)
                    : null,
                onTap: () async {
                  final nav = Navigator.of(context);
                  final prefs = await SharedPreferences.getInstance();
                  await prefs.setString('libraryDensity', 'compact');
                  setState(() => _libraryDensity = 'compact');
                  widget.onSettingsChanged();
                  nav.pop();
                },
              ),
              const SizedBox(height: 16),
            ],
          ),
        );
      },
    );
  }

  void _showLyricFontSizeDialog() {
    final isLight = isAppLight;
    showModalBottomSheet(
      context: context,
      backgroundColor: isLight
          ? const Color(0xFFF0F0F3)
          : const Color(0xFF161616),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setModalState) {
            return SafeArea(
              child: Padding(
                padding: const EdgeInsets.all(20.0),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
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
                      AppLocalizations.of(context).lyricFontSize,
                      style: TextStyle(
                        color: isLight ? const Color(0xFF1A1A1A) : Colors.white,
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 20),
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: isLight ? Colors.white : Colors.white10,
                        borderRadius: BorderRadius.circular(16),
                      ),
                      child: Text(
                        "Sample Lyric Line ♫",
                        style: GoogleFonts.getFont(
                          _activeFont == 'Spotify Style'
                              ? 'Figtree'
                              : _activeFont == 'Apple Music Style'
                              ? 'Inter'
                              : 'Plus Jakarta Sans',
                          fontSize: _lyricFontSize * _fontScale,
                          fontWeight: FontWeight.bold,
                          color: _activeAccentColor,
                        ),
                        textAlign: TextAlign.center,
                      ),
                    ),
                    const SizedBox(height: 20),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          "14sp",
                          style: TextStyle(
                            color: isLight ? Colors.black54 : Colors.white54,
                          ),
                        ),
                        Text(
                          "${_lyricFontSize.toInt()} sp",
                          style: TextStyle(
                            color: _activeAccentColor,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        Text(
                          "30sp",
                          style: TextStyle(
                            color: isLight ? Colors.black54 : Colors.white54,
                          ),
                        ),
                      ],
                    ),
                    Slider(
                      value: _lyricFontSize,
                      min: 14.0,
                      max: 30.0,
                      divisions: 16,
                      activeColor: _activeAccentColor,
                      onChanged: (val) {
                        setModalState(() {
                          _lyricFontSize = val;
                        });
                        setState(() {});
                      },
                      onChangeEnd: (val) async {
                        final prefs = await SharedPreferences.getInstance();
                        await prefs.setDouble('lyricFontSize', val);
                        widget.onSettingsChanged();
                      },
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  void _showPlaybackSpeedDialog() {
    final isLight = isAppLight;
    final speeds = [0.5, 0.75, 1.0, 1.25, 1.5, 1.75, 2.0];
    showModalBottomSheet(
      context: context,
      backgroundColor: isLight
          ? const Color(0xFFF0F0F3)
          : const Color(0xFF161616),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setModalState) {
            return SafeArea(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const SizedBox(height: 12),
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
                    AppLocalizations.of(context).playbackSpeed,
                    style: TextStyle(
                      color: isLight ? const Color(0xFF1A1A1A) : Colors.white,
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 16),
                  Divider(
                    color: isLight ? Colors.black12 : Colors.white10,
                    height: 1,
                  ),
                  Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 8,
                    ),
                    child: SwitchListTile(
                      value: _pitchLock,
                      activeColor: _activeAccentColor,
                      title: Text(
                        AppLocalizations.of(context).pitchLock,
                        style: TextStyle(
                          color: isLight
                              ? const Color(0xFF1A1A1A)
                              : Colors.white,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      onChanged: (val) async {
                        setModalState(() => _pitchLock = val);
                        setState(() => _pitchLock = val);
                        final prefs = await SharedPreferences.getInstance();
                        await prefs.setBool('pitchLock', val);
                        widget.onSettingsChanged();
                      },
                    ),
                  ),
                  Divider(
                    color: isLight ? Colors.black12 : Colors.white10,
                    height: 1,
                  ),
                  for (final spd in speeds)
                    ListTile(
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: 24,
                        vertical: 2,
                      ),
                      title: Text(
                        '${spd}x',
                        style: TextStyle(
                          color: _playbackSpeed == spd
                              ? _activeAccentColor
                              : (isLight
                                    ? const Color(0xFF1A1A1A)
                                    : Colors.white),
                          fontWeight: _playbackSpeed == spd
                              ? FontWeight.bold
                              : FontWeight.w400,
                        ),
                      ),
                      trailing: _playbackSpeed == spd
                          ? Icon(Icons.check, color: _activeAccentColor)
                          : null,
                      onTap: () async {
                        final nav = Navigator.of(context);
                        final prefs = await SharedPreferences.getInstance();
                        await prefs.setDouble('playbackSpeed', spd);
                        setState(() => _playbackSpeed = spd);
                        widget.onSettingsChanged();
                        nav.pop();
                      },
                    ),
                  const SizedBox(height: 16),
                ],
              ),
            );
          },
        );
      },
    );
  }

  void _showPlaylistAddPositionDialog() {
    final isLight = _selectedThemeMode == 'light';
    final loc = AppLocalizations.of(context);
    showModalBottomSheet(
      context: context,
      backgroundColor: isLight
          ? const Color(0xFFF0F0F3)
          : const Color(0xFF161616),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) {
        return SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const SizedBox(height: 12),
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
              const SizedBox(height: 16),
              Center(
                child: Text(
                  loc.newSongPositionInPlaylist,
                  style: TextStyle(
                    color: isLight ? const Color(0xFF1A1A1A) : Colors.white,
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
              const SizedBox(height: 16),
              Divider(
                color: isLight ? Colors.black12 : Colors.white10,
                height: 1,
              ),
              ListTile(
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: 24,
                  vertical: 4,
                ),
                leading: Icon(
                  Icons.vertical_align_top_rounded,
                  color: playlistAddSongPositionNotifier.value == 'top'
                      ? _activeAccentColor
                      : (isLight ? Colors.black54 : Colors.white54),
                ),
                title: Text(
                  loc.positionTop,
                  style: TextStyle(
                    color: playlistAddSongPositionNotifier.value == 'top'
                        ? _activeAccentColor
                        : (isLight ? const Color(0xFF1A1A1A) : Colors.white),
                    fontWeight: playlistAddSongPositionNotifier.value == 'top'
                        ? FontWeight.bold
                        : FontWeight.normal,
                  ),
                ),
                subtitle: Text(
                  loc.positionTopSubtitle,
                  style: TextStyle(
                    color: isLight ? Colors.black54 : Colors.white54,
                    fontSize: 12,
                  ),
                ),
                trailing: playlistAddSongPositionNotifier.value == 'top'
                    ? Icon(Icons.check, color: _activeAccentColor)
                    : null,
                onTap: () async {
                  final nav = Navigator.of(ctx);
                  playlistAddSongPositionNotifier.value = 'top';
                  final prefs = await SharedPreferences.getInstance();
                  await prefs.setString('playlist_add_song_position', 'top');
                  nav.pop();
                },
              ),
              ListTile(
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: 24,
                  vertical: 4,
                ),
                leading: Icon(
                  Icons.vertical_align_bottom_rounded,
                  color: playlistAddSongPositionNotifier.value == 'bottom'
                      ? _activeAccentColor
                      : (isLight ? Colors.black54 : Colors.white54),
                ),
                title: Text(
                  loc.positionBottom,
                  style: TextStyle(
                    color: playlistAddSongPositionNotifier.value == 'bottom'
                        ? _activeAccentColor
                        : (isLight ? const Color(0xFF1A1A1A) : Colors.white),
                    fontWeight:
                        playlistAddSongPositionNotifier.value == 'bottom'
                            ? FontWeight.bold
                            : FontWeight.normal,
                  ),
                ),
                subtitle: Text(
                  loc.positionBottomSubtitle,
                  style: TextStyle(
                    color: isLight ? Colors.black54 : Colors.white54,
                    fontSize: 12,
                  ),
                ),
                trailing: playlistAddSongPositionNotifier.value == 'bottom'
                    ? Icon(Icons.check, color: _activeAccentColor)
                    : null,
                onTap: () async {
                  final nav = Navigator.of(ctx);
                  playlistAddSongPositionNotifier.value = 'bottom';
                  final prefs = await SharedPreferences.getInstance();
                  await prefs.setString('playlist_add_song_position', 'bottom');
                  nav.pop();
                },
              ),
              const SizedBox(height: 16),
            ],
          ),
        );
      },
    );
  }
}
