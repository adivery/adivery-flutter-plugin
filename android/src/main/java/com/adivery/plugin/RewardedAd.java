package com.adivery.plugin;

import android.app.Activity;

import androidx.annotation.NonNull;

import com.adivery.sdk.Adivery;
import com.adivery.sdk.AdiveryLoadedAd;
import com.adivery.sdk.AdiveryRewardedCallback;

import io.flutter.plugin.common.BinaryMessenger;
import io.flutter.plugin.common.MethodCall;
import io.flutter.plugin.common.MethodChannel;

public class RewardedAd extends AdiveryRewardedCallback implements MethodChannel.MethodCallHandler {

    private final Activity activity;
    private final String placementId;
    private final MethodChannel channel;
    private AdiveryLoadedAd ad;

    public RewardedAd(Activity activity, String placementId, String id, BinaryMessenger messenger) {

        this.activity = activity;
        this.placementId = placementId;
        channel = new MethodChannel(messenger, "adivery/rewarded_" + id);
        channel.setMethodCallHandler(this);
    }

    @Override
    public void onMethodCall(@NonNull MethodCall call, @NonNull MethodChannel.Result result) {
        switch (call.method) {
            case "loadAd":
                loadAd();
                break;
            case "show":
                show();
                break;
            default:
                result.notImplemented();
        }
        result.success(true);
    }

    private void show() {
        if (this.ad != null) {
            this.ad.show();
        }
    }

    private void loadAd() {
        Adivery.requestRewardedAd(activity, placementId, this);
    }

    @Override
    public void onAdLoaded(AdiveryLoadedAd ad) {
        this.ad = ad;
        channel.invokeMethod("onAdLoaded", null);
    }

    @Override
    public void onAdClosed() {
        channel.invokeMethod("onAdClosed", null);
    }

    @Override
    public void onAdShown() {
        channel.invokeMethod("onAdShown", null);
    }

    @Override
    public void onAdClicked() {
        channel.invokeMethod("onAdClicked", null);
    }

    @Override
    public void onAdLoadFailed(int errorCode) {
        channel.invokeMethod("onAdLoadFailed", errorCode);
    }

    @Override
    public void onAdShowFailed(int errorCode) {
        channel.invokeMethod("onAdShowFailed", errorCode);
    }

    @Override
    public void onAdRewarded() {
        channel.invokeMethod("onAdRewarded", null);
    }
}
