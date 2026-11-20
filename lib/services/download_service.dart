import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/track.dart';
import '../services/ytmusic_service.dart';
import '../services/yt_player_service.dart';
import '../utils/audio_duration_parser.dart';
import '../utils/artwork_cache.dart';

enum DownloadStatus {
  pending,
  downloading,
  completed,
  failed,
  cancelled,
}

class DownloadTask {
  final String id;
  final Track track;
  double progress;
  int bytesReceived;
  int totalBytes;
  DownloadStatus status;
  String? error;
  IOSink? _activeSink;
  HttpClient? _activeClient;
  bool _cancelled = false;

  DownloadTask({
    required this.id,
    required this.track,
    this.progress = 0.0,
    this.bytesReceived = 0,
    this.totalBytes = 0,
    this.status = DownloadStatus.pending,
    this.error,
  });
}

class DownloadService {
  static final DownloadService instance = DownloadService._();
  DownloadService._();

  final ValueNotifier<List<DownloadTask>> activeTasksNotifier =
      ValueNotifier<List<DownloadTask>>([]);

  /// Callback to notify MainScreenState when a track finishes downloading.
  void Function(Track newTrack, Uint8List? coverBytes)? onTrackDownloaded;

  /// Callback to notify MainScreenState when a downloaded track is deleted.
  void Function(String trackId)? onTrackDeleted;

  /// Starts downloading a YouTube Music track.
  Future<void> downloadTrack(Track track) async {
    final videoId = track.path.isNotEmpty
        ? track.path
        : track.id.replaceFirst('ytm_', '');

    if (videoId.isEmpty) return;

    final taskId = 'ytm_$videoId';
    final existing = activeTasksNotifier.value
        .where((t) => t.id == taskId)
        .firstOrNull;

    if (existing != null) {
      if (existing.status == DownloadStatus.downloading) {
        return;
      }
      if (existing.status == DownloadStatus.failed) {
        // Retry
        activeTasksNotifier.value = activeTasksNotifier.value
            .where((t) => t.id != taskId)
            .toList();
      }
    }

    final task = DownloadTask(
      id: taskId,
      track: track,
      status: DownloadStatus.downloading,
    );

    activeTasksNotifier.value = [...activeTasksNotifier.value, task];

    _runDownload(task, videoId);
  }

  void cancelDownload(String taskId) {
    final task = activeTasksNotifier.value
        .where((t) => t.id == taskId)
        .firstOrNull;
    if (task != null) {
      task._cancelled = true;
      task.status = DownloadStatus.cancelled;
      try {
        task._activeClient?.close(force: true);
        task._activeSink?.close();
      } catch (_) {}
      activeTasksNotifier.value = [...activeTasksNotifier.value];
    }
  }

