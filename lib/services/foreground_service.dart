import 'package:flutter/services.dart';

class ForegroundService {
  static const _channel = MethodChannel('dk.jagtapp/foreground_service');

  static Future<void> start() async {
    try {
      await _channel.invokeMethod('startService');
    } on PlatformException catch (_) {}
  }

  static Future<void> stop() async {
    try {
      await _channel.invokeMethod('stopService');
    } on PlatformException catch (_) {}
  }
}
