import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:webview_flutter/webview_flutter.dart';
import 'package:webview_flutter_android/webview_flutter_android.dart';

class _WebViewDownloadContext {
  final File file;
  final IOSink sink;
  final void Function(int received, int total) onProgress;
  final Completer<bool> completer;

  _WebViewDownloadContext({
    required this.file,
    required this.sink,
    required this.onProgress,
    required this.completer,
  });
}

/// Background/hidden WebView-based player for YouTube Music.
/// Plays directly inside Chromium engine using the user's authenticated Google session.
class YtPlayerService {
  static const String userAgent =
      'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 '
      '(KHTML, like Gecko) Chrome/120.0.0.0 Safari/537.36';

  static final YtPlayerService instance = YtPlayerService._();
  YtPlayerService._();

  final Map<String, _WebViewDownloadContext> _activeWebViewDownloads = {};

  WebViewController? _controller;
  WebViewController get controller {
    _controller ??= _initController();
    return _controller!;
  }

  final StreamController<Duration> _positionStreamController =
      StreamController<Duration>.broadcast();
  Stream<Duration> get positionStream => _positionStreamController.stream;

  Duration currentPosition = Duration.zero;
  Duration currentDuration = Duration.zero;
  bool isPlaying = false;
  bool isBuffering = false;
  bool _isPageLoaded = false;
  bool _isLooping = false;
  bool get isLooping => _isLooping;
  String? currentVideoId;
  Timer? _bufferingSafetyTimer;
  DateTime? _lastEndedTime;

  VoidCallback? onStateChange;
  VoidCallback? onSongEnded;

  static const String _visibilitySpoofScript = '''
try {
  window._fleyShouldPlay = true;
  Object.defineProperties(document, {
    hidden: { get: () => false, configurable: true },
    visibilityState: { get: () => 'visible', configurable: true },
    webkitHidden: { get: () => false, configurable: true },
    webkitVisibilityState: { get: () => 'visible', configurable: true }
  });
  ['visibilitychange', 'webkitvisibilitychange', 'blur'].forEach(function(evt) {
    window.addEventListener(evt, function(e) {
      e.stopImmediatePropagation();
    }, true);
  });
  document.hasFocus = function() { return true; };
} catch(e) {}
''';

