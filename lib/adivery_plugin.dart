import 'dart:async';

import 'package:flutter/services.dart';

class AdiveryPlugin {
  static const MethodChannel _channel = const MethodChannel('adivery_plugin');

  static Future<bool> initialize(String appId) async {
    bool result = await _channel.invokeMethod("initialize", {"appId": appId});
    return result;
  }

  static void requestInterstitialAd(String placementId, String id) {
    _channel
        .invokeMethod("interstitial", {"placement_id": placementId, "id": id});
  }

  static void requestRewardedAd(String placementId, String id) {
    _channel.invokeMethod("rewarded", {"placement_id": placementId, "id": id});
  }

  static void requestNativeAd(String placementId, String id) {
    _channel.invokeMethod("native", {"placement_id": placementId, "id": id});
  }
}
