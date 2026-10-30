import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:file_selector/file_selector.dart';
import 'package:id3/id3.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/track.dart';
import '../utils/artwork_cache.dart';

class DesktopAudioScanner {
  static const String _prefsKeyCustomFolders = 'desktop_custom_music_folders';

  static final Set<String> _supportedExtensions = {
    '.mp3',
    '.m4a',
    '.flac',
    '.wav',
    '.ogg',
    '.aac',
  };

  /// Dapatkan direktori musik standar OS
  static List<String> getDefaultMusicDirectories() {
    final dirs = <String>[];
    if (Platform.isMacOS || Platform.isLinux) {
      final home = Platform.environment['HOME'];
      if (home != null) {
        final musicDir = Directory('$home/Music');
        if (musicDir.existsSync()) {
          dirs.add(musicDir.path);
        }
      }
    } else if (Platform.isWindows) {
      final userProfile = Platform.environment['USERPROFILE'];
      if (userProfile != null) {
        final musicDir = Directory('$userProfile\\Music');
        if (musicDir.existsSync()) {
          dirs.add(musicDir.path);
        }
      }
    }
    return dirs;
  }

  /// Dapatkan daftar folder musik kustom yang disimpan user
  static Future<List<String>> getCustomDirectories() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getStringList(_prefsKeyCustomFolders) ?? [];
  }

  /// Dialog pemilihan folder kustom menggunakan file_selector native
  static Future<String?> pickAndAddMusicFolder() async {
    try {
      final String? selectedPath = await getDirectoryPath(
        confirmButtonText: 'Select Folder',
      );
      if (selectedPath != null && selectedPath.isNotEmpty) {
        final prefs = await SharedPreferences.getInstance();
        final current = prefs.getStringList(_prefsKeyCustomFolders) ?? [];
        if (!current.contains(selectedPath)) {
          current.add(selectedPath);
          await prefs.setStringList(_prefsKeyCustomFolders, current);
        }
        return selectedPath;
      }
    } catch (e) {
      debugPrint('DesktopAudioScanner: Error picking directory: $e');
    }
    return null;
  }

  /// Hapus folder kustom
  static Future<void> removeCustomDirectory(String path) async {
    final prefs = await SharedPreferences.getInstance();
    final current = prefs.getStringList(_prefsKeyCustomFolders) ?? [];
    current.remove(path);
    await prefs.setStringList(_prefsKeyCustomFolders, current);
  }

  /// Pindai semua folder musik (default + kustom)
  static Future<List<Track>> scanAllTracks({
    bool filterShortAudio = false,
  }) async {
    final allFolders = <String>{};
    allFolders.addAll(getDefaultMusicDirectories());
    final customFolders = await getCustomDirectories();
    allFolders.addAll(customFolders);

    final List<File> audioFiles = [];
    for (final folderPath in allFolders) {
      final dir = Directory(folderPath);
      if (dir.existsSync()) {
        try {
          final entities = dir.listSync(recursive: true, followLinks: false);
          for (final entity in entities) {
            if (entity is File) {
              final ext = entity.path.toLowerCase();
              if (_supportedExtensions.any((s) => ext.endsWith(s))) {
                audioFiles.add(entity);
              }
            }
          }
        } catch (e) {
          debugPrint(
            'DesktopAudioScanner: Error reading directory $folderPath: $e',
          );
        }
      }
    }

    final List<Track> tracks = [];
    final Set<String> seenPaths = {};

    for (int i = 0; i < audioFiles.length; i++) {
      final file = audioFiles[i];
      final path = file.path;
      if (!seenPaths.add(path)) continue;

      String title = '';
      String artist = 'Unknown Artist';
      String album = 'Unknown Album';
      int duration = 0;

      final trackId = 'desktop_${path.hashCode.abs()}';

      // Parse ID3 tags jika file MP3
      if (path.toLowerCase().endsWith('.mp3')) {
        try {
          final bytes = file.readAsBytesSync();
          final mp3 = MP3Instance(bytes);
          if (mp3.parseTagsSync()) {
            final tags = mp3.getMetaTags();
            if (tags != null) {
              if (tags['Title'] != null &&
                  tags['Title'].toString().trim().isNotEmpty) {
                title = tags['Title'].toString().trim();
              }
              if (tags['Artist'] != null &&
                  tags['Artist'].toString().trim().isNotEmpty) {
                artist = tags['Artist'].toString().trim();
              }
              if (tags['Album'] != null &&
                  tags['Album'].toString().trim().isNotEmpty) {
                album = tags['Album'].toString().trim();
              }
              if (tags['Length'] != null) {
                duration = int.tryParse(tags['Length'].toString()) ?? 0;
              }

              // Extract embedded cover art
              final apic = tags['APIC'];
              if (apic is Map && apic['base64'] != null) {
                final String b64 = apic['base64'].toString();
                if (b64.isNotEmpty) {
                  try {
                    final Uint8List imgBytes = base64Decode(b64);
                    ArtworkCacheManager.setCachedArtwork(trackId, imgBytes);
                  } catch (_) {}
                }
              }
            }
          }
        } catch (e) {
          debugPrint('DesktopAudioScanner: ID3 parse error for $path: $e');
        }
      }

      // Check folder for cover image if artwork not found in tags
      if (!ArtworkCacheManager.isCached(trackId)) {
        try {
          final parent = file.parent;
          final candidateCovers = parent.listSync().whereType<File>().where((
            f,
          ) {
            final name = f.path.toLowerCase();
            return name.endsWith('.jpg') ||
                name.endsWith('.jpeg') ||
                name.endsWith('.png');
          }).toList();

          if (candidateCovers.isNotEmpty) {
            // Prioritaskan cover, folder, album, front
            File coverFile = candidateCovers.first;
            for (final f in candidateCovers) {
              final lower = f.path.toLowerCase();
              if (lower.contains('cover') ||
                  lower.contains('folder') ||
                  lower.contains('front') ||
                  lower.contains('album')) {
                coverFile = f;
                break;
              }
            }
            final imgBytes = coverFile.readAsBytesSync();
            ArtworkCacheManager.setCachedArtwork(trackId, imgBytes);
          }
        } catch (_) {}
      }

      // Smart Fallback jika title / artist kosong: parse nama file
      final filenameWithExt = file.uri.pathSegments.isNotEmpty
          ? file.uri.pathSegments.last
          : 'Track ${i + 1}';
      final dotIdx = filenameWithExt.lastIndexOf('.');
      final rawFilename = dotIdx != -1
          ? filenameWithExt.substring(0, dotIdx)
          : filenameWithExt;

      if (title.isEmpty || title == '<unknown>') {
        if (rawFilename.contains(' - ')) {
          final parts = rawFilename.split(' - ');
          if (artist == 'Unknown Artist' && parts.first.trim().isNotEmpty) {
            artist = parts.first.trim();
          }
          title = parts.sublist(1).join(' - ').trim();
        } else {
          title = rawFilename;
        }
      }

      // Bersihkan suffix tag seperti (Official Video), [Audio], dsb
      final cleanRegex = RegExp(
        r'[\[\(](official|audio|video|lyric|lyrics|music video|official video|official audio|official lyric video|official music video)[\]\)]',
        caseSensitive: false,
      );
      title = title.replaceAll(cleanRegex, '').trim();

      // Fallback album dari folder nama jika album kosong
      if (album == 'Unknown Album' && file.parent.path.isNotEmpty) {
        final parentName = file.parent.uri.pathSegments
            .where((s) => s.isNotEmpty)
            .toList();
        if (parentName.isNotEmpty) {
          album = parentName.last;
        }
      }

      if (filterShortAudio && duration > 0 && duration < 30000) {
        continue;
      }

      tracks.add(
        Track(
          id: trackId,
          title: title,
          artist: artist,
          album: album,
          url: file.uri.toString(),
          path: path,
          lyrics: const [],
          duration: duration,
        ),
      );
    }

    return tracks;
  }
}
