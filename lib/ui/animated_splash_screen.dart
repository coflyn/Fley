import 'dart:math' as math;
import 'package:flutter/material.dart';

class AnimatedSplashScreen extends StatefulWidget {
  final Color accentColor;
  final VoidCallback onFinish;
  final bool isReady;
  final String fontFamily;

  const AnimatedSplashScreen({
    super.key,
    required this.accentColor,
    required this.onFinish,
    this.isReady = true,
    this.fontFamily = '',
  });

  @override
  State<AnimatedSplashScreen> createState() => _AnimatedSplashScreenState();
}

class _Particle {
  final double relX; // 0.0 to 1.0 (normalized screen X)
  final double relY; // 0.0 to 1.0 (normalized screen Y)
  final double size; // 9.0 to 19.0
  final double baseOpacity; // 0.15 to 0.60
  final double phase; // Random animation phase
  final double driftRangeX;
  final double driftRangeY;
  final IconData icon;

  _Particle({
    required this.relX,
    required this.relY,
    required this.size,
    required this.baseOpacity,
    required this.phase,
    required this.driftRangeX,
    required this.driftRangeY,
    required this.icon,
  });
}

class _AnimatedSplashScreenState extends State<AnimatedSplashScreen>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  final List<_Particle> _particles = [];
  bool _isExiting = false;

  static const List<IconData> _iconPool = [
    Icons.music_note_rounded,
    Icons.headphones_rounded,
    Icons.graphic_eq_rounded,
    Icons.album_rounded,
    Icons.radio_rounded,
    Icons.volume_up_rounded,
    Icons.waves_rounded,
    Icons.favorite_rounded,
    Icons.tune_rounded,
    Icons.queue_music_rounded,
    Icons.auto_awesome_rounded,
    Icons.sensors_rounded,
    Icons.surround_sound_rounded,
    Icons.mic_none_rounded,
    Icons.podcasts_rounded,
    Icons.shuffle_rounded,
    Icons.wifi_rounded,
    Icons.bluetooth_audio_rounded,
    Icons.piano_rounded,
    Icons.speaker_rounded,
    Icons.speaker_group_rounded,
    Icons.audiotrack_rounded,
    Icons.library_music_rounded,
    Icons.equalizer_rounded,
  ];

  @override
  void initState() {
    super.initState();

    final random = math.Random(1337); // Seed for uniform, aesthetically scattered distribution
    const int particleCount = 125;

    for (int i = 0; i < particleCount; i++) {
      double rx = 0.03 + random.nextDouble() * 0.94;
      double ry = 0.03 + random.nextDouble() * 0.94;

      // Avoid placing particles directly on top of the center title
      final dx = (rx - 0.5).abs();
      final dy = (ry - 0.5).abs();
      if (dx < 0.22 && dy < 0.10) {
        if (random.nextBool()) {
          rx += (rx >= 0.5 ? 0.20 : -0.20);
        } else {
          ry += (ry >= 0.5 ? 0.12 : -0.12);
        }
        rx = rx.clamp(0.04, 0.96);
        ry = ry.clamp(0.04, 0.96);
      }

      _particles.add(
        _Particle(
          relX: rx,
          relY: ry,
          size: 9.0 + random.nextDouble() * 11.0,
          baseOpacity: 0.15 + random.nextDouble() * 0.45,
          phase: random.nextDouble() * 2 * math.pi,
          driftRangeX: 3.0 + random.nextDouble() * 6.0,
          driftRangeY: 3.0 + random.nextDouble() * 7.0,
          icon: _iconPool[random.nextInt(_iconPool.length)],
        ),
      );
    }

    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 3200),
    )..repeat();

    _scheduleExit();
  }

  void _scheduleExit() async {
    // Show splash for 1.6s
    await Future.delayed(const Duration(milliseconds: 1600));

    // Wait until library scan is ready (max 800ms additional grace period)
    int waitedMs = 0;
    while (!widget.isReady && waitedMs < 800) {
      await Future.delayed(const Duration(milliseconds: 100));
      waitedMs += 100;
    }

    if (!mounted) return;
    setState(() {
      _isExiting = true;
    });

    // Smooth fade transition duration
    await Future.delayed(const Duration(milliseconds: 380));
    if (mounted) {
      widget.onFinish();
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;
    final accent = widget.accentColor;

    // 100% OPAQUE background gradient: NO transparency, completely covers home
    final centerColor = Color.lerp(const Color(0xFF140F15), accent, 0.16)!;
    final midColor = const Color(0xFF0C090E);
    final outerColor = const Color(0xFF050406);

    // Warm pastel accent color for the floating micro-icons
    final iconColor = Color.lerp(
      accent,
      const Color(0xFFE0C4BD),
      0.45,
    )!;

    return AnimatedOpacity(
      opacity: _isExiting ? 0.0 : 1.0,
      duration: const Duration(milliseconds: 380),
      curve: Curves.easeInOutCubic,
      child: Material(
        color: outerColor, // Fully opaque barrier
        child: Container(
          width: double.infinity,
          height: double.infinity,
          decoration: BoxDecoration(
            color: outerColor,
            gradient: RadialGradient(
              center: Alignment.center,
              radius: 0.85,
              colors: [
                centerColor,
                midColor,
                outerColor,
              ],
              stops: const [0.0, 0.50, 1.0],
            ),
          ),
          child: AnimatedBuilder(
            animation: _controller,
            builder: (context, child) {
              final progress = _controller.value;
              final tAngle = progress * 2 * math.pi;

              return Stack(
                children: [
                  // 125 Scattered Dense Floating Music Micro-Icons
                  ..._particles.map((p) {
                    final driftX = math.sin(tAngle + p.phase) * p.driftRangeX;
                    final driftY = math.cos(tAngle + p.phase) * p.driftRangeY;
                    final posX = (p.relX * size.width) + driftX - (p.size / 2);
                    final posY = (p.relY * size.height) + driftY - (p.size / 2);

                    // Gentle breathing opacity pulse
                    final pulse = 0.75 + 0.25 * math.sin(tAngle * 1.5 + p.phase);
                    final opacity = (p.baseOpacity * pulse).clamp(0.08, 0.75);

                    return Positioned(
                      left: posX,
                      top: posY,
                      child: Opacity(
                        opacity: opacity,
                        child: Icon(
                          p.icon,
                          size: p.size,
                          color: iconColor,
                        ),
                      ),
                    );
                  }),

                  // Glowing Center "Fley" Logo
                  Center(
                    child: Builder(
                      builder: (context) {
                        final glowPulse = 0.85 + 0.15 * math.sin(tAngle);

                        return Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              'Fley',
                              style: TextStyle(
                                fontSize: 48,
                                fontWeight: FontWeight.w900,
                                letterSpacing: -1.2,
                                color: Colors.white,
                                fontFamily: widget.fontFamily.isNotEmpty
                                    ? widget.fontFamily
                                    : null,
                                shadows: [
                                  Shadow(
                                    color: accent.withValues(alpha: 0.85 * glowPulse),
                                    blurRadius: 30 * glowPulse,
                                  ),
                                  Shadow(
                                    color: accent.withValues(alpha: 0.50 * glowPulse),
                                    blurRadius: 58 * glowPulse,
                                  ),
                                  Shadow(
                                    color: Colors.white.withValues(alpha: 0.9),
                                    blurRadius: 8,
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(height: 6),
                            Text(
                              'FEEL THE MUSIC',
                              style: TextStyle(
                                fontSize: 10.5,
                                fontWeight: FontWeight.w700,
                                letterSpacing: 3.5,
                                color: Colors.white.withValues(alpha: 0.5),
                                fontFamily: widget.fontFamily.isNotEmpty
                                    ? widget.fontFamily
                                    : null,
                              ),
                            ),
                          ],
                        );
                      },
                    ),
                  ),
                ],
              );
            },
          ),
        ),
      ),
    );
  }
}
