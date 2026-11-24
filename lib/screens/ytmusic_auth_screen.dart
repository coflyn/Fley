import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:fley/l10n/app_localizations.dart';
import 'package:webview_flutter/webview_flutter.dart';
import 'package:webview_flutter_android/webview_flutter_android.dart';
import '../services/ytmusic_service.dart';
import '../utils/globals.dart';

/// WebView login screen for YouTube Music.
/// On Android uses AndroidWebViewCookieManager to read HttpOnly cookies.
class YtMusicAuthScreen extends StatefulWidget {
  final bool switchAccount;

  const YtMusicAuthScreen({super.key, this.switchAccount = false});

  @override
  State<YtMusicAuthScreen> createState() => _YtMusicAuthScreenState();
}

class _YtMusicAuthScreenState extends State<YtMusicAuthScreen> {
  late final WebViewController _controller;
  bool _done = false;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _controller = WebViewController()
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      ..setNavigationDelegate(NavigationDelegate(
        onPageStarted: (_) => setState(() => _loading = true),
        onPageFinished: (url) async {
          setState(() => _loading = false);
          if (_done) return;
          if (url.contains('music.youtube.com')) {
            await _harvestCookieAndFinish();
          }
        },
        onNavigationRequest: (_) => NavigationDecision.navigate,
      ));

