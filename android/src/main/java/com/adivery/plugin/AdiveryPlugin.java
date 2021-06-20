package com.adivery.plugin;


import android.app.Activity;
import android.util.Log;

import androidx.annotation.NonNull;

import com.adivery.sdk.Adivery;
import com.adivery.sdk.AdiveryListener;

import java.util.ArrayList;
import java.util.HashMap;
import java.util.List;
import java.util.Map;

import io.flutter.embedding.engine.plugins.FlutterPlugin;
import io.flutter.embedding.engine.plugins.activity.ActivityAware;
import io.flutter.embedding.engine.plugins.activity.ActivityPluginBinding;
import io.flutter.plugin.common.BinaryMessenger;
import io.flutter.plugin.common.MethodCall;
import io.flutter.plugin.common.MethodChannel;
import io.flutter.plugin.common.MethodChannel.MethodCallHandler;
import io.flutter.plugin.common.MethodChannel.Result;
import io.flutter.plugin.common.PluginRegistry.Registrar;

/**
 * AdiveryPlugin
 */
public class AdiveryPlugin implements FlutterPlugin, MethodCallHandler, ActivityAware {

  private static Activity activity;
  private static BinaryMessenger messenger;
  private MethodChannel channel;
  private final List<BaseAd> ads = new ArrayList<>();

  private final AdiveryListener listener = new AdiveryListener(){
    @Override
    public void onRewardedAdShown(@NonNull String placementId) {
      channel.invokeMethod("onRewardedAdShown", placementId);
    }

    @Override
    public void onRewardedAdLoaded(@NonNull String placementId) {
      channel.invokeMethod("onRewardedAdLoaded", placementId);
    }

    @Override
    public void onRewardedAdClosed(@NonNull String placementId, boolean isRewarded) {
      Map<String, Object> arguments = new HashMap<>();
      arguments.put("placement_id", placementId);
      arguments.put("is_rewarded", isRewarded);
      channel.invokeMethod("onRewardedAdClosed", arguments);
    }

    @Override
    public void onRewardedAdClicked(@NonNull String placementId) {
      channel.invokeMethod("onRewardedAdClicked", placementId);
    }

    @Override
    public void onInterstitialAdShown(@NonNull String placementId) {
      channel.invokeMethod("onInterstitialAdShown", placementId);
    }

    @Override
    public void onInterstitialAdLoaded(@NonNull String placementId) {
      channel.invokeMethod("onInterstitialAdLoaded", placementId);
    }

    @Override
    public void onInterstitialAdClosed(@NonNull String placementId) {
      channel.invokeMethod("onInterstitialAdClosed", placementId);
    }

    @Override
    public void onInterstitialAdClicked(@NonNull String placementId) {
      channel.invokeMethod("onInterstitialAdClicked", placementId);
    }

    @Override
    public void onError(@NonNull String placementId, @NonNull String reason) {
      Map<String, String> arguments = new HashMap<>();
      arguments.put("placement_id", placementId);
      arguments.put("reason", reason);
      channel.invokeMethod("onError", arguments);
    }
  };


  @Override
  public void onAttachedToEngine(FlutterPluginBinding flutterPluginBinding) {
    channel = new MethodChannel(flutterPluginBinding.getBinaryMessenger(),
        "adivery_plugin");
    channel.setMethodCallHandler(this);
    messenger = flutterPluginBinding.getBinaryMessenger();

    // factory for banner ad.
    flutterPluginBinding.getPlatformViewRegistry()
        .registerViewFactory("adivery/bannerAd",
            new AdiveryAdViewFactory(flutterPluginBinding.getBinaryMessenger()));
  }


  // handling flutter api v1
  public static void registerWith(Registrar registrar) {
    final MethodChannel channel = new MethodChannel(registrar.messenger(), "adivery_plugin");
    channel.setMethodCallHandler(new AdiveryPlugin());

    activity = registrar.activity();
    messenger = registrar.messenger();

    // factory for banner ad.
    registrar.platformViewRegistry()
        .registerViewFactory("adivery/bannerAd",
            new AdiveryAdViewFactory(registrar.messenger()));
  }

  @Override
  public void onMethodCall(@NonNull MethodCall call, @NonNull Result result) {
    switch (call.method) {
      case "initialize":
        Adivery.configure(activity.getApplication(), (String) call.argument("appId"));
        Adivery.addListener(listener);

        break;
      case "setLoggingEnabled":
        Boolean isLoggingEnabled = call.argument("isLoggingEnabled");
        Adivery.setLoggingEnabled(isLoggingEnabled == null ? false : isLoggingEnabled);
        break;
      case "interstitial":
        requestInterstitialAd((String) call.arguments);
        break;
      case "rewarded":
        requestRewardedAd((String) call.arguments);
        break;
      case "native":
        requestNativeAd((String) call.argument("placement_id"), (String) call.argument("id"));
        break;
      case "isLoaded":
        result.success(Adivery.isLoaded((String) call.arguments));
        return;
      case "show":
        Adivery.showAd((String) call.arguments);
        break;
      case "destroyAd":
        destroyAd((String) call.arguments);
      default:
        result.notImplemented();
    }
    result.success(true);
  }

  public void destroyAd(String id) {
    BaseAd ad = findAd(id);
    if (ad != null) {
      ads.remove(ad);
    }
  }

  private BaseAd findAd(String id) {
    for (BaseAd ad : ads) {
      if (ad.id.equals(id)) {
        return ad;
      }
    }
    return null;
  }

  private void requestNativeAd(String placementId, String id) {
    ads.add(new NativeAd(activity, placementId, id, messenger));
  }

  private void requestRewardedAd(String placementId) {
    Adivery.prepareRewardedAd(activity, placementId);
  }

  private void requestInterstitialAd(String placementId) {
    Adivery.prepareInterstitialAd(activity, placementId);
  }

  @Override
  public void onDetachedFromEngine(@NonNull FlutterPluginBinding binding) {
    channel.setMethodCallHandler(null);
    Adivery.removeListener(listener);
  }

  @Override
  public void onAttachedToActivity(@NonNull ActivityPluginBinding binding) {
    activity = binding.getActivity();
  }

  @Override
  public void onDetachedFromActivityForConfigChanges() {

  }

  @Override
  public void onReattachedToActivityForConfigChanges(@NonNull ActivityPluginBinding binding) {

  }

  @Override
  public void onDetachedFromActivity() {

  }
}
