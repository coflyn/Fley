import 'dart:convert';
import 'dart:io';
import 'package:crypto/crypto.dart';
import 'package:flutter/foundation.dart';
import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

const _cookieKey = 'ytm_cookie';
const _accountNameKey = 'ytm_account_name';

/// Returns or creates the dedicated downloads directory for Fley.
Future<Directory> getFleyDownloadsDirectory() async {
  Directory baseDir;
  if (Platform.isAndroid) {
    final ext = await getExternalStorageDirectory();
    baseDir = ext ?? await getApplicationDocumentsDirectory();
  } else if (Platform.isIOS) {
    baseDir = await getApplicationDocumentsDirectory();
  } else {
    final down = await getDownloadsDirectory();
    baseDir = down ?? await getApplicationDocumentsDirectory();
  }
  final downloadDir = Directory('${baseDir.path}/FleyDownloads');
  if (!await downloadDir.exists()) {
    await downloadDir.create(recursive: true);
  }
  return downloadDir;
}

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
  final String? artistBrowseId;
  final String? albumBrowseId;

  const YtTrack({
    required this.videoId,
    required this.title,
    required this.artist,
    required this.album,
    required this.thumbnailUrl,
    required this.durationMs,
    this.artistBrowseId,
    this.albumBrowseId,
  });

  YtTrack copyWith({
    String? videoId,
    String? title,
    String? artist,
    String? album,
    String? thumbnailUrl,
    int? durationMs,
    String? artistBrowseId,
    String? albumBrowseId,
  }) {
    return YtTrack(
      videoId: videoId ?? this.videoId,
      title: title ?? this.title,
      artist: artist ?? this.artist,
      album: album ?? this.album,
      thumbnailUrl: thumbnailUrl ?? this.thumbnailUrl,
      durationMs: durationMs ?? this.durationMs,
      artistBrowseId: artistBrowseId ?? this.artistBrowseId,
      albumBrowseId: albumBrowseId ?? this.albumBrowseId,
    );
  }
}

class YtPlaylist {
  final String playlistId;
  final String title;
  final String author;
  final String thumbnailUrl;
  final bool isAlbum;

