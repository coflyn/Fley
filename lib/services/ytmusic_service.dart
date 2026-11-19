import 'dart:convert';
import 'dart:io';
import 'package:crypto/crypto.dart';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

const _cookieKey = 'ytm_cookie';
const _accountNameKey = 'ytm_account_name';

/// Notifier for login state so UI can react without polling.
final ytmLoggedInNotifier = ValueNotifier<bool>(false);
final ytmAccountNameNotifier = ValueNotifier<String?>('');

Future<void> ytmInitFromPrefs() async {
  final prefs = await SharedPreferences.getInstance();
  final cookie = prefs.getString(_cookieKey) ?? '';
  ytmLoggedInNotifier.value = cookie.isNotEmpty;
  ytmAccountNameNotifier.value = prefs.getString(_accountNameKey);
}

Future<void> ytmSaveCookie(String cookie, {String? accountName}) async {
  final prefs = await SharedPreferences.getInstance();
  await prefs.setString(_cookieKey, cookie);
  if (accountName != null) await prefs.setString(_accountNameKey, accountName);
  ytmLoggedInNotifier.value = cookie.isNotEmpty;
  ytmAccountNameNotifier.value = accountName;
}

Future<void> ytmLogout() async {
  final prefs = await SharedPreferences.getInstance();
  await prefs.remove(_cookieKey);
  await prefs.remove(_accountNameKey);
  ytmLoggedInNotifier.value = false;
  ytmAccountNameNotifier.value = null;
}

Future<String> _getCookie() async {
  final prefs = await SharedPreferences.getInstance();
  return prefs.getString(_cookieKey) ?? '';
}

/// Build SAPISIDHASH Authorization header value.
/// Format: `SAPISIDHASH <ts>_<SHA1(ts + ' ' + sapisid + ' ' + origin)>`
String? _buildSapisidHash(String cookie, String origin) {
  // Extract SAPISID or __Secure-3PAPISID value from cookie string
  String? sapisid;
  for (final part in cookie.split(';')) {
    final kv = part.trim();
    if (kv.startsWith('__Secure-3PAPISID=')) {
      sapisid = kv.substring('__Secure-3PAPISID='.length);
      break;
    }
    if (kv.startsWith('SAPISID=') && sapisid == null) {
      sapisid = kv.substring('SAPISID='.length);
    }
  }
  if (sapisid == null || sapisid.isEmpty) return null;

  final ts = (DateTime.now().millisecondsSinceEpoch ~/ 1000).toString();
  final toHash = '$ts $sapisid $origin';
  final hash = sha1.convert(utf8.encode(toHash)).toString();
  return 'SAPISIDHASH ${ts}_$hash';
}

class YtTrack {
  final String videoId;
  final String title;
  final String artist;
  final String album;
  final String thumbnailUrl;
  final int durationMs;

  const YtTrack({
    required this.videoId,
    required this.title,
    required this.artist,
    required this.album,
    required this.thumbnailUrl,
    required this.durationMs,
  });
}

class YtPlaylist {
  final String playlistId;
  final String title;
  final String author;
  final String thumbnailUrl;

  const YtPlaylist({
    required this.playlistId,
    required this.title,
    required this.author,
    required this.thumbnailUrl,
  });
}

class YtMusicService {
  static const _apiKey = 'AIzaSyC9XL3ZjWddXya6X74dJoCTL-KOEVSHRUA';
  static const _baseUrl = 'music.youtube.com';
  static const _userAgent =
      'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 '
      '(KHTML, like Gecko) Chrome/120.0.0.0 Safari/537.36';

