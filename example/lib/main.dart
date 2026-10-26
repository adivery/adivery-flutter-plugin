import 'package:adivery/adivery.dart';
import 'package:adivery/adivery_ads.dart';
import 'package:flutter/material.dart';

void main() {
  runApp(MyApp());
}

class MyApp extends StatefulWidget {
  @override
  _MyAppState createState() => _MyAppState();
}

class _MyAppState extends State<MyApp> {
  static const String offerWallPlacementId =
      "9cad440a-8271-49d2-8f81-0819268a5ce4";

  static late _MyAppState instance;

  @override
  void initState() {
    super.initState();
    initPlatformState();
    instance = this;
  }

  void initPlatformState() {
    AdiveryPlugin.initialize("738c5e66-2e4f-4ff0-8118-ef6c8235a5e9");
    AdiveryPlugin.setLoggingEnabled(true);
    AdiveryPlugin.setUserId("test-user");
    AdiveryPlugin.addListener(
        onError: onError,
        onInterstitialLoaded: onInterstitialLoaded,
        onAppOpenAdLoaded: onAppOpenLoaded,
        onRewardedClosed: onRewardedClosed,
        onRewardedLoaded: (placement) => {},
        onOfferWallLoaded: onOfferWallLoaded,
        onOfferWallShown: onOfferWallShown,
        onOfferWallClicked: onOfferWallClicked,
        onOfferWallClosed: onOfferWallClosed,
        onOfferWallMissionRewarded: onOfferWallMissionRewarded);
    AdiveryPlugin.prepareInterstitialAd("5788d25b-b7d6-442c-a562-b4bef582c18c");
    AdiveryPlugin.prepareRewardedAd("29f509a9-3826-4ada-8404-4735aa14b510");
    AdiveryPlugin.prepareAppOpenAd("c0b3bf0e-75a5-4183-ad86-2cc5c07c07d6");
  }

  static void onInterstitialLoaded(String placement) {
    print("interstitial loaded");
  }

  static void onAppOpenLoaded(String placement) {
    print("AppOpen loaded");
  }

  static void onRewardedClosed(String placement, bool isRewarded) {
    print("ad rewarded: " + isRewarded.toString());
    if (isRewarded) {
      instance.setState(() {
        instance._reward += 1;
      });
    }
  }

  static void onError(String placement, String error) {
    print("onError" + error);
    if (placement == offerWallPlacementId) {
      instance.setState(() {
        instance._offerWallLoading = false;
      });
    }
  }

  static void onOfferWallLoaded(String placement) {
    print("OfferWall loaded");
    // The OfferWall is only prepared from its button, so show it right away.
    instance.setState(() {
      instance._offerWallLoading = false;
    });
    AdiveryPlugin.show(placement);
  }

  static void onOfferWallShown(String placement) {
    print("OfferWall shown");
  }

  static void onOfferWallClicked(String placement) {
    print("OfferWall clicked");
  }

  static void onOfferWallClosed(String placement) {
    print("OfferWall closed");
  }

  static void onOfferWallMissionRewarded(
      String placement, String currency, int rewardAmount) {
    print("OfferWall mission rewarded: $rewardAmount $currency");
    instance.setState(() {
      instance._reward += rewardAmount;
    });
  }

  static void _onAdLoaded(Ad ad) {
    print("banner loaded");
  }

  static void _onAdClicked(Ad ad) {
    print("banner clicked");
  }

  static void _onError(Ad ad, String error) {
    print("banner load failed " + error);
  }

  static int _index = 0;

  int _reward = 0;

  bool _offerWallLoading = false;

  NativeAd? nativeAd;

  List<Widget> _widgetOptions = <Widget>[
    Row(
      children: <Widget>[
        BannerAd(
          "06f0c520-3cc8-45c0-bbf1-f866f7eac525",
          BannerAdSize.BANNER,
          onAdLoaded: _onAdLoaded,
          onAdClicked: _onAdClicked,
        ),
      ],
    ),
    Row(
      children: <Widget>[
        BannerAd(
          "06f0c520-3cc8-45c0-bbf1-f866f7eac525",
          BannerAdSize.LARGE_BANNER,
          onAdLoaded: _onAdLoaded,
          onAdClicked: _onAdClicked,
          onError: _onError,
        ),
      ],
    ),
    Row(
      children: <Widget>[
        BannerAd(
          "06f0c520-3cc8-45c0-bbf1-f866f7eac525",
          BannerAdSize.MEDIUM_RECTANGLE,
          onAdLoaded: _onAdLoaded,
          onAdClicked: _onAdClicked,
          onError: _onError,
        ),
      ],
    ),
  ];

  void _onChanged(int index) {
    setState(() {
      _index = index;
    });
  }

  Widget _getBanner() {
    if (_index == 0) {
      return _widgetOptions.elementAt(0);
    } else if (_index == 1) {
      return BannerAd(
        "06f0c520-3cc8-45c0-bbf1-f866f7eac525",
        BannerAdSize.LARGE_BANNER,
        onAdLoaded: _onAdLoaded,
        onAdClicked: _onAdClicked,
        onError: _onError,
      );
    } else {
      return _widgetOptions.elementAt(2);
    }
  }

  _loadInterstitial() {
    var placementId = "5788d25b-b7d6-442c-a562-b4bef582c18c";
    AdiveryPlugin.isLoaded(placementId)
        .then((isLoaded) => showPlacement(isLoaded, placementId));
  }

