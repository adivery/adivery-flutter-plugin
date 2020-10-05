import 'dart:typed_data';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

abstract class Ad {
  void show();

  void loadAd();
}

typedef NativeAdEmptyFunction = void Function();
typedef NativeAdErrorFunction = void Function(int errorCode);

typedef EmptyFunction = void Function(Ad ad);
typedef ErrorFunction = void Function(Ad ad, int errorCode);
typedef NativeAdFunction = void Function(Map<dynamic, dynamic> nativeAd);

enum BannerAdSize { BANNER, LARGE_BANNER, MEDIUM_RECTANGLE }

class BannerAd extends StatefulWidget {
  final String placementId;
  final BannerAdSize bannerType;

  final EmptyFunction onAdLoaded;
  final ErrorFunction onAdLoadFailed;
  final ErrorFunction onAdShowFailed;
  final EmptyFunction onAdClicked;

  const BannerAd({
    Key key,
    this.placementId,
    this.bannerType,
    this.onAdLoaded,
    this.onAdLoadFailed,
    this.onAdShowFailed,
    this.onAdClicked,
  }) : super(key: key);

  @override
  State<StatefulWidget> createState() =>
      _TextViewState(
          placementId: placementId,
          bannerType: bannerType,
          onAdClicked: onAdClicked,
          onAdLoaded: onAdLoaded,
          onAdLoadFailed: onAdLoadFailed,
          onAdShowFailed: onAdShowFailed);
}

class _TextViewState extends State<BannerAd> {
  final String placementId;
  final BannerAdSize bannerType;

  final EmptyFunction onAdLoaded;
  final ErrorFunction onAdLoadFailed;
  final ErrorFunction onAdShowFailed;
  final EmptyFunction onAdClicked;

  _TextViewState({
    this.placementId,
    this.bannerType,
    this.onAdLoaded,
    this.onAdLoadFailed,
    this.onAdShowFailed,
    this.onAdClicked,
  }) : super();

  void _onPlatformViewCreated(int id) {
    BannerAdEventHandler handler = new BannerAdEventHandler(
        id: id,
        bannerType: bannerType,
        onAdLoaded: onAdLoaded,
        onAdClicked: onAdClicked,
        onAdShowFailed: onAdShowFailed,
        onAdLoadFailed: onAdLoadFailed);
    handler.openChannel();
  }

  @override
  Widget build(BuildContext context) {
    if (defaultTargetPlatform == TargetPlatform.android) {
      return Container(
        width: getBannerWidth(bannerType),
        height: getBannerHeight(bannerType),
        child: AndroidView(
          viewType: 'adivery/bannerAd',
          creationParamsCodec: StandardMessageCodec(),
          onPlatformViewCreated: _onPlatformViewCreated,
          creationParams: {
            "placement_id": placementId,
            "banner_type": getBannerType()
          },
        ),
      );
    }
    return Text(
        '$defaultTargetPlatform is not yet supported by the adivery plugin');
  }

  double getBannerHeight(BannerAdSize bannerType) {
    if (bannerType == BannerAdSize.BANNER) {
      return 50;
    } else if (bannerType == BannerAdSize.LARGE_BANNER) {
      return 100;
    } else {
      return 250;
    }
  }

  double getBannerWidth(BannerAdSize bannerType) {
    if (bannerType == BannerAdSize.BANNER) {
      return 320;
    } else if (bannerType == BannerAdSize.LARGE_BANNER) {
      return 320;
    } else {
      return 300;
    }
  }

  String getBannerType() {
    if (bannerType == BannerAdSize.BANNER) {
      return "banner";
    } else if (bannerType == BannerAdSize.LARGE_BANNER) {
      return "large_banner";
    } else {
      return "medium_rectangle";
    }
  }
}

class BannerAdEventHandler extends Ad {
  final int id;
  final BannerAdSize bannerType;

  final EmptyFunction onAdLoaded;
  final ErrorFunction onAdLoadFailed;
  final ErrorFunction onAdShowFailed;
  final EmptyFunction onAdClicked;

  MethodChannel _channel;

  BannerAdEventHandler({
    this.id,
    this.bannerType,
    this.onAdLoaded,
    this.onAdLoadFailed,
    this.onAdShowFailed,
    this.onAdClicked,
  });

  void openChannel() {
    _channel = new MethodChannel("adivery/banner_" + id.toString());
    _channel.setMethodCallHandler(handle);
  }

  Future<dynamic> handle(MethodCall call) {
    switch (call.method) {
      case "onAdLoaded":
        onAdLoaded(this);
        break;
      case "onAdClicked":
        onAdClicked(this);
        break;
      case "onAdLoadFailed":
        onAdLoadFailed(this, call.arguments as int);
        break;
      case "onAdShowFailed":
        onAdShowFailed(this, call.arguments as int);
        break;
    }
    return true as dynamic;
  }

