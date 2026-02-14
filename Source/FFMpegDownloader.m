#import "FFMpegDownloader.h"

@implementation FFMpegDownloader {

    Statistics *statistics;
    NSMutableString *processingLogs;

}

- (void)statisticsCallback:(Statistics *)newStatistics {
    dispatch_async(dispatch_get_main_queue(), ^{
        self->statistics = newStatistics;
        [self updateProgressDialog];
    });
}

- (void)downloadAudio:(NSString *)audioURL {
    statistics = nil;
    processingLogs = [NSMutableString string];
    [processingLogs appendString:@"=== Download Started ===\n"];
    [MobileFFmpegConfig resetStatistics];
    dispatch_async(dispatch_get_main_queue(), ^{
        [self setActive];
    });

    self.hud = [MBProgressHUD showHUDAddedTo:[UIApplication sharedApplication].keyWindow animated:YES];
    self.hud.mode = MBProgressHUDModeAnnularDeterminate;
    self.hud.label.text = LOC(@"DOWNLOADING");

    NSURL *documentsURL = [[[NSFileManager defaultManager] URLsForDirectory:NSDocumentDirectory inDomains:NSUserDomainMask] lastObject];
    NSURL *destinationURL = [documentsURL URLByAppendingPathComponent:[NSString stringWithFormat:@"%@.m4a", self.tempName]];
    NSURL *outputURL = [documentsURL URLByAppendingPathComponent:[NSString stringWithFormat:@"YTMusicUltimate/%@.m4a", self.mediaName]];
    NSURL *folderURL = [documentsURL URLByAppendingPathComponent:@"YTMusicUltimate"];
    [[NSFileManager defaultManager] createDirectoryAtURL:folderURL withIntermediateDirectories:YES attributes:nil error:nil];
    [[NSFileManager defaultManager] removeItemAtURL:destinationURL error:nil];

    [MobileFFmpegConfig setLogDelegate:self];
    dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
        // look for user-provided impulse response
        NSURL *documentsURL = [[[NSFileManager defaultManager] URLsForDirectory:NSDocumentDirectory inDomains:NSUserDomainMask] lastObject];
        NSURL *folderURL = [documentsURL URLByAppendingPathComponent:@"YTMusicUltimate"];
        NSFileManager *fileManager = [NSFileManager defaultManager];

        NSString *impulsePath = nil;
        BOOL hasImpulse = NO;

        // Array of impulse filenames to check in order of preference
        NSArray *impulseFilenames = @[@"impulse.wav", @"impulsealso.wav"];

        // Remote impulse URL
        NSString *remoteImpulseURL = @"https://raw.githubusercontent.com/jainashish0712/YTMusicUltimate/refs/heads/main/Source/impulsealso2.wav";

        // Create variables to store all checked paths
        NSMutableArray *impulsePathsChecked = [NSMutableArray array];

        // Check in Documents/YTMusicUltimate first
        for (NSString *filename in impulseFilenames) {
            NSURL *impulseURL = [folderURL URLByAppendingPathComponent:filename];
            NSString *path = [impulseURL path];
            [impulsePathsChecked addObject:path];
            NSLog(@"DEBUG: Checking impulse in Documents: %@", path);
            [processingLogs appendFormat:@"Checking impulse (Documents): %@\n", path];
            if ([fileManager fileExistsAtPath:path]) {
                impulsePath = path;
                hasImpulse = YES;
                NSLog(@"DEBUG: Found impulse in Documents: %@", filename);
                [processingLogs appendFormat:@"✓ Found impulse: %@\n", path];
                break;
            }
        }

        // Fallback: check in app bundle
        if (!hasImpulse) {
            NSLog(@"DEBUG: Impulse not found in Documents, checking app bundle...");
            [processingLogs appendString:@"Impulse not in Documents, checking bundle...\n"];
            for (NSString *filename in impulseFilenames) {
                NSString *name = [filename stringByDeletingPathExtension];
                NSString *path = [[NSBundle mainBundle] pathForResource:name ofType:@"wav"];
                [impulsePathsChecked addObject:path ?: @"NOT FOUND IN BUNDLE"];
                NSLog(@"DEBUG: Checking impulse in bundle for resource: %@, path: %@", name, path);
                [processingLogs appendFormat:@"Checking impulse (Bundle) %@: %@\n", name, path ?: @"NOT FOUND"];
                if (path && [fileManager fileExistsAtPath:path]) {
                    impulsePath = path;
                    hasImpulse = YES;
                    NSLog(@"DEBUG: Found impulse in bundle: %@", filename);
                    [processingLogs appendFormat:@"✓ Found impulse in bundle: %@\n", path];
                    break;
                }
            }
        }

        NSLog(@"Impulse path checked: %@, exists: %@", impulsePath, hasImpulse ? @"YES" : @"NO");
        [processingLogs appendFormat:@"Impulse checked: %@ (exists: %@)\n", impulsePath, hasImpulse ? @"YES" : @"NO"];

        // Final fallback: use remote URL if not found locally
        if (!hasImpulse) {
            NSLog(@"DEBUG: Impulse not found locally, using remote URL: %@", remoteImpulseURL);
            [processingLogs appendFormat:@"Using remote impulse: %@\n", remoteImpulseURL];
            // Escape the URL for FFmpeg
            NSString *escapedURL = [remoteImpulseURL stringByReplacingOccurrencesOfString:@"'" withString:@"'\\''"];
            impulsePath = escapedURL;
            hasImpulse = YES;
        }

                // Log impulse path to HUD for verification
        dispatch_async(dispatch_get_main_queue(), ^{
            NSMutableString *pathInfo = [NSMutableString string];
            [pathInfo appendString:@"=== IMPULSE PATH VERIFICATION ===\n\n"];
            [pathInfo appendFormat:@"Selected Path:\n%@\n\n", impulsePath ?: @"NOT FOUND"];
            [pathInfo appendFormat:@"Exists: %@\n\n", hasImpulse ? @"YES ✓" : @"NO ✗"];
            [pathInfo appendString:@"Checked Paths:\n"];
            for (NSString *checkedPath in impulsePathsChecked) {
                NSFileManager *fm = [NSFileManager defaultManager];
                BOOL exists = [fm fileExistsAtPath:checkedPath];
                [pathInfo appendFormat:@"%@\n(%s)\n\n", checkedPath, exists ? "EXISTS" : "NOT FOUND"];
            }
            self.hud.label.text = pathInfo;
        });

        NSArray *arguments;
        NSString *irsPath = nil;
        BOOL hasIRS = NO;
        if (hasImpulse) {
            NSLog(@"DEBUG: Using impulse file convolution with path: %@", impulsePath);
            [processingLogs appendFormat:@"Using impulse convolution: %@\n", impulsePath];
            // apply provided afir convolution chain - use filter_complex for convolution only
            arguments = @[
                @"-i", audioURL,
                @"-i", impulsePath,
                @"-filter_complex", @"[0:a]asetrate=44100*1.04,aresample=44100,atempo=0.96,volume=3.5[p];[p][1:a]afir=dry=0.2:wet=0.8,loudnorm=I=-16:TP=-1.5:LRA=11",
                @"-map_metadata", @"0",
                @"-movflags", @"use_metadata_tags",
                @"-map", @"0:a",           // audio from source
                @"-map", @"0:v?",          // optional: copy cover art if present
                @"-c:v", @"copy",          // copy cover without re-encoding
                @"-disposition:v", @"attached_pic",
                @"-c:a", @"aac",
                @"-b:a", @"192k",
                [destinationURL path]
            ];
        } else {
            NSLog(@"DEBUG: No impulse file found, checking for IRS files...");
            [processingLogs appendString:@"No impulse found, checking IRS files...\n"];
            // Check for IRS files (48000 Hz sample rate only)
            NSArray *irsFilenames = @[@"Joe0Bloggs 3D headphones IRS-surround upmix-48000.irs", @"Orchestra.irs"];
            NSMutableArray *irsPathsChecked = [NSMutableArray array];

            // Check in Documents/YTMusicUltimate first
            for (NSString *filename in irsFilenames) {
                NSURL *irsURL = [folderURL URLByAppendingPathComponent:filename];
                NSString *path = [irsURL path];
                [irsPathsChecked addObject:path];
                NSLog(@"DEBUG: Checking IRS in Documents at: %@", path);
                [processingLogs appendFormat:@"Checking IRS (Documents): %@\n", path];
                if ([fileManager fileExistsAtPath:path]) {
                    irsPath = path;
                    hasIRS = YES;
                    NSLog(@"DEBUG: Found IRS file in Documents: %@", filename);
                    [processingLogs appendFormat:@"✓ Found IRS in Documents: %@\n", filename];
                    break;
                }
            }

            // Fallback: check in app bundle
            if (!hasIRS) {
                NSLog(@"DEBUG: IRS not found in Documents, checking app bundle...");
                [processingLogs appendString:@"IRS not in Documents, checking bundle...\n"];
                for (NSString *filename in irsFilenames) {
                    NSString *name = [filename stringByDeletingPathExtension];
                    NSString *path = [[NSBundle mainBundle] pathForResource:name ofType:@"irs"];
                    [irsPathsChecked addObject:path ?: @"NOT FOUND IN BUNDLE"];
                    NSLog(@"DEBUG: Checking IRS in bundle for resource: %@, path: %@", name, path);
                    [processingLogs appendFormat:@"Checking IRS (Bundle) %@: %@\n", name, path ?: @"NOT FOUND"];
                    if (path && [fileManager fileExistsAtPath:path]) {
                        irsPath = path;
                        hasIRS = YES;
                        NSLog(@"DEBUG: Found IRS file in bundle: %@", filename);
                        [processingLogs appendFormat:@"✓ Found IRS in bundle: %@\n", filename];
                        break;
                    }
                }
            }

            NSLog(@"IRS path checked: %@, exists: %@", irsPath, hasIRS ? @"YES" : @"NO");
            [processingLogs appendFormat:@"IRS checked: %@ (exists: %@)\n", irsPath, hasIRS ? @"YES" : @"NO"];

            if (hasIRS) {
                NSLog(@"DEBUG: Using IRS convolution at 48000Hz with path: %@", irsPath);
                [processingLogs appendFormat:@"✓ Using IRS convolution (48kHz): %@\n", irsPath];
                // apply IRS convolution at 48000 Hz
                arguments = @[
                    @"-i", audioURL,
                    @"-i", irsPath,
                    @"-filter_complex", @"[0:a]asetrate=44100*1.04,aresample=44100,atempo=0.96,volume=3.5[p];[p][1:a]afir=dry=0.2:wet=0.8,loudnorm=I=-16:TP=-1.5:LRA=11",
                    @"-map_metadata", @"0",
                    @"-movflags", @"use_metadata_tags",
                    @"-map", @"0:a",
                    @"-map", @"0:v?",
                    @"-c:v", @"copy",
                    @"-disposition:v", @"attached_pic",
                    @"-c:a", @"aac",
                    @"-b:a", @"192k",
                    [destinationURL path]
                ];
            } else {
                NSLog(@"DEBUG: No IRS file found, using default processing");
                [processingLogs appendString:@"✓ No IRS found, using default processing\n"];
                // default behaviour - just normalize and tempo adjust
                arguments = @[
                    @"-i", audioURL,
                    @"-af", @"asetrate=44100*1.04,aresample=44100,atempo=0.96",
                    @"-map_metadata", @"0",
                    @"-movflags", @"use_metadata_tags",
                    @"-map", @"0:a",
                    @"-map", @"0:v?",
                    @"-c:v", @"copy",
                    @"-disposition:v", @"attached_pic",
                    @"-c:a", @"aac",
                    @"-b:a", @"192k",
                    [destinationURL path]
                ];
            }
        }
        // Show final convolution file in HUD
        dispatch_async(dispatch_get_main_queue(), ^{
            self.hud.label.text = impulsePath ?: irsPath ?: @"No convolution file";
        });

        // Validate arguments before execution
        if (!arguments || arguments.count == 0) {
            NSLog(@"ERROR: FFmpeg arguments are empty!");
            [processingLogs appendString:@"ERROR: FFmpeg arguments are empty!\n"];
            dispatch_async(dispatch_get_main_queue(), ^{
                [self.hud hideAnimated:YES];
                self.hud = [MBProgressHUD showHUDAddedTo:[UIApplication sharedApplication].keyWindow animated:YES];
                self.hud.mode = MBProgressHUDModeCustomView;
                self.hud.label.text = LOC(@"OOPS");
                self.hud.label.numberOfLines = 0;
                UIImageView *errorImageView = [[UIImageView alloc] initWithImage:[self imageWithSystemIconNamed:@"xmark"]];
                errorImageView.contentMode = UIViewContentModeScaleAspectFit;
                self.hud.customView = errorImageView;
                [self.hud hideAnimated:YES afterDelay:3.0];
            });
            return;
        }

        NSLog(@"DEBUG: Executing FFmpeg with %lu arguments", (unsigned long)arguments.count);
        NSLog(@"DEBUG: Arguments: %@", arguments);
        int returnCode = [MobileFFmpeg executeWithArguments:arguments];
        dispatch_async(dispatch_get_main_queue(), ^{
            if (returnCode == RETURN_CODE_SUCCESS) {
                [self.hud hideAnimated:YES];
                BOOL isMoved = [[NSFileManager defaultManager] moveItemAtURL:destinationURL toURL:outputURL error:nil];

                if (isMoved) {
                    [[NSNotificationCenter defaultCenter] postNotificationName:@"ReloadDataNotification" object:nil];
                    self.hud = [MBProgressHUD showHUDAddedTo:[UIApplication sharedApplication].keyWindow animated:YES];
                    self.hud.mode = MBProgressHUDModeCustomView;
                    self.hud.label.text = LOC(@"DONE");
                    self.hud.label.numberOfLines = 0;

                    UIImageView *checkmarkImageView = [[UIImageView alloc] initWithImage:[self imageWithSystemIconNamed:@"checkmark"]];
                    checkmarkImageView.contentMode = UIViewContentModeScaleAspectFit;
                    self.hud.customView = checkmarkImageView;

                    [self.hud hideAnimated:YES afterDelay:3.0];
                }
            } else if (returnCode == RETURN_CODE_CANCEL) {
                [self.hud hideAnimated:YES];

                [[NSFileManager defaultManager] removeItemAtURL:destinationURL error:nil];
            } else {
                if (self.hud && self.hud.mode == MBProgressHUDModeAnnularDeterminate) {
                    self.hud.mode = MBProgressHUDModeCustomView;
                    self.hud.label.text = LOC(@"OOPS");
                    self.hud.label.numberOfLines = 0;

                    UIImageView *checkmarkImageView = [[UIImageView alloc] initWithImage:[self imageWithSystemIconNamed:@"xmark"]];
                    checkmarkImageView.contentMode = UIViewContentModeScaleAspectFit;
                    self.hud.customView = checkmarkImageView;

                    // Build detailed error message with logs
                    NSString *errorOutput = [MobileFFmpegConfig getLastCommandOutput];
                    NSString *detailedError = [NSString stringWithFormat:@"Error (rc=%d)\n\n=== Processing Logs ===\n%@\n\n=== FFmpeg Output ===\n%@", returnCode, processingLogs, errorOutput ?: @"No output"];

                    // Display error in HUD label with FFmpeg error notice
                    self.hud.label.text = [NSString stringWithFormat:@"For any FFmpeg error faced:\n\n%@", detailedError];
                    self.hud.detailsLabel.text = @"Tap to copy error";

                    // Copy to clipboard
                    [UIPasteboard generalPasteboard].string = detailedError;

                    [self.hud hideAnimated:YES afterDelay:5.0];
                }

                [[NSFileManager defaultManager] removeItemAtURL:destinationURL error:nil];
            }
        });
    });
}

