import 'dart:typed_data';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:on_audio_query/on_audio_query.dart';

class ArtworkCacheManager {
  static final Map<String, Uint8List?> _memoryCache = {};
  static final OnAudioQuery _audioQuery = OnAudioQuery();
  static bool _isPreloading = false;

  /// Retrieves the native media store artwork from memory instantly if available.
  static Uint8List? getCachedArtwork(String trackId) {
    return _memoryCache[trackId];
  }

  /// Checks if the native artwork is already cached or confirmed null.
  static bool isCached(String trackId) {
    return _memoryCache.containsKey(trackId);
  }

  static final Map<String, Future<Uint8List?>> _inFlight = {};

  /// Fetches the native artwork asynchronously and stores it in the memory cache.
  static Future<Uint8List?> fetchAndCacheNativeArtwork(String trackId) async {
    if (_memoryCache.containsKey(trackId)) {
      return _memoryCache[trackId];
    }

    if (_inFlight.containsKey(trackId)) {
      return _inFlight[trackId]!;
    }

    final future = () async {
      Uint8List? bytes;
      final id = int.tryParse(trackId);
      if (id != null) {
        try {
          bytes = await _audioQuery.queryArtwork(
            id,
            ArtworkType.AUDIO,
            size: 200,
            quality: 50,
          );
        } catch (_) {}
      }

      _memoryCache[trackId] = (bytes != null && bytes.isNotEmpty) ? bytes : null;
      _inFlight.remove(trackId);
      return bytes;
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

    // Only warm initial viewport items to avoid choking the platform channel
    for (final track in tracks.take(25)) {
      final trackId = track.id.toString();
      final customPath = overrides[trackId]?['coverPath'];

      if (customPath != null && customPath.isNotEmpty) {
        final file = File(customPath);
        if (await file.exists()) {
          final provider = FileImage(file);
          provider.resolve(const ImageConfiguration());
        }
      } else {
        if (!_memoryCache.containsKey(trackId)) {
          await fetchAndCacheNativeArtwork(trackId);
        }
      }

      await Future.delayed(const Duration(milliseconds: 10));
    }

    _isPreloading = false;
  }
}
