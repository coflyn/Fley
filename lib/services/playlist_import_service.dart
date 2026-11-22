import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import '../models/track.dart';
import 'ytmusic_service.dart';

class ImportedPlaylistData {
  final String title;
  final String? coverUrl;
  final List<Track> tracks;

  ImportedPlaylistData({
    required this.title,
    this.coverUrl,
    required this.tracks,
  });
}

class PlaylistImportService {
  static final RegExp _ytmRegex =
      RegExp(r'(?:list=|\/playlist\/)([a-zA-Z0-9_-]+)');
  static final RegExp _spotifyRegex =
      RegExp(r'spotify\.com\/playlist\/([a-zA-Z0-9]+)');
  static final RegExp _appleMusicRegex =
      RegExp(r'music\.apple\.com\/(?:[a-zA-Z]{2}\/)?playlist\/(?:[^\/]+\/)?(pl\.[a-zA-Z0-9_-]+)');

  static bool isSupportedUrl(String url) {
    final clean = url.trim();
    return _ytmRegex.hasMatch(clean) ||
        _spotifyRegex.hasMatch(clean) ||
        _appleMusicRegex.hasMatch(clean);
  }

  static String? detectPlatform(String url) {
    final clean = url.trim();
    if (_spotifyRegex.hasMatch(clean)) return 'spotify';
    if (_ytmRegex.hasMatch(clean)) return 'ytmusic';
    if (_appleMusicRegex.hasMatch(clean)) return 'apple';
    return null;
  }

  static Future<ImportedPlaylistData?> importPlaylist(
    String url, {
    void Function(String message, double progress)? onProgress,
  }) async {
    final cleanUrl = url.trim();
    final platform = detectPlatform(cleanUrl);
    if (platform == null) return null;

    if (platform == 'ytmusic') {
      return _importFromYtm(cleanUrl, onProgress);
    } else if (platform == 'spotify') {
      return _importFromSpotify(cleanUrl, onProgress);
    } else if (platform == 'apple') {
      return _importFromAppleMusic(cleanUrl, onProgress);
    }
    return null;
  }

  static Future<ImportedPlaylistData?> _importFromYtm(
    String url,
    void Function(String message, double progress)? onProgress,
  ) async {
    final match = _ytmRegex.firstMatch(url);
    if (match == null) return null;
    final playlistId = match.group(1)!;

    onProgress?.call('Fetching YouTube Music playlist...', 0.2);
    final data = await YtMusicService.getPlaylistFullDetails(playlistId);
    if (data == null) return null;

    final title = data['title'] as String? ?? 'YouTube Music Playlist';
    final coverUrl = data['coverUrl'] as String?;
    final ytTracks = data['tracks'] as List<YtTrack>? ?? [];

    if (ytTracks.isEmpty) return null;

    onProgress?.call('Saving ${ytTracks.length} tracks...', 0.8);
    final tracks = ytTracks.map((y) {
      return Track(
        id: 'ytm_${y.videoId}',
        title: y.title,
        artist: y.artist,
        album: y.album.isNotEmpty ? y.album : title,
        url: y.thumbnailUrl,
        path: y.videoId,
        lyrics: const [],
        duration: y.durationMs,
        artistBrowseId: y.artistBrowseId,
        albumBrowseId: y.albumBrowseId,
      );
    }).toList();

    return ImportedPlaylistData(
      title: title,
      coverUrl: coverUrl,
      tracks: tracks,
    );
  }