  static Map<String, String> _headers(String cookie) {
    const origin = 'https://music.youtube.com';
    final sapisidHash = _buildSapisidHash(cookie, origin);
    String acceptLang = 'id-ID,id;q=0.9,en-US;q=0.8,en;q=0.7';
    try {
      final loc = Platform.localeName.replaceAll('_', '-');
      acceptLang = '$loc,id;q=0.9,en-US;q=0.8,en;q=0.7';
    } catch (_) {}
    return {
      'Cookie': cookie,
      'User-Agent': _userAgent,
      'Content-Type': 'application/json',
      'Accept': '*/*',
      'Accept-Language': acceptLang,
      'Origin': origin,
      'Referer': '$origin/',
      'X-Goog-AuthUser': '0',
      'x-origin': origin,
      ...?sapisidHash != null ? {'Authorization': sapisidHash} : null,
    };
  }

  static Map<String, dynamic> _context() {
    String hl = 'id';
    String gl = 'ID';
    try {
      final loc = Platform.localeName;
      final parts = loc.split('_');
      if (parts.isNotEmpty && parts[0].isNotEmpty) hl = parts[0];
      if (parts.length > 1 && parts[1].isNotEmpty) gl = parts[1];
      final tz = DateTime.now().timeZoneOffset.inHours;
      if ((gl == 'US' || gl.isEmpty) && (tz >= 7 && tz <= 9)) {
        gl = 'ID';
      }
    } catch (_) {}
    return {
      'client': {
        'clientName': 'WEB_REMIX',
        'clientVersion': '1.20231101.01.00',
        'hl': hl,
        'gl': gl,
      },
    };
  }

  static String getHighResThumbnail(String url) {
    if (url.isEmpty) return url;
    if (url.contains('googleusercontent.com')) {
      final reg = RegExp(r'=w\d+-h\d+[^?]*|=s\d+[^?]*');
      if (reg.hasMatch(url)) {
        return url.replaceAll(reg, '=w800-h800-l90-rj');
      } else if (url.contains('=')) {
        final base = url.split('=').first;
        return '$base=w800-h800-l90-rj';
      } else {
        return '$url=w800-h800-l90-rj';
      }
    }
    if (url.contains('ytimg.com')) {
      if (url.contains('/hqdefault.jpg') ||
          url.contains('/maxresdefault.jpg') ||
          url.contains('/sddefault.jpg')) {
        return url;
      }
      if (url.contains('/default.jpg')) {
        return url.replaceFirst('/default.jpg', '/hqdefault.jpg');
      }
      if (url.contains('/mqdefault.jpg')) {
        return url.replaceFirst('/mqdefault.jpg', '/hqdefault.jpg');
      }
    }
    return url;
  }

  /// Fetch Quick Picks / Home recommendations from YouTube Music home feed.
  static Future<List<YtTrack>> getHomeQuickPicks({int limit = 20}) async {
    final cookie = await _getCookie();
    final client = HttpClient();
    try {
      final uri = Uri.https(
        _baseUrl,
        '/youtubei/v1/browse',
        {'key': _apiKey, 'prettyPrint': 'false'},
      );
      final req = await client.postUrl(uri);
      _headers(cookie).forEach((k, v) => req.headers.set(k, v));
      req.write(jsonEncode({
        'context': _context(),
        'browseId': 'FEmusic_home',
      }));
      final res = await req.close();
      final body = await res.transform(utf8.decoder).join();
      final json = jsonDecode(body) as Map<String, dynamic>;
      final tracks = _parseBrowseFeed(json, limit);
      if (tracks.isNotEmpty) return tracks;
    } catch (e) {
      debugPrint('YTM browse home error: $e');
    } finally {
      client.close();
    }
    // Fallback to regional top hits search if browse is empty
    return search('Top Hits Indonesia', limit: limit);
  }