  static const String _hookScript = '''
(function() {
  window._fleyShouldPlay = true;
  window._fleySuppressEndedUntil = Date.now() + 5000;

  // 1. Spoof Page Visibility API (prevents YouTube background auto-pause after 30-40s)
  try {
    Object.defineProperties(document, {
      hidden: { get: () => false, configurable: true },
      visibilityState: { get: () => 'visible', configurable: true },
      webkitHidden: { get: () => false, configurable: true },
      webkitVisibilityState: { get: () => 'visible', configurable: true }
    });
    ['visibilitychange', 'webkitvisibilitychange', 'blur'].forEach(function(evt) {
      window.addEventListener(evt, function(e) {
        e.stopImmediatePropagation();
      }, true);
    });
    document.hasFocus = function() { return true; };
  } catch(e) {}

  // 2. Intercept API responses to remove ads at network level
  if (!window._fleyApiPatched) {
    window._fleyApiPatched = true;

    var origFetch = window.fetch;
    window.fetch = async function() {
      var response = await origFetch.apply(this, arguments);
      var url = arguments[0];
      var urlStr = (typeof url === 'string') ? url : (url && url.url ? url.url : '');
      if (urlStr.indexOf('/youtubei/v1/player') !== -1) {
        try {
          var text = await response.text();
          var sanitized = text
            .replace(/"adPlacements"/g, '"fleyNoAds"')
            .replace(/"adSlots"/g, '"fleyNoSlots"')
            .replace(/"playerAds"/g, '"fleyNoPlayerAds"');
          return new Response(sanitized, {
            status: response.status,
            statusText: response.statusText,
            headers: response.headers
          });
        } catch(e) {
          return response;
        }
      }
      return response;
    };

    var origOpen = XMLHttpRequest.prototype.open;
    var origSend = XMLHttpRequest.prototype.send;
    XMLHttpRequest.prototype.open = function(method, url) {
      this._url = url ? url.toString() : '';
      return origOpen.apply(this, arguments);
    };
    XMLHttpRequest.prototype.send = function() {
      var self = this;
      if (self._url && self._url.indexOf('/youtubei/v1/player') !== -1) {
        self.addEventListener('readystatechange', function() {
          if (self.readyState === 4 && self.responseText) {
            try {
              var sanitized = self.responseText
                .replace(/"adPlacements"/g, '"fleyNoAds"')
                .replace(/"adSlots"/g, '"fleyNoSlots"')
                .replace(/"playerAds"/g, '"fleyNoPlayerAds"');
              Object.defineProperty(self, 'responseText', { value: sanitized, configurable: true });
              Object.defineProperty(self, 'response', { value: sanitized, configurable: true });
            } catch(e) {}
          }
        });
      }
      return origSend.apply(this, arguments);
    };

    try {
      if (window.ytInitialPlayerResponse) {
        var str = JSON.stringify(window.ytInitialPlayerResponse)
          .replace(/"adPlacements"/g, '"fleyNoAds"')
          .replace(/"adSlots"/g, '"fleyNoSlots"')
          .replace(/"playerAds"/g, '"fleyNoPlayerAds"');
        window.ytInitialPlayerResponse = JSON.parse(str);
      }
    } catch(e) {}
  }

  function isAd() {
    var player = document.getElementById('movie_player');
    if (player && (player.classList.contains('ad-showing') || player.classList.contains('ad-interrupting'))) {
      return true;
    }
    if (document.querySelector('.ad-showing') || 
        document.querySelector('.ad-interrupting') || 
        document.querySelector('.ytp-ad-player-overlay') ||
        document.querySelector('.ytp-ad-skip-button') ||
        document.querySelector('.ytp-ad-skip-button-modern') ||
        document.querySelector('.videoAdUi')) {
      return true;
    }
    var v = document.querySelector('video');
    if (v && v.src && (v.src.indexOf('adformat=') !== -1 || v.src.indexOf('/pagead/') !== -1)) {
      return true;
    }
    return false;
  }

  // 3. Fast-forward & click skip if an ad slips through + auto-dismiss prompts + keep-alive
  setInterval(function() {
    var v = document.querySelector('video');
    if (isAd() && v) {
      window._fleySuppressEndedUntil = Date.now() + 4000;
      v.muted = true;
      v.playbackRate = 16.0;
      if (v.duration && !isNaN(v.duration) && isFinite(v.duration)) {
        v.currentTime = v.duration;
      }
    } else if (v && v.playbackRate > 1.0) {
      v.playbackRate = 1.0;
      v.muted = false;
    }

    var skip = document.querySelector(
      '.ytp-ad-skip-button, .ytp-ad-skip-button-modern, .ytp-skip-ad-button, .videoAdUiSkipButton, [class*="skip-button"], button.ytp-ad-skip-button-text'
    );
    if (skip) skip.click();

    var confirmBtn = document.querySelector('ytmusic-you-there-renderer yt-button-renderer') ||
                     document.querySelector('yt-confirm-dialog-renderer #confirm-button') ||
                     document.querySelector('#dismiss-button') ||
                     document.querySelector('.ytp-ad-overlay-close-button');
    if (confirmBtn) confirmBtn.click();

    // Auto keep-alive: if video paused unexpectedly while it should be playing
    if (v && v.paused && window._fleyShouldPlay && !isAd()) {
      v.play().catch(function(e){});
    }
  }, 200);

  // 4. Hook video events
  var checkCount = 0;
  function hook() {
    var v = document.querySelector('video');
    if (!v) {
      if (checkCount++ < 120) setTimeout(hook, 250);
      return;
    }

    if (window._fleyShouldPlay) {
      v.play().catch(function(e) {});
    }
    if (window._fleyLoop) {
      v.loop = true;
    }

    var player = document.getElementById('movie_player');
    if (player) {
      try {
        if (typeof player.setAutonav === 'function') player.setAutonav(false);
      } catch(e){}
    }
    if (player && typeof player.addEventListener === 'function' && !player._fleyHooked) {
      player._fleyHooked = true;
      player.addEventListener('onStateChange', function(st) {
        if (isAd()) return;
        if (st === 1) {
          try {
            FleyBridge.postMessage(JSON.stringify({type: 'play'}));
            FleyBridge.postMessage(JSON.stringify({type: 'buffering', val: false}));
          } catch(e){}
        } else if (st === 2) {
          try {
            FleyBridge.postMessage(JSON.stringify({type: 'pause'}));
            FleyBridge.postMessage(JSON.stringify({type: 'buffering', val: false}));
          } catch(e){}
        } else if (st === 3) {
          try {
            FleyBridge.postMessage(JSON.stringify({type: 'buffering', val: true}));
          } catch(e){}
        } else if (st === 0) {
          if (isAd()) return;
          var now = Date.now();
          if (window._fleySuppressEndedUntil && now < window._fleySuppressEndedUntil) {
            return;
          }
          window._fleySuppressEndedUntil = now + 4000;
          try { FleyBridge.postMessage(JSON.stringify({type: 'ended'})); } catch(e){}
        }
      });
    }

    function reportDuration() {
      if (isAd()) return;
      try {
        if (v.duration && !isNaN(v.duration) && v.duration > 0) {
          FleyBridge.postMessage(JSON.stringify({
            type: 'time',
            pos: v.currentTime || 0,
            dur: v.duration
          }));
        }
      } catch(e){}
    }
    v.addEventListener('durationchange', reportDuration, true);
    v.addEventListener('loadedmetadata', reportDuration, true);
    v.addEventListener('canplay', reportDuration, true);

    v.addEventListener('play', function() {
      if (isAd()) return;
      try {
        if (v.volume !== 1.0) v.volume = 1.0;
        if (v.muted) v.muted = false;
        FleyBridge.postMessage(JSON.stringify({type: 'play'}));
        FleyBridge.postMessage(JSON.stringify({type: 'buffering', val: false}));
      } catch(e){}
    }, true);

    v.addEventListener('playing', function() {
      if (isAd()) return;
      try {
        if (v.volume !== 1.0) v.volume = 1.0;
        if (v.muted) v.muted = false;
        FleyBridge.postMessage(JSON.stringify({type: 'buffering', val: false}));
      } catch(e){}
    }, true);

    v.addEventListener('waiting', function() {
      if (isAd()) return;
      try { FleyBridge.postMessage(JSON.stringify({type: 'buffering', val: true})); } catch(e){}
    }, true);

    v.addEventListener('pause', function() {
      if (isAd()) return;
      if (!window._fleyShouldPlay) {
        try { FleyBridge.postMessage(JSON.stringify({type: 'pause'})); } catch(e){}
      }
    }, true);

    v.addEventListener('ended', function() {
      if (isAd()) return;
      var now = Date.now();
      if (window._fleySuppressEndedUntil && now < window._fleySuppressEndedUntil) {
        return;
      }
      if (v.duration && v.currentTime && (v.duration - v.currentTime < 1.5)) {
        window._fleySuppressEndedUntil = now + 4000;
        try { FleyBridge.postMessage(JSON.stringify({type: 'ended'})); } catch(e){}
      }
    }, true);

    v.addEventListener('timeupdate', function() {
      if (isAd()) return;
      try {
        FleyBridge.postMessage(JSON.stringify({
          type: 'time',
          pos: v.currentTime,
          dur: v.duration
        }));
      } catch(e){}
    }, true);
  }
  hook();
})();
''';

