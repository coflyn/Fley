// ignore_for_file: library_private_types_in_public_api, deprecated_member_use, invalid_use_of_protected_member
part of 'settings_screen.dart';

extension SettingsBackupRestoreModals on _SettingsScreenState {
  Future<void> _handleBackup() async {
    final bool? confirm = await showConfirmationDialog(
      context,
      title: AppLocalizations.of(context).confirmBackup,
      content: AppLocalizations.of(context).confirmBackupBody,
      confirmText: AppLocalizations.of(context).backup,
      confirmColor: _activeAccentColor,
    );
    if (confirm != true) return;

    if (Platform.isAndroid) {
      try {
        await Permission.storage.request();
        await Permission.manageExternalStorage.request();
        await Permission.audio.request();
      } catch (_) {}
    }

    try {
      final prefs = await SharedPreferences.getInstance();
      final keys = prefs.getKeys();
      final Map<String, dynamic> prefsMap = {};
      for (String key in keys) {
        if (key == 'cached_tracks_list') continue;
        prefsMap[key] = prefs.get(key);
      }
      final String jsonString = jsonEncode(prefsMap);

      bool saved = false;

      try {
        String? downloadDir;
        if (Platform.isAndroid) {
          final publicDir = Directory('/storage/emulated/0/Download');
          if (!await publicDir.exists()) {
            await publicDir.create(recursive: true);
          }
          downloadDir = publicDir.path;
        } else if (Platform.isMacOS || Platform.isWindows || Platform.isLinux) {
          final down = await getDownloadsDirectory();
          if (down != null) {
            downloadDir = down.path;
          }
        }
        if (downloadDir != null) {
          final file = File('$downloadDir/Fley_Backup.json');
          await file.writeAsString(jsonString);
          saved = true;
        }
      } catch (_) {}

      if (!saved) {
        try {
          final extDir = await getExternalStorageDirectory();
          if (extDir != null) {
            if (!await extDir.exists()) {
              await extDir.create(recursive: true);
            }
            final file = File('${extDir.path}/Fley_Backup.json');
            await file.writeAsString(jsonString);
            saved = true;
          }
        } catch (_) {}
      }

      if (!saved) {
        final docDir = await getApplicationDocumentsDirectory();
        final file = File('${docDir.path}/Fley_Backup.json');
        await file.writeAsString(jsonString);
        saved = true;
      }

      if (!mounted) return;
      showFleyToast(AppLocalizations.of(context).backupSuccess);
    } catch (e) {
      if (!mounted) return;
      showFleyToast('${AppLocalizations.of(context).backupFailed}: $e');
    }
  }

  Future<void> _handleRestore() async {
    final bool? confirm = await showConfirmationDialog(
      context,
      title: AppLocalizations.of(context).confirmRestore,
      content: AppLocalizations.of(context).confirmRestoreBody,
      confirmText: AppLocalizations.of(context).restore,
      confirmColor: _activeAccentColor,
    );
    if (confirm != true) return;

    if (Platform.isAndroid) {
      try {
        await Permission.storage.request();
        await Permission.manageExternalStorage.request();
        await Permission.audio.request();
      } catch (_) {}
    }

    try {
      final List<File> candidateFiles = [];
      if (Platform.isAndroid) {
        candidateFiles.add(File('/storage/emulated/0/Download/Fley_Backup.json'));
        candidateFiles.add(File('/storage/emulated/0/Download/Flow_Backup.json'));
      } else if (Platform.isMacOS || Platform.isWindows || Platform.isLinux) {
        try {
          final down = await getDownloadsDirectory();
          if (down != null) {
            candidateFiles.add(File('${down.path}/Fley_Backup.json'));
            candidateFiles.add(File('${down.path}/Flow_Backup.json'));
          }
        } catch (_) {}
      }

      try {
        final extDir = await getExternalStorageDirectory();
        if (extDir != null) {
          candidateFiles.add(File('${extDir.path}/Fley_Backup.json'));
          candidateFiles.add(File('${extDir.path}/Flow_Backup.json'));
        }
      } catch (_) {}

      try {
        final docDir = await getApplicationDocumentsDirectory();
        candidateFiles.add(File('${docDir.path}/Fley_Backup.json'));
        candidateFiles.add(File('${docDir.path}/Flow_Backup.json'));
      } catch (_) {}

      File? foundFile;
      for (final f in candidateFiles) {
        try {
          if (await f.exists()) {
            foundFile = f;
            break;
          }
        } catch (_) {}
      }

      if (foundFile == null) {
        try {
          final XFile? picked = await openFile(
            acceptedTypeGroups: [
              const XTypeGroup(label: 'JSON Backup', extensions: ['json']),
            ],
          );
          if (picked != null) {
            foundFile = File(picked.path);
          }
        } catch (_) {}
      }

      if (foundFile != null) {
        final String jsonString = await foundFile.readAsString();
        final Map<String, dynamic> prefsMap = jsonDecode(jsonString);

        const doubleKeys = {
          'fontScale',
          'playbackSpeed',
          'lyricFontSize',
          'customThemeBgBlur',
          'customThemeBgDim',
          'playerCustomBgBlur',
          'playerCustomBgDim',
          'detailViewCustomBgBlur',
          'detailViewCustomBgDim',
          'playerCustomBgOffsetX',
          'playerCustomBgOffsetY',
        };

        final prefs = await SharedPreferences.getInstance();
        for (String key in prefsMap.keys) {
          if (key == 'cached_tracks_list') continue;
          final value = prefsMap[key];
          if (doubleKeys.contains(key) && value is num) {
            await prefs.setDouble(key, value.toDouble());
          } else if (value is double) {
            await prefs.setDouble(key, value);
          } else if (value is int) {
            await prefs.setInt(key, value);
          } else if (value is bool) {
            await prefs.setBool(key, value);
          } else if (value is String) {
            await prefs.setString(key, value);
          } else if (value is List) {
            await prefs.setStringList(
              key,
              value.map((e) => e.toString()).toList(),
            );
          }
        }

        await _loadSettings();
        if (!mounted) return;
        showFleyToast(AppLocalizations.of(context).restoreSuccess);
        widget.onSettingsChanged();
        widget.onRescanLibrary();
      } else {
        if (!mounted) return;
        showFleyToast(AppLocalizations.of(context).noBackupFound);
      }
    } catch (e) {
      if (!mounted) return;
      showFleyToast('${AppLocalizations.of(context).restoreFailed}: $e');
    }
  }

  Future<void> _showResetConfirmation() async {
    final bool? confirm = await showConfirmationDialog(
      context,
      title: AppLocalizations.of(context).resetConfirmTitle,
      content: AppLocalizations.of(context).resetConfirmBody,
      confirmText: AppLocalizations.of(context).reset,
    );
    if (confirm == true) {
      if (mounted) {
        Navigator.pop(context); // close settings
      }
      widget.onResetData();
    }
  }
}