  @override
  void loadAd() {}

  @override
  void show() {}
}

class InterstitialAd {
  static const MethodChannel _channel = const MethodChannel('adivery_plugin');
  final String placementId;
  final EmptyFunction onAdLoaded;
  final EmptyFunction onAdClicked;
  final EmptyFunction onAdShown;
  final ErrorFunction onAdShowFailed;
  final ErrorFunction onAdLoadFailed;
  final EmptyFunction onAdClosed;
  final String id = UniqueKey().toString();

  InterstitialAd({
    this.placementId,
    this.onAdLoaded,
    this.onAdClicked,
    this.onAdShown,
    this.onAdShowFailed,
    this.onAdLoadFailed,
    this.onAdClosed,
  });

  InterstitialAdEvenHandler _handler;

  void loadAd() {
    _channel
        .invokeMethod("interstitial", {"placement_id": placementId, "id": id});
    _handler = new InterstitialAdEvenHandler(
        id: id,
        onAdLoadFailed: onAdLoadFailed,
        onAdShowFailed: onAdShowFailed,
        onAdClicked: onAdClicked,
        onAdLoaded: onAdLoaded,
        onAdClosed: onAdClosed,
        onAdShown: onAdShown);
    _handler.openChannel();
    _handler.loadAd();
  }

  void show() {
    _handler.show();
  }
}

class InterstitialAdEvenHandler extends Ad {
  final String placementId;
  final EmptyFunction onAdLoaded;
  final EmptyFunction onAdClicked;
  final EmptyFunction onAdShown;
  final ErrorFunction onAdShowFailed;
  final ErrorFunction onAdLoadFailed;
  final EmptyFunction onAdClosed;
  final String id;

  MethodChannel _channel;

  InterstitialAdEvenHandler({
    this.placementId,
    this.id,
    this.onAdLoaded,
    this.onAdClicked,
    this.onAdShown,
    this.onAdShowFailed,
    this.onAdLoadFailed,
    this.onAdClosed,
  });

  void openChannel() {
    _channel = new MethodChannel("adivery/interstitial_" + id);
    _channel.setMethodCallHandler(handle);
  }

  Future<dynamic> handle(MethodCall call) {
    switch (call.method) {
      case "onAdLoaded":
        onAdLoaded(this);
        break;
      case "onAdClicked":
        onAdClicked(this);
        break;
      case "onAdLoadFailed":
        onAdLoadFailed(this, call.arguments as int);
        break;
      case "onAdShowFailed":
        onAdShowFailed(this, call.arguments as int);
        break;
      case "onAdShown":
        onAdShown(this);
        break;
      case "onAdClosed":
        onAdClosed(this);
        break;
    }
    return true as dynamic;
  }

  @override
  void loadAd() {
    _channel.invokeMethod("loadAd");
  }

  @override
  void show() {
    _channel.invokeMethod("show");
  }
}

class RewardedAd {
  static const MethodChannel _channel = const MethodChannel('adivery_plugin');

  final String placementId;
  final EmptyFunction onAdLoaded;
  final EmptyFunction onAdClicked;
  final EmptyFunction onAdShown;
  final ErrorFunction onAdShowFailed;
  final ErrorFunction onAdLoadFailed;
  final EmptyFunction onAdClosed;
  final EmptyFunction onAdRewarded;
  final String id = UniqueKey().toString();

  RewardedAd({this.placementId,
    this.onAdLoaded,
    this.onAdClicked,
    this.onAdShown,
    this.onAdShowFailed,
    this.onAdLoadFailed,
    this.onAdClosed,
    this.onAdRewarded});

  RewardedAdEventHandler _handler;

  void loadAd() {
    _channel.invokeMethod("rewarded", {"placement_id": placementId, "id": id});
    _handler = new RewardedAdEventHandler(
        id: id,
        onAdLoadFailed: onAdLoadFailed,
        onAdShowFailed: onAdShowFailed,
        onAdClicked: onAdClicked,
        onAdLoaded: onAdLoaded,
        onAdClosed: onAdClosed,
        onAdShown: onAdShown,
        onAdRewarded: onAdRewarded);
    _handler.openChannel();
    _handler.loadAd();
  }

  void show() {
    _handler.show();
  }
}

class RewardedAdEventHandler extends Ad {
  final String placementId;
  final EmptyFunction onAdLoaded;
  final EmptyFunction onAdClicked;
  final EmptyFunction onAdShown;
  final ErrorFunction onAdShowFailed;
  final ErrorFunction onAdLoadFailed;
  final EmptyFunction onAdClosed;
  final EmptyFunction onAdRewarded;
  final String id;

