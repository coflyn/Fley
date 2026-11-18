import 'dart:io';
import 'package:flutter/material.dart';
import 'package:webview_flutter/webview_flutter.dart';
import 'package:webview_flutter_android/webview_flutter_android.dart';
import '../services/ytmusic_service.dart';
import '../utils/globals.dart';

/// WebView login screen for YouTube Music.
/// On Android uses AndroidWebViewCookieManager to read HttpOnly cookies.
class YtMusicAuthScreen extends StatefulWidget {
  const YtMusicAuthScreen({super.key});

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
      ))
      ..loadRequest(Uri.parse(
        'https://accounts.google.com/ServiceLogin'
        '?service=youtube'
        '&continue=https://music.youtube.com/',
      ));
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

    if (parts.isEmpty) {
      _done = false;
      return;
    }

    _done = true;
    final cookieString = parts.join('; ');
    final title = await _controller.getTitle() ?? '';
    await ytmSaveCookie(cookieString, accountName: title.isNotEmpty ? title : null);

    if (mounted) {
      showFleyToast('YouTube Music connected!');
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
          'Connect YouTube Music',
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
