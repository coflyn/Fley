import 'dart:convert';
import 'dart:typed_data';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:id3/id3.dart';
import 'package:on_audio_query/on_audio_query.dart';
import 'package:path_provider/path_provider.dart';

class ArtworkCacheManager {
  static final Map<String, Uint8List?> _memoryCache = {};
  static final Map<String, String> _trackPaths = {};
  static final OnAudioQuery _audioQuery = OnAudioQuery();
  static bool _isPreloading = false;
  static final ValueNotifier<int> updateNotifier = ValueNotifier<int>(0);
  static Directory? _ytmCoversDir;
  static Directory? _ytmLyricsDir;
  static final Set<String> _pendingDownloads = {};

  /// Initialize persistent disk directory for YTM cover art and lyrics.
  static Future<void> init() async {
    if (_ytmCoversDir != null && _ytmLyricsDir != null) return;
    try {
      final base = await getApplicationSupportDirectory();
      _ytmCoversDir = Directory('${base.path}/ytm_covers');
      if (!await _ytmCoversDir!.exists()) {
        await _ytmCoversDir!.create(recursive: true);
      }
      _ytmLyricsDir = Directory('${base.path}/ytm_lyrics');
      if (!await _ytmLyricsDir!.exists()) {
        await _ytmLyricsDir!.create(recursive: true);
      }
    } catch (_) {
      try {
        final doc = await getApplicationDocumentsDirectory();
        _ytmCoversDir = Directory('${doc.path}/ytm_covers');
        if (!await _ytmCoversDir!.exists()) {
          await _ytmCoversDir!.create(recursive: true);
        }
        _ytmLyricsDir = Directory('${doc.path}/ytm_lyrics');
        if (!await _ytmLyricsDir!.exists()) {
          await _ytmLyricsDir!.create(recursive: true);
        }
      } catch (_) {}
    }
  }

  /// Returns cached YTM cover file on disk if it exists.
  static File? getYtmCoverFile(String videoId) {
    if (_ytmCoversDir == null || videoId.isEmpty) return null;
    final file = File('${_ytmCoversDir!.path}/$videoId.jpg');
    return file.existsSync() && file.lengthSync() > 0 ? file : null;
  }

  /// Returns cached YTM lyrics (.lrc) file on disk if it exists.
  static File? getYtmLyricsFile(String videoId) {
    if (_ytmLyricsDir == null || videoId.isEmpty) return null;
    final file = File('${_ytmLyricsDir!.path}/$videoId.lrc');
    return file.existsSync() && file.lengthSync() > 0 ? file : null;
  }

  /// Saves lyrics (.lrc) string to persistent disk storage for offline use.
  static Future<File?> saveYtmLyricsFile(String videoId, String lrcContent) async {
    if (videoId.isEmpty || lrcContent.trim().isEmpty) return null;
    try {
      if (_ytmLyricsDir == null) await init();
      if (_ytmLyricsDir == null) return null;
      final file = File('${_ytmLyricsDir!.path}/$videoId.lrc');
      await file.writeAsString(lrcContent.trim());
      return file;
    } catch (_) {
      return null;
    }
  }

  /// Asynchronously fetches YTM cover and saves to disk cache for offline use.
  static Future<File?> saveYtmCover(String videoId, String imageUrl) async {
    if (videoId.isEmpty || imageUrl.isEmpty || !imageUrl.startsWith('http')) {
      return null;
    }
    if (_pendingDownloads.contains(videoId)) return null;

    try {
      if (_ytmCoversDir == null) await init();
      if (_ytmCoversDir == null) return null;

      final file = File('${_ytmCoversDir!.path}/$videoId.jpg');
      if (file.existsSync() && file.lengthSync() > 0) return file;

      _pendingDownloads.add(videoId);

      final client = HttpClient();
      client.connectionTimeout = const Duration(seconds: 8);
      final req = await client.getUrl(Uri.parse(imageUrl));
      final res = await req.close();
      if (res.statusCode == 200) {
        final bytes = await res.fold<List<int>>([], (prev, el) => prev..addAll(el));
        if (bytes.isNotEmpty) {
          await file.writeAsBytes(bytes);
          updateNotifier.value++;
          client.close();
          _pendingDownloads.remove(videoId);
          return file;
        }
      }
      client.close();
    } catch (_) {
    } finally {
      _pendingDownloads.remove(videoId);
    }
    return null;
  }

  /// Retrieves the native media store artwork from memory instantly if available.
  static Uint8List? getCachedArtwork(String trackId) {
    return _memoryCache[trackId];
  }

