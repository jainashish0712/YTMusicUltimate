#import <Foundation/Foundation.h>
#import <UIKit/UIKit.h>

static BOOL YTMU(NSString *key) {
    NSDictionary *dict =
        [[NSUserDefaults standardUserDefaults] dictionaryForKey:@"YTMUltimate"];
    return [dict[key] boolValue];
}

@interface YTMAppDelegate : UIResponder
- (void)ytmu_clearCache;
@end

%hook YTMAppDelegate

%new
- (void)ytmu_clearCache {
    NSString *cachePath = NSSearchPathForDirectoriesInDomains(NSCachesDirectory, NSUserDomainMask, YES).firstObject;
    [[NSFileManager defaultManager] removeItemAtPath:cachePath error:nil];
}

- (void)applicationWillTerminate:(UIApplication *)application {
    %orig;

    if (YTMU(@"YTMUltimateIsEnabled")) {
        [self ytmu_clearCache];
    }
}

- (void)applicationDidEnterBackground:(UIApplication *)application {
    %orig;

    if (YTMU(@"YTMUltimateIsEnabled")) {
        __block UIBackgroundTaskIdentifier task =
            [[UIApplication sharedApplication]
                beginBackgroundTaskWithExpirationHandler:^{
                    [[UIApplication sharedApplication] endBackgroundTask:task];
                    task = UIBackgroundTaskInvalid;
                }];

        dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
            [self ytmu_clearCache];
            [[UIApplication sharedApplication] endBackgroundTask:task];
            task = UIBackgroundTaskInvalid;
        });
    }
}

%end
