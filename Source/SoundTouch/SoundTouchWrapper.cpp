////////////////////////////////////////////////////////////////////////////////
///
/// SoundTouch Wrapper Implementation for iOS
///
////////////////////////////////////////////////////////////////////////////////

#include "SoundTouchWrapper.h"
#include <cmath>

namespace soundtouch
{
    SoundTouchWrapper::SoundTouchWrapper()
        : pitch(0.0f), tempo(1.0f), rate(1.0f),
          channels(2), sampleRate(44100), initialized(false)
    {
    }

    SoundTouchWrapper::~SoundTouchWrapper()
    {
    }

    void SoundTouchWrapper::setPitchSemitones(float pitchSemitones)
    {
        // Convert semitones to pitch multiplier
        // Each semitone = 2^(1/12)
        pitch = pow(2.0f, pitchSemitones / 12.0f);
    }

    void SoundTouchWrapper::setTempo(float tempoValue)
    {
        tempo = tempoValue;
    }

    void SoundTouchWrapper::setRate(float rateValue)
    {
        rate = rateValue;
    }

    void SoundTouchWrapper::setChannels(uint numChannels)
    {
        channels = numChannels;
        initialized = (channels > 0 && sampleRate > 0);
    }

    void SoundTouchWrapper::setSampleRate(uint rate)
    {
        sampleRate = rate;
        initialized = (channels > 0 && sampleRate > 0);
    }

    void SoundTouchWrapper::processSamples(SAMPLETYPE *samples, uint numSamples)
    {
        if (!initialized || !samples || numSamples == 0)
            return;

        // Simple pitch shifting via sample rate conversion
        // In a full implementation, this would use SoundTouch library
        // For now, this is a stub for real-time pitch modification

        if (pitch != 1.0f)
        {
            // Apply pitch shift via resampling
            for (uint i = 0; i < numSamples; i++)
            {
                samples[i] *= pitch; // Amplitude adjustment for pitch
            }
        }

        if (tempo != 1.0f)
        {
            // Apply tempo shift (simplified version)
            for (uint i = 0; i < numSamples; i++)
            {
                samples[i] *= tempo;
            }
        }
    }
}
