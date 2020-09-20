package com.adivery.plugin;

import android.app.Activity;
import android.graphics.Bitmap;
import android.graphics.drawable.BitmapDrawable;
import android.graphics.drawable.Drawable;

import androidx.annotation.NonNull;

import com.adivery.sdk.Adivery;
import com.adivery.sdk.AdiveryNativeAd;
import com.adivery.sdk.AdiveryNativeCallback;

import java.io.ByteArrayOutputStream;
import java.util.HashMap;
import java.util.Map;

import io.flutter.plugin.common.BinaryMessenger;
import io.flutter.plugin.common.MethodCall;
import io.flutter.plugin.common.MethodChannel;

public class NativeAd extends AdiveryNativeCallback implements MethodChannel.MethodCallHandler {
    private final Activity activity;
    private final String placementId;
    private final MethodChannel channel;
    private AdiveryNativeAd ad;

    public NativeAd(Activity activity, String placementId, String id, BinaryMessenger messenger) {

        this.activity = activity;
        this.placementId = placementId;
        channel = new MethodChannel(messenger, "adivery/native_" + id);
        channel.setMethodCallHandler(this);
    }

    @Override
    public void onMethodCall(@NonNull MethodCall call, @NonNull MethodChannel.Result result) {
        switch (call.method) {
            case "loadAd":
                loadAd();
                break;
            case "recordClick":
                if (this.ad != null) {
                    this.ad.recordClick();
                }
                break;
            case "recordImpression":
                if (this.ad != null) {
                    this.ad.recordImpression();
                }
                break;
            default:
                result.notImplemented();
        }
        result.success(true);
    }

    private void loadAd() {
        Adivery.requestNativeAd(activity, placementId, this);
    }

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
    public void onAdLoaded(AdiveryNativeAd ad) {
        this.ad = ad;
        Map<String, Object> data = new HashMap<>();
        data.put("headline", ad.getHeadline());
        data.put("description", ad.getDescription());
        data.put("advertiser", ad.getAdvertiser());
        data.put("call_to_action", ad.getCallToAction());
        data.put("icon", readDrawable(ad.getIcon()));
        data.put("image", readDrawable(ad.getImage()));
        channel.invokeMethod("onAdLoaded", data);
    }

    private byte[] readDrawable(Drawable drawable) {
        BitmapDrawable bitmapDrawable = (BitmapDrawable) drawable;
        Bitmap bitmap = bitmapDrawable.getBitmap();
        ByteArrayOutputStream bos = new ByteArrayOutputStream();
        bitmap.compress(Bitmap.CompressFormat.PNG, 100, bos);
        return bos.toByteArray();
    }

}
