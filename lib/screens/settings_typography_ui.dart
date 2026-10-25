// ignore_for_file: library_private_types_in_public_api, deprecated_member_use, invalid_use_of_protected_member
part of 'settings_screen.dart';

extension SettingsTypographyModals on _SettingsScreenState {
  void _showTypographyPreviewDialog() {
    String tempFont = _activeFont;
    double tempFontScale = _fontScale;
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
        return StatefulBuilder(
          builder: (context, setModalState) {
            TextStyle previewTextStyle({
              double size = 14,
              FontWeight weight = FontWeight.normal,
              Color? color,
            }) {
              final baseStyle = TextStyle(
                fontSize: size * tempFontScale,
                fontWeight: weight,
                color:
                    color ?? (isLight ? const Color(0xFF1A1A1A) : Colors.white),
              );
              if (tempFont == 'Spotify Style') {
                return GoogleFonts.figtree(textStyle: baseStyle);
              } else if (tempFont == 'Apple Music Style') {
                return GoogleFonts.inter(textStyle: baseStyle);
              } else {
                return GoogleFonts.plusJakartaSans(textStyle: baseStyle);
              }
            }

            return DraggableScrollableSheet(
              initialChildSize: 0.85,
              minChildSize: 0.5,
              maxChildSize: 0.95,
              expand: false,
              builder: (context, scrollController) {
                return SingleChildScrollView(
                  controller: scrollController,
                  physics: const BouncingScrollPhysics(),
                  padding: const EdgeInsets.symmetric(
                    horizontal: 20,
                    vertical: 12,
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
                      const SizedBox(height: 16),
                      Center(
                        child: Text(
                          AppLocalizations.of(context).typographyFontSize,
                          style: TextStyle(
                            color: isLight
                                ? const Color(0xFF1A1A1A)
                                : Colors.white,
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                      const SizedBox(height: 20),

                      // Live Preview Section Header
                      Row(
                        children: [
                          Icon(
                            Icons.visibility_outlined,
                            color: _activeAccentColor,
                            size: 18,
                          ),
                          const SizedBox(width: 8),
                          Text(
                            AppLocalizations.of(context).livePreview,
                            style: TextStyle(
                              color: isLight ? Colors.black54 : Colors.white70,
                              fontSize: 14,
                              fontWeight: FontWeight.bold,
                              letterSpacing: 0.5,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 10),

                      // Live Simulated Library Window
                      Container(
                        width: double.infinity,
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(
                            color: Colors.white.withOpacity(0.08),
                          ),
                          gradient: const LinearGradient(
                            begin: Alignment.topCenter,
                            end: Alignment.bottomCenter,
                            colors: [Color(0xFF0A0A0A), Color(0xFF0A0A0A)],
                          ),
                        ),
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            // Simulated Header App Bar
                            Padding(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 24,
                                vertical: 8,
                              ),
                              child: Row(
                                mainAxisAlignment:
                                    MainAxisAlignment.spaceBetween,
                                children: [
                                  Expanded(
                                    child: FittedBox(
                                      fit: BoxFit.scaleDown,
                                      alignment: Alignment.centerLeft,
                                      child: Text(
                                        'Fley',
                                        style: previewTextStyle(
                                          size: 32,
                                          weight: FontWeight.w800,
                                        ).copyWith(letterSpacing: -1.0),
                                      ),
                                    ),
                                  ),
                                  const SizedBox(width: 16),
                                  Icon(
                                    Icons.settings,
                                    color: Colors.white,
                                    size: 24 * tempFontScale,
                                  ),
                                ],
                              ),
                            ),

                            // Simulated Search Bar & Sort Button Row
                            Padding(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 24,
                                vertical: 4,
                              ),
                              child: Row(
                                children: [
                                  Expanded(
                                    child: Container(
                                      height: 42,
                                      decoration: BoxDecoration(
                                        color: const Color(0xFF161616),
                                        borderRadius: BorderRadius.circular(10),
                                      ),
                                      child: Row(
                                        children: [
                                          const SizedBox(width: 12),
                                          Icon(
                                            Icons.search,
                                            color: Colors.white.withOpacity(
                                              0.3,
                                            ),
                                            size: 20 * tempFontScale,
                                          ),
                                          const SizedBox(width: 8),
                                          Expanded(
                                            child: Text(
                                              AppLocalizations.of(
                                                context,
                                              ).searchSongs,
                                              maxLines: 1,
                                              overflow: TextOverflow.ellipsis,
                                              style: previewTextStyle(
                                                size: 13,
                                                color: Colors.white.withOpacity(
                                                  0.3,
                                                ),
                                              ),
                                            ),
                                          ),
                                          const SizedBox(width: 12),
                                        ],
                                      ),
                                    ),
                                  ),
                                  const SizedBox(width: 8),
                                  Container(
                                    width: 42,
                                    height: 42,
                                    decoration: BoxDecoration(
                                      color: const Color(0xFF161616),
                                      borderRadius: BorderRadius.circular(10),
                                    ),
                                    alignment: Alignment.center,
                                    child: Icon(
                                      Icons.sort_rounded,
                                      color: Colors.white.withOpacity(0.5),
                                      size: 20 * tempFontScale,
                                    ),
                                  ),
                                ],
                              ),
                            ),

                            // Simulated Filter Capsules
                            Padding(
                              padding: const EdgeInsets.only(
                                left: 24,
                                right: 24,
                                top: 16,
                                bottom: 12,
                              ),
                              child: Row(
                                children: [
                                  Expanded(
                                    child: _buildSimulatedFilterCapsule(
                                      AppLocalizations.of(context).songsTitle,
                                      true,
                                      previewTextStyle,
                                    ),
                                  ),
                                  const SizedBox(width: 8),
                                  Expanded(
                                    child: _buildSimulatedFilterCapsule(
                                      AppLocalizations.of(context).playlists,
                                      false,
                                      previewTextStyle,
                                    ),
                                  ),
                                  const SizedBox(width: 8),
                                  Expanded(
                                    child: _buildSimulatedFilterCapsule(
                                      AppLocalizations.of(context).artists,
                                      false,
                                      previewTextStyle,
                                    ),
                                  ),
                                  const SizedBox(width: 8),
                                  Expanded(
                                    child: _buildSimulatedFilterCapsule(
                                      AppLocalizations.of(context).albums,
                                      false,
                                      previewTextStyle,
                                    ),
                                  ),
                                ],
                              ),
                            ),

                            const SizedBox(height: 8),

                            // Simulated Song List (Padding left/right 16)
                            Padding(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 16,
                              ),
                              child: Column(
                                children: [
                                  _buildSimulatedSongRow(
                                    title: 'Alexandra',
                                    artist: 'Reality Club',
                                    duration: '4:08',
                                    textStyleHelper: previewTextStyle,
                                    tempFontScale: tempFontScale,
                                  ),
                                  const SizedBox(height: 4),
                                  _buildSimulatedSongRow(
                                    title: 'About You',
                                    artist: 'The 1975',
                                    duration: '5:26',
                                    textStyleHelper: previewTextStyle,
                                    tempFontScale: tempFontScale,
                                  ),
                                  const SizedBox(height: 4),
                                  _buildSimulatedSongRow(
                                    title: 'Apocalypse',
                                    artist: 'Cigarettes After Sex',
                                    duration: '4:50',
                                    textStyleHelper: previewTextStyle,
                                    tempFontScale: tempFontScale,
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 24),

                      // Typography Selection Row
                      Text(
                        AppLocalizations.of(context).fontFamily,
                        style: const TextStyle(
                          color: Colors.white70,
                          fontSize: 13,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 10),
                      Row(
                        children: [
                          Expanded(
                            child: _buildFontSelectorChip(
                              label: 'Plus Jakarta',
                              value: 'Plus Jakarta Sans',
                              selectedValue: tempFont,
                              onTap: () => setModalState(
                                () => tempFont = 'Plus Jakarta Sans',
                              ),
                            ),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: _buildFontSelectorChip(
                              label: 'Spotify Style',
                              value: 'Spotify Style',
                              selectedValue: tempFont,
                              onTap: () => setModalState(
                                () => tempFont = 'Spotify Style',
                              ),
                            ),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: _buildFontSelectorChip(
                              label: 'Apple Style',
                              value: 'Apple Music Style',
                              selectedValue: tempFont,
                              onTap: () => setModalState(
                                () => tempFont = 'Apple Music Style',
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 24),

                      // Font Size Selection List
                      Text(
                        AppLocalizations.of(context).fontSize,
                        style: const TextStyle(
                          color: Colors.white70,
                          fontSize: 13,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 10),
                      _buildFontSizeSelectorRow(
                        '${AppLocalizations.of(context).sizeSmall} (85%)',
                        0.85,
                        tempFontScale,
                        (val) {
                          setModalState(() => tempFontScale = val);
                        },
                      ),
                      _buildFontSizeSelectorRow(
                        '${AppLocalizations.of(context).sizeDefault} (100%)',
                        1.0,
                        tempFontScale,
                        (val) {
                          setModalState(() => tempFontScale = val);
                        },
                      ),
                      _buildFontSizeSelectorRow(
                        '${AppLocalizations.of(context).sizeLarge} (115%)',
                        1.15,
                        tempFontScale,
                        (val) {
                          setModalState(() => tempFontScale = val);
                        },
                      ),
                      _buildFontSizeSelectorRow(
                        '${AppLocalizations.of(context).sizeExtraLarge} (130%)',
                        1.3,
                        tempFontScale,
                        (val) {
                          setModalState(() => tempFontScale = val);
                        },
                      ),

                      const SizedBox(height: 32),

                      // Bottom actions Close & Save
                      Row(
                        children: [
                          Expanded(
                            child: InkWell(
                              onTap: () => Navigator.pop(context),
                              borderRadius: BorderRadius.circular(12),
                              child: Container(
                                height: 48,
                                decoration: BoxDecoration(
                                  color: Colors.white.withOpacity(0.06),
                                  borderRadius: BorderRadius.circular(12),
                                  border: Border.all(
                                    color: Colors.white.withOpacity(0.05),
                                  ),
                                ),
                                child: Center(
                                  child: Text(
                                    AppLocalizations.of(context).close,
                                    style: TextStyle(
                                      color: Colors.white70,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: InkWell(
                              onTap: () async {
                                final prefs =
                                    await SharedPreferences.getInstance();
                                await prefs.setString('activeFont', tempFont);
                                await prefs.setDouble(
                                  'fontScale',
                                  tempFontScale,
                                );
                                ref
                                    .read(settingsProvider.notifier)
                                    .updateSetting(activeFont: tempFont);
                                ref
                                    .read(settingsProvider.notifier)
                                    .updateSetting(fontScale: tempFontScale);
                                setState(() {
                                  _activeFont = tempFont;
                                  _fontScale = tempFontScale;
                                });
                                if (context.mounted) {
                                  Navigator.pop(context);
                                }
                                showFleyToast(
                                  "Typography & size updated successfully!",
                                );
                              },
                              borderRadius: BorderRadius.circular(12),
                              child: Container(
                                height: 48,
                                decoration: BoxDecoration(
                                  gradient: LinearGradient(
                                    colors: [
                                      _activeAccentColor,
                                      _activeAccentColor.withOpacity(0.8),
                                    ],
                                  ),
                                  borderRadius: BorderRadius.circular(12),
                                  boxShadow: [
                                    BoxShadow(
                                      color: _activeAccentColor.withOpacity(
                                        0.3,
                                      ),
                                      blurRadius: 10,
                                      offset: const Offset(0, 4),
                                    ),
                                  ],
                                ),
                                child: Center(
                                  child: Text(
                                    AppLocalizations.of(context).save,
                                    style: TextStyle(
                                      color: Colors.white,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 20),
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
