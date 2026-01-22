#import <Foundation/Foundation.h>
#import <UIKit/UIKit.h>
#import <objc/runtime.h>
#import <objc/message.h>
#import "Headers/YTPlayerViewController.h"
#import "Headers/YTMToastController.h"
#import "Headers/Localization.h"

static BOOL YTMU(NSString *key) {
    NSDictionary *dict =
        [[NSUserDefaults standardUserDefaults] dictionaryForKey:@"YTMUltimate"];
    return [dict[key] boolValue];
}

#pragma mark - Always High Audio Quality

%hook YTMMediaQualityController
- (NSInteger)audioQuality {
    if (YTMU(@"YTMUltimateIsEnabled") && YTMU(@"alwaysHighQuality")) {
        return 2;
    }
    return %orig;
}

- (void)setAudioQuality:(NSInteger)quality {
    %orig(YTMU(@"alwaysHighQuality") ? 2 : quality);
}
%end

#pragma mark - Skip Disliked Songs

%hook YTMQueueController

%new
- (void)checkAndSkipDislikedSong {
    SEL valueForKeySel = @selector(valueForKey:);
    id currentItem =
        ((id (*)(id, SEL, id))objc_msgSend)(self, valueForKeySel, @"_currentItem");

    if (!currentItem) return;

    SEL likeStatusSel = NSSelectorFromString(@"likeStatus");
    if (!class_getInstanceMethod(object_getClass(currentItem), likeStatusSel)) return;

    NSInteger status =
        ((NSInteger (*)(id, SEL))objc_msgSend)(currentItem, likeStatusSel);

    if (status == 2) {
        dispatch_async(dispatch_get_main_queue(), ^{
            [[%c(YTMToastController) alloc]
                showMessage:LOC(@"SKIPPED_DISLIKED")];
        });

        dispatch_after(dispatch_time(DISPATCH_TIME_NOW, 0.5 * NSEC_PER_SEC),
                       dispatch_get_main_queue(), ^{
            SEL nextSel = @selector(advanceToNextItem);
            if (class_getInstanceMethod(object_getClass(self), nextSel)) {
                ((void (*)(id, SEL))objc_msgSend)(self, nextSel);
            }
        });
    }
}

- (void)advanceToNextItem {
    %orig;

    if (YTMU(@"YTMUltimateIsEnabled") && YTMU(@"skipDislikedSongs")) {
        SEL checkSel = @selector(checkAndSkipDislikedSong);
        if (class_getInstanceMethod(object_getClass(self), checkSel)) {
            ((void (*)(id, SEL))objc_msgSend)(self, checkSel);
        }
    }
}
%end

#pragma mark - Discord Presence (storage only)

@interface YTMUDiscordRPC : NSObject
+ (instancetype)sharedInstance;
- (void)updatePresenceWithTitle:(NSString *)title artist:(NSString *)artist;
- (void)clearPresence;
@end

%subclass YTMUDiscordRPC : NSObject

+ (instancetype)sharedInstance {
    static YTMUDiscordRPC *instance;
    static dispatch_once_t once;
    dispatch_once(&once, ^{
        instance = [self new];
    });
    return instance;
}