  static Future<ImportedPlaylistData?> _importFromSpotify(
    String url,
    void Function(String message, double progress)? onProgress,
  ) async {
    final match = _spotifyRegex.firstMatch(url);
    if (match == null) return null;
    final playlistId = match.group(1)!;

    onProgress?.call('Fetching Spotify playlist metadata...', 0.15);
    final spotifyData = await _fetchSpotifyPlaylist(playlistId);
    if (spotifyData == null) return null;

    final title = spotifyData['name'] as String? ?? 'Spotify Playlist';
    final images = spotifyData['images'] as List?;
    final coverUrl = (images != null && images.isNotEmpty)
        ? images.first['url'] as String?
        : null;

    final items = spotifyData['tracks']?['items'] as List? ?? [];
    if (items.isEmpty) return null;

    final rawTrackPairs = <Map<String, dynamic>>[];
    for (final item in items) {
      final track = item['track'] ?? item;
      if (track == null) continue;
      final name = track['name'] as String? ?? '';
      final artists = track['artists'] as List? ?? [];
      final artistName = artists.isNotEmpty
          ? (artists.first['name'] as String? ?? '')
          : '';
      final durationMs = track['duration_ms'] as int? ?? 0;
      if (name.isNotEmpty) {
        rawTrackPairs.add({
          'title': name,
          'artist': artistName,
          'duration': durationMs,
        });
      }
    }

    if (rawTrackPairs.isEmpty) return null;

    return _matchAndBuildPlaylist(
      title: title,
      coverUrl: coverUrl,
      rawTrackPairs: rawTrackPairs,
      onProgress: onProgress,
    );
  }

  static Future<ImportedPlaylistData?> _importFromAppleMusic(
    String url,
    void Function(String message, double progress)? onProgress,
  ) async {
    onProgress?.call('Fetching Apple Music playlist metadata...', 0.15);
    final appleData = await _fetchAppleMusicPlaylist(url);
    if (appleData == null) return null;

    final title = appleData['title'] as String? ?? 'Apple Music Playlist';
    final coverUrl = appleData['coverUrl'] as String?;
    final rawTrackPairs =
        appleData['tracks'] as List<Map<String, dynamic>>? ?? [];

    if (rawTrackPairs.isEmpty) return null;

    return _matchAndBuildPlaylist(
      title: title,
      coverUrl: coverUrl,
      rawTrackPairs: rawTrackPairs,
      onProgress: onProgress,
    );
  }

  static Future<ImportedPlaylistData?> _matchAndBuildPlaylist({
    required String title,
    required String? coverUrl,
    required List<Map<String, dynamic>> rawTrackPairs,
    void Function(String message, double progress)? onProgress,
  }) async {
    final total = rawTrackPairs.length.clamp(1, 60);
    final toProcess = rawTrackPairs.take(total).toList();
    final resolvedTracks = <Track>[];

    for (int i = 0; i < toProcess.length; i++) {
      final pair = toProcess[i];
      final songTitle = pair['title'] as String;
      final artistName = pair['artist'] as String;
      final query = '$songTitle $artistName';

      final progress = 0.2 + (0.75 * (i / total));
      onProgress?.call(
        'Matching tracks (${i + 1}/$total): $songTitle...',
        progress,
      );

      try {
        final matches = await YtMusicService.search(query, limit: 1);
        if (matches.isNotEmpty) {
          final m = matches.first;
          resolvedTracks.add(
            Track(
              id: 'ytm_${m.videoId}',
              title: m.title.isNotEmpty ? m.title : songTitle,
              artist: m.artist.isNotEmpty ? m.artist : artistName,
              album: m.album.isNotEmpty ? m.album : title,
              url: m.thumbnailUrl,
              path: m.videoId,
              lyrics: const [],
              duration: m.durationMs > 0
                  ? m.durationMs
                  : (pair['duration'] as int? ?? 0),
              artistBrowseId: m.artistBrowseId,
              albumBrowseId: m.albumBrowseId,
            ),
          );
        } else {
          resolvedTracks.add(
            Track(
              id: 'ytm_matched_${i}_${DateTime.now().millisecondsSinceEpoch}',
              title: songTitle,
              artist: artistName,
              album: title,
              url: '',
              path: '',
              lyrics: const [],
              duration: pair['duration'] as int? ?? 0,
            ),
          );
        }
      } catch (e) {
        debugPrint('Matching track error: $e');
      }
    }

    if (resolvedTracks.isEmpty) return null;

    return ImportedPlaylistData(
      title: title,
      coverUrl: coverUrl,
      tracks: resolvedTracks,
    );
  }

