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

  String _getDetailViewBackgroundStyleLabel(String style) {
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

  Widget _buildBackgroundStyleItem({
    required String id,
    required String currentSelectedId,
    required String title,
    required String subtitle,
    required IconData icon,
    String? customPath,
    required VoidCallback onTap,
  }) {
    final isSelected = currentSelectedId == id;
    final isLight = _selectedThemeMode == 'light';
    final primaryTextColor = isLight ? const Color(0xFF1A1A1A) : Colors.white;
    final secondaryTextColor = isLight ? Colors.black45 : Colors.white38;

    return ListTile(
      contentPadding: const EdgeInsets.symmetric(horizontal: 24, vertical: 4),
      leading: Container(
        width: 40,
        height: 40,
        decoration: BoxDecoration(
          color: isSelected
              ? _activeAccentColor.withValues(alpha: 0.1)
              : (isLight
                    ? Colors.black.withValues(alpha: 0.04)
                    : Colors.white.withValues(alpha: 0.05)),
          shape: BoxShape.circle,
        ),
        child: Icon(
          icon,
          color: isSelected
              ? _activeAccentColor
              : (isLight ? Colors.black54 : Colors.white70),
          size: 20,
        ),
      ),
      title: Text(
        title,
        style: TextStyle(
          color: primaryTextColor,
          fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
          fontFamily: getFontFamily(_activeFont),
        ),
      ),
      subtitle: Text(
        subtitle,
        style: TextStyle(
          color: secondaryTextColor,
          fontSize: 13,
          fontFamily: getFontFamily(_activeFont),
        ),
      ),
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (id == 'custom' &&
              customPath != null &&
              File(customPath).existsSync()) ...[
            ClipRRect(
              borderRadius: BorderRadius.circular(4),
              child: Image.file(
                File(customPath),
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
      onTap: onTap,
    );
  }

  void _showPlayerBackgroundStyleDialog() {
    final loc = AppLocalizations.of(context);
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (context) {
        final isLight = _selectedThemeMode == 'light';
        final cardColor = isLight ? Colors.white : const Color(0xFF161616);
        final titleColor = isLight ? const Color(0xFF1A1A1A) : Colors.white;

        return StatefulBuilder(
          builder: (context, setModalState) {
            return Container(
              decoration: BoxDecoration(
                color: cardColor,
                borderRadius:
                    const BorderRadius.vertical(top: Radius.circular(24)),
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
                          ? Colors.black.withValues(alpha: 0.08)
                          : Colors.white24,
                      borderRadius: BorderRadius.circular(2.5),
                    ),
                  ),
                  const SizedBox(height: 16),
                  Text(
                    loc.playerBackground,
                    style: TextStyle(
                      color: titleColor,
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      fontFamily: getFontFamily(_activeFont),
                    ),
                  ),
                  const SizedBox(height: 16),
                  _buildBackgroundStyleItem(
                    id: 'gradient',
                    currentSelectedId: _playerBackgroundStyle,
                    title: loc.gradientDynamic,
                    subtitle: loc.playerBgDescGradient,
                    icon: Icons.gradient_rounded,
                    onTap: () async {
                      final prefs = await SharedPreferences.getInstance();
                      await prefs.setString(
                        'playerBackgroundStyle',
                        'gradient',
                      );
                      if (!mounted) return;
                      setState(() => _playerBackgroundStyle = 'gradient');
                      setModalState(() {});
                      ref
                          .read(settingsProvider.notifier)
                          .updateSetting(playerBackgroundStyle: 'gradient');
                      showFleyToast(
                        '${loc.toastBgStyleSet} ${loc.gradientDynamic}',
                      );
                      if (context.mounted) Navigator.pop(context);
                    },
                  ),
                  _buildBackgroundStyleItem(
                    id: 'blur',
                    currentSelectedId: _playerBackgroundStyle,
                    title: loc.blurredCover,
                    subtitle: loc.playerBgDescBlur,
                    icon: Icons.blur_on_rounded,
                    onTap: () async {
                      final prefs = await SharedPreferences.getInstance();
                      await prefs.setString('playerBackgroundStyle', 'blur');
                      if (!mounted) return;
                      setState(() => _playerBackgroundStyle = 'blur');
                      setModalState(() {});
                      ref
                          .read(settingsProvider.notifier)
                          .updateSetting(playerBackgroundStyle: 'blur');
                      showFleyToast(
                        '${loc.toastBgStyleSet} ${loc.blurredCover}',
                      );
                      if (context.mounted) Navigator.pop(context);
                    },
                  ),
                  _buildBackgroundStyleItem(
                    id: 'amoled',
                    currentSelectedId: _playerBackgroundStyle,
                    title: loc.amoledBlack,
                    subtitle: loc.playerBgDescAmoled,
                    icon: Icons.brightness_2_outlined,
                    onTap: () async {
                      final prefs = await SharedPreferences.getInstance();
                      await prefs.setString('playerBackgroundStyle', 'amoled');
                      if (!mounted) return;
                      setState(() => _playerBackgroundStyle = 'amoled');
                      setModalState(() {});
                      ref
                          .read(settingsProvider.notifier)
                          .updateSetting(playerBackgroundStyle: 'amoled');
                      showFleyToast(
                        '${loc.toastBgStyleSet} ${loc.amoledBlack}',
                      );
                      if (context.mounted) Navigator.pop(context);
                    },
                  ),
                  _buildBackgroundStyleItem(
                    id: 'custom',
                    currentSelectedId: _playerBackgroundStyle,
                    title: loc.customImage,
                    subtitle: loc.playerBgDescCustom,
                    icon: Icons.image_outlined,
                    customPath: _playerCustomBgPath,
                    onTap: () async {
                      if (_playerCustomBgPath != null &&
                          File(_playerCustomBgPath!).existsSync()) {
                        final prefs = await SharedPreferences.getInstance();
                        await prefs.setString(
                          'playerBackgroundStyle',
                          'custom',
                        );
                        if (!mounted) return;
                        setState(() => _playerBackgroundStyle = 'custom');
                        setModalState(() {});
                        ref
                            .read(settingsProvider.notifier)
                            .updateSetting(playerBackgroundStyle: 'custom');
                        showFleyToast(
                          '${loc.toastBgStyleSet} ${loc.customImage}',
                        );
                        if (context.mounted) Navigator.pop(context);
                      } else {
                        final picker = ImagePicker();
                        final image = await picker.pickImage(
                          source: ImageSource.gallery,
                        );
                        if (image != null) {
                          String? targetPath;
                          if (image.path.toLowerCase().endsWith('.gif')) {
                            final appDir =
                                await getApplicationDocumentsDirectory();
                            final gifFile = File(
                              '${appDir.path}/custom_bg_${DateTime.now().millisecondsSinceEpoch}.gif',
                            );
                            await File(image.path).copy(gifFile.path);
                            targetPath = gifFile.path;
                          } else {
                            if (!context.mounted) return;
                            targetPath = await ImageCropperUtil.cropImage(
                              context: context,
                              sourcePath: image.path,
                            );
                          }
                          if (targetPath != null) {
                            final prefs =
                                await SharedPreferences.getInstance();
                            await prefs.setString(
                              'playerBackgroundStyle',
                              'custom',
                            );
                            await prefs.setString(
                              'playerCustomBgPath',
                              targetPath,
                            );
                            if (!mounted) return;
                            setState(() {
                              _playerBackgroundStyle = 'custom';
                              _playerCustomBgPath = targetPath;
                            });
                            setModalState(() {});
                            ref.read(settingsProvider.notifier).updateSetting(
                                  playerBackgroundStyle: 'custom',
                                  playerCustomBgPath: targetPath,
                                );
                            showFleyToast(
                              '${loc.toastBgStyleSet} ${loc.customImage}',
                            );
                            if (context.mounted) Navigator.pop(context);
                          }
                        }
                      }
                    },
                  ),
                  const SizedBox(height: 24),
                ],
              ),
            );
          },
        );
      },
    );
  }

  void _showDetailViewBackgroundStyleDialog() {
    final loc = AppLocalizations.of(context);
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (context) {
        final isLight = _selectedThemeMode == 'light';
        final cardColor = isLight ? Colors.white : const Color(0xFF161616);
        final titleColor = isLight ? const Color(0xFF1A1A1A) : Colors.white;

        return StatefulBuilder(
          builder: (context, setModalState) {
            return Container(
              decoration: BoxDecoration(
                color: cardColor,
                borderRadius:
                    const BorderRadius.vertical(top: Radius.circular(24)),
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
                          ? Colors.black.withValues(alpha: 0.08)
                          : Colors.white24,
                      borderRadius: BorderRadius.circular(2.5),
                    ),
                  ),
                  const SizedBox(height: 16),
                  Text(
                    loc.detailViewBackground,
                    style: TextStyle(
                      color: titleColor,
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      fontFamily: getFontFamily(_activeFont),
                    ),
                  ),
                  const SizedBox(height: 16),
                  _buildBackgroundStyleItem(
                    id: 'gradient',
                    currentSelectedId: _detailViewBackgroundStyle,
                    title: loc.gradientDynamic,
                    subtitle: loc.playerBgDescGradient,
                    icon: Icons.gradient_rounded,
                    onTap: () async {
                      final prefs = await SharedPreferences.getInstance();
                      await prefs.setString(
                        'detailViewBackgroundStyle',
                        'gradient',
                      );
                      if (!mounted) return;
                      setState(() => _detailViewBackgroundStyle = 'gradient');
                      setModalState(() {});
                      ref
                          .read(settingsProvider.notifier)
                          .updateSetting(detailViewBackgroundStyle: 'gradient');
                      showFleyToast(
                        '${loc.toastBgStyleSet} ${loc.gradientDynamic}',
                      );
                      if (context.mounted) Navigator.pop(context);
                    },
                  ),
                  _buildBackgroundStyleItem(
                    id: 'blur',
                    currentSelectedId: _detailViewBackgroundStyle,
                    title: loc.blurredCover,
                    subtitle: loc.playerBgDescBlur,
                    icon: Icons.blur_on_rounded,
                    onTap: () async {
                      final prefs = await SharedPreferences.getInstance();
                      await prefs.setString('detailViewBackgroundStyle', 'blur');
                      if (!mounted) return;
                      setState(() => _detailViewBackgroundStyle = 'blur');
                      setModalState(() {});
                      ref
                          .read(settingsProvider.notifier)
                          .updateSetting(detailViewBackgroundStyle: 'blur');
                      showFleyToast(
                        '${loc.toastBgStyleSet} ${loc.blurredCover}',
                      );
                      if (context.mounted) Navigator.pop(context);
                    },
                  ),
                  _buildBackgroundStyleItem(
                    id: 'amoled',
                    currentSelectedId: _detailViewBackgroundStyle,
                    title: loc.amoledBlack,
                    subtitle: loc.playerBgDescAmoled,
                    icon: Icons.brightness_2_outlined,
                    onTap: () async {
                      final prefs = await SharedPreferences.getInstance();
                      await prefs.setString(
                        'detailViewBackgroundStyle',
                        'amoled',
                      );
                      if (!mounted) return;
                      setState(() => _detailViewBackgroundStyle = 'amoled');
                      setModalState(() {});
                      ref
                          .read(settingsProvider.notifier)
                          .updateSetting(detailViewBackgroundStyle: 'amoled');
                      showFleyToast(
                        '${loc.toastBgStyleSet} ${loc.amoledBlack}',
                      );
                      if (context.mounted) Navigator.pop(context);
                    },
                  ),
                  _buildBackgroundStyleItem(
                    id: 'custom',
                    currentSelectedId: _detailViewBackgroundStyle,
                    title: loc.customImage,
                    subtitle: loc.playerBgDescCustom,
                    icon: Icons.image_outlined,
                    customPath: _detailViewCustomBgPath,
                    onTap: () async {
                      if (_detailViewCustomBgPath != null &&
                          File(_detailViewCustomBgPath!).existsSync()) {
                        final prefs = await SharedPreferences.getInstance();
                        await prefs.setString(
                          'detailViewBackgroundStyle',
                          'custom',
                        );
                        if (!mounted) return;
                        setState(() => _detailViewBackgroundStyle = 'custom');
                        setModalState(() {});
                        ref
                            .read(settingsProvider.notifier)
                            .updateSetting(detailViewBackgroundStyle: 'custom');
                        showFleyToast(
                          '${loc.toastBgStyleSet} ${loc.customImage}',
                        );
                        if (context.mounted) Navigator.pop(context);
                      } else {
                        final picker = ImagePicker();
                        final image = await picker.pickImage(
                          source: ImageSource.gallery,
                        );
                        if (image != null) {
                          String? targetPath;
                          if (image.path.toLowerCase().endsWith('.gif')) {
                            final appDir =
                                await getApplicationDocumentsDirectory();
                            final gifFile = File(
                              '${appDir.path}/custom_detail_bg_${DateTime.now().millisecondsSinceEpoch}.gif',
                            );
                            await File(image.path).copy(gifFile.path);
                            targetPath = gifFile.path;
                          } else {
                            if (!context.mounted) return;
                            targetPath = await ImageCropperUtil.cropImage(
                              context: context,
                              sourcePath: image.path,
                            );
                          }
                          if (targetPath != null) {
                            final prefs =
                                await SharedPreferences.getInstance();
                            await prefs.setString(
                              'detailViewBackgroundStyle',
                              'custom',
                            );
                            await prefs.setString(
                              'detailViewCustomBgPath',
                              targetPath,
                            );
                            if (!mounted) return;
                            setState(() {
                              _detailViewBackgroundStyle = 'custom';
                              _detailViewCustomBgPath = targetPath;
                            });
                            setModalState(() {});
                            ref.read(settingsProvider.notifier).updateSetting(
                                  detailViewBackgroundStyle: 'custom',
                                  detailViewCustomBgPath: targetPath,
                                );
                            showFleyToast(
                              '${loc.toastBgStyleSet} ${loc.customImage}',
                            );
                            if (context.mounted) Navigator.pop(context);
                          }
                        }
                      }
                    },
                  ),
                  const SizedBox(height: 24),
                ],
              ),
            );
          },
        );
      },
    );
  }

  void _showHomeBannerOptionsModal() {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (context) {
        final isLight = _selectedThemeMode == 'light';
        final cardColor = isLight ? Colors.white : const Color(0xFF161616);
        final titleColor = isLight ? const Color(0xFF1A1A1A) : Colors.white;
        final loc = AppLocalizations.of(context);

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
                      ? Colors.black.withValues(alpha: 0.08)
                      : Colors.white24,
                  borderRadius: BorderRadius.circular(2.5),
                ),
              ),
              const SizedBox(height: 16),
              Text(
                loc.homeBanner,
                style: TextStyle(
                  color: titleColor,
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  fontFamily: getFontFamily(_activeFont),
                ),
              ),
              const SizedBox(height: 16),
              ListTile(
                contentPadding:
                    const EdgeInsets.symmetric(horizontal: 24, vertical: 4),
                leading: Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    color: _activeAccentColor.withValues(alpha: 0.1),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    Icons.photo_library_outlined,
                    color: _activeAccentColor,
                    size: 20,
                  ),
                ),
                title: Text(
                  AppLocalizations.of(context).changeBannerGif,
                  style: TextStyle(
                    color: titleColor,
                    fontFamily: getFontFamily(_activeFont),
                  ),
                ),
                subtitle: Text(
                  AppLocalizations.of(context).homeBannerDesc,
                  style: TextStyle(
                    color: isLight ? Colors.black45 : Colors.white38,
                    fontSize: 13,
                    fontFamily: getFontFamily(_activeFont),
                  ),
                ),
                onTap: () async {
                  final picker = ImagePicker();
                  final image =
                      await picker.pickImage(source: ImageSource.gallery);
                  if (image != null) {
                    String? targetPath;
                    if (image.path.toLowerCase().endsWith('.gif')) {
                      final appDir = await getApplicationDocumentsDirectory();
                      final gifFile = File(
                        '${appDir.path}/home_banner_${DateTime.now().millisecondsSinceEpoch}.gif',
                      );
                      await File(image.path).copy(gifFile.path);
                      targetPath = gifFile.path;
                    } else {
                      if (!context.mounted) return;
                      targetPath = await ImageCropperUtil.cropImage(
                        context: context,
                        sourcePath: image.path,
                      );
                    }
                    if (targetPath != null) {
                      final prefs = await SharedPreferences.getInstance();
                      await prefs.setString('homeBannerPath', targetPath);
                      homeBannerPathNotifier.value = targetPath;
                      ref
                          .read(settingsProvider.notifier)
                          .updateSetting(homeBannerPath: targetPath);
                      showFleyToast(
                        lookupAppLocalizations(
                          Locale(FleyStrings.currentLang),
                        ).wallpaperUpdated,
                      );
                      if (context.mounted) Navigator.pop(context);
                    }
                  }
                },
              ),
              ListTile(
                contentPadding:
                    const EdgeInsets.symmetric(horizontal: 24, vertical: 4),
                leading: Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    color: isLight
                        ? Colors.black.withValues(alpha: 0.04)
                        : Colors.white.withValues(alpha: 0.05),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    Icons.restart_alt_rounded,
                    color: isLight ? Colors.black54 : Colors.white70,
                    size: 20,
                  ),
                ),
                title: Text(
                  loc.resetDefaultBanner,
                  style: TextStyle(
                    color: titleColor,
                    fontFamily: getFontFamily(_activeFont),
                  ),
                ),
                subtitle: Text(
                  loc.defaultBanner,
                  style: TextStyle(
                    color: isLight ? Colors.black45 : Colors.white38,
                    fontSize: 13,
                    fontFamily: getFontFamily(_activeFont),
                  ),
                ),
                onTap: () async {
                  final prefs = await SharedPreferences.getInstance();
                  await prefs.remove('homeBannerPath');
                  homeBannerPathNotifier.value = null;
                  ref
                      .read(settingsProvider.notifier)
                      .updateSetting(homeBannerPath: '');
                  showFleyToast(
                    lookupAppLocalizations(
                      Locale(FleyStrings.currentLang),
                    ).wallpaperUpdated,
                  );
                  if (context.mounted) Navigator.pop(context);
                },
              ),
              ValueListenableBuilder<bool>(
                valueListenable: showHomeBannerNotifier,
                builder: (context, showBanner, _) {
                  return ListTile(
                    contentPadding:
                        const EdgeInsets.symmetric(horizontal: 24, vertical: 4),
                    leading: Container(
                      width: 40,
                      height: 40,
                      decoration: BoxDecoration(
                        color: isLight
                            ? Colors.black.withValues(alpha: 0.04)
                            : Colors.white.withValues(alpha: 0.05),
                        shape: BoxShape.circle,
                      ),
                      child: Icon(
                        showBanner
                            ? Icons.visibility_off_outlined
                            : Icons.visibility_outlined,
                        color: isLight ? Colors.black54 : Colors.white70,
                        size: 20,
                      ),
                    ),
                    title: Text(
                      showBanner ? loc.hideBanner : loc.showBanner,
                      style: TextStyle(
                        color: titleColor,
                        fontFamily: getFontFamily(_activeFont),
                      ),
                    ),
                    subtitle: Text(
                      showBanner ? loc.bannerShown : loc.bannerHidden,
                      style: TextStyle(
                        color: isLight ? Colors.black45 : Colors.white38,
                        fontSize: 13,
                        fontFamily: getFontFamily(_activeFont),
                      ),
                    ),
                    onTap: () async {
                      final newStatus = !showBanner;
                      final prefs = await SharedPreferences.getInstance();
                      await prefs.setBool('showHomeBanner', newStatus);
                      showHomeBannerNotifier.value = newStatus;
                      ref
                          .read(settingsProvider.notifier)
                          .updateSetting(showHomeBanner: newStatus);
                      showFleyToast(
                        newStatus ? loc.bannerShown : loc.bannerHidden,
                      );
                      if (context.mounted) Navigator.pop(context);
                    },
                  );
                },
              ),
              const SizedBox(height: 24),
            ],
          ),
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
