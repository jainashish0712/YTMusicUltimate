#include "GSVolBar.h"

static BOOL YTMU(NSString *key) {
    NSDictionary *YTMUltimateDict = [[NSUserDefaults standardUserDefaults] dictionaryForKey:@"YTMUltimate"];
    return [YTMUltimateDict[key] boolValue];
}

static BOOL volumeBar = YTMU(@"YTMUltimateIsEnabled") && YTMU(@"volBar");

@interface YTMWatchView: UIView
@property (readonly, nonatomic) BOOL isExpanded;
@property (nonatomic, strong) UIView *tabView;
@property (nonatomic) long long currentLayout;
@property (nonatomic, strong) GSVolBar *volumeBar;

- (void)updateVolBarVisibility;
@end

%hook YTMWatchView
%property (nonatomic, strong) GSVolBar *volumeBar;

- (instancetype)initWithColorScheme:(id)scheme {
    self = %orig;

    if (self && volumeBar) {

        CGFloat barWidth = self.frame.size.width * 0.35;
        CGFloat x = (self.frame.size.width - barWidth) / 2;

        self.volumeBar = [[GSVolBar alloc] initWithFrame:CGRectMake(x, 0, barWidth, 25)];
        [self addSubview:self.volumeBar];
    }

    return self;
}

- (void)layoutSubviews {
    %orig;

    if (volumeBar) {

        CGFloat barWidth = self.frame.size.width * 0.35;
        CGFloat x = (self.frame.size.width - barWidth) / 2;

        self.volumeBar.frame = CGRectMake(
            x,
            CGRectGetMinY(self.tabView.frame) - 10,
            barWidth,
            25
        );
    }
}


- (void)updateColorsAfterLayoutChangeTo:(long long)arg1 {
    %orig;

    if (volumeBar) {
        [self updateVolBarVisibility];
    }
}

- (void)updateColorsBeforeLayoutChangeTo:(long long)arg1 {
    %orig;

    if (volumeBar) {
        self.volumeBar.hidden = YES;
    }
}

%new
- (void)updateVolBarVisibility {
    if (volumeBar) {
        dispatch_async(dispatch_get_main_queue(), ^(void){
            self.volumeBar.hidden = !(self.isExpanded && self.currentLayout == 2);
        });
    }
}

%end