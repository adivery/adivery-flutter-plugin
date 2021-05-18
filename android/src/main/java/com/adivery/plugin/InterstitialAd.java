package com.adivery.plugin;

import android.app.Activity;

import androidx.annotation.NonNull;

import com.adivery.sdk.Adivery;
import com.adivery.sdk.AdiveryInterstitialCallback;
import com.adivery.sdk.AdiveryLoadedAd;

import io.flutter.plugin.common.BinaryMessenger;
import io.flutter.plugin.common.MethodCall;
import io.flutter.plugin.common.MethodChannel;

public class InterstitialAd extends BaseAd implements MethodChannel.MethodCallHandler {
    private Activity activity;
    private final String placementId;
    private final MethodChannel channel;
    private AdiveryLoadedAd ad;
    private final AdiveryInterstitialCallback callback = new AdiveryInterstitialCallback() {
        @Override
        public void onAdShowFailed(int errorCode) {
            channel.invokeMethod("onAdShowFailed", errorCode);
        }

        @Override
        public void onAdLoadFailed(int errorCode) {
            channel.invokeMethod("onAdLoadFailed", errorCode);
        }

        @Override
        public void onAdClicked() {
            channel.invokeMethod("onAdClicked", null);
        }

        @Override
        public void onAdShown() {
            channel.invokeMethod("onAdShown", null);
        }

        @Override
        public void onAdLoaded(AdiveryLoadedAd ad) {
            InterstitialAd.this.ad = ad;
            channel.invokeMethod("onAdLoaded", null);
        }

        @Override
        public void onAdClosed() {
            channel.invokeMethod("onAdClosed", null);
        }
    };

    public InterstitialAd(Activity activity, String placementId, String id, BinaryMessenger messenger) {
        super(id);
        this.activity = activity;

        this.placementId = placementId;
        channel = new MethodChannel(messenger, "adivery/interstitial_" + id);
        channel.setMethodCallHandler(this);
    }

    @Override
    public void onMethodCall(@NonNull MethodCall call, @NonNull MethodChannel.Result result) {
        switch (call.method) {
            case "loadAd":
                loadAd();
                break;
            case "show":
                showAd();
                break;
            default:
                result.notImplemented();
        }
        result.success(null);
    }

    private void showAd() {
        if (this.ad != null) {
            this.ad.show();
        }
    }

    private void loadAd() {
        Adivery.requestInterstitialAd(activity, placementId, callback);
    }


}
