#import <UIKit/UIKit.h>

@interface YTColorCalculations : NSObject
+ (UIColor *)themeColorForImage:(UIImage *)image textColor:(UIColor *)textColor;
@end

%hook YTColorCalculations
+ (UIColor *)themeColorForImage:(UIImage *)image textColor:(UIColor *)textColor {
    UIColor *orig = %orig;

    if (YTMU(@"YTMUltimateIsEnabled") && YTMU(@"saturatedGradient")) {
        CGFloat hue, saturation, brightness, alpha;
        [orig getHue:&hue saturation:&saturation brightness:&brightness alpha:&alpha];
        saturation = MIN(saturation * 1.4, 1.0); // Increase by 40%
        return [UIColor colorWithHue:hue saturation:saturation brightness:brightness alpha:alpha];
    }

    return orig;
}
%end