  static Future<Map<String, dynamic>?> _fetchSpotifyPlaylist(
    String playlistId,
  ) async {
    // 1. Try Spotify Web Player guest token
    try {
      final client = HttpClient();
      final tokenUri = Uri.parse(
        'https://open.spotify.com/get_access_token?reason=transport&productType=web_player',
      );
      final req = await client.getUrl(tokenUri);
      req.headers.set(
        'User-Agent',
        'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0.0.0 Safari/537.36',
      );
      final res = await req.close();
      if (res.statusCode == 200) {
        final body = await res.transform(utf8.decoder).join();
        final tokenJson = jsonDecode(body);
        final token = tokenJson['accessToken'] as String?;
        if (token != null && token.isNotEmpty) {
          final apiUri = Uri.parse(
            'https://api.spotify.com/v1/playlists/$playlistId?fields=name,images,tracks.items(track(name,duration_ms,artists(name)))',
          );
          final apiReq = await client.getUrl(apiUri);
          apiReq.headers.set('Authorization', 'Bearer $token');
          apiReq.headers.set('User-Agent', 'Mozilla/5.0');
          final apiRes = await apiReq.close();
          if (apiRes.statusCode == 200) {
            final apiBody = await apiRes.transform(utf8.decoder).join();
            return jsonDecode(apiBody) as Map<String, dynamic>?;
          }
        }
      }
    } catch (e) {
      debugPrint('Spotify guest token error: $e');
    }

    // 2. Fallback: Parse Spotify Embed Page
    try {
      final client = HttpClient();
      final embedUri = Uri.parse(
        'https://open.spotify.com/embed/playlist/$playlistId',
      );
      final req = await client.getUrl(embedUri);
      req.headers.set(
        'User-Agent',
        'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36',
      );
      final res = await req.close();
      if (res.statusCode == 200) {
        final html = await res.transform(utf8.decoder).join();
        final match = RegExp(
          r'<script id="__NEXT_DATA__" type="application/json">([^<]+)</script>',
        ).firstMatch(html);
        if (match != null) {
          final data = jsonDecode(match.group(1)!);
          final entity =
              data['props']?['pageProps']?['state']?['data']?['entity'];
          if (entity != null) {
            final name =
                entity['title'] ?? entity['name'] ?? 'Spotify Playlist';
            final trackList = (entity['trackList'] as List?) ?? [];
            final items = trackList.map((t) {
              return {
                'track': {
                  'name': t['title'] ?? '',
                  'artists': [
                    {'name': t['subtitle'] ?? ''}
                  ],
                  'duration_ms': t['duration'] ?? 0,
                }
              };
            }).toList();
            return {
              'name': name,
              'tracks': {'items': items},
            };
          }
        }
      }
    } catch (e) {
      debugPrint('Spotify embed fallback error: $e');
    }
    return null;
  }

