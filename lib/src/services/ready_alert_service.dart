import 'package:flutter/services.dart';
import 'package:flutter/foundation.dart';
import 'dart:js_interop';
import 'package:vibration/vibration.dart';

class ReadyAlertService {
  Future<bool> enableAlerts() async {
    if (!kIsWeb) {
      return true;
    }
    final alerts = globalContext['bawarchiiAlerts'];
    final requestPermission = alerts?['requestPermission'];
    if (requestPermission == null) {
      return false;
    }
    final result =
        await (requestPermission as JSFunction).callAsFunction().toDart;
    return result.dartify() == 'granted';
  }

  Future<void> buzz() async {
    _notifyReady();
    _playReadySound();
    final hasVibrator = await Vibration.hasVibrator() ?? false;
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
    final notifyReady = globalContext['bawarchiiAlerts']?['notifyReady'];
    if (notifyReady is JSFunction) {
      notifyReady.callAsFunction();
    }
  }

  void _playReadySound() {
    if (!kIsWeb) {
      SystemSound.play(SystemSoundType.alert);
      return;
    }
    final playReadySound = globalContext['bawarchiiAlerts']?['playReadySound'];
    if (playReadySound is JSFunction) {
      playReadySound.callAsFunction();
    }
  }
}