  RewardedAdEventHandler({this.placementId,
    this.id,
    this.onAdLoaded,
    this.onAdClicked,
    this.onAdShown,
    this.onAdShowFailed,
    this.onAdLoadFailed,
    this.onAdClosed,
    this.onAdRewarded});

  MethodChannel _channel;

  void openChannel() {
    _channel = new MethodChannel("adivery/rewarded_" + id);
    _channel.setMethodCallHandler(handle);
  }

  Future<dynamic> handle(MethodCall call) {
    switch (call.method) {
      case "onAdLoaded":
        onAdLoaded(this);
        break;
      case "onAdClicked":
        onAdClicked(this);
        break;
      case "onAdLoadFailed":
        onAdLoadFailed(this, call.arguments as int);
        break;
      case "onAdShowFailed":
        onAdShowFailed(this, call.arguments as int);
        break;
      case "onAdShown":
        onAdShown(this);
        break;
      case "onAdClosed":
        onAdClosed(this);
        break;
      case "onAdRewarded":
        onAdRewarded(this);
        break;
    }
    return true as dynamic;
  }

  @override
  void loadAd() {
    _channel.invokeMethod("loadAd");
  }

  @override
  void show() {
    _channel.invokeMethod("show");
  }
}

class NativeAd {
  static const MethodChannel _channel = const MethodChannel('adivery_plugin');

  final String placementId;
  final NativeAdEmptyFunction onAdLoaded;
  final NativeAdEmptyFunction onAdClicked;
  final NativeAdEmptyFunction onAdShown;
  final NativeAdErrorFunction onAdShowFailed;
  final NativeAdErrorFunction onAdLoadFailed;
  final NativeAdEmptyFunction onAdClosed;
  final String id = UniqueKey().toString();

  NativeAd({this.placementId,
    this.onAdLoaded,
    this.onAdClosed,
    this.onAdClicked,
    this.onAdShowFailed,
    this.onAdLoadFailed,
    this.onAdShown});

  NativeAdEventHandler _handler;

  String headline;
  String description;
  Image icon;
  Image image;
  String callToAction;
  String advertiser;
  bool isLoaded = false;

  void loadAd() {
    _channel.invokeMethod("native", {"placement_id": placementId, "id": id});
    _handler = new NativeAdEventHandler(
        onAdLoaded: (data) {
          headline = data['headline'];
          description = data['description'];
          callToAction = data['call_to_action'];
          advertiser = data['advertiser'];
          if (data['icon'] != null) {
            Uint8List list = data['icon'];
            icon = Image.memory(list);
          }
          if (data['image'] != null) {
            Uint8List list = data['image'];
            image = Image.memory(list);
          }
          isLoaded = true;

          onAdLoaded();
        },
        onAdShown: onAdShown,
        onAdClosed: onAdClosed,
        onAdClicked: onAdClicked,
        onAdShowFailed: onAdShowFailed,
        onAdLoadFailed: onAdLoadFailed,
        placementId: placementId,
        id: id);
    _handler.openChannel();
    _handler.loadAd();
  }

  void recordClick() {
    _handler.recordClick();
  }
}

class NativeAdEventHandler {
  final String placementId;
  final NativeAdFunction onAdLoaded;
  final NativeAdEmptyFunction onAdClicked;
  final NativeAdEmptyFunction onAdShown;
  final NativeAdErrorFunction onAdShowFailed;
  final NativeAdErrorFunction onAdLoadFailed;
  final NativeAdEmptyFunction onAdClosed;
  final String id;

  NativeAdEventHandler({this.id,
    this.placementId,
    this.onAdLoaded,
    this.onAdClosed,
    this.onAdClicked,
    this.onAdShowFailed,
    this.onAdLoadFailed,
    this.onAdShown});

  MethodChannel _channel;

  void openChannel() {
    _channel = new MethodChannel("adivery/native_" + id);
    _channel.setMethodCallHandler(handle);
  }

  Future<dynamic> handle(MethodCall call) {
    switch (call.method) {
      case "onAdLoaded":
        onAdLoaded(call.arguments);
        break;
      case "onAdClicked":
        onAdClicked();
        break;
      case "onAdLoadFailed":
        onAdLoadFailed(call.arguments as int);
        break;
      case "onAdShowFailed":
        onAdShowFailed(call.arguments as int);
        break;
      case "onAdShown":
        onAdShown();
        break;
      case "onAdClosed":
        onAdClosed();
        break;
    }
    return true as dynamic;
  }

  void loadAd() {
    _channel.invokeMethod("loadAd");
  }

  void recordClick() {
    _channel.invokeMethod("recordClick");
  }
}
