#import "AdiveryPlugin.h"

@implementation AdiveryPlugin
+ (void)registerWithRegistrar:(NSObject<FlutterPluginRegistrar>*)registrar {
  FlutterMethodChannel* channel = [FlutterMethodChannel
      methodChannelWithName:@"adivery_plugin"
            binaryMessenger:[registrar messenger]];
  AdiveryPlugin* instance = [[AdiveryPlugin alloc] init];
  [registrar addMethodCallDelegate:instance channel:channel];
}

- (void)handleMethodCall:(FlutterMethodCall*)call result:(FlutterResult)result {
   result(@(success));
}

@end
