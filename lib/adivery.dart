import 'package:flutter/services.dart';

class AdiveryPlugin {
  static const MethodChannel _channel = const MethodChannel('adivery_plugin');

  static void initialize(String appId) async {
    await _channel.invokeMethod("initialize", {"appId": appId});
  }

  static void setLoggingEnabled(bool isLoggingEnabled) async {
    await _channel.invokeMethod(
        "setLoggingEnabled", {"isLoggingEnabled": isLoggingEnabled});
  }
}
