package com.adivery.plugin;

import android.app.Activity;
import android.graphics.Bitmap;
import android.graphics.drawable.BitmapDrawable;
import android.graphics.drawable.Drawable;

import com.adivery.sdk.Adivery;
import com.adivery.sdk.AdiveryNativeCallback;
import com.adivery.sdk.networks.adivery.AdiveryNativeAd;

import java.io.ByteArrayOutputStream;
import java.util.HashMap;
import java.util.Map;

import io.flutter.plugin.common.BinaryMessenger;
import io.flutter.plugin.common.MethodCall;
import io.flutter.plugin.common.MethodChannel;

public class NativeAd extends BaseAd implements MethodChannel.MethodCallHandler {
    private final Activity activity;
    private final String placementId;
    private final MethodChannel channel;
    private AdiveryNativeAd ad;
    private final AdiveryNativeCallback callback = new AdiveryNativeCallback() {
        @Override
        public void onAdShowFailed(String reason) {
            channel.invokeMethod("onError", reason);
        }

        @Override
        public void onAdLoadFailed(String reason) {
            channel.invokeMethod("onError", reason);
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
        public void onAdLoaded(com.adivery.sdk.NativeAd ad) {
            if (!(ad instanceof AdiveryNativeAd)){
                return;
            }
            NativeAd.this.ad = (AdiveryNativeAd) ad;
            Map<String, Object> data = new HashMap<>();
            data.put("headline", NativeAd.this.ad.getHeadline());
            data.put("description", NativeAd.this.ad.getDescription());
            data.put("advertiser", NativeAd.this.ad.getAdvertiser());
            data.put("call_to_action", NativeAd.this.ad.getCallToAction());
            data.put("icon", readDrawable(NativeAd.this.ad.getIcon()));
            data.put("image", readDrawable(NativeAd.this.ad.getImage()));
            channel.invokeMethod("onAdLoaded", data);
            NativeAd.this.ad.recordImpression();
        }
    };

    public NativeAd(Activity activity, String placementId, String id, BinaryMessenger messenger) {
        super(id);
        this.activity = activity;
        this.placementId = placementId;
        channel = new MethodChannel(messenger, "adivery/native_" + id);
        channel.setMethodCallHandler(this);
    }

    @Override
    public void onMethodCall(MethodCall call, MethodChannel.Result result) {
        switch (call.method) {
            case "loadAd":
                loadAd();
                break;
            case "recordClick":
                if (this.ad != null) {
                    this.ad.recordClick();
                }
                break;
            default:
                result.notImplemented();
        }
        result.success(true);
    }

    private void loadAd() {
        Adivery.requestNativeAd(activity, placementId, callback);
    }
    
    private byte[] readDrawable(Drawable drawable) {
        BitmapDrawable bitmapDrawable = (BitmapDrawable) drawable;
        Bitmap bitmap = bitmapDrawable.getBitmap();
        ByteArrayOutputStream bos = new ByteArrayOutputStream();
        bitmap.compress(Bitmap.CompressFormat.PNG, 100, bos);
        return bos.toByteArray();
    }

}