  WebViewController _initController() {
    final c = WebViewController();
    c.setJavaScriptMode(JavaScriptMode.unrestricted);
    c.setUserAgent(
      'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0.0.0 Safari/537.36',
    );

    if (Platform.isAndroid) {
      try {
        final androidController = c.platform as AndroidWebViewController;
        androidController.setMediaPlaybackRequiresUserGesture(false);
      } catch (e) {
        debugPrint('YtPlayerService AndroidWebViewController config error: $e');
      }
    }

    c.addJavaScriptChannel(
      'FleyBridge',
      onMessageReceived: (JavaScriptMessage msg) {
        try {
          final data = jsonDecode(msg.message) as Map<String, dynamic>;
          final type = data['type'] as String?;
          if (type == 'play') {
            isPlaying = true;
            isBuffering = false;
            _bufferingSafetyTimer?.cancel();
            onStateChange?.call();
          } else if (type == 'buffering') {
            final val = data['val'] == true;
            if (val) {
              isBuffering = true;
              _bufferingSafetyTimer?.cancel();
              _bufferingSafetyTimer =
                  Timer(const Duration(milliseconds: 1000), () {
                if (isBuffering) {
                  isBuffering = false;
                  onStateChange?.call();
                }
              });
            } else {
              isBuffering = false;
              _bufferingSafetyTimer?.cancel();
            }
            onStateChange?.call();
          } else if (type == 'pause') {
            isPlaying = false;
            isBuffering = false;
            _bufferingSafetyTimer?.cancel();
            onStateChange?.call();
          } else if (type == 'ended') {
            final now = DateTime.now();
            if (_lastEndedTime != null &&
                now.difference(_lastEndedTime!).inMilliseconds < 4000) {
              return;
            }
            if (currentPosition < const Duration(seconds: 3)) {
              return;
            }
            _lastEndedTime = now;
            isPlaying = false;
            isBuffering = false;
            _bufferingSafetyTimer?.cancel();
            onStateChange?.call();
            onSongEnded?.call();
          } else if (type == 'time') {
            final posSec = (data['pos'] as num?)?.toDouble() ?? 0.0;
            final durSec = (data['dur'] as num?)?.toDouble() ?? 0.0;
            currentPosition = Duration(milliseconds: (posSec * 1000).toInt());
            final wasZero = currentDuration == Duration.zero;
            if (durSec > 0) {
              currentDuration = Duration(milliseconds: (durSec * 1000).toInt());
              if (wasZero) {
                onStateChange?.call();
              }
            }
            if (isBuffering) {
              isBuffering = false;
              _bufferingSafetyTimer?.cancel();
              onStateChange?.call();
            }
            _positionStreamController.add(currentPosition);
          } else if (type == 'dl_chunk') {
            final id = data['id'] as String?;
            final b64 = data['data'] as String? ?? '';
            final received = data['received'] as int? ?? 0;
            final total = data['total'] as int? ?? 0;
            final ctx = _activeWebViewDownloads[id];
            if (ctx != null && b64.isNotEmpty) {
              final bytes = base64Decode(b64);
              ctx.sink.add(bytes);
              ctx.onProgress(received, total);
            }
          } else if (type == 'dl_done') {
            final id = data['id'] as String?;
            final ctx = _activeWebViewDownloads.remove(id);
            if (ctx != null) {
              ctx.sink.flush().then((_) => ctx.sink.close()).then((_) {
                if (!ctx.completer.isCompleted) {
                  ctx.completer.complete(true);
                }
              });
            }
          } else if (type == 'dl_error') {
            final id = data['id'] as String?;
            final ctx = _activeWebViewDownloads.remove(id);
            if (ctx != null) {
              ctx.sink.close();
              if (!ctx.completer.isCompleted) {
                ctx.completer.complete(false);
              }
            }
          }
        } catch (_) {}
      },
    );

    c.setNavigationDelegate(NavigationDelegate(
      onPageStarted: (url) {
        _isPageLoaded = false;
        c.runJavaScript(_visibilitySpoofScript).catchError((_) {});
      },
      onPageFinished: (url) {
        _isPageLoaded = true;
        c.runJavaScript(_hookScript);
      },
    ));

    return c;
  }

