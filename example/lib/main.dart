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
  static _MyAppState instance;

  @override
  void initState() {
    super.initState();
    initPlatformState();
    instance = this;
  }

  void initPlatformState() {
    AdiveryPlugin.initialize("59c36ce3-7125-40a7-bd34-144e6906c796");
    AdiveryPlugin.setLoggingEnabled(true);
    AdiveryPlugin.prepareInterstitialAd("915fc1d8-9bc1-47b8-96fb-751e7ebf540b");
    AdiveryPlugin.prepareRewardedAd("59007992-f059-4aba-8229-94342e48cad7");
    AdiveryPlugin.addListener(
        onError: onError,
        onInterstitialLoaded: onInterstitialLoaded,
        onRewardedClosed: onRewardedClosed,
        onRewardedLoaded: (placement) => {});
  }

  static void onInterstitialLoaded(String placement) {
    print("interstitial loaded");
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

  NativeAd nativeAd;

  List<Widget> _widgetOptions = <Widget>[
    Row(
      children: <Widget>[
        BannerAd(
          "2f71ec44-f30a-4043-9cc1-f32347a07f8b",
          BannerAdSize.BANNER,
          onAdLoaded: _onAdLoaded,
          onAdClicked: _onAdClicked,
        ),
      ],
    ),
    Row(
      children: <Widget>[
        BannerAd(
          "2f71ec44-f30a-4043-9cc1-f32347a07f8b",
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
          "2f71ec44-f30a-4043-9cc1-f32347a07f8b",
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
        "2f71ec44-f30a-4043-9cc1-f32347a07f8b",
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
    var placementId = "915fc1d8-9bc1-47b8-96fb-751e7ebf540b";
    AdiveryPlugin.isLoaded(placementId)
        .then((isLoaded) => showPlacement(isLoaded, placementId));
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
        home: Scaffold(
            appBar: AppBar(
              title: const Text('Adivery example app'),
            ),
            body: Center(
              child: Container(
                child: Column(
                  children: <Widget>[
                    Center(
                      child: Text("Your reward is: $_reward"),
                    ),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: <Widget>[
                        Flexible(
                          flex: 1,
                          fit: FlexFit.tight,
                          child: ElevatedButton(
                            child: Text("Banner"),
                            onPressed: () {
                              _onChanged(0);
                            },
                          ),
                        ),
                        Flexible(
                          flex: 1,
                          child: ElevatedButton(
                            child: Text("Large Banner"),
                            onPressed: () {
                              _onChanged(1);
                            },
                          ),
                        ),
                        Flexible(
                          flex: 1,
                          child: ElevatedButton(
                            child: Text("Medium Rectangle"),
                            onPressed: () {
                              _onChanged(2);
                            },
                          ),
                        ),
                      ],
                    ),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceAround,
                      children: <Widget>[_getBanner()],
                    ),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceAround,
                      children: <Widget>[
                        Flexible(
                            child: ElevatedButton(
                                onPressed: _loadInterstitial,
                                child: Text("InterstitialAd"))),
                        Flexible(
                          child: ElevatedButton(
                            onPressed: _loadRewardedAd,
                            child: Text("RewardedAd"),
                          ),
                        ),
                        Flexible(
                          child: ElevatedButton(
                            onPressed: _loadNative,
                            child: Text("NativeAd"),
                          ),
                        )
                      ],
                    ),
                    _nativeAd()
                  ],
                ),
              ),
            )));
  }

  void _loadRewardedAd() {
    var placementId = "59007992-f059-4aba-8229-94342e48cad7";
    AdiveryPlugin.isLoaded(placementId)
        .then((isLoaded) => showPlacement(isLoaded, placementId));
  }

  Widget _nativeAd() {
    if (nativeAd != null && nativeAd.isLoaded) {
      return Column(
        children: <Widget>[
          Row(
              mainAxisAlignment: MainAxisAlignment.end,
              mainAxisSize: MainAxisSize.max,
              children: <Widget>[
                Flexible(
                  flex: 2,
                  child: Column(children: <Widget>[
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: <Widget>[
                        Flexible(
                          flex: 1,
                          child: ElevatedButton(
                            onPressed: () {
                              nativeAd.recordClick();
                            },
                            child: Text(nativeAd.callToAction),
                          ),
                        ),
                        Flexible(
                          flex: 2,
                          child: Text(
                            nativeAd.headline,
                            style: TextStyle(
                                color: Colors.black,
                                fontWeight: FontWeight.bold,
                                fontSize: 16),
                            textAlign: TextAlign.end,
                          ),
                        )
                      ],
                    ),
                    Text(
                      nativeAd.description,
                      textAlign: TextAlign.end,
                    )
                  ]),
                ),
                Flexible(
                  flex: 1,
                  fit: FlexFit.loose,
                  child: Column(
                    children: <Widget>[
                      nativeAd.icon,
                      Text(nativeAd.advertiser)
                    ],
                  ),
                ),
              ]),
          nativeAd.image,
        ],
      );
    } else {
      return Container();
    }
  }

  void _loadNative() {
    nativeAd = new NativeAd(
      "25928bf1-d4f7-432c-aaf7-1780602796c3",
      onAdLoaded: _onNativeAdLoaded,
    );
    nativeAd.loadAd();
    // call nativeAd.destroy(); when Widget removed;
  }

  void _onNativeAdLoaded() {
    setState(() {});
  }

  void showPlacement(bool isLoaded, String placementId) {
    if (isLoaded) {
      AdiveryPlugin.show(placementId);
    }
  }
}
