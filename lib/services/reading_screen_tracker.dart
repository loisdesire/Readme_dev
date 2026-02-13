import 'dart:math';

import 'package:flutter/foundation.dart';

class ReadingScreenTracker {
  static final ValueNotifier<int> _activeReaders = ValueNotifier<int>(0);

  static ValueListenable<int> get activeReaders => _activeReaders;

  static bool get isReadingActive => _activeReaders.value > 0;

  static void enter() {
    _activeReaders.value = _activeReaders.value + 1;
  }

  static void exit() {
    _activeReaders.value = max(0, _activeReaders.value - 1);
  }
}