  Future<void> _runDownload(DownloadTask task, String videoId) async {
    final dir = await getFleyDownloadsDirectory();
    final safeTitle =
        task.track.title.replaceAll(RegExp(r'[\\/:*?"<>|]'), '_').trim();
    final safeArtist = (task.track.artist.isNotEmpty &&
            task.track.artist != '<unknown>')
        ? task.track.artist.replaceAll(RegExp(r'[\\/:*?"<>|]'), '_').trim()
        : '';
    String fileBaseName =
        safeArtist.isNotEmpty ? '$safeArtist - $safeTitle' : safeTitle;
    if (fileBaseName.isEmpty) {
      fileBaseName = 'ytm_$videoId';
    }

    final audioFile = File('${dir.path}/$fileBaseName.m4a');

    try {
      if (task._cancelled) return;

      bool downloaded = false;

      // Method 1: High-reliability proxied stream (bypasses YouTube 403 / PoToken)
      downloaded = await _downloadFromAudioProxy(task, videoId, audioFile);

      // Method 2: Direct HTTP stream download if proxy failed
      if (!downloaded && !task._cancelled) {
        String? streamUrl = await YtPlayerService.instance.resolveStreamUrl(videoId);
        if (streamUrl == null || streamUrl.isEmpty) {
          try {
            streamUrl = await YtMusicService.getStreamUrl(videoId);
          } catch (_) {}
        }
        if (streamUrl != null && streamUrl.isNotEmpty) {
          try {
            downloaded = await _downloadDirectHttp(task, streamUrl, audioFile);
          } catch (e) {
            debugPrint('Direct HTTP download failed: $e');
          }
        }
      }

      // Method 3: In-WebView streaming download fallback
      if (!downloaded && !task._cancelled) {
        downloaded = await YtPlayerService.instance.downloadViaWebView(
          videoId,
          task.id,
          audioFile,
          onProgress: (received, total) {
            task.bytesReceived = received;
            task.totalBytes = total;
            if (total > 0) {
              task.progress = (received / total).clamp(0.0, 1.0);
            }
            activeTasksNotifier.value = [...activeTasksNotifier.value];
          },
        );
      }

      if (task._cancelled) {
        if (await audioFile.exists()) {
          try {
            await audioFile.delete();
          } catch (_) {}
        }
        return;
      }

      if (!downloaded || !(await audioFile.exists()) || (await audioFile.length()) == 0) {
        throw Exception('Download failed (stream unavailable or restricted)');
      }

      // 3. Download and cache cover artwork
      Uint8List? artBytes;
      final newTrackId = 'local_ytm_$videoId';
      if (task.track.url.isNotEmpty && task.track.url.startsWith('http')) {
        try {
          final artClient = HttpClient();
          artClient.connectionTimeout = const Duration(seconds: 8);
          final artReq = await artClient.getUrl(Uri.parse(task.track.url));
          final artRes = await artReq.close();
          if (artRes.statusCode == 200) {
            artBytes = Uint8List.fromList(
              await artRes.fold<List<int>>([], (prev, el) => prev..addAll(el)),
            );
            final coverFile = File('${dir.path}/$fileBaseName.jpg');
            await coverFile.writeAsBytes(artBytes);

            final prefs = await SharedPreferences.getInstance();
            final raw = prefs.getString('metadata_overrides') ?? '{}';
            Map<String, dynamic> overrides = {};
            try {
              overrides = jsonDecode(raw) as Map<String, dynamic>;
            } catch (_) {}
            overrides[newTrackId] = {'coverPath': coverFile.path};
            await prefs.setString('metadata_overrides', jsonEncode(overrides));
          }
          artClient.close();
        } catch (_) {}
      }

      String albumName = task.track.album.trim();
      String? albumBrowseId = task.track.albumBrowseId;
      String? artistBrowseId = task.track.artistBrowseId;

      bool isIgnoredAlbum(String s) {
        final t = s.trim().toLowerCase();
        if (t.isEmpty ||
            t == 'youtube music' ||
            t == '<unknown>' ||
            t == 'unknown album') {
          return true;
        }
        if (RegExp(
          r'^\d+([.,]\d+)?[kmb]?\s*(plays?|views?|ditonton|tayangan|x ditonton)?$',
          caseSensitive: false,
        ).hasMatch(t)) {
          return true;
        }
        return false;
      }

      if (isIgnoredAlbum(albumName)) {
        try {
          final query = '${task.track.title} ${task.track.artist}'.trim();
          final results = await YtMusicService.search(query, limit: 3);
          for (final res in results) {
            if (!isIgnoredAlbum(res.album)) {
              albumName = res.album;
              albumBrowseId ??= res.albumBrowseId;
              artistBrowseId ??= res.artistBrowseId;
              break;
            }
          }
        } catch (_) {}
      }

      if (isIgnoredAlbum(albumName)) {
        albumName = '${task.track.title} - Single';
      }

      final downloadedTrack = Track(
        id: newTrackId,
        title: task.track.title,
        artist: task.track.artist,
        album: albumName,
        url: audioFile.path,
        path: audioFile.path,
        lyrics: task.track.lyrics,
        duration: task.track.duration,
        artistBrowseId: artistBrowseId,
        albumBrowseId: albumBrowseId,
      );

      // If cached LRC exists on disk, copy to downloaded file .lrc
      final cachedLrc = ArtworkCacheManager.getYtmLyricsFile(videoId);
      if (cachedLrc != null && cachedLrc.existsSync()) {
        try {
          final lrcDest = File('${dir.path}/$fileBaseName.lrc');
          await cachedLrc.copy(lrcDest.path);
        } catch (_) {}
      }

      task.status = DownloadStatus.completed;
      task.progress = 1.0;
      activeTasksNotifier.value = [...activeTasksNotifier.value];

      await _saveToDownloadsRegistry(downloadedTrack);
      onTrackDownloaded?.call(downloadedTrack, artBytes);
    } catch (e) {
      debugPrint('Download error: $e');
      if (await audioFile.exists()) {
        try {
          await audioFile.delete();
        } catch (_) {}
      }
      task.status = DownloadStatus.failed;
      task.error = e.toString().replaceFirst('Exception: ', '');
      activeTasksNotifier.value = [...activeTasksNotifier.value];
    }
  }