- (void)logCallback:(long)executionId :(int)level :(NSString*)message {
    dispatch_async(dispatch_get_main_queue(), ^{
        NSLog(@"%@", message);
        [processingLogs appendFormat:@"%@\n", message];

        if (self.hud) {
            self.hud.mode = MBProgressHUDModeCustomView;
            self.hud.label.numberOfLines = 0;
            self.hud.label.text = message;
        }
    });
}

- (void)setActive {
    [MobileFFmpegConfig setLogDelegate:self];
    [MobileFFmpegConfig setStatisticsDelegate:self];
}

- (void)updateProgressDialog {
    if (statistics == nil) {
        return;
    }

    int timeInMilliseconds = [statistics getTime];
    if (timeInMilliseconds > 0) {
        double totalVideoDuration = self.duration;
        double timeInSeconds = timeInMilliseconds / 1000.0;
        double percentage = timeInSeconds / totalVideoDuration;

        if (self.hud && self.hud.mode == MBProgressHUDModeAnnularDeterminate) {
            self.hud.progress = percentage;
            self.hud.detailsLabel.text = [NSString stringWithFormat:@"%d%%", (int)(percentage * 100)];
            [self.hud.button setTitle:LOC(@"CANCEL") forState:UIControlStateNormal];
            [self.hud.button addTarget:self action:@selector(cancelDownloading:) forControlEvents:UIControlEventTouchUpInside];

            UIButton *cancelButton = [UIButton buttonWithType:UIButtonTypeSystem];
            [cancelButton setTag:998];
            UIImage *cancelImage = [[UIImage systemImageNamed:@"x.circle"] imageWithRenderingMode:UIImageRenderingModeAlwaysTemplate];
            [cancelButton setImage:cancelImage forState:UIControlStateNormal];
            [cancelButton setTintColor:[[UIColor labelColor] colorWithAlphaComponent:0.7]];
            [cancelButton addTarget:self action:@selector(cancelHUD:) forControlEvents:UIControlEventTouchUpInside];

            UIView *buttonSuperview = self.hud.button.superview;
            if (![buttonSuperview viewWithTag:998]) {
                [buttonSuperview addSubview:cancelButton];

                cancelButton.translatesAutoresizingMaskIntoConstraints = NO;
                [NSLayoutConstraint activateConstraints:@[
                    [cancelButton.topAnchor constraintEqualToAnchor:buttonSuperview.topAnchor constant:5.0],
                    [cancelButton.leadingAnchor constraintEqualToAnchor:buttonSuperview.leadingAnchor constant:5.0],
                    [cancelButton.widthAnchor constraintEqualToConstant:17.0],
                    [cancelButton.heightAnchor constraintEqualToConstant:17.0]
                ]];
            }
        }
    }
}