  Future<void> loadAndPlay(String videoId, {Duration? initialPosition}) async {
    _lastEndedTime = DateTime.now();
    currentVideoId = videoId;
    final int startSec = initialPosition != null && initialPosition > Duration.zero
        ? initialPosition.inSeconds
        : 0;
    currentPosition = initialPosition ?? Duration.zero;
    currentDuration = Duration.zero;
    isPlaying = true;
    isBuffering = true;
    _bufferingSafetyTimer?.cancel();
    _bufferingSafetyTimer = Timer(const Duration(milliseconds: 1200), () {
      if (isBuffering) {
        isBuffering = false;
        onStateChange?.call();
      }
    });
    onStateChange?.call();

    if (_isPageLoaded) {
      try {
        final result = await controller.runJavaScriptReturningResult('''
(function() {
  window._fleyShouldPlay = true;
  window._fleySuppressEndedUntil = Date.now() + 4000;
  var p = document.getElementById('movie_player');
  if (p) {
    try { if (typeof p.setAutonav === 'function') p.setAutonav(false); } catch(e){}
    if (typeof p.loadVideoById === 'function') {
      p.loadVideoById({videoId: '$videoId', startSeconds: $startSec});
      try {
        if (typeof p.unMute === 'function') p.unMute();
        if (typeof p.setVolume === 'function') p.setVolume(100);
      } catch(e){}
      var vid = document.querySelector('video');
      if (vid) {
        try {
          vid.muted = false;
          if (vid.volume !== 1.0) vid.volume = 1.0;
        } catch(e){}
      }
      return 'ok';
    }
  }
  return 'fallback';
})();
''');
        final str = result.toString().replaceAll('"', '').trim();
        if (str == 'ok') {
          return;
        }
      } catch (e) {
        debugPrint('YtPlayerService SPA switch fallback: $e');
      }
    }

    _isPageLoaded = false;
    final url = startSec > 0
        ? 'https://music.youtube.com/watch?v=$videoId&t=${startSec}s'
        : 'https://music.youtube.com/watch?v=$videoId';
    controller.loadRequest(Uri.parse(url));
  }