  Future<bool> _downloadFromAudioProxy(
    DownloadTask task,
    String videoId,
    File destination,
  ) async {
    final candidateHosts = [
      'https://yt.chocolatemoo53.com',
      'https://inv.nadeko.net',
      'https://invidious.nerdvpn.de',
      'https://invidious.tiekoetter.com',
      'https://invidious.protokolla.fi',
    ];

    // Priority itags: 140 = M4A AAC (128 kbps), 251 = WebM Opus (160 kbps), 18 = MP4 (360p)
    final itags = [140, 251, 18];

    for (final host in candidateHosts) {
      if (task._cancelled) return false;
      for (final itag in itags) {
        if (task._cancelled) return false;
        HttpClient? client;
        IOSink? sink;
        try {
          final uri =
              Uri.parse('$host/latest_version?id=$videoId&itag=$itag&local=true');
          client = HttpClient();
          client.connectionTimeout = const Duration(seconds: 8);
          task._activeClient = client;

          final req = await client.getUrl(uri);
          req.headers.set('User-Agent', YtPlayerService.userAgent);
          req.headers.set('Accept', '*/*');

          final res = await req.close();
          final ctype = res.headers.value(HttpHeaders.contentTypeHeader) ?? '';
          final isAudioOrMedia = ctype.contains('audio') ||
              ctype.contains('video') ||
              ctype.contains('octet-stream') ||
              res.contentLength > 200000;

          if ((res.statusCode == 200 || res.statusCode == 206) && isAudioOrMedia) {
            task.totalBytes = res.contentLength > 0 ? res.contentLength : 0;
            task.bytesReceived = 0;
            sink = destination.openWrite();
            task._activeSink = sink;

            await for (final chunk in res) {
              if (task._cancelled) {
                await sink.close();
                client.close(force: true);
                return false;
              }
              sink.add(chunk);
              task.bytesReceived += chunk.length;
              if (task.totalBytes > 0) {
                task.progress =
                    (task.bytesReceived / task.totalBytes).clamp(0.0, 1.0);
              }
              activeTasksNotifier.value = [...activeTasksNotifier.value];
            }

            await sink.flush();
            await sink.close();
            client.close();

            if (await destination.exists() && (await destination.length()) > 50000) {
              return true;
            }
          }
        } catch (e) {
          debugPrint('Proxy download attempt ($host itag=$itag) failed: $e');
        } finally {
          try {
            await sink?.close();
          } catch (_) {}
          try {
            client?.close(force: true);
          } catch (_) {}
        }
      }
    }
    return false;
  }

  Future<bool> _downloadDirectHttp(
    DownloadTask task,
    String streamUrl,
    File destination,
  ) async {
    final client = HttpClient();
    client.connectionTimeout = const Duration(seconds: 15);
    task._activeClient = client;

    final req = await client.getUrl(Uri.parse(streamUrl));
    req.headers.set('User-Agent', YtPlayerService.userAgent);
    req.headers.set('Origin', 'https://music.youtube.com');
    req.headers.set('Referer', 'https://music.youtube.com/');
    req.headers.set('Range', 'bytes=0-');

    final prefs = await SharedPreferences.getInstance();
    final cookie = prefs.getString('ytm_cookie') ?? '';
    if (cookie.isNotEmpty) {
      req.headers.set('Cookie', cookie);
    }

    final res = await req.close();
    if (res.statusCode != 200 && res.statusCode != 206) {
      client.close();
      return false;
    }

    task.totalBytes = res.contentLength > 0 ? res.contentLength : 0;
    final sink = destination.openWrite();
    task._activeSink = sink;

    await for (final chunk in res) {
      if (task._cancelled) {
        await sink.close();
        client.close();
        return false;
      }
      sink.add(chunk);
      task.bytesReceived += chunk.length;
      if (task.totalBytes > 0) {
        task.progress = (task.bytesReceived / task.totalBytes).clamp(0.0, 1.0);
        activeTasksNotifier.value = [...activeTasksNotifier.value];
      }
    }

    await sink.flush();
    await sink.close();
    client.close();
    return true;
  }

  static const String _registryKey = 'fley_downloads_registry';

