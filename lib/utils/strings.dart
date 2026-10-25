// Fley Localization System
// Supports: English (en), Indonesian (id), Japanese (ja)
//
// Usage: AppLocalizations.of(context).library

import 'package:flutter/material.dart';

final ValueNotifier<String> languageNotifier = ValueNotifier<String>('en');

class FleyStrings {
  static String get currentLang => languageNotifier.value;
}
