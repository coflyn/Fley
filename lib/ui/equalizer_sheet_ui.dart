// ignore_for_file: invalid_use_of_protected_member
part of '../main.dart';

class _EqualizerSheetContent extends StatefulWidget {
  final AudioPlayer player;
  final String activeFont;
  final Color accentColor;

  const _EqualizerSheetContent({
    required this.player,
    required this.activeFont,
    required this.accentColor,
  });

  @override
  State<_EqualizerSheetContent> createState() => _EqualizerSheetContentState();
}

class _EqualizerSheetContentState extends State<_EqualizerSheetContent> {
  static const _channel = MethodChannel('com.fley.audio/equalizer');
  bool _initialized = false;
  bool _enabled = false;
  int _bands = 0;
  int _minLevel = -1500;
  int _maxLevel = 1500;
  List<int> _frequencies = [];
  List<int> _levels = [];
  String? _error;
  String _activePreset = lookupAppLocalizations(
    Locale(FleyStrings.currentLang),
  ).customTime;

  final Map<String, List<int>> _presets = {
    'Flat': [0, 0, 0, 0, 0],
    'Classical': [500, 300, -200, 400, 400],
    'Dance': [600, 0, 200, 400, 100],
    'Folk': [300, 0, 0, 200, -100],
    'Heavy Metal': [400, 100, 900, 300, 0],
    'Hip Hop': [500, 300, 0, 100, 500],
    'Jazz': [400, 200, -200, 200, 500],
    'Pop': [-200, -100, 500, 100, -200],
    'Rock': [500, 300, -100, 300, 500],
    'Bass Booster': [900, 600, 0, 0, 0],
    'Vocal Booster': [-200, 0, 600, 400, 0],
  };

  @override
  void initState() {
    super.initState();
    _initEQ();
  }

  Future<void> _initEQ() async {
    final sessionId = widget.player.androidAudioSessionId ?? 0;
    if (sessionId == 0) {
      setState(() {
        _error = AppLocalizations.of(context).eqErrorPlayFirst;
        _initialized = true;
      });
      return;
    }

    try {
      final res = await _channel.invokeMapMethod<String, dynamic>(
        'initEqualizer',
        {'audioSessionId': sessionId},
      );
      if (res != null) {
        final prefs = await SharedPreferences.getInstance();
        setState(() {
          _bands = res['bands'] as int;
          _minLevel = res['minLevel'] as int;
          _maxLevel = res['maxLevel'] as int;
          _frequencies = List<int>.from(res['frequencies']);

          final savedLevelsStr = prefs.getString('saved_eq_levels');
          if (savedLevelsStr != null) {
            _levels = List<int>.from(jsonDecode(savedLevelsStr));
            for (int i = 0; i < _levels.length; i++) {
              if (i < _bands) {
                _channel.invokeMethod('setBandLevel', {
                  'band': i,
                  'level': _levels[i],
                });
              }
            }
          } else {
            _levels = List<int>.from(res['levels']);
          }

          _enabled =
              prefs.getBool('saved_eq_enabled') ?? res['enabled'] as bool;
          _channel.invokeMethod('setEqualizerEnabled', {'enable': _enabled});
          _activePreset =
              prefs.getString('saved_eq_preset') ??
              AppLocalizations.of(context).customTime;
          _initialized = true;
        });
      }
    } catch (e) {
      setState(() {
        _error = AppLocalizations.of(context).eqErrorUnsupported;
        _initialized = true;
      });
    }
  }

  Future<void> _updateBandLevel(int band, int value) async {
    if (!_enabled) return;
    setState(() {
      _levels[band] = value;
      _activePreset = AppLocalizations.of(context).customTime;
    });
    try {
      await _channel.invokeMethod('setBandLevel', {
        'band': band,
        'level': value,
      });
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('saved_eq_levels', jsonEncode(_levels));
      await prefs.setString(
        'saved_eq_preset',
        lookupAppLocalizations(Locale(FleyStrings.currentLang)).customTime,
      );
    } catch (_) {}
  }

  Future<void> _toggleEnabled(bool val) async {
    setState(() {
      _enabled = val;
    });
    try {
      await _channel.invokeMethod('setEqualizerEnabled', {'enable': val});
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool('saved_eq_enabled', val);
    } catch (_) {}
  }

  Future<void> _selectPreset(String name) async {
    if (!_enabled) return;
    final presetVals = _presets[name];
    if (presetVals != null) {
      setState(() {
        _activePreset = name;
        for (int i = 0; i < _levels.length; i++) {
          if (i < presetVals.length) {
            _levels[i] = presetVals[i];
          }
        }
      });

      try {
        for (int i = 0; i < _levels.length; i++) {
          await _channel.invokeMethod('setBandLevel', {
            'band': i,
            'level': _levels[i],
          });
        }
        final prefs = await SharedPreferences.getInstance();
        await prefs.setString('saved_eq_levels', jsonEncode(_levels));
        await prefs.setString('saved_eq_preset', name);
      } catch (_) {}
    }
  }