  Future<void> _saveToDownloadsRegistry(Track track) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString(_registryKey) ?? '{}';
      final Map<String, dynamic> registry = jsonDecode(raw);
      registry[track.id] = track.toMap();
      await prefs.setString(_registryKey, jsonEncode(registry));
    } catch (_) {}
  }

  Future<void> _removeFromDownloadsRegistry(String trackId) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString(_registryKey) ?? '{}';
      final Map<String, dynamic> registry = jsonDecode(raw);
      registry.remove(trackId);
      await prefs.setString(_registryKey, jsonEncode(registry));
    } catch (_) {}
  }

  Future<void> _clearDownloadsRegistry() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove(_registryKey);
    } catch (_) {}
  }

  /// Retrieves all valid downloaded tracks from the persistent registry and disk.
  Future<List<Track>> getDownloadedTracks() async {
    final List<Track> tracks = [];
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString(_registryKey) ?? '{}';
      final Map<String, dynamic> registry = jsonDecode(raw);
      final List<String> toRemove = [];

      for (final entry in registry.entries) {
        try {
          final t = Track.fromMap(Map<String, dynamic>.from(entry.value));
          if (File(t.path).existsSync()) {
            tracks.add(t);
          } else {
            toRemove.add(entry.key);
          }
        } catch (_) {}
      }

      if (toRemove.isNotEmpty) {
        for (final k in toRemove) {
          registry.remove(k);
        }
        await prefs.setString(_registryKey, jsonEncode(registry));
      }

      // Check FleyDownloads directory for any audio files not yet in registry
      final dir = await getFleyDownloadsDirectory();
      if (await dir.exists()) {
        final list = dir.listSync();
        for (final item in list) {
          if (item is File) {
            final p = item.path;
            final lower = p.toLowerCase();
            if ((lower.endsWith('.m4a') || lower.endsWith('.mp3')) &&
                !tracks.any((t) => t.path == p)) {
              final fileName = item.uri.pathSegments.last;
              final dotIdx = fileName.lastIndexOf('.');
              final baseName =
                  dotIdx != -1 ? fileName.substring(0, dotIdx) : fileName;
              String title = baseName;
              String artist = 'Unknown Artist';
              if (baseName.contains(' - ')) {
                final parts = baseName.split(' - ');
                artist = parts.first.trim();
                title = parts.sublist(1).join(' - ').trim();
              }
              final tId = 'local_ytm_${baseName.hashCode.abs()}';
              final t = Track(
                id: tId,
                title: title,
                artist: artist,
                album: 'YouTube Music',
                url: p,
                path: p,
                lyrics: const [],
                duration: AudioDurationParser.getDurationMs(item) ?? 0,
              );
              tracks.add(t);
              registry[tId] = t.toMap();
            }
          }
        }
        await prefs.setString(_registryKey, jsonEncode(registry));
      }
    } catch (_) {}
    return tracks;
  }

  /// Delete a downloaded track and its associated artwork from disk.
  Future<void> deleteDownload(Track track) async {
    try {
      final audioFile = File(track.path);
      if (await audioFile.exists()) {
        await audioFile.delete();
      }
      // Also delete companion .jpg cover if present
      final jpgPath = track.path.replaceAll(RegExp(r'\.m4a$'), '.jpg');
      final jpgFile = File(jpgPath);
      if (await jpgFile.exists()) {
        await jpgFile.delete();
      }
      // Also delete companion .lrc if present
      final lrcPath = track.path.replaceAll(RegExp(r'\.m4a$'), '.lrc');
      final lrcFile = File(lrcPath);
      if (await lrcFile.exists()) {
        await lrcFile.delete();
      }
    } catch (_) {}

    await _removeFromDownloadsRegistry(track.id);
    onTrackDeleted?.call(track.id);
  }

  /// Returns total bytes occupied by downloaded audio in FleyDownloads.
  Future<int> getTotalDownloadBytes() async {
    try {
      final dir = await getFleyDownloadsDirectory();
      int total = 0;
      if (await dir.exists()) {
        final list = dir.listSync();
        for (final item in list) {
          if (item is File && item.path.endsWith('.m4a')) {
            total += item.lengthSync();
          }
        }
      }
      return total;
    } catch (_) {
      return 0;
    }
  }

  /// Deletes all downloaded files in FleyDownloads directory.
  Future<void> clearAllDownloads() async {
    try {
      final dir = await getFleyDownloadsDirectory();
      if (await dir.exists()) {
        final list = dir.listSync();
        for (final item in list) {
          if (item is File) {
            try {
              item.deleteSync();
            } catch (_) {}
          }
        }
      }
    } catch (_) {}
    await _clearDownloadsRegistry();
  }
}