    _initAndLoad();
  }

  Future<void> _initAndLoad() async {
    if (!ytmLoggedInNotifier.value || widget.switchAccount) {
      try {
        await WebViewCookieManager().clearCookies();
        await _controller.clearCache();
        await _controller.clearLocalStorage();
      } catch (_) {}
    }
    final url = widget.switchAccount
        ? 'https://accounts.google.com/Logout?continue=https://accounts.google.com/ServiceLogin?service=youtube%26continue=https://music.youtube.com/'
        : 'https://accounts.google.com/ServiceLogin?service=youtube&continue=https://music.youtube.com/';
    _controller.loadRequest(Uri.parse(url));
  }

  Future<void> _harvestCookieAndFinish() async {
    if (_done) return;

    final seen = <String>{};
    final parts = <String>[];

    if (Platform.isAndroid) {
      // AndroidWebViewCookieManager can read HttpOnly cookies
      final androidManager = AndroidWebViewCookieManager(
        AndroidWebViewCookieManagerCreationParams.fromPlatformWebViewCookieManagerCreationParams(
          const PlatformWebViewCookieManagerCreationParams(),
        ),
      );

      final domains = [
        Uri.parse('https://music.youtube.com'),
        Uri.parse('https://youtube.com'),
        Uri.parse('https://google.com'),
        Uri.parse('https://accounts.google.com'),
      ];

      for (final uri in domains) {
        try {
          final cookies = await androidManager.getCookies(uri);
          for (final c in cookies) {
            if (seen.add(c.name)) parts.add('${c.name}=${c.value}');
          }
        } catch (e) {
          debugPrint('getCookies($uri) error: $e');
        }
      }
    }

    // Fallback / supplement: JS-accessible (non-HttpOnly) cookies
    try {
      final jsRaw = await _controller
          .runJavaScriptReturningResult('document.cookie') as String;
      final jsCookie = jsRaw.replaceAll(RegExp(r'^"|"$'), '');
      for (final pair in jsCookie.split(';')) {
        final name = pair.split('=').first.trim();
        if (name.isNotEmpty && seen.add(name)) parts.add(pair.trim());
      }
    } catch (_) {}

    debugPrint('YTM cookie names: ${seen.toList()}');

    // Ensure actual login token exists before declaring login successful
    final hasAuth = seen.contains('SAPISID') ||
        seen.contains('__Secure-3PAPISID') ||
        seen.contains('SID');
    if (!hasAuth || parts.isEmpty) {
      _done = false;
      return;
    }

    _done = true;
    final cookieString = parts.join('; ');

    String? accountName;
    String? accountAvatar;
    try {
      final jsRes = await _controller.runJavaScriptReturningResult('''
        (function() {
          var avatar = '';
          var img = document.querySelector('ytmusic-settings-button img') ||
                    document.querySelector('button#avatar-btn img') ||
                    document.querySelector('#avatar-btn img') ||
                    document.querySelector('img#img');
          if (img && img.src) avatar = img.src;

          var name = '';
          var nameEl = document.querySelector('#account-name') ||
                       document.querySelector('yt-formatted-string.ytd-channel-name') ||
                       document.querySelector('.ytmusic-settings-button #text');
          if (nameEl && nameEl.textContent) name = nameEl.textContent.trim();
          return JSON.stringify({avatar: avatar, name: name});
        })()
      ''');
      final clean = jsRes.toString().replaceAll(RegExp(r'^"|"$'), '').replaceAll(r'\"', '"');
      final data = jsonDecode(clean) as Map<String, dynamic>;
      if (data['name'] is String && (data['name'] as String).isNotEmpty) {
        accountName = data['name'] as String;
      }
      if (data['avatar'] is String && (data['avatar'] as String).isNotEmpty) {
        accountAvatar = data['avatar'] as String;
      }
    } catch (e) {
      debugPrint('Error extracting YTM profile info in webview: $e');
    }

    if (accountName == null || accountName.isEmpty) {
      final title = await _controller.getTitle() ?? '';
      if (title.isNotEmpty && !title.toLowerCase().contains('youtube')) {
        accountName = title;
      }
    }

    await ytmSaveCookie(
      cookieString,
      accountName: accountName != null && accountName.isNotEmpty ? accountName : null,
      accountAvatar: accountAvatar != null && accountAvatar.isNotEmpty ? accountAvatar : null,
    );

    // Also trigger background API fetch to ensure full high-res profile details are synced
    YtMusicService.fetchAccountProfile().ignore();

    if (mounted) {
      showFleyToast(AppLocalizations.of(context).ytmConnectedToast);
      Navigator.pop(context, true);
    }
  }

  @override
  Widget build(BuildContext context) {
    final isLight = isAppLight;
    final bgColor = isLight ? const Color(0xFFF7F7FA) : const Color(0xFF0F0F12);
    final textColor = isLight ? const Color(0xFF1A1A1A) : Colors.white;

    return Scaffold(
      backgroundColor: bgColor,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        title: Text(
          AppLocalizations.of(context).connectYtMusic,
          style: TextStyle(
            fontSize: 17,
            fontWeight: FontWeight.w700,
            color: textColor,
            fontFamily: getFontFamily(),
          ),
        ),
        centerTitle: true,
        leading: IconButton(
          icon: Icon(Icons.close, color: textColor),
          onPressed: () => Navigator.pop(context, false),
        ),
        actions: [
          IconButton(
            icon: Icon(Icons.switch_account_rounded, color: textColor),
            tooltip: AppLocalizations.of(context).switchAccount,
            onPressed: () async {
              final switchPrompt =
                  AppLocalizations.of(context).signInAnotherAccountPrompt;
              setState(() {
                _loading = true;
                _done = false;
              });
              try {
                await WebViewCookieManager().clearCookies();
                await _controller.clearCache();
                await _controller.clearLocalStorage();
              } catch (_) {}
              _controller.loadRequest(Uri.parse(
                'https://accounts.google.com/Logout'
                '?continue=https://accounts.google.com/ServiceLogin?service=youtube%26continue=https://music.youtube.com/',
              ));
              showFleyToast(switchPrompt);
            },
          ),
          if (_loading)
            const Padding(
              padding: EdgeInsets.only(right: 16),
              child: Center(
                child: SizedBox(
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator(strokeWidth: 2),
                ),
              ),
            ),
        ],
      ),
      body: WebViewWidget(controller: _controller),
    );
  }
}