  void setLoop(bool loop) {
    _isLooping = loop;
    controller.runJavaScript('''
window._fleyLoop = $loop;
try {
  var v = document.querySelector('video');
  if (v) v.loop = $loop;
  var p = document.getElementById('movie_player');
  if (p && typeof p.setLoop === 'function') p.setLoop($loop);
} catch(e){}
''').catchError((_) {});
  }

  void stop() {
    isPlaying = false;
    isBuffering = false;
    currentVideoId = null;
    currentPosition = Duration.zero;
    currentDuration = Duration.zero;
    _bufferingSafetyTimer?.cancel();
    controller.runJavaScript('''
window._fleyShouldPlay = false;
window._fleyLoop = false;
try {
  var p = document.getElementById('movie_player');
  if (p && typeof p.pauseVideo === 'function') {
    p.pauseVideo();
  } else if (p && typeof p.stopVideo === 'function') {
    p.stopVideo();
  }
  var v = document.querySelector('video');
  if (v) {
    v.pause();
  }
} catch(e){}
''').catchError((_) {});
  }

  String? _lastPreloadedVideoId;

  /// Preloads and pre-buffers next YouTube Music track in the background for gapless playback.
  void preloadNext(String videoId) {
    if (videoId.isEmpty || _lastPreloadedVideoId == videoId) return;
    _lastPreloadedVideoId = videoId;
    final js = '''
(function() {
  try {
    var key = (window.ytcfg && window.ytcfg.get) ? window.ytcfg.get('INNERTUBE_API_KEY') : 'AIzaSyC9XL3ZjWddXya6X74dJoCTL-KOEVSHRUA';
    var ctx = (window.ytcfg && window.ytcfg.get) ? window.ytcfg.get('INNERTUBE_CONTEXT') : {
      client: { clientName: 'WEB_REMIX', clientVersion: '1.20231101.01.00', hl: 'en', gl: 'US' }
    };
    fetch('/youtubei/v1/player?key=' + key, {
      method: 'POST',
      headers: { 'Content-Type': 'application/json' },
      body: JSON.stringify({ context: ctx, videoId: '$videoId' })
    }).then(function(r) { return r.json(); }).then(function(j) {
      var fmts = (j.streamingData && j.streamingData.adaptiveFormats) || [];
      for (var i = 0; i < fmts.length; i++) {
        var f = fmts[i];
        if (f.mimeType && f.mimeType.indexOf('audio/') === 0 && f.url) {
          fetch(f.url, { headers: { 'Range': 'bytes=0-262143' }, mode: 'no-cors' }).catch(function(){});
          break;
        }
      }
    }).catch(function(){});
  } catch(e){}
})();
''';
    controller.runJavaScript(js).catchError((_) {});
  }

