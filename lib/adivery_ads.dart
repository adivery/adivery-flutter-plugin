import 'dart:typed_data';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

abstract class Ad {
  void show();

  void loadAd();
}

typedef NativeAdEmptyFunction = void Function();
typedef NativeAdErrorFunction = void Function(String reason);

typedef EmptyFunction = void Function(Ad ad);
typedef ErrorFunction = void Function(Ad ad, String reason);
typedef NativeAdFunction = void Function(Map<dynamic, dynamic> nativeAd);

enum BannerAdSize { BANNER, LARGE_BANNER, MEDIUM_RECTANGLE }

class BannerAd extends StatefulWidget {
  final String placementId;
  final BannerAdSize bannerSize;

  final EmptyFunction? onAdLoaded;
  final ErrorFunction? onError;
  final EmptyFunction? onAdClicked;


  const BannerAd(
    this.placementId,
    this.bannerSize, {
    Key? key,
    this.onAdLoaded,
    this.onError,
    this.onAdClicked,
  }) : super(key: key);

  @override
  State<StatefulWidget> createState() => _TextViewState(placementId, bannerSize,
      onAdClicked: onAdClicked,
      onAdLoaded: onAdLoaded,
      onError: onError);
}

class _TextViewState extends State<BannerAd> {
  final String placementId;
  final BannerAdSize bannerType;

  final EmptyFunction? onAdLoaded;
  final ErrorFunction? onError;
  final EmptyFunction? onAdClicked;

  _TextViewState(
    this.placementId,
    this.bannerType, {
    this.onAdLoaded,
    this.onError,
    this.onAdClicked,
  }) : super();

  void _onPlatformViewCreated(int id) {
    BannerAdEventHandler handler = new BannerAdEventHandler(id, bannerType,
        onAdLoaded: onAdLoaded,
        onAdClicked: onAdClicked,
        onError: onError);
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

  double getBannerHeight(BannerAdSize? bannerType) {
    if (bannerType == BannerAdSize.BANNER) {
      return 50;
    } else if (bannerType == BannerAdSize.LARGE_BANNER) {
      return 100;
    } else {
      return 250;
    }
  }

  double getBannerWidth(BannerAdSize? bannerType) {
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
  final BannerAdSize bannerSize;

  final EmptyFunction? onAdLoaded;
  final ErrorFunction? onError;
  final EmptyFunction? onAdClicked;

  late MethodChannel _channel;

  BannerAdEventHandler(
    this.id,
    this.bannerSize, {
    this.onAdLoaded,
    this.onError,
    this.onAdClicked,
  });

  void openChannel() {
    _channel = new MethodChannel("adivery/banner_" + id.toString());
    _channel.setMethodCallHandler(handle);
  }

  Future<dynamic> handle(MethodCall call) {
    switch (call.method) {
      case "onAdLoaded":
        onAdLoaded?.call(this);
        break;
      case "onAdClicked":
        onAdClicked?.call(this);
        break;
      case "onAdLoadFailed":
        onError?.call(this, call.arguments as String);
        break;
      case "onAdShowFailed":
        onError?.call(this, call.arguments as String);
        break;
    }
    return true as dynamic;
  }

  @override
  void loadAd() {}

  @override
  void show() {}
}

class NativeAd {
  static const MethodChannel _channel = const MethodChannel('adivery_plugin');

  final String placementId;
  final NativeAdEmptyFunction? onAdLoaded;
  final NativeAdEmptyFunction? onAdClicked;
  final NativeAdEmptyFunction? onAdShown;
  final NativeAdErrorFunction? onError;
  final NativeAdEmptyFunction? onAdClosed;
  final String id = UniqueKey().toString();


  NativeAd(this.placementId,
      {this.onAdLoaded,
      this.onAdClosed,
      this.onAdClicked,
      this.onError,
      this.onAdShown});

  late NativeAdEventHandler _handler;

  String? headline;
  String? description;
  Image? icon;
  Image? image;
  String? callToAction;
  String? advertiser;
  bool isLoaded = false;

  void loadAd() {
    _channel.invokeMethod("native", {"placement_id": placementId, "id": id});
    _handler = new NativeAdEventHandler(
      id,
      placementId,
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

        onAdLoaded?.call();
      },
      onAdShown: onAdShown,
      onAdClosed: onAdClosed,
      onAdClicked: onAdClicked,
      onError: onError,
    );
    _handler.openChannel();
    _handler.loadAd();
  }

  void recordClick() {
    _handler.recordClick();
  }

  void destroy() {
    _channel.invokeListMethod("destroyAd", id);
  }
}

class NativeAdEventHandler {
  final String placementId;
  final NativeAdFunction? onAdLoaded;
  final NativeAdEmptyFunction? onAdClicked;
  final NativeAdEmptyFunction? onAdShown;
  final NativeAdErrorFunction? onError;
  final NativeAdEmptyFunction? onAdClosed;
  final String id;

  NativeAdEventHandler(this.id, this.placementId,
      {this.onAdLoaded,
      this.onAdClosed,
      this.onAdClicked,
      this.onError,
      this.onAdShown});

  late MethodChannel _channel;

  void openChannel() {
    _channel = new MethodChannel("adivery/native_" + id);
    _channel.setMethodCallHandler(handle);
  }

  Future<dynamic> handle(MethodCall call) {
    switch (call.method) {
      case "onAdLoaded":
        onAdLoaded?.call(call.arguments);
        break;
      case "onAdClicked":
        onAdClicked?.call();
        break;
      case "onAdLoadFailed":
        onError?.call(call.arguments as String);
        break;
      case "onAdShowFailed":
        onError?.call(call.arguments as String);
        break;
      case "onAdShown":
        onAdShown?.call();
        break;
      case "onAdClosed":
        onAdClosed?.call();
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