%new
- (void)updatePresenceWithTitle:(NSString *)title artist:(NSString *)artist {
    if (!YTMU(@"YTMUltimateIsEnabled") || !YTMU(@"discordRPC")) return;

    // Ensure we have non-nil strings before creating dictionary
    NSString *safeTitle = title ?: @"";
    NSString *safeArtist = artist ?: @"";
    
    NSDictionary *nowPlaying = @{
        @"title": safeTitle,
        @"artist": safeArtist
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
- (void)playbackController:(id)controller didActivateVideo:(id)video withPlaybackData:(id)data {
    %orig;
    
    if (YTMU(@"YTMUltimateIsEnabled") && YTMU(@"discordRPC")) {
        @try {
            YTPlayerResponse *response = self.playerResponse;
            if (response && response.playerData) {
                id videoDetails = response.playerData.videoDetails;
                if (videoDetails && [videoDetails respondsToSelector:@selector(valueForKey:)]) {
                    id titleObj = [videoDetails valueForKey:@"title"];
                    id authorObj = [videoDetails valueForKey:@"author"];
                    
                    NSString *title = ([titleObj isKindOfClass:[NSString class]]) ? titleObj : nil;
                    NSString *author = ([authorObj isKindOfClass:[NSString class]]) ? authorObj : nil;
                    
                    // Update Discord RPC with safe values
                    [[%c(YTMUDiscordRPC) sharedInstance] updatePresenceWithTitle:title artist:author];
                }
            }
        } @catch (NSException *exception) {
            // Silently handle any exceptions when accessing video details
            NSLog(@"[YTMusicUltimate] Error updating Discord RPC: %@", exception);
        }
    }
}

- (void)playbackControllerDidStopPlaying:(id)controller {
    %orig;

    if (YTMU(@"YTMUltimateIsEnabled") && YTMU(@"discordRPC")) {
        [[%c(YTMUDiscordRPC) sharedInstance] clearPresence];
    }
}
%end

#pragma mark - Auto Clear Cache

%hook YTMAppDelegate

%new
- (void)ytmu_clearCache {
    NSFileManager *fileManager = [NSFileManager defaultManager];
    NSString *cachePath = NSSearchPathForDirectoriesInDomains(NSCachesDirectory, NSUserDomainMask, YES).firstObject;
    
    if (!cachePath || !fileManager) return;
    
    // Get all files in cache directory
    NSError *error = nil;
    NSArray *files = [fileManager contentsOfDirectoryAtPath:cachePath error:&error];
    
    if (error || !files) {
        NSLog(@"[YTMusicUltimate] Error reading cache: %@", error.localizedDescription);
        return;
    }
    
    // Calculate total size and collect file info
    unsigned long long totalSize = 0;
    NSMutableArray *fileInfos = [NSMutableArray array];
    
    for (NSString *fileName in files) {
        NSString *filePath = [cachePath stringByAppendingPathComponent:fileName];
        
        // Skip directories and hidden files
        BOOL isDirectory = NO;
        if ([fileManager fileExistsAtPath:filePath isDirectory:&isDirectory] && !isDirectory) {
            NSDictionary *attributes = [fileManager attributesOfItemAtPath:filePath error:nil];
            if (attributes) {
                unsigned long long fileSize = [attributes fileSize];
                totalSize += fileSize;
                [fileInfos addObject:@{@"path": filePath, @"size": @(fileSize)}];
            }
        }
    }
    
    // Target size: 1KB (1024 bytes)
    const unsigned long long targetSize = 1024;
    
    // Sort by size (largest first) to remove biggest files first
    [fileInfos sortUsingComparator:^NSComparisonResult(NSDictionary *obj1, NSDictionary *obj2) {
        NSNumber *size1 = obj1[@"size"];
        NSNumber *size2 = obj2[@"size"];
        return [size2 compare:size1];
    }];
    
    // Remove files until we're under 1KB
    for (NSDictionary *fileInfo in fileInfos) {
        if (totalSize <= targetSize) break;
        
        NSString *filePath = fileInfo[@"path"];
        NSNumber *fileSize = fileInfo[@"size"];
        NSString *fileName = [filePath lastPathComponent];
        
        // Skip important system files
        if ([fileName hasPrefix:@"."] || 
            [fileName containsString:@"com.apple"] ||
            [fileName containsString:@"YTMusicUltimate"]) {
            continue;
        }
        
        NSError *removeError = nil;
        if ([fileManager removeItemAtPath:filePath error:&removeError]) {
            totalSize -= [fileSize unsignedLongLongValue];
        }
    }
    
    // If cache is completely empty or very small, create a placeholder to maintain ~1KB
    if (totalSize < targetSize) {
        NSString *placeholderPath = [cachePath stringByAppendingPathComponent:@".ytmu_cache_placeholder"];
        NSData *placeholderData = [NSData dataWithBytes:"YTMusicUltimate Cache Placeholder" length:32];
        [placeholderData writeToFile:placeholderPath atomically:YES];
    }
    
    NSLog(@"[YTMusicUltimate] Cache cleared. Final size: %llu bytes", totalSize);
}

- (void)applicationWillTerminate:(UIApplication *)application {
    %orig;

    if (YTMU(@"YTMUltimateIsEnabled") && YTMU(@"autoClearCacheOnClose")) {
        // Run synchronously on termination to ensure it completes
        [self ytmu_clearCache];
    }
}

- (void)applicationDidEnterBackground:(UIApplication *)application {
    %orig;

    // Also clear cache when app goes to background
    if (YTMU(@"YTMUltimateIsEnabled") && YTMU(@"autoClearCacheOnClose")) {
        // Use background task to ensure it completes
        __block UIBackgroundTaskIdentifier bgTask = [[UIApplication sharedApplication] beginBackgroundTaskWithExpirationHandler:^{
            [[UIApplication sharedApplication] endBackgroundTask:bgTask];
            bgTask = UIBackgroundTaskInvalid;
        }];
        
        dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
            [self ytmu_clearCache];
            [[UIApplication sharedApplication] endBackgroundTask:bgTask];
            bgTask = UIBackgroundTaskInvalid;
        });
    }
}
%end

%ctor {
    @try {
        NSMutableDictionary *dict =
            [NSMutableDictionary dictionaryWithDictionary:
                [[NSUserDefaults standardUserDefaults]
                    dictionaryForKey:@"YTMUltimate"] ?: @{}];

        NSDictionary *defaults = @{
            @"alwaysHighQuality": @NO,
            @"skipDislikedSongs": @NO,
            @"discordRPC": @NO,
            @"autoClearCacheOnClose": @YES
        };

        for (NSString *key in defaults) {
            // Safety check: ensure key is not nil before using it
            if (key && [key isKindOfClass:[NSString class]] && !dict[key]) {
                dict[key] = defaults[key];
            }
        }

        [[NSUserDefaults standardUserDefaults]
            setObject:dict
               forKey:@"YTMUltimate"];
    } @catch (NSException *exception) {
        NSLog(@"[YTMusicUltimate] Error in constructor: %@", exception);
    }
}