  static Future<Map<String, dynamic>?> _fetchAppleMusicPlaylist(
    String url,
  ) async {
    try {
      final client = HttpClient();
      final uri = Uri.parse(url);
      final req = await client.getUrl(uri);
      req.headers.set(
        'User-Agent',
        'Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/122.0.0.0 Safari/537.36',
      );
      req.headers.set('Accept-Language', 'en-US,en;q=0.9');
      final res = await req.close();
      if (res.statusCode == 200 ||
          res.statusCode == 301 ||
          res.statusCode == 302) {
        final html = await res.transform(utf8.decoder).join();

        // 1. Title
        String? title;
        final ogTitleMatch = RegExp(
          r'<meta property="og:title" content="([^"]+)"',
        ).firstMatch(html);
        if (ogTitleMatch != null) {
          title = _unescapeHtml(ogTitleMatch.group(1)!);
        } else {
          final titleTagMatch = RegExp(
            r'<title>([^<]+)<\/title>',
          ).firstMatch(html);
          if (titleTagMatch != null) {
            title = _unescapeHtml(titleTagMatch.group(1)!)
                .replaceAll(
                  RegExp(r'\s+on Apple Music.*$', caseSensitive: false),
                  '',
                )
                .replaceAll(
                  RegExp(r'\s+di Apple Music.*$', caseSensitive: false),
                  '',
                );
          }
        }
        title ??= 'Apple Music Playlist';

        // 2. Cover image
        String? coverUrl;
        final ogImageMatch = RegExp(
          r'<meta property="og:image" content="([^"]+)"',
        ).firstMatch(html);
        if (ogImageMatch != null) {
          coverUrl = ogImageMatch.group(1)!.replaceAll(
                '{w}x{h}bb',
                '600x600bb',
              );
        }

        // 3. Tracks from ld+json
        final tracks = <Map<String, dynamic>>[];
        final ldJsonMatches = RegExp(
          r'<script type="application\/ld\+json">([\s\S]*?)<\/script>',
        ).allMatches(html);
        for (final m in ldJsonMatches) {
          try {
            final raw = m.group(1)?.trim();
            if (raw == null || raw.isEmpty) continue;
            final dynamic parsed = jsonDecode(raw);
            final List<dynamic> entities = parsed is List
                ? parsed
                : (parsed is Map && parsed['@graph'] is List
                    ? parsed['@graph'] as List
                    : [parsed]);

            for (final entity in entities) {
              if (entity is Map) {
                if (entity['@type'] == 'MusicPlaylist' ||
                    entity.containsKey('track')) {
                  if (title == 'Apple Music Playlist' &&
                      entity['name'] != null) {
                    title = entity['name'].toString();
                  }
                  final trackList = entity['track'] as List? ?? [];
                  for (final t in trackList) {
                    if (t is Map) {
                      final name = t['name']?.toString() ?? '';
                      String artist = '';
                      if (t['byArtist'] != null) {
                        final by = t['byArtist'];
                        if (by is List && by.isNotEmpty) {
                          artist = by.first['name']?.toString() ?? '';
                        } else if (by is Map) {
                          artist = by['name']?.toString() ?? '';
                        }
                      }
                      if (artist.isEmpty && t['author'] != null) {
                        final auth = t['author'];
                        if (auth is List && auth.isNotEmpty) {
                          artist = auth.first['name']?.toString() ?? '';
                        } else if (auth is Map) {
                          artist = auth['name']?.toString() ?? '';
                        }
                      }
                      if (name.isNotEmpty) {
                        tracks.add({
                          'title': name,
                          'artist': artist,
                          'duration': _parseIsoDuration(
                            t['duration']?.toString(),
                          ),
                        });
                      }
                    }
                  }
                }
              }
            }
          } catch (e) {
            debugPrint('Apple Music ld+json parse error: $e');
          }
        }

        // Fallback: server data or html regex if ld+json empty
        if (tracks.isEmpty) {
          final rowMatches = RegExp(
            r'class="[^"]*songs-list-row__song-name[^"]*"[^>]*>([^<]+)<\/div>[\s\S]*?class="[^"]*songs-list-row__by-line[^"]*"[^>]*>[\s\S]*?<a[^>]*>([^<]+)<\/a>',
          ).allMatches(html);
          for (final rm in rowMatches) {
            tracks.add({
              'title': _unescapeHtml(rm.group(1)!.trim()),
              'artist': _unescapeHtml(rm.group(2)!.trim()),
              'duration': 0,
            });
          }
        }

        return {
          'title': title,
          'coverUrl': coverUrl,
          'tracks': tracks,
        };
      }
    } catch (e) {
      debugPrint('Apple Music fetch error: $e');
    }
    return null;
  }

  static String _unescapeHtml(String input) {
    return input
        .replaceAll('&amp;', '&')
        .replaceAll('&lt;', '<')
        .replaceAll('&gt;', '>')
        .replaceAll('&quot;', '"')
        .replaceAll('&#39;', "'")
        .replaceAll('&apos;', "'");
  }

  static int _parseIsoDuration(String? iso) {
    if (iso == null || !iso.startsWith('PT')) return 0;
    try {
      final minMatch = RegExp(r'(\d+)M').firstMatch(iso);
      final secMatch = RegExp(r'(\d+)S').firstMatch(iso);
      final mins = minMatch != null ? int.parse(minMatch.group(1)!) : 0;
      final secs = secMatch != null ? int.parse(secMatch.group(1)!) : 0;
      return (mins * 60 + secs) * 1000;
    } catch (_) {
      return 0;
    }
  }
}