  /// Search YT Music. Returns up to [limit] tracks.
  static Future<List<YtTrack>> search(String query, {int limit = 20}) async {
    final cookie = await _getCookie();
    if (cookie.isEmpty) throw Exception('Not logged in');

    final client = HttpClient();
    try {
      final uri = Uri.https(
        _baseUrl,
        '/youtubei/v1/search',
        {'key': _apiKey, 'prettyPrint': 'false'},
      );
      final req = await client.postUrl(uri);
      _headers(cookie).forEach((k, v) => req.headers.set(k, v));
      req.write(jsonEncode({
        'context': _context(),
        'query': query,
        'params': 'EgWKAQIIAWoKEAoQAxAEEAkQBQ%3D%3D', // songs filter
      }));
      final res = await req.close();
      final body = await res.transform(utf8.decoder).join();
      return _parseSearchResults(jsonDecode(body), limit);
    } finally {
      client.close();
    }
  }

  static YtTrack? _parseResponsiveItem(Map<String, dynamic> renderer) {
    final videoId = renderer['playlistItemData']?['videoId'] as String? ??
        renderer['overlay']?['musicItemThumbnailOverlayRenderer']
            ?['content']?['musicPlayButtonRenderer']?['playNavigationEndpoint']
            ?['watchEndpoint']?['videoId'] as String? ??
        '';
    if (videoId.isEmpty) return null;

    // columns: 0 = title, 1 = artist•album•duration
    final cols = renderer['flexColumns'] as List? ?? [];
    String title = '';
    String artist = '';
    String album = '';

    if (cols.isNotEmpty) {
      final runs = cols[0]['musicResponsiveListItemFlexColumnRenderer']
          ?['text']?['runs'] as List?;
      title = runs?.map((r) => r['text']).join('') ?? '';
    }
    if (cols.length > 1) {
      final runs = cols[1]['musicResponsiveListItemFlexColumnRenderer']
          ?['text']?['runs'] as List? ?? [];
      final parts = runs
          .where((r) => (r['text'] as String?) != ' • ')
          .map((r) => r['text'] as String? ?? '')
          .where((s) => s.isNotEmpty)
          .toList();
      if (parts.isNotEmpty) artist = parts[0];
      if (parts.length > 1) album = parts[1];
    }

    final thumbs = renderer['thumbnail']?['musicThumbnailRenderer']
        ?['thumbnail']?['thumbnails'] as List?;
    final rawThumbUrl = thumbs?.last?['url'] as String? ?? '';
    final thumbUrl = getHighResThumbnail(rawThumbUrl);

    // Duration from last run of col1 (format "M:SS")
    int durationMs = 0;
    if (cols.length > 1) {
      final runs = cols[1]['musicResponsiveListItemFlexColumnRenderer']
          ?['text']?['runs'] as List? ?? [];
      final lastText = runs.isNotEmpty
          ? runs.last['text'] as String? ?? ''
          : '';
      final dParts = lastText.split(':');
      if (dParts.length == 2) {
        final m = int.tryParse(dParts[0]) ?? 0;
        final s = int.tryParse(dParts[1]) ?? 0;
        durationMs = (m * 60 + s) * 1000;
      }
    }

    return YtTrack(
      videoId: videoId,
      title: title,
      artist: artist,
      album: album,
      thumbnailUrl: thumbUrl,
      durationMs: durationMs,
    );
  }

  static List<YtTrack> _parseBrowseFeed(Map<String, dynamic> json, int limit) {
    final results = <YtTrack>[];
    try {
      final tabs = json['contents']?['singleColumnBrowseResultsRenderer']
          ?['tabs'] as List?;
      if (tabs == null || tabs.isEmpty) return results;
      final contents = tabs.first['tabRenderer']?['content']
          ?['sectionListRenderer']?['contents'] as List?;
      if (contents == null) return results;

      for (final section in contents) {
        final shelf = section['musicCarouselShelfRenderer'] as Map<String, dynamic>?;
        if (shelf == null) continue;
        final items = shelf['contents'] as List?;
        if (items == null) continue;

        for (final item in items) {
          if (results.length >= limit) break;
          final renderer = item['musicResponsiveListItemRenderer'] as Map<String, dynamic>?;
          if (renderer == null) continue;
          final track = _parseResponsiveItem(renderer);
          if (track != null) results.add(track);
        }
        if (results.isNotEmpty) break;
      }
    } catch (e) {
      debugPrint('YTM browse parse error: $e');
    }
    return results;
  }

