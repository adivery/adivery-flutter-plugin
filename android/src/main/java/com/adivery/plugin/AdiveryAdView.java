package com.adivery.plugin;

import android.content.Context;
import android.view.View;
import android.view.ViewGroup;
import android.widget.LinearLayout;

import com.adivery.sdk.AdiveryAdListener;
import com.adivery.sdk.AdiveryBannerAdView;
import com.adivery.sdk.BannerSize;


import java.util.Map;

import io.flutter.plugin.common.BinaryMessenger;
import io.flutter.plugin.common.MethodChannel;
import io.flutter.plugin.platform.PlatformView;

public class AdiveryAdView extends AdiveryAdListener implements PlatformView {
  private LinearLayout layout;
  private final MethodChannel channel;
  private String placementId = null;
  private String bannerType = null;

  public AdiveryAdView(Context context, int id, BinaryMessenger messenger, Object args) {
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
    BannerSize bannerSize = getBannerType();
    AdiveryBannerAdView adView = new AdiveryBannerAdView(layout.getContext());
    adView.setPlacementId(placementId);
    adView.setBannerSize(bannerSize);
    adView.setBannerAdListener(this);
    LinearLayout.LayoutParams params =
        new LinearLayout.LayoutParams(ViewGroup.LayoutParams.MATCH_PARENT, ViewGroup.LayoutParams.MATCH_PARENT);
    adView.setLayoutParams(params);
    adView.loadAd();
    layout.addView(adView);
  }

  private BannerSize getBannerType() {
    if (bannerType.equalsIgnoreCase("banner")) {
      return BannerSize.BANNER;
    } else if (bannerType.equalsIgnoreCase("large_banner")) {
      return BannerSize.LARGE_BANNER;
    } else if (bannerType.equalsIgnoreCase("smart")) {
      return BannerSize.SMART_BANNER;
    } else {
      return BannerSize.MEDIUM_RECTANGLE;
    }
  }

  @Override
  public void onAdLoaded() {
    channel.invokeMethod("onAdLoaded", null);
  }

  @Override
  public void onAdClicked() {
    channel.invokeMethod("onAdClicked", null);
  }

  @Override
  public void onError(String reason) {
    channel.invokeMethod("onAdLoadFailed", reason);
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
