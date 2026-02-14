#import <AVFoundation/AVFoundation.h>
#import <AudioToolbox/AudioToolbox.h>
#import "SoundTouch/SoundTouch.h"

using namespace soundtouch;

static SoundTouch *st = nullptr;

static void TapPrepare(MTAudioProcessingTapRef tap,
                       CMItemCount maxFrames,
                       const AudioStreamBasicDescription *asbd)
{
    st = new SoundTouch();
    st->setSampleRate(asbd->mSampleRate);
    st->setChannels(asbd->mChannelsPerFrame);

    st->setPitch(1.12f);   // realtime pitch factor
    st->setTempo(1.0f);    // keep tempo unchanged
}

static void TapUnprepare(MTAudioProcessingTapRef tap) {
    delete st;
    st = nullptr;
}

static OSStatus TapProcess(MTAudioProcessingTapRef tap,
                           CMItemCount numberFrames,
                           MTAudioProcessingTapFlags flags,
                           AudioBufferList *bufferList,
                           CMItemCount *numberFramesOut,
                           MTAudioProcessingTapFlags *flagsOut)
{
    OSStatus status = MTAudioProcessingTapGetSourceAudio(
        tap,
        numberFrames,
        bufferList,
        flagsOut,
        NULL,
        numberFramesOut);

    if (status != noErr || !st) return status;

    float *samples = (float *)bufferList->mBuffers[0].mData;
    int frames = (int)*numberFramesOut;

    st->putSamples(samples, frames);
    int received = st->receiveSamples(samples, frames);

    *numberFramesOut = received;

    return noErr;
}

%hook AVPlayerItem

- (void)setAudioMix:(AVAudioMix *)audioMix {

    AVMutableAudioMix *mix = [AVMutableAudioMix audioMix];
    AVMutableAudioMixInputParameters *params =
        [AVMutableAudioMixInputParameters audioMixInputParameters];

    MTAudioProcessingTapCallbacks callbacks;
    callbacks.version = kMTAudioProcessingTapCallbacksVersion_0;
    callbacks.clientInfo = NULL;
    callbacks.init = NULL;
    callbacks.finalize = NULL;
    callbacks.prepare = TapPrepare;
    callbacks.unprepare = TapUnprepare;
    callbacks.process = TapProcess;

    MTAudioProcessingTapRef tap;
    MTAudioProcessingTapCreate(kCFAllocatorDefault,
                               &callbacks,
                               kMTAudioProcessingTapCreationFlag_PostEffects,
                               &tap);

    params.audioTapProcessor = tap;
    mix.inputParameters = @[params];

    %orig(mix);
}

%end
