// ignore_for_file: library_private_types_in_public_api, deprecated_member_use, invalid_use_of_protected_member
part of 'settings_screen.dart';

extension SettingsThemeModeModals on _SettingsScreenState {
  String _getPlayerBackgroundStyleLabel(String style) {
    switch (style) {
      case 'gradient':
        return AppLocalizations.of(context).gradientDynamic;
      case 'blur':
        return AppLocalizations.of(context).blurredCover;
      case 'amoled':
        return AppLocalizations.of(context).amoledBlack;
      case 'custom':
        return AppLocalizations.of(context).customImage;
      default:
        return AppLocalizations.of(context).gradientDynamic;
    }
  }

  void _showPlayerBackgroundStyleDialog() {
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
            return DraggableScrollableSheet(
              initialChildSize: 0.55,
              minChildSize: 0.3,
              maxChildSize: 0.75,
              expand: false,
              builder: (context, scrollController) {
                final options = [
                  {
                    'id': 'gradient',
                    'label': AppLocalizations.of(context).gradientDynamic,
                    'desc': AppLocalizations.of(context).playerBgDescGradient,
                  },
                  {
                    'id': 'blur',
                    'label': AppLocalizations.of(context).blurredCover,
                    'desc': AppLocalizations.of(context).playerBgDescBlur,
                  },
                  {
                    'id': 'amoled',
                    'label': AppLocalizations.of(context).amoledBlack,
                    'desc': AppLocalizations.of(context).playerBgDescAmoled,
                  },
                  {
                    'id': 'custom',
                    'label': AppLocalizations.of(context).customImage,
                    'desc': AppLocalizations.of(context).playerBgDescCustom,
                  },
                ];

                return Column(
                  children: [
                    const SizedBox(height: 12),
                    Container(
                      width: 40,
                      height: 4,
                      decoration: BoxDecoration(
                        color: isLight ? Colors.black12 : Colors.white24,
                        borderRadius: BorderRadius.circular(10),
                      ),
                    ),
                    const SizedBox(height: 16),
                    Text(
                      AppLocalizations.of(context).playerBackground,
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                        fontFamily: getFontFamily(_activeFont),
                        color: isLight ? const Color(0xFF1A1A1A) : Colors.white,
                      ),
                    ),
                    const SizedBox(height: 16),
                    Expanded(
                      child: ListView.builder(
                        controller: scrollController,
                        itemCount: options.length,
                        itemBuilder: (context, index) {
                          final opt = options[index];
                          final id = opt['id'] as String;
                          final label = opt['label'] as String;
                          final desc = opt['desc'] as String;
                          final isSelected = _playerBackgroundStyle == id;

                          return ListTile(
                            contentPadding: const EdgeInsets.symmetric(
                              horizontal: 24,
                              vertical: 4,
                            ),
                            onTap: () async {
                              if (id == 'custom') {
                                if (_playerCustomBgPath != null &&
                                    File(_playerCustomBgPath!).existsSync()) {
                                  final prefs =
                                      await SharedPreferences.getInstance();
                                  await prefs.setString(
                                    'playerBackgroundStyle',
                                    'custom',
                                  );
                                  if (!mounted) return;
                                  setState(() {
                                    _playerBackgroundStyle = 'custom';
                                  });
                                  setModalState(() {
                                    _playerBackgroundStyle = 'custom';
                                  });
                                  ref
                                      .read(settingsProvider.notifier)
                                      .updateSetting(
                                        playerBackgroundStyle: 'custom',
                                      );
                                  showFleyToast(
                                    '${lookupAppLocalizations(Locale(FleyStrings.currentLang)).toastBgStyleSet} $label',
                                  );
                                  if (!context.mounted) return;
                                  Navigator.pop(context);
                                } else {
                                  final ImagePicker picker = ImagePicker();
                                  final XFile? image = await picker.pickImage(
                                    source: ImageSource.gallery,
                                  );
                                  if (image != null) {
                                    if (!context.mounted) return;
                                    final croppedPath =
                                        await ImageCropperUtil.cropImage(
                                          context: context,
                                          sourcePath: image.path,
                                        );
                                    if (croppedPath != null) {
                                      final prefs =
                                          await SharedPreferences.getInstance();
                                      await prefs.setString(
                                        'playerBackgroundStyle',
                                        'custom',
                                      );
                                      await prefs.setString(
                                        'playerCustomBgPath',
                                        croppedPath,
                                      );
                                      if (!mounted) return;
                                      setState(() {
                                        _playerBackgroundStyle = 'custom';
                                        _playerCustomBgPath = croppedPath;
                                      });
                                      setModalState(() {
                                        _playerBackgroundStyle = 'custom';
                                      });
                                      ref
                                          .read(settingsProvider.notifier)
                                          .updateSetting(
                                            playerBackgroundStyle: 'custom',
                                          );
                                      ref
                                          .read(settingsProvider.notifier)
                                          .updateSetting(
                                            playerCustomBgPath: croppedPath,
                                          );
                                      showFleyToast(
                                        '${lookupAppLocalizations(Locale(FleyStrings.currentLang)).toastBgStyleSet} $label',
                                      );
                                      if (!context.mounted) return;
                                      Navigator.pop(context);
                                    }
                                  }
                                }
                              } else {
                                final prefs =
                                    await SharedPreferences.getInstance();
                                await prefs.setString(
                                  'playerBackgroundStyle',
                                  id,
                                );
                                if (!mounted) return;
                                setState(() {
                                  _playerBackgroundStyle = id;
                                });
                                setModalState(() {
                                  _playerBackgroundStyle = id;
                                });
                                ref
                                    .read(settingsProvider.notifier)
                                    .updateSetting(playerBackgroundStyle: id);
                                showFleyToast(
                                  '${lookupAppLocalizations(Locale(FleyStrings.currentLang)).toastBgStyleSet} $label',
                                );
                                if (!context.mounted) return;
                                Navigator.pop(context);
                              }
                            },
                            title: Text(
                              label,
                              style: TextStyle(
                                color: isLight
                                    ? const Color(0xFF1A1A1A)
                                    : Colors.white,
                                fontWeight: isSelected
                                    ? FontWeight.bold
                                    : FontWeight.normal,
                                fontFamily: getFontFamily(_activeFont),
                              ),
                            ),
                            subtitle: Text(
                              desc,
                              style: TextStyle(
                                color: isLight
                                    ? Colors.black54
                                    : Colors.white54,
                                fontSize: 13,
                              ),
                            ),
                            trailing: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                if (id == 'custom' &&
                                    _playerCustomBgPath != null) ...[
                                  ClipRRect(
                                    borderRadius: BorderRadius.circular(4),
                                    child: Image.file(
                                      File(_playerCustomBgPath!),
                                      width: 28,
                                      height: 28,
                                      fit: BoxFit.cover,
                                    ),
                                  ),
                                  const SizedBox(width: 8),
                                ],
                                if (isSelected)
                                  Icon(
                                    Icons.check_circle,
                                    color: _activeAccentColor,
                                  ),
                              ],
                            ),
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

  String _getThemeModeLabel(String mode) {
    switch (mode) {
      case 'light':
        return AppLocalizations.of(context).lightMode;
      case 'custom':
        return AppLocalizations.of(context).customTheme;
      case 'dark':
      default:
        return AppLocalizations.of(context).darkMode;
    }
  }

  void _showThemeModeSelectionDialog() {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (context) {
        final isLight = _selectedThemeMode == 'light';
        final cardColor = isLight ? Colors.white : const Color(0xFF161616);
        final titleColor = isLight ? const Color(0xFF1A1A1A) : Colors.white;

        return Container(
          decoration: BoxDecoration(
            color: cardColor,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const SizedBox(height: 12),
              Container(
                width: 40,
                height: 5,
                decoration: BoxDecoration(
                  color: isLight
                      ? Colors.black.withOpacity(0.08)
                      : Colors.white24,
                  borderRadius: BorderRadius.circular(2.5),
                ),
              ),
              const SizedBox(height: 16),
              Text(
                AppLocalizations.of(context).themeMode,
                style: TextStyle(
                  color: titleColor,
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 16),
              _buildThemeModeItem(
                id: 'dark',
                title: AppLocalizations.of(context).darkMode,
                subtitle: AppLocalizations.of(context).themeModeDescDark,
                icon: Icons.dark_mode_outlined,
              ),
              _buildThemeModeItem(
                id: 'light',
                title: AppLocalizations.of(context).lightMode,
                subtitle: AppLocalizations.of(context).themeModeDescLight,
                icon: Icons.light_mode_outlined,
              ),
              _buildThemeModeItem(
                id: 'custom',
                title: AppLocalizations.of(context).customTheme,
                subtitle: AppLocalizations.of(context).themeModeDescCustom,
                icon: Icons.color_lens_outlined,
              ),
              const SizedBox(height: 24),
            ],
          ),
        );
      },
    );
  }

  Widget _buildThemeModeItem({
    required String id,
    required String title,
    required String subtitle,
    required IconData icon,
  }) {
    final isSelected = _selectedThemeMode == id;
    final isLight = _selectedThemeMode == 'light';
    final primaryTextColor = isLight ? const Color(0xFF1A1A1A) : Colors.white;
    final secondaryTextColor = isLight ? Colors.black45 : Colors.white38;

    return ListTile(
      leading: Container(
        width: 40,
        height: 40,
        decoration: BoxDecoration(
          color: isSelected
              ? _activeAccentColor.withOpacity(0.1)
              : (isLight
                    ? Colors.black.withOpacity(0.04)
                    : Colors.white.withOpacity(0.05)),
          shape: BoxShape.circle,
        ),
        child: Icon(
          icon,
          color: isSelected
              ? _activeAccentColor
              : (isLight ? Colors.black54 : Colors.white70),
        ),
      ),
      title: Text(
        title,
        style: TextStyle(
          color: primaryTextColor,
          fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
        ),
      ),
      subtitle: Text(
        subtitle,
        style: TextStyle(color: secondaryTextColor, fontSize: 12),
      ),
      trailing: isSelected
          ? Icon(Icons.check_circle, color: _activeAccentColor)
          : null,
      onTap: () async {
        Navigator.pop(context);
        final prefs = await SharedPreferences.getInstance();
        await prefs.setString('themeMode', id);
        setState(() {
          _selectedThemeMode = id;
        });
        ref.read(settingsProvider.notifier).updateSetting(themeMode: id);
      },
    );
  }

  Widget _buildStylePill(String id, String label) {
    final isSelected = _customThemeStyle == id;
    final isLight = _selectedThemeMode == 'light';

    return GestureDetector(
      onTap: () async {
        final prefs = await SharedPreferences.getInstance();
        await prefs.setString('customThemeStyle', id);
        setState(() {
          _customThemeStyle = id;
        });
        ref.read(settingsProvider.notifier).updateSetting(customThemeStyle: id);
        showFleyToast(
          '${lookupAppLocalizations(Locale(FleyStrings.currentLang)).toastThemeStyleSet} $label',
        );
      },
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(vertical: 8),
        decoration: BoxDecoration(
          color: isSelected
              ? _activeAccentColor
              : (isLight
                    ? Colors.black.withOpacity(0.05)
                    : Colors.white.withValues(alpha: 0.05)),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: isSelected
                ? _activeAccentColor
                : (isLight ? Colors.black12 : Colors.white10),
            width: 1,
          ),
        ),
        alignment: Alignment.center,
        child: Text(
          label,
          style: TextStyle(
            color: isSelected
                ? Colors.white
                : (isLight ? Colors.black87 : Colors.white70),
            fontSize: 12,
            fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
            fontFamily: getFontFamily(_activeFont),
          ),
        ),
      ),
    );
  }

  Widget _buildCustomBgOption({
    required String id,
    required String name,
    required Color color,
  }) {
    final isSelected = _customThemeBg == id;
    final isLight = _selectedThemeMode == 'light';

    return GestureDetector(
      onTap: () async {
        final prefs = await SharedPreferences.getInstance();
        await prefs.setString('customThemeBg', id);
        setState(() {
          _customThemeBg = id;
        });
        ref.read(settingsProvider.notifier).updateSetting(customThemeBg: id);

        if (id == 'custom_image' && _customThemeBgPath == null) {
          final ImagePicker picker = ImagePicker();
          final XFile? image = await picker.pickImage(
            source: ImageSource.gallery,
          );
          if (image != null) {
            if (!mounted) return;
            final croppedPath = await ImageCropperUtil.cropImage(
              context: context,
              sourcePath: image.path,
            );
            if (croppedPath != null) {
              await prefs.setString('customThemeBgPath', croppedPath);
              setState(() {
                _customThemeBgPath = croppedPath;
              });
              ref
                  .read(settingsProvider.notifier)
                  .updateSetting(customThemeBgPath: croppedPath);
              showFleyToast(
                lookupAppLocalizations(
                  Locale(FleyStrings.currentLang),
                ).wallpaperUpdated,
              );
            }
          }
        }
      },
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 250),
        curve: Curves.easeInOut,
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        decoration: BoxDecoration(
          color: isSelected
              ? _activeAccentColor.withOpacity(0.15)
              : (isLight
                    ? Colors.black.withOpacity(0.04)
                    : Colors.white.withOpacity(0.05)),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: isSelected ? _activeAccentColor : Colors.transparent,
            width: 1.5,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 16,
              height: 16,
              decoration: BoxDecoration(
                color: id == 'custom_image' && _customThemeBgPath != null
                    ? null
                    : color,
                image:
                    id == 'custom_image' &&
                        _customThemeBgPath != null &&
                        File(_customThemeBgPath!).existsSync()
                    ? DecorationImage(
                        image: FileImage(File(_customThemeBgPath!)),
                        fit: BoxFit.cover,
                      )
                    : null,
                shape: BoxShape.circle,
                border: Border.all(
                  color: isLight ? Colors.black26 : Colors.white30,
                  width: 1,
                ),
              ),
              child: isSelected && id == 'dynamic'
                  ? const Icon(Icons.star, size: 8, color: Colors.white)
                  : (id == 'custom_image' && _customThemeBgPath == null
                        ? const Icon(Icons.add, size: 8, color: Colors.white)
                        : null),
            ),
            const SizedBox(width: 8),
            Text(
              name,
              style: TextStyle(
                color: isSelected
                    ? _activeAccentColor
                    : (isLight ? const Color(0xFF1A1A1A) : Colors.white70),
                fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                fontSize: 13,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