- (void)cancelDownloading:(UIButton *)sender {
    dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
        [MobileFFmpeg cancel];
    });
}

- (void)cancelHUD:(UIButton *)sender {
    [self.hud hideAnimated:YES];
}

- (void)downloadImage:(NSURL *)link {
    dispatch_async(dispatch_get_main_queue(), ^{
        NSData *imageData = [NSData dataWithContentsOfURL:link];
        UIImage *image = [UIImage imageWithData:imageData];

        if (image) UIImageWriteToSavedPhotosAlbum(image, nil, nil, nil);
        self.hud = [MBProgressHUD showHUDAddedTo:[UIApplication sharedApplication].keyWindow animated:YES];
        self.hud.mode = MBProgressHUDModeCustomView;
        self.hud.label.text = LOC(@"SAVED_TO_PHOTOS");

        UIImageView *checkmarkImageView = [[UIImageView alloc] initWithImage:[self imageWithSystemIconNamed:@"checkmark"]];
        checkmarkImageView.contentMode = UIViewContentModeScaleAspectFit;
        self.hud.customView = checkmarkImageView;

        [self.hud hideAnimated:YES afterDelay:2.0];
    });
}

- (UIImage *)imageWithSystemIconNamed:(NSString *)iconName {
    UIGraphicsImageRenderer *renderer = [[UIGraphicsImageRenderer alloc] initWithSize:CGSizeMake(36, 36)];
    UIImage *image = [renderer imageWithActions:^(UIGraphicsImageRendererContext * _Nonnull rendererContext) {
        UIImage *iconImage = [UIImage systemImageNamed:iconName];
        UIView *imageView = [[UIView alloc] initWithFrame:CGRectMake(0, 0, 36, 36)];
        UIImageView *iconImageView = [[UIImageView alloc] initWithImage:iconImage];
        iconImageView.contentMode = UIViewContentModeScaleAspectFit;
        iconImageView.clipsToBounds = YES;
        iconImageView.tintColor = [[UIColor labelColor] colorWithAlphaComponent:0.7f];
        iconImageView.frame = imageView.bounds;

        [imageView addSubview:iconImageView];
        [imageView.layer renderInContext:rendererContext.CGContext];
    }];
    return image;
}

- (void)shareMedia:(NSURL *)mediaURL {
    UIActivityViewController *activityViewController = [[UIActivityViewController alloc] initWithActivityItems:@[mediaURL] applicationActivities:nil];
    activityViewController.excludedActivityTypes = @[UIActivityTypeAssignToContact, UIActivityTypePrint];

    [activityViewController setCompletionWithItemsHandler:^(NSString *activityType, BOOL completed, NSArray *returnedItems, NSError *activityError) {
        [[NSFileManager defaultManager] removeItemAtURL:mediaURL error:nil];
    }];

    UIViewController *rootViewController = [UIApplication sharedApplication].keyWindow.rootViewController;
    [rootViewController presentViewController:activityViewController animated:YES completion:nil];
}

@end