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

- (BOOL)application:(UIApplication *)application didFinishLaunchingWithOptions:(NSDictionary *)launchOptions {
    BOOL result = %orig;
    
    if (YTMU(@"YTMUltimateIsEnabled")) {
        // Clear cache on app launch - most reliable method
        // This clears cache from the previous session before the new session starts
        dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
            [self ytmu_clearCache];
        });
    }
    
    return result;
}

%end
