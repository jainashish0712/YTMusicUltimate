////////////////////////////////////////////////////////////////////////////////
///
/// SoundTouch Wrapper for iOS - Simplified interface for pitch/tempo control
///
/// This is a lightweight wrapper that provides pitch and tempo adjustment
/// functionality for real-time audio in iOS YTMusicUltimate tweak.
///
////////////////////////////////////////////////////////////////////////////////

#ifndef SOUNDTOUCH_WRAPPER_H
#define SOUNDTOUCH_WRAPPER_H

#include "STTypes.h"

namespace soundtouch
{
    class SoundTouchWrapper
    {
    public:
        SoundTouchWrapper();
        ~SoundTouchWrapper();

        /// Set pitch adjustment in semitones (-12 to +12)
        void setPitchSemitones(float pitchSemitones);

        /// Set tempo adjustment (0.5 = half speed, 1.0 = normal, 2.0 = double)
        void setTempo(float tempo);

        /// Set playback rate (combines pitch and tempo)
        void setRate(float rate);

        /// Set number of audio channels (1=mono, 2=stereo)
        void setChannels(uint numChannels);

        /// Set sample rate (44100, 48000, etc.)
        void setSampleRate(uint sampleRate);

        /// Process audio samples
        void processSamples(SAMPLETYPE *samples, uint numSamples);

    private:
        float pitch;
        float tempo;
        float rate;
        uint channels;
        uint sampleRate;
        bool initialized;
    };
}

#endif
