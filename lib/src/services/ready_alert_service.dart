import 'dart:js_interop';
import 'dart:js_interop_unsafe';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:vibration/vibration.dart';

class ReadyAlertService {
  Future<bool> enableAlerts() async {
    if (!kIsWeb) {
      return true;
    }
    final alerts = globalContext.getProperty<JSObject?>('bawarchiiAlerts'.toJS);
    final requestPermission =
        alerts?.getProperty<JSFunction?>('requestPermission'.toJS);
    if (requestPermission == null) {
      return false;
    }
    final promise = requestPermission.callAsFunction() as JSPromise<JSAny?>;
    final result = await promise.toDart;
    return result.dartify() == 'granted';
  }

  Future<void> buzz() async {
    _notifyReady();
    _playReadySound();
    final hasVibrator = await Vibration.hasVibrator();
    if (hasVibrator) {
      await Vibration.vibrate(pattern: [0, 240, 120, 240, 120, 320]);
      return;
    }
    await HapticFeedback.heavyImpact();
  }

  void _notifyReady() {
    if (!kIsWeb) {
      return;
    }
    final notifyReady = globalContext
        .getProperty<JSObject?>('bawarchiiAlerts'.toJS)
        ?.getProperty<JSFunction?>('notifyReady'.toJS);
    if (notifyReady != null) {
      notifyReady.callAsFunction();
    }
  }

  void _playReadySound() {
    if (!kIsWeb) {
      SystemSound.play(SystemSoundType.alert);
      return;
    }
    final playReadySound = globalContext
        .getProperty<JSObject?>('bawarchiiAlerts'.toJS)
        ?.getProperty<JSFunction?>('playReadySound'.toJS);
    if (playReadySound != null) {
      playReadySound.callAsFunction();
    }
  }
}
