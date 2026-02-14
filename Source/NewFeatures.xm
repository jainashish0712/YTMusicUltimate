#import <Foundation/Foundation.h>
#import <UIKit/UIKit.h>
#import <objc/runtime.h>
#import <objc/message.h>

#import "Headers/YTPlayerViewController.h"
#import "Headers/YTMToastController.h"
#import "Headers/Localization.h"

#pragma mark - Helpers

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
- (void)updatePresenceWithTitle:(NSString *)title
                         artist:(NSString *)artist
                          album:(NSString *)album
                     artworkURL:(NSString *)artworkURL;
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
- (void)updatePresenceWithTitle:(NSString *)title
                         artist:(NSString *)artist
                          album:(NSString *)album
                     artworkURL:(NSString *)artworkURL {

    if (!YTMU(@"YTMUltimateIsEnabled") || !YTMU(@"discordRPC")) return;

    NSDictionary *nowPlaying = @{
        @"title": title ?: @"",
        @"artist": artist ?: @"",
        @"album": album ?: @"",
        @"artworkURL": artworkURL ?: @""
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


#pragma mark - Player Hooks

%hook YTPlayerViewController

- (void)playbackController:(id)controller
        didActivateVideo:(id)video
       withPlaybackData:(id)data {

    %orig;

    if (!YTMU(@"YTMUltimateIsEnabled") || !YTMU(@"discordRPC")) return;

    @try {

        YTPlayerResponse *response = self.playerResponse;
        if (!response || !response.playerData) return;

        id videoDetails = response.playerData.videoDetails;
        if (!videoDetails || ![videoDetails respondsToSelector:@selector(valueForKey:)]) return;

        NSString *title = nil;
        NSString *artist = nil;
        NSString *album = nil;
        NSString *artworkURL = nil;

        // Title
        id titleObj = [videoDetails valueForKey:@"title"];
        if ([titleObj isKindOfClass:[NSString class]]) {
            title = titleObj;
        }

        // Artist
        id authorObj = [videoDetails valueForKey:@"author"];
        if ([authorObj isKindOfClass:[NSString class]]) {
            artist = authorObj;
        }

        // Album (may not exist in all versions)
        id albumObj = [videoDetails valueForKey:@"album"];
        if ([albumObj isKindOfClass:[NSString class]]) {
            album = albumObj;
        }

        // Thumbnail extraction (highest resolution)
        id thumbnailObj = [videoDetails valueForKey:@"thumbnail"];
        if ([thumbnailObj respondsToSelector:@selector(valueForKey:)]) {

            id thumbnailsArray = [thumbnailObj valueForKey:@"thumbnails"];

            if ([thumbnailsArray isKindOfClass:[NSArray class]] &&
                [thumbnailsArray count] > 0) {

                id highestResThumb = [thumbnailsArray lastObject];

                if ([highestResThumb respondsToSelector:@selector(valueForKey:)]) {

                    id urlObj = [highestResThumb valueForKey:@"url"];

                    if ([urlObj isKindOfClass:[NSString class]]) {
                        artworkURL = urlObj;

                        // Optional: force higher resolution if pattern exists
                        artworkURL =
                        [artworkURL stringByReplacingOccurrencesOfString:@"w120-h120"
                                                              withString:@"w1000-h1000"];
                    }
                }
            }
        }

        if (title || artist || album || artworkURL) {
            [[%c(YTMUDiscordRPC) sharedInstance]
                updatePresenceWithTitle:title
                                 artist:artist
                                  album:album
                             artworkURL:artworkURL];
        }

    } @catch (NSException *exception) {
        NSLog(@"[YTMusicUltimate] Discord RPC error: %@", exception);
    }
}

- (void)playbackControllerDidStopPlaying:(id)controller {
    %orig;

    if (YTMU(@"YTMUltimateIsEnabled") && YTMU(@"discordRPC")) {
        [[%c(YTMUDiscordRPC) sharedInstance] clearPresence];
    }
}

%end


#pragma mark - Defaults

%ctor {
    NSMutableDictionary *dict =
        [NSMutableDictionary dictionaryWithDictionary:
            [[NSUserDefaults standardUserDefaults]
                dictionaryForKey:@"YTMUltimate"] ?: @{}];

    NSDictionary *defaults = @{
        @"alwaysHighQuality": @NO,
        @"skipDislikedSongs": @NO,
        @"discordRPC": @NO
    };

    for (NSString *key in defaults) {
        if (!dict[key]) {
            dict[key] = defaults[key];
        }
    }

    [[NSUserDefaults standardUserDefaults]
        setObject:dict
           forKey:@"YTMUltimate"];
}