  static List<YtTrack> _parseSearchResults(Map<String, dynamic> json, int limit) {
    final results = <YtTrack>[];
    try {
      final tabs = json['contents']?['tabbedSearchResultsRenderer']
          ?['tabs'] as List?;
      if (tabs == null) return results;
      final contents = tabs.first['tabRenderer']?['content']
          ?['sectionListRenderer']?['contents'] as List?;
      if (contents == null) return results;

      for (final section in contents) {
        final items = section['musicShelfRenderer']?['contents'] as List?;
        if (items == null) continue;
        for (final item in items) {
          if (results.length >= limit) break;
          final renderer = item['musicResponsiveListItemRenderer'] as Map<String, dynamic>?;
          if (renderer == null) continue;
          final track = _parseResponsiveItem(renderer);
          if (track != null) results.add(track);
        }
        if (results.length >= limit) break;
      }
    } catch (e) {
      debugPrint('YTM parse error: $e');
    }
    return results;
  }

  /// Search trending community playlists from YouTube Music.
  static Future<List<YtPlaylist>> getCommunityPlaylists({int limit = 15}) async {
    final cookie = await _getCookie();
    final client = HttpClient();
    try {
      final uri = Uri.https(
        _baseUrl,
        '/youtubei/v1/search',
        {'key': _apiKey, 'prettyPrint': 'false'},
      );
      final req = await client.postUrl(uri);
      _headers(cookie).forEach((k, v) => req.headers.set(k, v));
      req.write(jsonEncode({
        'context': _context(),
        'query': 'Trending Indonesia',
        'params': 'EgeKAQQoAEABahIQDhAKEAUQCRADEAQQFRAQEBE%3D', // Community playlists filter
      }));
      final res = await req.close();
      final body = await res.transform(utf8.decoder).join();
      final json = jsonDecode(body) as Map<String, dynamic>;
      return _parseCommunityPlaylists(json, limit);
    } catch (e) {
      debugPrint('YTM community playlists error: $e');
      return [];
    } finally {
      client.close();
    }
  }

  static List<YtPlaylist> _parseCommunityPlaylists(
      Map<String, dynamic> json, int limit) {
    final results = <YtPlaylist>[];
    try {
      final tabs = json['contents']?['tabbedSearchResultsRenderer']
          ?['tabs'] as List?;
      if (tabs == null || tabs.isEmpty) return results;
      final contents = tabs.first['tabRenderer']?['content']
          ?['sectionListRenderer']?['contents'] as List?;
      if (contents == null) return results;

      for (final section in contents) {
        final items = section['musicShelfRenderer']?['contents'] as List?;
        if (items == null) continue;
        for (final item in items) {
          if (results.length >= limit) break;
          final renderer =
              item['musicResponsiveListItemRenderer'] as Map<String, dynamic>?;
          if (renderer == null) continue;

          final browseId = renderer['navigationEndpoint']?['browseEndpoint']
              ?['browseId'] as String? ?? '';
          if (browseId.isEmpty) continue;

          final cols = renderer['flexColumns'] as List? ?? [];
          String title = '';
          String author = '';

          if (cols.isNotEmpty) {
            final runs = cols[0]['musicResponsiveListItemFlexColumnRenderer']
                ?['text']?['runs'] as List?;
            title = runs?.map((r) => r['text']).join('') ?? '';
          }
          if (cols.length > 1) {
            final runs = cols[1]['musicResponsiveListItemFlexColumnRenderer']
                ?['text']?['runs'] as List? ?? [];
            final parts = runs
                .where((r) => (r['text'] as String?) != ' • ')
                .map((r) => r['text'] as String? ?? '')
                .where((s) => s.isNotEmpty)
                .toList();
            if (parts.isNotEmpty) author = parts.join(' • ');
          }

          final thumbs = renderer['thumbnail']?['musicThumbnailRenderer']
              ?['thumbnail']?['thumbnails'] as List?;
          final rawThumbUrl = thumbs?.last?['url'] as String? ?? '';
          final thumbUrl = getHighResThumbnail(rawThumbUrl);

          results.add(YtPlaylist(
            playlistId: browseId,
            title: title,
            author: author,
            thumbnailUrl: thumbUrl,
          ));
        }
        if (results.length >= limit) break;
      }
    } catch (e) {
      debugPrint('YTM community playlist parse error: $e');
    }
    return results;
  }