  _loadAppOpen() {
    var placementId = "c0b3bf0e-75a5-4183-ad86-2cc5c07c07d6";
    AdiveryPlugin.isLoaded(placementId)
        .then((isLoaded) => showAppOpenPlacement(isLoaded, placementId));
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
        home: Scaffold(
            appBar: AppBar(
              title: const Text('Adivery example app'),
            ),
            body: SingleChildScrollView(
              child: Column(
                children: <Widget>[
                  Padding(
                    padding: const EdgeInsets.all(8),
                    child: Text("Your reward is: $_reward"),
                  ),
                  // Fullscreen formats.
                  _buttonRow(<Widget>[
                    ElevatedButton(
                        onPressed: _loadInterstitial,
                        child: Text("InterstitialAd")),
                    ElevatedButton(
                        onPressed: _loadRewardedAd, child: Text("RewardedAd")),
                  ]),
                  _buttonRow(<Widget>[
                    ElevatedButton(
                        onPressed: _loadAppOpen, child: Text("OpenAppAds")),
                    ElevatedButton(
                        onPressed: _offerWallLoading ? null : _loadOfferWallAd,
                        child: Text("OfferWallAd")),
                  ]),
                  const Divider(),
                  // Banner sizes, right above the banner they switch.
                  Wrap(
                    spacing: 8,
                    alignment: WrapAlignment.center,
                    children: <Widget>[
                      ElevatedButton(
                        child: Text("Banner"),
                        onPressed: () {
                          _onChanged(0);
                        },
                      ),
                      ElevatedButton(
                        child: Text("Large Banner"),
                        onPressed: () {
                          _onChanged(1);
                        },
                      ),
                      ElevatedButton(
                        child: Text("Medium Rectangle"),
                        onPressed: () {
                          _onChanged(2);
                        },
                      ),
                    ],
                  ),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceAround,
                    children: <Widget>[_getBanner()],
                  ),
                  const Divider(),
                  // Native ad, right above where it renders.
                  _buttonRow(<Widget>[
                    ElevatedButton(
                        onPressed: _loadNative, child: Text("NativeAd")),
                  ]),
                  _nativeAd()
                ],
              ),
            )));
  }

  Widget _buttonRow(List<Widget> buttons) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      child: Row(
        children: <Widget>[
          for (var i = 0; i < buttons.length; i++) ...[
            if (i > 0) const SizedBox(width: 8),
            Expanded(child: buttons[i]),
          ],
        ],
      ),
    );
  }

  void _loadRewardedAd() {
    var placementId = "29f509a9-3826-4ada-8404-4735aa14b510";
    AdiveryPlugin.isLoaded(placementId)
        .then((isLoaded) => showPlacement(isLoaded, placementId));
  }

  void _loadOfferWallAd() {
    // The OfferWall is only loaded on request (the SDK doesn't prefetch another
    // one after it closes); the button stays disabled until it loads or fails.
    setState(() {
      _offerWallLoading = true;
    });
    AdiveryPlugin.prepareOfferWallAd(offerWallPlacementId);
  }

  Widget _nativeAd() {
    if (nativeAd != null && nativeAd!.isLoaded == true) {
      return Column(
        children: <Widget>[
          Row(
            mainAxisAlignment: MainAxisAlignment.end,
            mainAxisSize: MainAxisSize.max,
            children: <Widget>[
              Flexible(
                flex: 2,
                child: Column(
                  children: <Widget>[
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: <Widget>[
                        if (nativeAd!.callToAction != null)
                          Flexible(
                            flex: 1,
                            child: ElevatedButton(
                              onPressed: () {
                                nativeAd!.recordClick();
                              },
                              child: Text(nativeAd!.callToAction!),
                            ),
                          ),
                        if (nativeAd!.headline != null)
                          Flexible(
                            flex: 2,
                            child: Text(
                              nativeAd!.headline!,
                              style: const TextStyle(
                                color: Colors.black,
                                fontWeight: FontWeight.bold,
                                fontSize: 16,
                              ),
                              textAlign: TextAlign.end,
                            ),
                          ),
                      ],
                    ),
                    if (nativeAd!.description != null)
                      Text(
                        nativeAd!.description!,
                        textAlign: TextAlign.end,
                      ),
                  ],
                ),
              ),
              Flexible(
                flex: 1,
                fit: FlexFit.loose,
                child: Column(
                  children: <Widget>[
                    if (nativeAd!.icon != null) nativeAd!.icon!,
                    if (nativeAd!.advertiser != null)
                      Text(nativeAd!.advertiser!),
                  ],
                ),
              ),
            ],
          ),
          if (nativeAd!.image != null) nativeAd!.image!,
        ],
      );
    } else {
      return Container();
    }
  }

  void _loadNative() {
    nativeAd = new NativeAd(
      "9bc87b9f-3aef-4988-b1d2-2f4e5b67b2c5",
      onAdLoaded: _onNativeAdLoaded,
    );
    nativeAd?.loadAd();
    // call nativeAd.destroy(); when Widget removed;
  }

  void _onNativeAdLoaded() {
    setState(() {});
  }

  void showPlacement(bool? isLoaded, String placementId) {
    if (isLoaded == true) {
      AdiveryPlugin.show(placementId);
    }
  }

  void showAppOpenPlacement(bool? isLoaded, String placementId) {
    if (isLoaded == true) {
      AdiveryPlugin.showAppOpenPlacement(placementId);
    }
  }
}