  void play() {
    isPlaying = true;
    controller.runJavaScript('''
window._fleyShouldPlay = true;
try {
  var p = document.getElementById('movie_player');
  if (p && typeof p.playVideo === 'function') {
    p.playVideo();
  } else {
    document.querySelector('video')?.play();
  }
} catch(e){}
''');
  }

  void pause() {
    isPlaying = false;
    controller.runJavaScript('''
window._fleyShouldPlay = false;
try {
  var p = document.getElementById('movie_player');
  if (p && typeof p.pauseVideo === 'function') {
    p.pauseVideo();
  } else {
    document.querySelector('video')?.pause();
  }
} catch(e){}
''');
  }

  void seekTo(Duration position) {
    currentPosition = position;
    _positionStreamController.add(position);
    final sec = position.inMilliseconds / 1000.0;
    controller.runJavaScript('''
try {
  var p = document.getElementById('movie_player');
  if (p && typeof p.seekTo === 'function') {
    p.seekTo($sec, true);
  } else {
    var v = document.querySelector('video');
    if (v) v.currentTime = $sec;
  }
} catch(e){}
''');
  }

  /// Resolves direct stream URL using the authenticated in-app Chromium WebView.
  Future<String?> resolveStreamUrl(String videoId) async {
    try {
      final js = '''
(async function() {
  try {
    var key = (window.ytcfg && window.ytcfg.get) ? window.ytcfg.get('INNERTUBE_API_KEY') : 'AIzaSyC9XL3ZjWddXya6X74dJoCTL-KOEVSHRUA';
    var ctx = (window.ytcfg && window.ytcfg.get) ? window.ytcfg.get('INNERTUBE_CONTEXT') : {
      client: { clientName: 'WEB_REMIX', clientVersion: '1.20231101.01.00', hl: 'id', gl: 'ID' }
    };
    var r = await fetch('/youtubei/v1/player?key=' + key, {
      method: 'POST',
      headers: { 'Content-Type': 'application/json' },
      body: JSON.stringify({ context: ctx, videoId: '$videoId' })
    });
    var j = await r.json();
    var fmts = (j.streamingData && j.streamingData.adaptiveFormats) || [];
    var best = null;
    var bestBr = 0;
    for (var i = 0; i < fmts.length; i++) {
      var f = fmts[i];
      if (f.mimeType && f.mimeType.indexOf('audio/') === 0 && f.url) {
        if (f.bitrate > bestBr) {
          bestBr = f.bitrate;
          best = f.url;
        }
      }
    }
    return best || '';
  } catch(e) {
    return '';
  }
})()
''';
      final res = await controller.runJavaScriptReturningResult(js);
      var url = res.toString();
      if (url.startsWith('"') && url.endsWith('"')) {
        url = url.substring(1, url.length - 1);
      }
      return url.isNotEmpty && url != 'null' ? url : null;
    } catch (_) {
      return null;
    }
  }