  @override
  Widget build(BuildContext context) {
    final isLight = isAppLight;
    final textStyle = TextStyle(
      color: isLight ? const Color(0xFF1A1A1A) : Colors.white,
      fontFamily: getFontFamily(widget.activeFont),
    );
    if (!_initialized) {
      return Container(
        height: 400,
        alignment: Alignment.center,
        color: isLight ? const Color(0xFFF0F0F3) : const Color(0xFF121212),
        child: CircularProgressIndicator(
          valueColor: AlwaysStoppedAnimation<Color>(widget.accentColor),
        ),
      );
    }

    if (_error != null) {
      return Container(
        padding: const EdgeInsets.all(24),
        color: isLight ? const Color(0xFFF0F0F3) : const Color(0xFF121212),
        child: SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 48,
                height: 5,
                decoration: BoxDecoration(
                  color: isLight ? Colors.black12 : Colors.white24,
                  borderRadius: BorderRadius.circular(10),
                ),
              ),
              const SizedBox(height: 24),
              Icon(
                Icons.equalizer_rounded,
                size: 64,
                color: widget.accentColor,
              ),
              const SizedBox(height: 16),
              Text(
                _error!,
                style: textStyle.copyWith(
                  fontSize: 14,
                  color: isLight ? Colors.black45 : Colors.white54,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 24),
            ],
          ),
        ),
      );
    }

    return Container(
      color: isLight ? const Color(0xFFF0F0F3) : const Color(0xFF121212),
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
      child: SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: Container(
                width: 48,
                height: 5,
                decoration: BoxDecoration(
                  color: isLight ? Colors.black12 : Colors.white24,
                  borderRadius: BorderRadius.circular(10),
                ),
              ),
            ),
            const SizedBox(height: 20),

            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      AppLocalizations.of(context).systemEqualizer,
                      style: textStyle.copyWith(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                        letterSpacing: -0.5,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      AppLocalizations.of(context).equalizerSubtitle,
                      style: textStyle.copyWith(
                        fontSize: 12,
                        color: isLight ? Colors.black54 : Colors.white38,
                      ),
                    ),
                  ],
                ),
                Switch.adaptive(
                  value: _enabled,
                  activeThumbColor: widget.accentColor,
                  activeTrackColor: widget.accentColor.withValues(alpha: 0.3),
                  onChanged: (val) => _toggleEnabled(val),
                ),
              ],
            ),
            const SizedBox(height: 20),

            Opacity(
              opacity: _enabled ? 1.0 : 0.4,
              child: IgnorePointer(
                ignoring: !_enabled,
                child: SizedBox(
                  height: 38,
                  child: ListView(
                    scrollDirection: Axis.horizontal,
                    children: _presets.keys.map((presetName) {
                      final isActive = _activePreset == presetName;
                      return Padding(
                        padding: const EdgeInsets.only(right: 8.0),
                        child: ChoiceChip(
                          label: Text(presetName),
                          selected: isActive,
                          selectedColor: widget.accentColor,
                          backgroundColor: isLight
                              ? Colors.black.withValues(alpha: 0.05)
                              : const Color(0xFF1E1E1E),
                          labelStyle: textStyle.copyWith(
                            fontSize: 13,
                            fontWeight: isActive
                                ? FontWeight.bold
                                : FontWeight.normal,
                            color: isActive
                                ? Colors.white
                                : (isLight ? Colors.black87 : Colors.white70),
                          ),
                          onSelected: (selected) {
                            if (selected) {
                              _selectPreset(presetName);
                            }
                          },
                        ),
                      );
                    }).toList(),
                  ),
                ),
              ),
            ),
            const SizedBox(height: 24),

            Opacity(
              opacity: _enabled ? 1.0 : 0.3,
              child: IgnorePointer(
                ignoring: !_enabled,
                child: Container(
                  height: 220,
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  decoration: BoxDecoration(
                    color: isLight
                        ? Colors.black.withValues(alpha: 0.05)
                        : const Color(0xFF1A1A1A),
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                    children: List.generate(_bands, (index) {
                      final freq = _frequencies[index];
                      final freqLabel = freq >= 1000
                          ? '${(freq / 1000).toStringAsFixed(0)}k'
                          : '$freq';
                      final level = _levels[index];
                      final dbVal = (level / 100).toStringAsFixed(0);

                      return Column(
                        children: [
                          Text(
                            '${dbVal}dB',
                            style: textStyle.copyWith(
                              fontSize: 10,
                              color: isLight ? Colors.black54 : Colors.white54,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const SizedBox(height: 8),

                          Expanded(
                            child: RotatedBox(
                              quarterTurns: 3,
                              child: SliderTheme(
                                data: SliderThemeData(
                                  trackHeight: 3.5,
                                  activeTrackColor: widget.accentColor,
                                  inactiveTrackColor: isLight
                                      ? Colors.black12
                                      : Colors.white12,
                                  thumbColor: isLight
                                      ? widget.accentColor
                                      : Colors.white,
                                  overlayColor: widget.accentColor.withValues(
                                    alpha: 0.2,
                                  ),
                                  thumbShape: const RoundSliderThumbShape(
                                    enabledThumbRadius: 6.5,
                                    elevation: 2,
                                  ),
                                ),
                                child: Slider(
                                  value: level.toDouble(),
                                  min: _minLevel.toDouble(),
                                  max: _maxLevel.toDouble(),
                                  onChanged: (val) {
                                    _updateBandLevel(index, val.toInt());
                                  },
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(height: 8),

                          Text(
                            '${freqLabel}Hz',
                            style: textStyle.copyWith(
                              fontSize: 11,
                              color: isLight ? Colors.black45 : Colors.white38,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ],
                      );
                    }),
                  ),
                ),
              ),
            ),
            const SizedBox(height: 16),
          ],
        ),
      ),
    );
  }
}
