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
    if (cachePath) {
        [[NSFileManager defaultManager] removeItemAtPath:cachePath error:nil];
    }
}

- (void)applicationWillTerminate:(UIApplication *)application {
    %orig;

    if (YTMU(@"YTMUltimateIsEnabled")) {
        // Clear cache synchronously since app is terminating
        [self ytmu_clearCache];
    }
}

- (void)applicationDidEnterBackground:(UIApplication *)application {
    %orig;

    if (YTMU(@"YTMUltimateIsEnabled")) {
        // Clear cache immediately - don't wait for background task
        [self ytmu_clearCache];
        
        // Also set up background task as backup in case we need more time
        __block UIBackgroundTaskIdentifier task =
            [[UIApplication sharedApplication]
                beginBackgroundTaskWithExpirationHandler:^{
                    [[UIApplication sharedApplication] endBackgroundTask:task];
                    task = UIBackgroundTaskInvalid;
                }];

        if (task != UIBackgroundTaskInvalid) {
            // Clear cache again in background task to ensure it's done
            dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_HIGH, 0), ^{
                [self ytmu_clearCache];
                if (task != UIBackgroundTaskInvalid) {
                    [[UIApplication sharedApplication] endBackgroundTask:task];
                    task = UIBackgroundTaskInvalid;
                }
            });
        }
    }
}

%end