  /// Fetch tracks of a YouTube Music playlist.
  static Future<List<YtTrack>> getPlaylistTracks(String playlistId,
      {int limit = 50}) async {
    final cookie = await _getCookie();
    final client = HttpClient();
    try {
      final uri = Uri.https(
        _baseUrl,
        '/youtubei/v1/browse',
        {'key': _apiKey, 'prettyPrint': 'false'},
      );
      final req = await client.postUrl(uri);
      _headers(cookie).forEach((k, v) => req.headers.set(k, v));
      final browseId =
          playlistId.startsWith('VL') ? playlistId : 'VL$playlistId';
      req.write(jsonEncode({
        'context': _context(),
        'browseId': browseId,
      }));
      final res = await req.close();
      final body = await res.transform(utf8.decoder).join();
      final json = jsonDecode(body) as Map<String, dynamic>;

      final results = <YtTrack>[];
      final secContents = json['contents']?['twoColumnBrowseResultsRenderer']
          ?['secondaryContents']?['sectionListRenderer']?['contents'] as List?;
      List? items;
      if (secContents != null && secContents.isNotEmpty) {
        items = secContents.first['musicPlaylistShelfRenderer']?['contents']
            as List?;
      }
      if (items == null) {
        final tabs = json['contents']?['singleColumnBrowseResultsRenderer']
            ?['tabs'] as List?;
        final tabContents = tabs?.first['tabRenderer']?['content']
            ?['sectionListRenderer']?['contents'] as List?;
        items = tabContents?.first['musicPlaylistShelfRenderer']?['contents']
            as List?;
      }

      if (items != null) {
        for (final item in items) {
          if (results.length >= limit) break;
          final renderer =
              item['musicResponsiveListItemRenderer'] as Map<String, dynamic>?;
          if (renderer == null) continue;
          final track = _parseResponsiveItem(renderer);
          if (track != null) results.add(track);
        }
      }
      return results;
    } catch (e) {
      debugPrint('YTM playlist tracks error: $e');
      return [];
    } finally {
      client.close();
    }
  }

