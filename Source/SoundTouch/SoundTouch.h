////////////////////////////////////////////////////////////////////////////////
///
/// SoundTouch - main class for tempo/pitch/rate adjusting routines.
///
/// Notes:
/// - Initialize the SoundTouch object instance by setting up the sound stream
///   parameters with functions 'setSampleRate' and 'setChannels', then set
///   desired tempo/pitch/rate settings with the corresponding functions.
///
/// - The SoundTouch class behaves like a first-in-first-out pipeline
///
////////////////////////////////////////////////////////////////////////////////

#ifndef SoundTouch_H
#define SoundTouch_H

#include "STTypes.h"

namespace soundtouch
{

/// Soundtouch library version string
#define SOUNDTOUCH_VERSION          "2.1.3"

/// SoundTouch library version id
#define SOUNDTOUCH_VERSION_ID       (20103)

//
// Available setting IDs for the 'setSetting' & 'getSetting' functions:

#define SETTING_USE_AA_FILTER       0
#define SETTING_AA_FILTER_LENGTH    1
#define SETTING_USE_QUICKSEEK       2
#define SETTING_SEQUENCE_MS         3
#define SETTING_SEEKWINDOW_MS       4
#define SETTING_OVERLAP_MS          5
#define SETTING_NOMINAL_INPUT_SEQUENCE  6
#define SETTING_NOMINAL_OUTPUT_SEQUENCE 7
#define SETTING_INITIAL_LATENCY     8

class SoundTouch
{
public:
    SoundTouch();
    ~SoundTouch();

    /// Sets the number of channels, 1 = mono, 2 = stereo
    void setChannels(uint numChannels);

    /// Set sample rate.
    void setSampleRate(uint srate);

    /// Sets pitch change in octaves compared to the original pitch
    /// (-1.00 .. +1.00)
    void setPitchOctaves(double newPitch);

    /// Sets pitch change in semitones compared to the original pitch
    /// (-12 .. +12)
    void setPitchSemiTones(int newPitch);
    void setPitchSemiTones(double newPitch);

    /// Sets the new tempo. Normal rate = 1.0, smaller values represent slower
    /// tempo, larger faster tempo.
    void setTempo(double newTempo);

    /// Sets the rate that the application is trying to change the sample rate.
    /// Normal rate = 1.0, smaller values represent slower rate, larger faster rates.
    void setRate(double newRate);

    /// Sets pitch change via a pitch factor
    /// Rate changes the pitch and tempo together, keeping the pitch/tempo ratio
    /// the same. This function sets pitch change via a factor relative to the
    /// nominal pitch.
    void setPitch(double newPitch);

    /// Returns the current effective pitch.
    double getPitch() const;

    /// Returns the current effective tempo.
    double getTempo() const;

    /// Returns the current effective rate.
    double getRate() const;

    /// Adds 'numSamples' pcs of samples from the 'samples' memory position into
    /// the input of the object.
    virtual void putSamples(const SAMPLETYPE *samples,  ///< Pointer to sample buffer.
                           uint numSamples                ///< Number of samples in buffer.
                           );

    /// Output samples from beginning of the sample buffer.
    virtual uint receiveSamples(SAMPLETYPE *output,      ///< Buffer where to copy output samples.
                               uint maxSamples            ///< How many samples to receive at max.
                               );

    /// Flushes the last samples from the processing pipeline to the output.
    void flush();

    /// Changes a setting controlling the processing system behaviour.
    bool setSetting(int settingId, int value);

    /// Reads a setting controlling the processing system behaviour.
    int getSetting(int settingId) const;

    /// Returns number of samples currently unprocessed.
    virtual uint numUnprocessedSamples() const;

    /// Get ratio between input and output audio durations.
    double getInputOutputSampleRatio();

    /// Clears all the samples in the object's output and internal processing buffers.
    virtual void clear();

    /// Returns nonzero if there aren't any 'ready' samples.
    virtual int isEmpty() const;

    /// Get SoundTouch library version string
    static const char *getVersionString();

    /// Get SoundTouch library version Id
    static uint getVersionId();

    /// Return number of channels
    uint numChannels() const
    {
        return channels;
    }

protected:
    int getEffectiveChannels() const;

private:
    void calcEffectiveRateAndTempo();

    uint channels;
    uint sampleRate;
    double rate;
    double tempo;
    double pitch;
    bool bSrateSet;
};

}

#endif
