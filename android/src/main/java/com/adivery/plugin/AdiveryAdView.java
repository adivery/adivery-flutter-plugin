package com.adivery.plugin;

import android.content.Context;
import android.view.View;
import android.view.ViewGroup;
import android.widget.LinearLayout;

import com.adivery.sdk.Adivery;
import com.adivery.sdk.AdiveryBannerCallback;
import com.adivery.sdk.BannerType;


import java.util.Map;

import io.flutter.plugin.common.BinaryMessenger;
import io.flutter.plugin.common.MethodChannel;
import io.flutter.plugin.platform.PlatformView;

public class AdiveryAdView extends AdiveryBannerCallback implements PlatformView {
    private LinearLayout layout;
    private final MethodChannel channel;
    private String placementId = null;
    private String bannerType = null;

    public AdiveryAdView(Context context,int id, BinaryMessenger messenger, Object args) {
        this.layout = new LinearLayout(context);

        if (args instanceof Map) {
            Map<Object, Object> map = (Map<Object, Object>) args;
            this.placementId = (String) map.get("placement_id");
            this.bannerType = (String) map.get("banner_type");
        }

        channel = new MethodChannel(messenger, "adivery/banner_" + id);

        requestAd();
    }

    private void requestAd() {
        if (placementId == null || bannerType == null) {
            return;
        }
        BannerType bannerType = getBannerType();
        Adivery.requestBannerAd(layout.getContext(), placementId, bannerType, this);
    }

    private BannerType getBannerType() {
        if (bannerType.equalsIgnoreCase("banner")) {
            return BannerType.BANNER;
        } else if (bannerType.equalsIgnoreCase("large_banner")) {
            return BannerType.LARGE_BANNER;
        } else return BannerType.MEDIUM_RECTANGLE;
    }

    @Override
    public void onAdLoaded(View adView) {
        LinearLayout.LayoutParams params =
                new LinearLayout.LayoutParams(ViewGroup.LayoutParams.MATCH_PARENT, ViewGroup.LayoutParams.MATCH_PARENT);
        adView.setLayoutParams(params);
        layout.addView(adView);
        channel.invokeMethod("onAdLoaded", null);
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
    public View getView() {
        return layout;
    }

    @Override
    public void dispose() {
        channel.setMethodCallHandler(null);
    }
}