  /// Resolve audio stream URL for [videoId].
  /// Tries multiple clients in order until one returns a valid stream.
  static Future<String> getStreamUrl(String videoId) async {
    final cookie = await _getCookie();
    if (cookie.isEmpty) throw Exception('Not logged in');

    // Try clients in order: ANDROID_MUSIC → TVHTML5_SIMPLY_EMBEDDED → IOS
    final clients = [
      _androidMusicPayload(videoId),
      _tvEmbeddedPayload(videoId),
      _iosPayload(videoId),
    ];

    final client = HttpClient();
    try {
      for (final payload in clients) {
        final uri = Uri.https(
          'www.youtube.com',
          '/youtubei/v1/player',
          {'key': _apiKey, 'prettyPrint': 'false'},
        );
        final req = await client.postUrl(uri);
        req.headers.set('Content-Type', 'application/json');
        req.headers.set('Cookie', cookie);
        req.headers.set('User-Agent', payload['_ua'] as String);
        // Inject SAPISIDHASH for auth
        const origin = 'https://www.youtube.com';
        final sapisidHash = _buildSapisidHash(cookie, origin);
        if (sapisidHash != null) req.headers.set('Authorization', sapisidHash);
        req.headers.set('X-Goog-AuthUser', '0');
        (payload['_headers'] as Map<String, String>?)
            ?.forEach((k, v) => req.headers.set(k, v));

        final body = payload..remove('_ua')..remove('_headers');
        req.write(jsonEncode(body));

        final res = await req.close();
        final responseBody = await res.transform(utf8.decoder).join();
        final json = jsonDecode(responseBody) as Map<String, dynamic>;

        final status = json['playabilityStatus']?['status'] as String? ?? '';
        final reason = json['playabilityStatus']?['reason'] as String? ?? '';
        debugPrint('YTM [${ (json['context']?['client']?['clientName'] ?? '?')  }] status: $status | $reason');

        if (status == 'UNPLAYABLE' || status == 'LOGIN_REQUIRED') continue;

        final allFormats = <dynamic>[
          ...json['streamingData']?['adaptiveFormats'] as List? ?? [],
          ...json['streamingData']?['formats'] as List? ?? [],
        ];
        debugPrint('YTM formats: ${allFormats.length}');
        if (allFormats.isEmpty) continue;

        Map<String, dynamic>? best;
        int bestBitrate = 0;
        for (final f in allFormats) {
          final mime = f['mimeType'] as String? ?? '';
          final url = f['url'] as String?;
          if (url == null || url.isEmpty) continue;
          final bitrate = f['bitrate'] as int? ?? 0;
          if (mime.startsWith('audio/') && bitrate > bestBitrate) {
            bestBitrate = bitrate;
            best = f as Map<String, dynamic>;
          }
        }
        best ??= allFormats
            .cast<Map<String, dynamic>>()
            .firstWhere((f) => (f['url'] as String?)?.isNotEmpty == true,
                orElse: () => {});

        final url = best['url'] as String?;
        if (url != null && url.isNotEmpty) return url;
      }
      throw Exception('No audio stream found from any client');
    } finally {
      client.close();
    }
  }

  static Map<String, dynamic> _androidMusicPayload(String videoId) => {
        '_ua': 'com.google.android.apps.youtube.music/6.42.52 (Linux; U; Android 11) gzip',
        '_headers': <String, String>{
          'X-YouTube-Client-Name': '21',
          'X-YouTube-Client-Version': '6.42.52',
        },
        'context': {
          'client': {
            'clientName': 'ANDROID_MUSIC',
            'clientVersion': '6.42.52',
            'androidSdkVersion': 30,
            'hl': 'en',
          },
        },
        'videoId': videoId,
        'contentCheckOk': true,
        'racyCheckOk': true,
      };

  static Map<String, dynamic> _tvEmbeddedPayload(String videoId) => {
        '_ua': 'Mozilla/5.0 (SMART-TV; Linux; Tizen 6.0) AppleWebKit/538.1 (KHTML, like Gecko) Version/6.0 TV Safari/538.1',
        '_headers': <String, String>{},
        'context': {
          'client': {
            'clientName': 'TVHTML5_SIMPLY_EMBEDDED_PLAYER',
            'clientVersion': '2.0',
            'hl': 'en',
          },
          'thirdParty': {'embedUrl': 'https://www.youtube.com/'},
        },
        'videoId': videoId,
        'contentCheckOk': true,
        'racyCheckOk': true,
      };

  static Map<String, dynamic> _iosPayload(String videoId) => {
        '_ua': 'com.google.ios.youtube/19.29.1 (iPhone16,2; U; CPU iOS 17_5_1 like Mac OS X)',
        '_headers': <String, String>{},
        'context': {
          'client': {
            'clientName': 'IOS',
            'clientVersion': '19.29.1',
            'deviceMake': 'Apple',
            'deviceModel': 'iPhone16,2',
            'hl': 'en',
            'osName': 'iPhone',
            'osVersion': '17.5.1.21F90',
          },
        },
        'videoId': videoId,
        'contentCheckOk': true,
        'racyCheckOk': true,
      };
}