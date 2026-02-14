#import <AVFoundation/AVFoundation.h>

%hook HAMPlayer  // or deepest audio renderer subclass you find

- (void)play {  // hook actual playback start method (research exact selector)
    %orig;

    static AVAudioEngine *engine = nil;
    static AVAudioUnitTimePitch *pitch = nil;
    static dispatch_once_t once;
    dispatch_once(&once, ^{
        engine = [[AVAudioEngine alloc] init];
        pitch = [[AVAudioUnitTimePitch alloc] init];
        pitch.pitch = 70.0;  // cents; 100 = 1 semitone → 70 ≈ 0.7 semitones for ~1.04 rate
        // pitch.rate = 1.04;  // alternative if you want varispeed instead
        [engine attachNode:pitch];
        // Connect chain: source node → pitch → engine.mainMixerNode → output
        // Requires finding HAM's AVAudioNode reference (very hard, likely crashes without)
    });
}

%end