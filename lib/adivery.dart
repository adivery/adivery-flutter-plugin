import 'package:flutter/services.dart';

typedef EmptyFunction = void Function(String placement);
typedef ErrorFunction = void Function(String placement, String reason);
typedef RewardFunction = void Function(String placement, bool isRewarded);

class AdiveryPlugin {
  static const MethodChannel _channel = const MethodChannel('adivery_plugin');
  static EmptyFunction? _onInterstitialLoaded;
  static EmptyFunction? _onInterstitialClicked;
  static EmptyFunction? _onInterstitialShown;
  static EmptyFunction? _onInterstitialClosed;
  static EmptyFunction? _onRewardedLoaded;
  static EmptyFunction? _onRewardedClicked;
  static EmptyFunction? _onRewardedShown;
  static RewardFunction? _onRewardedClosed;
  static ErrorFunction? _onError;

  static void addListener(
      {EmptyFunction? onInterstitialLoaded,
      EmptyFunction? onInterstitialClicked,
      EmptyFunction? onInterstitialShown,
      EmptyFunction? onInterstitialClosed,
      EmptyFunction? onRewardedLoaded,
      EmptyFunction? onRewardedClicked,
      EmptyFunction? onRewardedShown,
      RewardFunction? onRewardedClosed,
      ErrorFunction? onError}) {
    _onError = onError;
    _onInterstitialClicked = onInterstitialClicked;
    _onInterstitialClosed = onInterstitialClosed;
    _onInterstitialLoaded = onInterstitialLoaded;
    _onInterstitialShown = onInterstitialShown;
    _onRewardedClicked = onRewardedClicked;
    _onRewardedClosed = onRewardedClosed;
    _onRewardedLoaded = onRewardedLoaded;
    _onRewardedShown = onRewardedShown;
  }

  static void initialize(
    String appId,
  ) async {
    await _channel.invokeMethod("initialize", {"appId": appId});

    _channel.setMethodCallHandler((call) => _handleMethodCall(call));
  }

  static void setLoggingEnabled(bool isLoggingEnabled) async {
    await _channel.invokeMethod(
        "setLoggingEnabled", {"isLoggingEnabled": isLoggingEnabled});
  }

  static void prepareInterstitialAd(String placementId) async {
    await _channel.invokeMethod("interstitial", placementId);
  }

  static void prepareRewardedAd(String placementId) async {
    await _channel.invokeMethod("rewarded", placementId);
  }

  static Future<bool?> isLoaded(String placementId) async {
    return _channel.invokeMethod("isLoaded", placementId);
  }

  static void show(String placement) async {
    _channel.invokeMethod("show", placement);
  }

  static _handleMethodCall(MethodCall call) {
    switch (call.method) {
      case "onRewardedAdShown":
        _onRewardedShown?.call((call.arguments as String));
        break;
      case "onRewardedAdLoaded":
        _onRewardedLoaded?.call(call.arguments as String);
        break;
      case "onRewardedAdClosed":
        var args = call.arguments as Map<dynamic, dynamic>;
        var placement = args["placement_id"] as String;
        var isRewarded = args["is_rewarded"] as bool;
        _onRewardedClosed?.call(placement, isRewarded);
        break;
      case "onRewardedAdClicked":
        _onRewardedClicked?.call(call.arguments as String);
        break;
      case "onInterstitialAdShown":
        _onInterstitialShown?.call(call.arguments as String);
        break;
      case "onInterstitialAdLoaded":
        _onInterstitialLoaded?.call(call.arguments as String);
        break;
      case "onInterstitialAdClosed":
        _onInterstitialClosed?.call(call.arguments as String);
        break;
      case "onInterstitialAdClicked":
        _onInterstitialClicked?.call(call.arguments as String);
        break;
      case "onError":
        var args = call.arguments as Map<dynamic, dynamic>;
        var placement = args["placement_id"] as String;
        var reason = args["reason"] as String;
        _onError?.call(placement, reason);
        break;
    }
  }
}
