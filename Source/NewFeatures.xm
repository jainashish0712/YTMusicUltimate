#import <Foundation/Foundation.h>
#import <UIKit/UIKit.h>
#import <objc/runtime.h>
#import <objc/message.h>
#import "Headers/YTPlayerViewController.h"
#import "Headers/YTMWatchViewController.h"
#import "Headers/YTMToastController.h"
#import "Headers/Localization.h"
#import "Headers/YTAlertView.h"

static BOOL YTMU(NSString *key) {
    NSDictionary *dict =
        [[NSUserDefaults standardUserDefaults] dictionaryForKey:@"YTMUltimate"];
    return [dict[key] boolValue];
}

#pragma mark - Feature 1: Always High Audio Quality

@interface YTIMediaQualitySettingOption : NSObject
@property (nonatomic, assign) NSInteger quality;
@end

@interface YTMMediaQualityController : NSObject
- (void)setAudioQuality:(NSInteger)quality;
- (NSInteger)audioQuality;
@end

%hook YTMMediaQualityController
- (NSInteger)audioQuality {
    if (YTMU(@"YTMUltimateIsEnabled") && YTMU(@"alwaysHighQuality")) {
        return 2;
    }
    return %orig;
}

- (void)setAudioQuality:(NSInteger)quality {
    if (YTMU(@"YTMUltimateIsEnabled") && YTMU(@"alwaysHighQuality")) {
        %orig(2);
    } else {
        %orig;
    }
}
%end

%hook YTMSettings
- (NSInteger)audioQuality {
    if (YTMU(@"YTMUltimateIsEnabled") && YTMU(@"alwaysHighQuality")) {
        return 2;
    }
    return %orig;
}

- (void)setAudioQuality:(NSInteger)quality {
    if (YTMU(@"YTMUltimateIsEnabled") && YTMU(@"alwaysHighQuality")) {
        %orig(2);
    } else {
        %orig;
    }
}

- (BOOL)isHighQualityAudioEnabled {
    if (YTMU(@"YTMUltimateIsEnabled") && YTMU(@"alwaysHighQuality")) {
        return YES;
    }
    return %orig;
}
%end

%hook YTIStreamingData
- (id)adaptiveFormats {
    return %orig;
}
%end

%hook YTMQualitySettings
- (BOOL)allowHighQualityAudio {
    if (YTMU(@"YTMUltimateIsEnabled") && YTMU(@"alwaysHighQuality")) {
        return YES;
    }
    return %orig;
}

- (BOOL)preferHighQualityAudio {
    if (YTMU(@"YTMUltimateIsEnabled") && YTMU(@"alwaysHighQuality")) {
        return YES;
    }
    return %orig;
}
%end

#pragma mark - Feature 2: Skip Disliked Songs

%hook YTMQueueController
%new
- (void)checkAndSkipDislikedSong {
    id currentItem = [self valueForKey:@"_currentItem"];
    if (!currentItem) return;

    NSInteger likeStatus = [[currentItem valueForKey:@"likeStatus"] integerValue];
    if (likeStatus == 2) {
        dispatch_async(dispatch_get_main_queue(), ^{
            [[%c(YTMToastController) alloc] showMessage:LOC(@"SKIPPED_DISLIKED")];
        });

        dispatch_after(dispatch_time(DISPATCH_TIME_NOW, 0.5 * NSEC_PER_SEC),
                       dispatch_get_main_queue(), ^{
            [self advanceToNextItem];
        });
    }
}

- (void)advanceToNextItem {
    %orig;

    if (YTMU(@"YTMUltimateIsEnabled") && YTMU(@"skipDislikedSongs")) {
        [self checkAndSkipDislikedSong];
    }
}
%end

#pragma mark - Feature 3: Discord Rich Presence (basic)

@interface YTMUDiscordRPC : NSObject
+ (instancetype)sharedInstance;
- (void)updatePresenceWithTitle:(NSString *)title artist:(NSString *)artist;
- (void)clearPresence;
@end

%subclass YTMUDiscordRPC : NSObject

+ (instancetype)sharedInstance {
    static YTMUDiscordRPC *instance;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        instance = [self new];
    });
    return instance;
}

%new
- (void)updatePresenceWithTitle:(NSString *)title artist:(NSString *)artist {
    if (!YTMU(@"YTMUltimateIsEnabled") || !YTMU(@"discordRPC")) return;

    NSDictionary *nowPlaying = @{
        @"title": title ?: @"",
        @"artist": artist ?: @""
    };

    [[NSUserDefaults standardUserDefaults]
        setObject:nowPlaying
           forKey:@"YTMUltimate_NowPlaying"];
}

%new
- (void)clearPresence {
    [[NSUserDefaults standardUserDefaults]
        removeObjectForKey:@"YTMUltimate_NowPlaying"];
}
%end

%hook YTPlayerViewController
- (void)playbackControllerDidStopPlaying:(id)controller {
    %orig;

    if (YTMU(@"YTMUltimateIsEnabled") && YTMU(@"discordRPC")) {
        [[%c(YTMUDiscordRPC) sharedInstance] clearPresence];
    }
}
%end

#pragma mark - Feature 4: Auto Clear Cache on Close

@interface YTMAppDelegate : UIResponder <UIApplicationDelegate>
@end

%hook YTMAppDelegate
%new
- (void)clearCache {
    dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_LOW, 0), ^{
        NSString *cachePath =
            NSSearchPathForDirectoriesInDomains(NSCachesDirectory,
                                                NSUserDomainMask,
                                                YES).firstObject;
        if (!cachePath) return;

        [[NSFileManager defaultManager]
            removeItemAtPath:cachePath
                       error:nil];
    });
}

- (void)applicationWillTerminate:(UIApplication *)application {
    %orig;

    if (YTMU(@"YTMUltimateIsEnabled") && YTMU(@"autoClearCacheOnClose")) {
        [self clearCache];
    }
}
%end

%ctor {
    NSMutableDictionary *dict =
        [NSMutableDictionary dictionaryWithDictionary:
            [[NSUserDefaults standardUserDefaults]
                dictionaryForKey:@"YTMUltimate"] ?: @{}];

    NSArray *keys = @[
        @"alwaysHighQuality",
        @"skipDislikedSongs",
        @"discordRPC",
        @"autoClearCacheOnClose"
    ];

    for (NSString *key in keys) {
        if (!dict[key]) {
            dict[key] = @([key isEqual:@"autoClearCacheOnClose"]);
        }
    }

    [[NSUserDefaults standardUserDefaults]
        setObject:dict
           forKey:@"YTMUltimate"];
}
