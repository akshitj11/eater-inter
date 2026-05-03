import 'package:flutter/services.dart';
import 'package:vibration/vibration.dart';

class ReadyAlertService {
  Future<void> buzz() async {
    final hasVibrator = await Vibration.hasVibrator() ?? false;
    if (hasVibrator) {
      await Vibration.vibrate(pattern: [0, 240, 120, 240, 120, 320]);
      return;
    }
    await HapticFeedback.heavyImpact();
  }
}