  /// Downloads audio stream chunk-by-chunk inside the Chromium WebView session.
  /// Bypasses IP restriction / HTTP 403 on client because fetch runs inside the browser.
  Future<bool> downloadViaWebView(
    String videoId,
    String taskId,
    File destination, {
    required void Function(int received, int total) onProgress,
  }) async {
    final sink = destination.openWrite();
    final completer = Completer<bool>();
    _activeWebViewDownloads[taskId] = _WebViewDownloadContext(
      file: destination,
      sink: sink,
      onProgress: onProgress,
      completer: completer,
    );

    // Timeout safety (3 minutes max)
    Timer(const Duration(minutes: 3), () {
      if (!completer.isCompleted) {
        final ctx = _activeWebViewDownloads.remove(taskId);
        ctx?.sink.close();
        completer.complete(false);
      }
    });

    final js = '''
(async function() {
  try {
    var key = (window.ytcfg && window.ytcfg.get) ? window.ytcfg.get('INNERTUBE_API_KEY') : 'AIzaSyC9XL3ZjWddXya6X74dJoCTL-KOEVSHRUA';
    var ctx = (window.ytcfg && window.ytcfg.get) ? window.ytcfg.get('INNERTUBE_CONTEXT') : {
      client: { clientName: 'WEB_REMIX', clientVersion: '1.20231101.01.00', hl: 'id', gl: 'ID' }
    };
    var r = await fetch('/youtubei/v1/player?key=' + key, {
      method: 'POST',
      headers: { 'Content-Type': 'application/json' },
      body: JSON.stringify({ context: ctx, videoId: '$videoId' })
    });
    var j = await r.json();
    var fmts = (j.streamingData && j.streamingData.adaptiveFormats) || [];
    var url = '';
    var bestBr = 0;
    for (var i = 0; i < fmts.length; i++) {
      var f = fmts[i];
      if (f.mimeType && f.mimeType.indexOf('audio/') === 0 && f.url) {
        if (f.bitrate > bestBr) {
          bestBr = f.bitrate;
          url = f.url;
        }
      }
    }
    if (!url) throw new Error('No stream URL');
    var audioRes = await fetch(url);
    if (!audioRes.ok) throw new Error('HTTP ' + audioRes.status);
    var reader = audioRes.body.getReader();
    var total = parseInt(audioRes.headers.get('content-length') || '0', 10);
    var received = 0;
    while(true) {
      var chunk = await reader.read();
      if (chunk.done) break;
      var val = chunk.value;
      received += val.length;
      var bin = '';
      for (var k = 0; k < val.length; k++) {
        bin += String.fromCharCode(val[k]);
      }
      FleyBridge.postMessage(JSON.stringify({
        type: 'dl_chunk',
        id: '$taskId',
        data: btoa(bin),
        received: received,
        total: total
      }));
    }
    FleyBridge.postMessage(JSON.stringify({
      type: 'dl_done',
      id: '$taskId'
    }));
  } catch(e) {
    FleyBridge.postMessage(JSON.stringify({
      type: 'dl_error',
      id: '$taskId',
      error: e.toString()
    }));
  }
})()
''';
    try {
      await controller.runJavaScript(js);
    } catch (e) {
      final ctx = _activeWebViewDownloads.remove(taskId);
      ctx?.sink.close();
      return false;
    }

    return completer.future;
  }

  Widget? _cachedWidget;

  Widget buildWidget() {
    return _cachedWidget ??= RepaintBoundary(
      child: SizedBox(
        width: 1,
        height: 1,
        child: WebViewWidget(controller: controller),
      ),
    );
  }
}