  const YtPlaylist({
    required this.playlistId,
    required this.title,
    required this.author,
    required this.thumbnailUrl,
    this.isAlbum = false,
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
    String hl = 'en';
    String gl = 'US';
    try {
      final loc = Platform.localeName;
      final parts = loc.split(RegExp(r'[-_]'));
      if (parts.isNotEmpty && parts[0].isNotEmpty) hl = parts[0].toLowerCase();
      if (parts.length > 1 && parts[1].isNotEmpty) gl = parts[1].toUpperCase();
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
    String? artistBrowseId;
    String? albumBrowseId;

    if (cols.isNotEmpty) {
      final runs = cols[0]['musicResponsiveListItemFlexColumnRenderer']
          ?['text']?['runs'] as List?;
      title = runs?.map((r) => r['text']).join('') ?? '';
    }
    if (cols.length > 1) {
      final runs = cols[1]['musicResponsiveListItemFlexColumnRenderer']
          ?['text']?['runs'] as List? ?? [];

      for (final r in runs) {
        final text = (r['text'] as String? ?? '').trim();
        final bId = r['navigationEndpoint']?['browseEndpoint']?['browseId']
            as String? ??
            '';
        final pageType = r['navigationEndpoint']?['browseEndpoint']
            ?['browseEndpointContextSupportedConfigs']
            ?['browseEndpointContextMusicConfig']?['pageType'] as String? ??
            '';
        if (pageType == 'MUSIC_PAGE_TYPE_ARTIST' || bId.startsWith('UC')) {
          if (artist.isEmpty && text.isNotEmpty) artist = text;
          artistBrowseId ??= bId;
        } else if (pageType == 'MUSIC_PAGE_TYPE_ALBUM' ||
            bId.startsWith('MPREb')) {
          if (text.isNotEmpty) album = text;
          albumBrowseId ??= bId;
        }
      }

      bool isIgnoredMetadata(String s) {
        final lower = s.trim().toLowerCase();
        if (lower.isEmpty || lower == '•') return true;
        if (lower == 'song' ||
            lower == 'lagu' ||
            lower == 'video' ||
            lower == 'single' ||
            lower == 'audio') {
          return true;
        }
        if (RegExp(
          r'^\d+([.,]\d+)?\s*[kmb]?\s*(plays?|views?|ditonton|tayangan|x ditonton)?$',
          caseSensitive: false,
        ).hasMatch(lower)) {
          return true;
        }
        if (RegExp(r'^\d{1,2}:\d{2}(:\d{2})?$').hasMatch(lower)) {
          return true;
        }
        return false;
      }

      final parts = runs
          .map((r) => (r['text'] as String? ?? '').trim())
          .where((s) => s.isNotEmpty && s != '•')
          .toList();

      if (artist.isEmpty && parts.isNotEmpty && !isIgnoredMetadata(parts[0])) {
        artist = parts[0];
      }
      if (album.isEmpty && parts.length > 1) {
        for (int i = 1; i < parts.length; i++) {
          final p = parts[i];
          if (p != artist && !isIgnoredMetadata(p)) {
            album = p;
            break;
          }
        }
      }
    }

    final thumbs = renderer['thumbnail']?['musicThumbnailRenderer']
        ?['thumbnail']?['thumbnails'] as List?;
    final rawThumbUrl = thumbs?.last?['url'] as String? ?? '';
    final thumbUrl = getHighResThumbnail(rawThumbUrl);

    // Duration parsing
    int durationMs = 0;

    // 1. Check fixedColumns
    final fixedCols = renderer['fixedColumns'] as List? ?? [];
    if (fixedCols.isNotEmpty) {
      final runs = fixedCols[0]['musicResponsiveListItemFixedColumnRenderer']
          ?['text']?['runs'] as List? ?? [];
      if (runs.isNotEmpty) {
        final text = runs.first['text'] as String? ?? '';
        durationMs = _parseDurationText(text);
      }
    }

    // 2. Check lengthText
    if (durationMs == 0 && renderer['lengthText'] != null) {
      final lengthRuns = renderer['lengthText']['runs'] as List?;
      final text = lengthRuns != null && lengthRuns.isNotEmpty
          ? (lengthRuns.first['text'] as String? ?? '')
          : (renderer['lengthText']['simpleText'] as String? ?? '');
      durationMs = _parseDurationText(text);
    }

    // 3. Scan runs and text across flexColumns
    if (durationMs == 0 && cols.isNotEmpty) {
      for (final col in cols) {
        final colText = col['musicResponsiveListItemFlexColumnRenderer']?['text'];
        final runs = colText?['runs'] as List? ?? [];
        for (final r in runs) {
          final t = (r['text'] as String? ?? '').trim();
          final match = RegExp(r'\b(\d{1,2}:\d{2}(?::\d{2})?)\b').firstMatch(t);
          if (match != null) {
            durationMs = _parseDurationText(match.group(1)!);
            if (durationMs > 0) break;
          }
        }
        if (durationMs == 0 && colText?['simpleText'] != null) {
          final t = (colText!['simpleText'] as String? ?? '').trim();
          final match = RegExp(r'\b(\d{1,2}:\d{2}(?::\d{2})?)\b').firstMatch(t);
          if (match != null) {
            durationMs = _parseDurationText(match.group(1)!);
          }
        }
        if (durationMs > 0) break;
      }
    }

    return YtTrack(
      videoId: videoId,
      title: title,
      artist: artist,
      album: album,
      thumbnailUrl: thumbUrl,
      durationMs: durationMs,
      artistBrowseId: artistBrowseId,
      albumBrowseId: albumBrowseId,
    );
  }

  static int _parseDurationText(String text) {
    final clean = text.trim();
    final parts = clean.split(':');
    if (parts.length == 2) {
      final m = int.tryParse(parts[0]) ?? 0;
      final s = int.tryParse(parts[1]) ?? 0;
      return (m * 60 + s) * 1000;
    } else if (parts.length == 3) {
      final h = int.tryParse(parts[0]) ?? 0;
      final m = int.tryParse(parts[1]) ?? 0;
      final s = int.tryParse(parts[2]) ?? 0;
      return (h * 3600 + m * 60 + s) * 1000;
    }
    return 0;
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

  /// Fetch new official albums & singles releases from YouTube Music (FEmusic_new_releases).
  static Future<List<YtPlaylist>> getNewReleases({int limit = 20}) async {
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
        'browseId': 'FEmusic_new_releases',
      }));
      final res = await req.close();
      final body = await res.transform(utf8.decoder).join();
      final json = jsonDecode(body) as Map<String, dynamic>;
      return _extractNewReleases(json, limit);
    } catch (e) {
      debugPrint('YTM getNewReleases error: $e');
      return [];
    } finally {
      client.close();
    }
  }

  static List<YtPlaylist> _extractNewReleases(Map<String, dynamic> json, int limit) {
    final results = <YtPlaylist>[];
    try {
      final tabs = (json['contents']?['singleColumnBrowseResultsRenderer']
              ?['tabs'] as List?) ??
          (json['contents']?['tabbedSearchResultsRenderer']?['tabs'] as List?);
      if (tabs == null || tabs.isEmpty) return results;
      final contents = tabs.first['tabRenderer']?['content']
          ?['sectionListRenderer']?['contents'] as List?;
      if (contents == null) return results;

      for (final section in contents) {
        final shelf =
            section['musicCarouselShelfRenderer'] as Map<String, dynamic>?;
        if (shelf == null) continue;
        final items = shelf['contents'] as List? ?? [];
        for (final item in items) {
          if (results.length >= limit) break;
          final renderer =
              item['musicTwoRowItemRenderer'] as Map<String, dynamic>?;
          if (renderer != null) {
            final pl = _parseTwoRowPlaylist(renderer);
            if (pl != null &&
                pl.playlistId.isNotEmpty &&
                !results.any((r) => r.playlistId == pl.playlistId)) {
              results.add(pl);
            }
          }
        }
        if (results.length >= limit) break;
      }
    } catch (e) {
      debugPrint('YTM parse new releases error: $e');
    }
    return results;
  }

  /// Fetch top charts and curated playlists from YouTube Music (FEmusic_charts & FEmusic_home).
  static Future<List<YtPlaylist>> getCommunityPlaylists({int limit = 15}) async {
    final cookie = await _getCookie();
    final client = HttpClient();
    final results = <YtPlaylist>[];

    // 1. Official Charts (FEmusic_charts)
    try {
      final chartsUri = Uri.https(
        _baseUrl,
        '/youtubei/v1/browse',
        {'key': _apiKey, 'prettyPrint': 'false'},
      );
      final req = await client.postUrl(chartsUri);
      _headers(cookie).forEach((k, v) => req.headers.set(k, v));
      req.write(jsonEncode({
        'context': _context(),
        'browseId': 'FEmusic_charts',
      }));
      final res = await req.close();
      final body = await res.transform(utf8.decoder).join();
      final json = jsonDecode(body) as Map<String, dynamic>;
      final chartsList = _extractChartsPlaylists(json, limit);
      for (final pl in chartsList) {
        if (!results.any((r) => r.playlistId == pl.playlistId)) {
          results.add(pl);
        }
      }
    } catch (e) {
      debugPrint('YTM charts error: $e');
    }

    // 2. Curated editorial shelves from Home feed
    if (results.length < limit) {
      try {
        final homeUri = Uri.https(
          _baseUrl,
          '/youtubei/v1/browse',
          {'key': _apiKey, 'prettyPrint': 'false'},
        );
        final homeReq = await client.postUrl(homeUri);
        _headers(cookie).forEach((k, v) => homeReq.headers.set(k, v));
        homeReq.write(jsonEncode({
          'context': _context(),
          'browseId': 'FEmusic_home',
        }));
        final homeRes = await homeReq.close();
        final homeBody = await homeRes.transform(utf8.decoder).join();
        final homeJson = jsonDecode(homeBody) as Map<String, dynamic>;
        final homePlaylists = _extractCommunityPlaylistsFromHome(
          homeJson,
          limit - results.length,
        );
        for (final pl in homePlaylists) {
          if (!results.any((r) => r.playlistId == pl.playlistId)) {
            results.add(pl);
          }
        }
      } catch (e) {
        debugPrint('YTM community playlists from home error: $e');
      }
    }

    // 3. Fallback: Search Top Hits globally or regionally
    if (results.isEmpty) {
      try {
        final uri = Uri.https(
          _baseUrl,
          '/youtubei/v1/search',
          {'key': _apiKey, 'prettyPrint': 'false'},
        );
        final req = await client.postUrl(uri);
        _headers(cookie).forEach((k, v) => req.headers.set(k, v));
        final gl = _context()['client']['gl'] as String? ?? 'US';
        final query = gl == 'ID' ? 'Top Hits Indonesia' : 'Top Hits Global';
        req.write(jsonEncode({
          'context': _context(),
          'query': query,
          'params': 'EgeKAQQoAEABahIQDhAKEAUQCRADEAQQFRAQEBE%3D',
        }));
        final res = await req.close();
        final body = await res.transform(utf8.decoder).join();
        final json = jsonDecode(body) as Map<String, dynamic>;
        results.addAll(_parseCommunityPlaylists(json, limit));
      } catch (e) {
        debugPrint('YTM fallback search playlists error: $e');
      }
    }

    client.close();
    return results;
  }

  static List<YtPlaylist> _extractChartsPlaylists(Map<String, dynamic> json, int limit) {
    final results = <YtPlaylist>[];
    try {
      final tabs = (json['contents']?['singleColumnBrowseResultsRenderer']
              ?['tabs'] as List?) ??
          (json['contents']?['tabbedSearchResultsRenderer']?['tabs'] as List?);
      if (tabs == null || tabs.isEmpty) return results;
      final contents = tabs.first['tabRenderer']?['content']
          ?['sectionListRenderer']?['contents'] as List?;
      if (contents == null) return results;

      for (final section in contents) {
        final shelf =
            section['musicCarouselShelfRenderer'] as Map<String, dynamic>?;
        if (shelf == null) continue;
        final items = shelf['contents'] as List? ?? [];
        for (final item in items) {
          if (results.length >= limit) break;
          final renderer =
              item['musicTwoRowItemRenderer'] as Map<String, dynamic>?;
          if (renderer != null) {
            final pl = _parseTwoRowPlaylist(renderer);
            if (pl != null &&
                pl.playlistId.isNotEmpty &&
                !results.any((r) => r.playlistId == pl.playlistId)) {
              results.add(pl);
            }
          }
        }
        if (results.length >= limit) break;
      }
    } catch (_) {}
    return results;
  }

  static YtPlaylist? _parseTwoRowPlaylist(Map<String, dynamic> renderer) {
    final nav = renderer['navigationEndpoint']?['browseEndpoint'];
    var browseId = nav?['browseId'] as String? ?? '';
    if (browseId.isEmpty) return null;
    final bool isAlbum = browseId.startsWith('MPREb') ||
        nav?['browseEndpointContextSupportedConfigs']
                ?['browseEndpointContextMusicConfig']?['pageType'] ==
            'MUSIC_PAGE_TYPE_ALBUM';
    if (browseId.startsWith('VL')) {
      browseId = browseId.substring(2);
    }

    final titleRuns = renderer['title']?['runs'] as List? ?? [];
    final title =
        titleRuns.map((r) => r['text'] as String? ?? '').join('').trim();
    if (title.isEmpty) return null;

    final subRuns = renderer['subtitle']?['runs'] as List? ?? [];
    final authorParts = subRuns
        .where((r) => (r['text'] as String?) != ' • ')
        .map((r) => (r['text'] as String? ?? '').trim())
        .where((s) =>
            s.isNotEmpty &&
            s.toLowerCase() != 'single' &&
            s.toLowerCase() != 'album' &&
            s.toLowerCase() != 'ep')
        .toList();
    final author =
        authorParts.isNotEmpty ? authorParts.join(' • ') : 'Various Artists';

    final thumbs = renderer['thumbnailRenderer']?['musicThumbnailRenderer']
            ?['thumbnail']?['thumbnails'] as List? ??
        renderer['thumbnail']?['musicThumbnailRenderer']?['thumbnail']
            ?['thumbnails'] as List?;
    final rawThumbUrl = (thumbs != null && thumbs.isNotEmpty)
        ? (thumbs.last['url'] as String? ?? '')
        : '';
    final thumbUrl = getHighResThumbnail(rawThumbUrl);

    return YtPlaylist(
      playlistId: browseId,
      title: title,
      author: author,
      thumbnailUrl: thumbUrl,
      isAlbum: isAlbum,
    );
  }

  static List<YtPlaylist> _extractCommunityPlaylistsFromHome(
      Map<String, dynamic> json, int limit) {
    final results = <YtPlaylist>[];
    try {
      final tabs = (json['contents']?['singleColumnBrowseResultsRenderer']
              ?['tabs'] as List?) ??
          (json['contents']?['tabbedSearchResultsRenderer']?['tabs'] as List?);
      if (tabs == null || tabs.isEmpty) return results;
      final contents = tabs.first['tabRenderer']?['content']
          ?['sectionListRenderer']?['contents'] as List?;
      if (contents == null) return results;

      Map<String, dynamic>? targetShelf;

      for (final section in contents) {
        final shelf =
            section['musicCarouselShelfRenderer'] as Map<String, dynamic>?;
        if (shelf == null) continue;
        final header = shelf['header']
                ?['musicCarouselShelfBasicHeaderRenderer'] ??
            shelf['header']?['musicHeaderRenderer'];
        final titleRuns = header?['title']?['runs'] as List? ?? [];
        final titleText = titleRuns
            .map((r) => r['text'] as String? ?? '')
            .join('')
            .toLowerCase();

        final items = shelf['contents'] as List? ?? [];
        final hasPlaylists = items.any((it) {
          final twoRow = it['musicTwoRowItemRenderer'];
          if (twoRow == null) return false;
          final bId = twoRow['navigationEndpoint']?['browseEndpoint']
                  ?['browseId'] as String? ??
              '';
          return bId.contains('PL') || bId.startsWith('VL');
        });

        if (!hasPlaylists) continue;

        if (titleText.contains('komunitas') ||
            titleText.contains('community') ||
            (titleText.contains('trending') && titleText.contains('playlist'))) {
          targetShelf = shelf;
          break;
        } else {
          targetShelf ??= shelf;
        }
      }

      if (targetShelf != null) {
        final items = targetShelf['contents'] as List? ?? [];
        for (final item in items) {
          if (results.length >= limit) break;
          final renderer =
              item['musicTwoRowItemRenderer'] as Map<String, dynamic>?;
          if (renderer != null) {
            final pl = _parseTwoRowPlaylist(renderer);
            if (pl != null) results.add(pl);
          }
        }
      }
    } catch (e) {
      debugPrint('YTM parse community playlists from home error: $e');
    }
    return results;
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

  static String? _extractHeaderThumbnail(Map<String, dynamic> json) {
    try {
      final twoTabs = json['contents']?['twoColumnBrowseResultsRenderer']?['tabs']
          as List?;
      if (twoTabs != null && twoTabs.isNotEmpty) {
        final secContents = twoTabs.first['tabRenderer']?['content']
            ?['sectionListRenderer']?['contents'] as List?;
        if (secContents != null && secContents.isNotEmpty) {
          final header = secContents.first['musicResponsiveHeaderRenderer']
              as Map<String, dynamic>?;
          final thumbs = header?['thumbnail']?['musicThumbnailRenderer']
              ?['thumbnail']?['thumbnails'] as List?;
          if (thumbs != null && thumbs.isNotEmpty) {
            final url = thumbs.last['url'] as String? ?? '';
            if (url.isNotEmpty) return getHighResThumbnail(url);
          }
        }
      }

      final rootHeader = json['header']?['musicDetailHeaderRenderer'] ??
          json['header']?['musicResponsiveHeaderRenderer'] ??
          json['header']?['musicImmersiveHeaderRenderer'] ??
          json['header']?['musicVisualHeaderRenderer'];
      if (rootHeader != null) {
        final thumbs = rootHeader['thumbnail']?['musicThumbnailRenderer']
            ?['thumbnail']?['thumbnails'] as List?;
        if (thumbs != null && thumbs.isNotEmpty) {
          final url = thumbs.last['url'] as String? ?? '';
          if (url.isNotEmpty) return getHighResThumbnail(url);
        }
      }

      final singleTabs = json['contents']
          ?['singleColumnBrowseResultsRenderer']?['tabs'] as List?;
      if (singleTabs != null && singleTabs.isNotEmpty) {
        final secContents = singleTabs.first['tabRenderer']?['content']
            ?['sectionListRenderer']?['contents'] as List?;
        if (secContents != null && secContents.isNotEmpty) {
          final header = secContents.first['musicResponsiveHeaderRenderer']
              as Map<String, dynamic>?;
          final thumbs = header?['thumbnail']?['musicThumbnailRenderer']
              ?['thumbnail']?['thumbnails'] as List?;
          if (thumbs != null && thumbs.isNotEmpty) {
            final url = thumbs.last['url'] as String? ?? '';
            if (url.isNotEmpty) return getHighResThumbnail(url);
          }
        }
      }
    } catch (_) {}
    return null;
  }

  static Map<String, dynamic>? _findBottomEndpoint(Map<String, dynamic> json) {
    try {
      final List sections = [];
      final singleTabs = json['contents']
          ?['singleColumnBrowseResultsRenderer']?['tabs'] as List?;
      if (singleTabs != null && singleTabs.isNotEmpty) {
        final tabContents = singleTabs.first['tabRenderer']?['content']
            ?['sectionListRenderer']?['contents'] as List?;
        if (tabContents != null) sections.addAll(tabContents);
      }
      final twoTabs = json['contents']?['twoColumnBrowseResultsRenderer']
          ?['tabs'] as List?;
      if (twoTabs != null && twoTabs.isNotEmpty) {
        final tabContents = twoTabs.first['tabRenderer']?['content']
            ?['sectionListRenderer']?['contents'] as List?;
        if (tabContents != null) sections.addAll(tabContents);
      }
      for (final section in sections) {
        final shelf = section['musicShelfRenderer'] as Map<String, dynamic>?;
        final endpoint = shelf?['bottomEndpoint']?['browseEndpoint']
            as Map<String, dynamic>?;
        if (endpoint != null && endpoint['browseId'] != null) {
          return endpoint;
        }
      }
    } catch (_) {}
    return null;
  }

  static List<YtTrack> _extractAlbumTracks(
      Map<String, dynamic> json, int limit) {
    final results = <YtTrack>[];
    try {
      final albumCover = _extractHeaderThumbnail(json);
      final List sections = [];
      final secContents = json['contents']?['twoColumnBrowseResultsRenderer']
          ?['secondaryContents']?['sectionListRenderer']?['contents'] as List?;
      if (secContents != null) sections.addAll(secContents);

      final singleTabs = json['contents']?['singleColumnBrowseResultsRenderer']
          ?['tabs'] as List?;
      if (singleTabs != null && singleTabs.isNotEmpty) {
        final tabContents = singleTabs.first['tabRenderer']?['content']
            ?['sectionListRenderer']?['contents'] as List?;
        if (tabContents != null) sections.addAll(tabContents);
      }

      final twoTabs = json['contents']?['twoColumnBrowseResultsRenderer']
          ?['tabs'] as List?;
      if (twoTabs != null && twoTabs.isNotEmpty) {
        final tabContents = twoTabs.first['tabRenderer']?['content']
            ?['sectionListRenderer']?['contents'] as List?;
        if (tabContents != null) sections.addAll(tabContents);
      }

      for (final section in sections) {
        final items = (section['musicPlaylistShelfRenderer']?['contents']
                as List?) ??
            (section['musicShelfRenderer']?['contents'] as List?);
        if (items != null && items.isNotEmpty) {
          for (final item in items) {
            if (results.length >= limit) break;
            final renderer = item['musicResponsiveListItemRenderer']
                as Map<String, dynamic>?;
            if (renderer == null) continue;
            final parsed = _parseResponsiveItem(renderer);
            if (parsed != null &&
                !results.any((t) => t.videoId == parsed.videoId)) {
              final track = (parsed.thumbnailUrl.isEmpty &&
                      albumCover != null &&
                      albumCover.isNotEmpty)
                  ? parsed.copyWith(thumbnailUrl: albumCover)
                  : parsed;
              results.add(track);
            }
          }
          if (results.isNotEmpty) break;
        }
      }
    } catch (e) {
      debugPrint('YTM extract album tracks error: $e');
    }
    return results;
  }

  static List<YtTrack> _extractArtistTracks(
      Map<String, dynamic> json, String artistName, int limit) {
    final results = <YtTrack>[];
    final cleanArtist = artistName.trim().toLowerCase();
    try {
      final artistCover = _extractHeaderThumbnail(json);
      final List sections = [];
      final singleTabs = json['contents']?['singleColumnBrowseResultsRenderer']
          ?['tabs'] as List?;
      if (singleTabs != null && singleTabs.isNotEmpty) {
        final tabContents = singleTabs.first['tabRenderer']?['content']
            ?['sectionListRenderer']?['contents'] as List?;
        if (tabContents != null) sections.addAll(tabContents);
      }

      final twoTabs = json['contents']?['twoColumnBrowseResultsRenderer']
          ?['tabs'] as List?;
      if (twoTabs != null && twoTabs.isNotEmpty) {
        final tabContents = twoTabs.first['tabRenderer']?['content']
            ?['sectionListRenderer']?['contents'] as List?;
        if (tabContents != null) sections.addAll(tabContents);
      }

      final secContents = json['contents']?['twoColumnBrowseResultsRenderer']
          ?['secondaryContents']?['sectionListRenderer']?['contents'] as List?;
      if (secContents != null) sections.addAll(secContents);

      for (final section in sections) {
        final shelf = section['musicShelfRenderer'] as Map<String, dynamic>?;
        if (shelf == null) continue;
        final items = shelf['contents'] as List?;
        if (items == null) continue;

        for (final item in items) {
          if (results.length >= limit) break;
          final renderer = item['musicResponsiveListItemRenderer']
              as Map<String, dynamic>?;
          if (renderer == null) continue;
          final parsed = _parseResponsiveItem(renderer);
          if (parsed != null &&
              !results.any((t) => t.videoId == parsed.videoId)) {
            final tArtist = parsed.artist.trim().toLowerCase();
            if (cleanArtist.isEmpty ||
                tArtist.contains(cleanArtist) ||
                cleanArtist.contains(tArtist)) {
              final track = (parsed.thumbnailUrl.isEmpty &&
                      artistCover != null &&
                      artistCover.isNotEmpty)
                  ? parsed.copyWith(thumbnailUrl: artistCover)
                  : parsed;
              results.add(track);
            }
          }
        }
        if (results.isNotEmpty) break;
      }
    } catch (e) {
      debugPrint('YTM extract artist tracks error: $e');
    }
    return results;
  }

  static Future<Map<String, dynamic>?> _fetchBrowseJson(String browseId,
      {String? params}) async {
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
      final cleanBrowseId = browseId.startsWith('VL') ||
              browseId.startsWith('MPREb') ||
              browseId.startsWith('UC') ||
              browseId.startsWith('OLAK5uy') ||
              browseId.startsWith('FEmusic')
          ? browseId
          : 'VL$browseId';
      final payload = <String, dynamic>{
        'context': _context(),
        'browseId': cleanBrowseId,
      };
      if (params != null && params.isNotEmpty) {
        payload['params'] = params;
      }
      req.write(jsonEncode(payload));
      final res = await req.close();
      final body = await res.transform(utf8.decoder).join();
      return jsonDecode(body) as Map<String, dynamic>;
    } catch (e) {
      debugPrint('YTM fetch browse json error: $e');
      return null;
    } finally {
      client.close();
    }
  }

  /// Fetch tracks of a YouTube Music playlist.
  static Future<List<YtTrack>> getPlaylistTracks(String playlistId,
      {int limit = 50}) async {
    final json = await _fetchBrowseJson(playlistId);
    if (json == null) return [];
    return _extractAlbumTracks(json, limit);
  }

  /// Search YouTube Music specifically for an artist and return its UC browseId.
  static Future<String?> findArtistBrowseId(String artistName) async {
    final cleanArtist = artistName.trim();
    if (cleanArtist.isEmpty || cleanArtist == '<unknown>') return null;

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
        'query': cleanArtist,
        'params': 'EgWKAQIgAWoKEAoQAxAEEAkQBQ%3D%3D', // Artists filter
      }));
      final res = await req.close();
      final body = await res.transform(utf8.decoder).join();
      final match =
          RegExp(r'\"browseId\":\s*\"(UC[^\"]+)\"').firstMatch(body);
      if (match != null) {
        return match.group(1);
      }
    } catch (e) {
      debugPrint('findArtistBrowseId error: $e');
    } finally {
      client.close();
    }
    return null;
  }

  /// Fetch songs for an artist from YTM, falling back to search if needed.
  static Future<List<YtTrack>> getArtistTracks(String artistName,
      {String? browseId, int limit = 50}) async {
    final cleanArtist = artistName.trim();
    var effectiveBrowseId = browseId;
    if (effectiveBrowseId == null || effectiveBrowseId.isEmpty) {
      effectiveBrowseId = await findArtistBrowseId(cleanArtist);
    }
    if (effectiveBrowseId != null && effectiveBrowseId.isNotEmpty) {
      final json = await _fetchBrowseJson(effectiveBrowseId);
      if (json != null) {
        final bottomEndpoint = _findBottomEndpoint(json);
        if (bottomEndpoint != null) {
          final moreBrowseId = bottomEndpoint['browseId'] as String? ?? '';
          final moreParams = bottomEndpoint['params'] as String?;
          if (moreBrowseId.isNotEmpty) {
            final moreJson =
                await _fetchBrowseJson(moreBrowseId, params: moreParams);
            if (moreJson != null) {
              final moreTracks = _extractAlbumTracks(moreJson, limit);
              if (moreTracks.isNotEmpty) return moreTracks;
            }
          }
        }

        final tracks = _extractArtistTracks(json, cleanArtist, limit);
        if (tracks.isNotEmpty) return tracks;
      }
    }
    try {
      final searchResults = await search(cleanArtist, limit: limit);
      final cleanLower = cleanArtist.toLowerCase();
      final filtered = searchResults.where((t) {
        final a = t.artist.trim().toLowerCase();
        return cleanLower.isEmpty ||
            a.contains(cleanLower) ||
            cleanLower.contains(a);
      }).toList();
      return filtered.isNotEmpty ? filtered : searchResults;
    } catch (e) {
      debugPrint('YTM getArtistTracks search fallback error: $e');
      return [];
    }
  }

  /// Search YouTube Music specifically for an album and return its MPREb browseId.
  static Future<String?> findAlbumBrowseId(String albumName,
      {String? artistName}) async {
    final cleanAlbum = albumName
        .replaceAll(RegExp(r'\s*-\s*Single$', caseSensitive: false), '')
        .trim();
    if (cleanAlbum.isEmpty) return null;
    final cleanArtist = (artistName != null &&
            artistName.isNotEmpty &&
            artistName != '<unknown>' &&
            artistName != 'Unknown Artist')
        ? artistName.trim()
        : '';
    final query =
        cleanArtist.isNotEmpty ? '$cleanAlbum $cleanArtist' : cleanAlbum;

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
        'query': query,
        'params': 'EgWKAQIBAWoKEAoQAxAEEAkQBQ%3D%3D', // Albums filter
      }));
      final res = await req.close();
      final body = await res.transform(utf8.decoder).join();
      final match =
          RegExp(r'\"browseId\":\s*\"(MPREb[^\"]+)\"').firstMatch(body);
      if (match != null) {
        return match.group(1);
      }
    } catch (e) {
      debugPrint('findAlbumBrowseId error: $e');
    } finally {
      client.close();
    }
    return null;
  }

  /// Fetch songs for an album from YTM, falling back to search if needed.
  static Future<List<YtTrack>> getAlbumTracks(String albumName,
      {String? artistName, String? browseId, int limit = 50}) async {
    var effectiveBrowseId = browseId;
    if (effectiveBrowseId == null || effectiveBrowseId.isEmpty) {
      effectiveBrowseId =
          await findAlbumBrowseId(albumName, artistName: artistName);
    }

    if (effectiveBrowseId != null && effectiveBrowseId.isNotEmpty) {
      final json = await _fetchBrowseJson(effectiveBrowseId);
      if (json != null) {
        final tracks = _extractAlbumTracks(json, limit);
        if (tracks.isNotEmpty) return tracks;
      }
    }
    final cleanArtist = (artistName != null &&
            artistName.isNotEmpty &&
            artistName != '<unknown>' &&
            artistName != 'Unknown Artist')
        ? artistName.trim()
        : '';
    final cleanAlbumQuery = albumName
        .replaceAll(RegExp(r'\s*-\s*Single$', caseSensitive: false), '')
        .trim();
    final query = cleanArtist.isNotEmpty
        ? '$cleanAlbumQuery $cleanArtist'
        : cleanAlbumQuery;
    try {
      final searchResults = await search(query, limit: limit);
      final cleanAlbumLower = albumName.trim().toLowerCase();
      final cleanArtistLower = cleanArtist.toLowerCase();
      final filtered = searchResults.where((t) {
        final a = t.artist.trim().toLowerCase();
        final alb = t.album.trim().toLowerCase();
        final matchArtist = cleanArtistLower.isEmpty ||
            a.contains(cleanArtistLower) ||
            cleanArtistLower.contains(a);
        final matchAlbum = cleanAlbumLower.isEmpty ||
            alb.contains(cleanAlbumLower) ||
            cleanAlbumLower.contains(alb);
        return matchArtist || matchAlbum;
      }).toList();
      return filtered.isNotEmpty ? filtered : searchResults;
    } catch (e) {
      debugPrint('YTM getAlbumTracks search fallback error: $e');
      return [];
    }
  }

  /// Resolve audio stream URL for [videoId].
  /// Tries InnerTube first, then Invidious/Piped public instances as fallback.
  static Future<String> getStreamUrl(String videoId) async {
    final cookie = await _getCookie();

    // 1. Try InnerTube if cookie available
    if (cookie.isNotEmpty) {
      final clients = [
        _androidMusicPayload(videoId),
        _tvEmbeddedPayload(videoId),
        _iosPayload(videoId),
      ];

      final client = HttpClient();
      client.connectionTimeout = const Duration(seconds: 5);
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
          const origin = 'https://www.youtube.com';
          final sapisidHash = _buildSapisidHash(cookie, origin);
          if (sapisidHash != null) req.headers.set('Authorization', sapisidHash);
          req.headers.set('X-Goog-AuthUser', '0');
          (payload['_headers'] as Map<String, String>?)
              ?.forEach((k, v) => req.headers.set(k, v));

          final body = Map<String, dynamic>.from(payload)
            ..remove('_ua')
            ..remove('_headers');
          req.write(jsonEncode(body));

          final res = await req.close();
          final responseBody = await res.transform(utf8.decoder).join();
          final json = jsonDecode(responseBody) as Map<String, dynamic>;

          final status = json['playabilityStatus']?['status'] as String? ?? '';
          if (status == 'UNPLAYABLE' || status == 'LOGIN_REQUIRED') continue;

          final allFormats = <dynamic>[
            ...json['streamingData']?['adaptiveFormats'] as List? ?? [],
            ...json['streamingData']?['formats'] as List? ?? [],
          ];
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

          final url = best?['url'] as String?;
          if (url != null && url.isNotEmpty) return url;
        }
      } catch (e) {
        debugPrint('InnerTube stream URL error: $e');
      } finally {
        client.close();
      }
    }

    // 2. High-reliability fallback: Invidious public instances
    final invidiousHosts = [
      'yt.chocolatemoo53.com',
      'inv.nadeko.net',
      'invidious.nerdvpn.de',
      'yt.artemislena.eu',
      'invidious.projectsegfau.lt',
    ];

    final client = HttpClient();
    client.connectionTimeout = const Duration(seconds: 6);
    try {
      for (final host in invidiousHosts) {
        try {
          final uri = Uri.https(host, '/api/v1/videos/$videoId');
          final req = await client.getUrl(uri);
          final res = await req.close();
          if (res.statusCode == 200) {
            final str = await res.transform(utf8.decoder).join();
            final json = jsonDecode(str) as Map<String, dynamic>;
            final adaptive = json['adaptiveFormats'] as List? ?? [];
            Map<String, dynamic>? best;
            int bestBitrate = 0;
            for (final f in adaptive) {
              final type = f['type'] as String? ?? '';
              final url = f['url'] as String?;
              if (url == null || url.isEmpty) continue;
              final bitrate = int.tryParse(f['bitrate']?.toString() ?? '0') ?? 0;
              if (type.startsWith('audio/') && bitrate > bestBitrate) {
                bestBitrate = bitrate;
                best = f as Map<String, dynamic>;
              }
            }
            final url = best?['url'] as String?;
            if (url != null && url.isNotEmpty) return url;
          }
        } catch (_) {}
      }

      // 3. Fallback: Piped instances
      final pipedHosts = [
        'api.piped.privacy.com.de',
        'pipedapi.kavin.rocks',
        'pipedapi.drgns.space',
      ];
      for (final host in pipedHosts) {
        try {
          final uri = Uri.https(host, '/streams/$videoId');
          final req = await client.getUrl(uri);
          final res = await req.close();
          if (res.statusCode == 200) {
            final str = await res.transform(utf8.decoder).join();
            final json = jsonDecode(str) as Map<String, dynamic>;
            final audioStreams = json['audioStreams'] as List? ?? [];
            if (audioStreams.isNotEmpty) {
              final url = audioStreams.first['url'] as String?;
              if (url != null && url.isNotEmpty) return url;
            }
          }
        } catch (_) {}
      }
    } finally {
      client.close();
    }

    throw Exception('No audio stream found from any client');
  }

  /// Fetch lyrics for [videoId] from YouTube Music InnerTube.
  /// Returns a map with 'plainLyrics' (string).
  static Future<Map<String, dynamic>?> getLyrics(String videoId) async {
    final cookie = await _getCookie();
    final client = HttpClient();
    client.connectionTimeout = const Duration(seconds: 6);

    try {
      // 1. Next endpoint to find lyrics browseId
      final nextUri = Uri.https(
        _baseUrl,
        '/youtubei/v1/next',
        {'key': _apiKey, 'prettyPrint': 'false'},
      );
      final nextReq = await client.postUrl(nextUri);
      final headers = _headers(cookie);
      headers.forEach((k, v) => nextReq.headers.set(k, v));
      final nextBody = {
        'context': _context(),
        'videoId': videoId,
      };
      nextReq.write(jsonEncode(nextBody));
      final nextRes = await nextReq.close();
      if (nextRes.statusCode != 200) return null;
      final nextResBody = await nextRes.transform(utf8.decoder).join();
      final nextJson = jsonDecode(nextResBody) as Map<String, dynamic>;

      final tabs = nextJson['contents']
          ?['singleColumnMusicWatchNextResultsRenderer']
          ?['tabbedRenderer']
          ?['watchNextTabbedResultsRenderer']
          ?['tabs'] as List?;
      if (tabs == null || tabs.isEmpty) return null;

      String? lyricsBrowseId;
      for (final tab in tabs) {
        final tabRenderer = tab['tabRenderer'] as Map<String, dynamic>?;
        final endpoint = tabRenderer?['endpoint']?['browseEndpoint']
            as Map<String, dynamic>?;
        final browseId = endpoint?['browseId'] as String? ?? '';
        final title = (tabRenderer?['title'] as String? ?? '').toLowerCase();
        if (browseId.startsWith('MPLYt') ||
            title.contains('lirik') ||
            title.contains('lyrics')) {
          lyricsBrowseId = browseId;
          break;
        }
      }

      if (lyricsBrowseId == null || lyricsBrowseId.isEmpty) return null;

      // 2. Browse endpoint using lyricsBrowseId
      final browseUri = Uri.https(
        _baseUrl,
        '/youtubei/v1/browse',
        {'key': _apiKey, 'prettyPrint': 'false'},
      );
      final browseReq = await client.postUrl(browseUri);
      headers.forEach((k, v) => browseReq.headers.set(k, v));
      final browseBody = {
        'context': _context(),
        'browseId': lyricsBrowseId,
      };
      browseReq.write(jsonEncode(browseBody));
      final browseRes = await browseReq.close();
      if (browseRes.statusCode != 200) return null;
      final browseResBody = await browseRes.transform(utf8.decoder).join();
      final browseJson = jsonDecode(browseResBody) as Map<String, dynamic>;

      final contents = browseJson['contents']
          ?['sectionListRenderer']
          ?['contents'] as List?;
      if (contents == null || contents.isEmpty) return null;

      for (final item in contents) {
        final shelf = item['musicDescriptionShelfRenderer']
            as Map<String, dynamic>?;
        if (shelf != null) {
          final runs = shelf['description']?['runs'] as List?;
          if (runs != null && runs.isNotEmpty) {
            final plainText = runs.map((r) => r['text'] ?? '').join('');
            final footerRuns = shelf['footer']?['runs'] as List?;
            final source = footerRuns != null && footerRuns.isNotEmpty
                ? '\n\n${footerRuns.map((r) => r['text'] ?? '').join('')}'
                : '';
            return {
              'plainLyrics': '$plainText$source',
            };
          }
        }
      }

      return null;
    } catch (e) {
      debugPrint('YTM getLyrics error: $e');
      return null;
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