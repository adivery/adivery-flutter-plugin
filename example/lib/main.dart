import 'package:flutter/material.dart';

import 'package:adivery/adivery.dart';
import 'package:adivery/adivery_ads.dart';

void main() {
  runApp(MyApp());
}

class MyApp extends StatefulWidget {
  @override
  _MyAppState createState() => _MyAppState();
}

class _MyAppState extends State<MyApp> {
  @override
  void initState() {
    super.initState();
    initPlatformState();
  }

  void initPlatformState() {
    AdiveryPlugin.initialize("7e27fb38-5aff-473a-998f-437b89426f66");
  }

  static void _onAdLoaded(Ad ad) {
    print("banner loaded");
  }

  static void _onAdClicked(Ad ad) {
    print("banner clicked");
  }

  static int _index = 0;

  int _reward = 0;

  NativeAd nativeAd;

  List<Widget> _widgetOptions = <Widget>[
    Row(
      children: <Widget>[
        BannerAd(
          placementId: "2f71ec44-f30a-4043-9cc1-f32347a07f8b",
          bannerType: BannerAdSize.BANNER,
          onAdLoaded: _onAdLoaded,
          onAdClicked: _onAdClicked,
        ),
      ],
    ),
    Row(
      children: <Widget>[
        BannerAd(
          placementId: "ee1b7e7e-9b9b-4c91-8033-a66ca2a026ed",
          bannerType: BannerAdSize.LARGE_BANNER,
          onAdLoaded: _onAdLoaded,
          onAdClicked: _onAdClicked,
        ),
      ],
    ),
    Row(
      children: <Widget>[
        BannerAd(
          placementId: "5f2c4c86-a6ec-4735-9a44-f881fe40789f",
          bannerType: BannerAdSize.MEDIUM_RECTANGLE,
          onAdLoaded: _onAdLoaded,
          onAdClicked: _onAdClicked,
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
        placementId: "ee1b7e7e-9b9b-4c91-8033-a66ca2a026ed",
        bannerType: BannerAdSize.LARGE_BANNER,
        onAdLoaded: _onAdLoaded,
        onAdClicked: _onAdClicked,
      );
    } else {
      return _widgetOptions.elementAt(2);
    }
  }

  _loadInterstitial() {
    InterstitialAd(
        placementId: "de5db046-765d-478f-bb2e-30dc2eaf3f51",
        onAdLoaded: (ad) {
          ad.show();
        },
        onAdShown: (ad) {
          print("interstitialAd shown");
        },
        onAdLoadFailed: (ad, code) {
          print("show ad failed");
        }).loadAd();
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
                          child: RaisedButton(
                            child: Text("Banner"),
                            onPressed: () {
                              _onChanged(0);
                            },
                          ),
                        ),
                        Flexible(
                          flex: 1,
                          child: RaisedButton(
                            child: Text("Large Banner"),
                            onPressed: () {
                              _onChanged(1);
                            },
                          ),
                        ),
                        Flexible(
                          flex: 1,
                          child: RaisedButton(
                            child: Text("Normal Square"),
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
                            child: RaisedButton(
                                onPressed: _loadInterstitial,
                                child: Text("InterstitialAd"))),
                        Flexible(
                          child: RaisedButton(
                            onPressed: _loadRewardedAd,
                            child: Text("RewardedAd"),
                          ),
                        ),
                        Flexible(
                          child: RaisedButton(
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
    RewardedAd(
        placementId: "3f97dc4d-3e09-4024-acaf-931862c03ba8",
        onAdLoaded: (ad) {
          ad.show();
        },
        onAdRewarded: (ad) {
          print("Ad rewarded");
          setState(() {
            _reward += 100;
          });
        }).loadAd();
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
                          child: RaisedButton(
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
        placementId: "103ea0d3-7b1d-458e-ac9d-a3165e7634d2",
        onAdLoaded: _onNativeAdLoaded);
    nativeAd.loadAd();
  }

  void _onNativeAdLoaded() {
    setState(() {});
  }
}
