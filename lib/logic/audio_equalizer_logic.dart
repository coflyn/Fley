// ignore_for_file: invalid_use_of_protected_member, deprecated_member_use
part of '../main.dart';

extension _AudioEqualizerLogic on _MainScreenState {
  Future<void> _applySavedEqualizerSettings(int sessionId) async {
    if (sessionId == 0) return;
    try {
      const channel = MethodChannel('com.fley.audio/equalizer');
      final prefs = await SharedPreferences.getInstance();
      final enabled = prefs.getBool('saved_eq_enabled') ?? false;
      if (enabled) {
        final res = await channel.invokeMapMethod<String, dynamic>(
          'initEqualizer',
          {'audioSessionId': sessionId},
        );
        if (res != null) {
          final savedLevelsStr = prefs.getString('saved_eq_levels');
          if (savedLevelsStr != null) {
            final levels = List<int>.from(jsonDecode(savedLevelsStr));
            for (int i = 0; i < levels.length; i++) {
              if (i < (res['bands'] as int)) {
                await channel.invokeMethod('setBandLevel', {
                  'band': i,
                  'level': levels[i],
                });
              }
            }
          }
          await channel.invokeMethod('setEqualizerEnabled', {'enable': true});
        }
      }
    } catch (_) {}
  }
}