  /// Sets artwork directly into memory cache (used by desktop scanner).
  static void setCachedArtwork(String trackId, Uint8List? bytes) {
    _memoryCache[trackId] = bytes;
    updateNotifier.value++;
  }

  /// Registers track path for lazy artwork loading.
  static void registerTrackPath(String trackId, String path) {
    if (path.isNotEmpty) {
      _trackPaths[trackId] = path;
    }
  }

  /// Checks if the native artwork is already cached or confirmed null.
  static bool isCached(String trackId) {
    return _memoryCache.containsKey(trackId);
  }

  /// Extracts embedded ID3 cover art from audio file, or folder image.
  static Uint8List? extractArtworkFromFile(String path) {
    final lower = path.toLowerCase();
    if (lower.endsWith('.mp3')) {
      try {
        final file = File(path);
        if (file.existsSync()) {
          final bytes = file.readAsBytesSync();
          final mp3 = MP3Instance(bytes);
          if (mp3.parseTagsSync()) {
            final tags = mp3.getMetaTags();
            if (tags != null) {
              final apic = tags['APIC'];
              if (apic is Map && apic['base64'] != null) {
                final String b64 = apic['base64'].toString();
                if (b64.isNotEmpty) {
                  return base64Decode(b64);
                }
              }
            }
          }
        }
      } catch (_) {}
    }

    try {
      final file = File(path);
      final parent = file.parent;
      if (parent.existsSync()) {
        final candidateCovers = parent.listSync().whereType<File>().where((f) {
          final name = f.path.toLowerCase();
          return name.endsWith('.jpg') ||
              name.endsWith('.jpeg') ||
              name.endsWith('.png');
        }).toList();
        if (candidateCovers.isNotEmpty) {
          return candidateCovers.first.readAsBytesSync();
        }
      }
    } catch (_) {}

    return null;
  }

  static final Map<String, Future<Uint8List?>> _inFlight = {};

  /// Fetches the native artwork asynchronously and stores it in the memory cache.
  static Future<Uint8List?> fetchAndCacheNativeArtwork(
    String trackId, {
    String? trackPath,
  }) async {
    if (_memoryCache.containsKey(trackId) && _memoryCache[trackId] != null) {
      return _memoryCache[trackId];
    }

    if (trackPath != null && trackPath.isNotEmpty) {
      _trackPaths[trackId] = trackPath;
    }

    final resolvedPath = trackPath ?? _trackPaths[trackId];

    if (_inFlight.containsKey(trackId)) {
      return _inFlight[trackId]!;
    }

    final future = () async {
      Uint8List? bytes;

      // 1. If path is available, extract directly from file
      if (resolvedPath != null && resolvedPath.isNotEmpty) {
        bytes = extractArtworkFromFile(resolvedPath);
      }

      // 2. Fallback to native MediaStore if int trackId
      if (bytes == null || bytes.isEmpty) {
        final id = int.tryParse(trackId);
        if (id != null && (Platform.isAndroid || Platform.isIOS)) {
          try {
            bytes = await _audioQuery.queryArtwork(
              id,
              ArtworkType.AUDIO,
              size: 200,
              quality: 50,
            );
          } catch (_) {}
        }
      }

      final validBytes = (bytes != null && bytes.isNotEmpty) ? bytes : null;
      _memoryCache[trackId] = validBytes;
      _inFlight.remove(trackId);
      if (validBytes != null) {
        updateNotifier.value++;
      }
      return validBytes;
    }();

    _inFlight[trackId] = future;
    return future;
  }

  /// Silently preloads thumbnails in the background so initial view is smooth.
  static Future<void> preloadAllArtworks(
    List<dynamic> tracks,
    Map<String, dynamic> overrides,
  ) async {
    if (_isPreloading) return;
    _isPreloading = true;

    for (final track in tracks.take(50)) {
      final trackId = track.id.toString();
      final trackPath = track.path?.toString() ?? '';
      final customPath = overrides[trackId]?['coverPath'];

      if (trackPath.isNotEmpty) {
        _trackPaths[trackId] = trackPath;
      }

      if (customPath != null && customPath.isNotEmpty) {
        final file = File(customPath);
        if (await file.exists()) {
          final provider = FileImage(file);
          provider.resolve(const ImageConfiguration());
        }
      } else {
        if (!_memoryCache.containsKey(trackId) || _memoryCache[trackId] == null) {
          await fetchAndCacheNativeArtwork(trackId, trackPath: trackPath);
        }
      }

      await Future.delayed(const Duration(milliseconds: 5));
    }

    _isPreloading = false;
  }
}
