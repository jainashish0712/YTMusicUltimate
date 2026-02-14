////////////////////////////////////////////////////////////////////////////////
///
/// SoundTouch - main class for tempo/pitch/rate adjusting routines
///
/// Implementation file
///
////////////////////////////////////////////////////////////////////////////////

#include <assert.h>
#include <math.h>
#include "SoundTouch.h"
#include "TDStretch.h"
#include "RateTransposer.h"

using namespace soundtouch;

SoundTouch::SoundTouch()
{
    pRateTransposer = new RateTransposer();
    pTDStretch = TDStretch::newInstance();

    rate = tempo = 0;

    virtualPitch =
    virtualRate =
    virtualTempo = 1.0;

    calcEffectiveRateAndTempo();

    samplesExpectedOut = 0;
    samplesOutput = 0;

    channels = 0;
    bSrateSet = false;
}

SoundTouch::~SoundTouch()
{
    delete pRateTransposer;
    delete pTDStretch;
}

/// Get SoundTouch library version string
const char *SoundTouch::getVersionString()
{
    static const char *_version = SOUNDTOUCH_VERSION;
    return _version;
}

/// Get SoundTouch library version Id
uint SoundTouch::getVersionId()
{
    return SOUNDTOUCH_VERSION_ID;
}

void SoundTouch::setChannels(uint numChannels)
{
    if (channels == numChannels) return;

    assert(numChannels > 0);

    channels = numChannels;
    pRateTransposer->setChannels(numChannels);
    pTDStretch->setChannels(numChannels);
}

void SoundTouch::setSampleRate(uint srate)
{
    assert(srate > 0);

    if (sampleRate == srate) return;

    sampleRate = srate;
    pRateTransposer->setSampleRate(srate);
    pTDStretch->setSampleRate(srate);

    calcEffectiveRateAndTempo();

    bSrateSet = true;
}

void SoundTouch::setPitchOctaves(double newPitch)
{
    virtualPitch = pow(2.0, newPitch);
    calcEffectiveRateAndTempo();
}

void SoundTouch::setPitchSemiTones(int newPitch)
{
    setPitchSemiTones((double)newPitch);
}

void SoundTouch::setPitchSemiTones(double newPitch)
{
    virtualPitch = pow(2.0, newPitch / 12.0);
    calcEffectiveRateAndTempo();
}

void SoundTouch::setPitch(double newPitch)
{
    virtualPitch = newPitch;
    calcEffectiveRateAndTempo();
}

double SoundTouch::getPitch() const
{
    return virtualPitch;
}

void SoundTouch::setTempo(double newTempo)
{
    virtualTempo = newTempo;
    calcEffectiveRateAndTempo();
}

double SoundTouch::getTempo() const
{
    return virtualTempo;
}

void SoundTouch::setRate(double newRate)
{
    virtualRate = newRate;
    calcEffectiveRateAndTempo();
}

double SoundTouch::getRate() const
{
    return virtualRate;
}

void SoundTouch::calcEffectiveRateAndTempo()
{
    double oldRate = rate;
    double oldTempo = tempo;

    rate = virtualRate * virtualPitch;
    tempo = virtualTempo / virtualPitch;

    if (rate <= 0 || tempo <= 0)
    {
        rate = oldRate;
        tempo = oldTempo;
    }
}

void SoundTouch::putSamples(const SAMPLETYPE *samples, uint nSamples)
{
    if (bSrateSet == false)
    {
        assert(false);
        return;
    }

    if (channels == 0)
    {
        assert(false);
        return;
    }

    pRateTransposer->putSamples(samples, nSamples);
}

uint SoundTouch::receiveSamples(SAMPLETYPE *output, uint maxSamples)
{
    return pTDStretch->receiveSamples(output, maxSamples);
}

void SoundTouch::flush()
{
    pRateTransposer->flush();
    pTDStretch->flush();
}

void SoundTouch::clear()
{
    pRateTransposer->clear();
    pTDStretch->clear();

    samplesExpectedOut = 0;
    samplesOutput = 0;
}

bool SoundTouch::setSetting(int settingId, int value)
{
    int samplerate;

    if (pTDStretch == NULL) return false;

    switch (settingId)
    {
        case SETTING_USE_AA_FILTER :
            pRateTransposer->setSetting(settingId, value);
            return true;

        case SETTING_AA_FILTER_LENGTH :
            pRateTransposer->setSetting(settingId, value);
            return true;

        case SETTING_USE_QUICKSEEK :
            pTDStretch->setSetting(settingId, value);
            return true;

        case SETTING_SEQUENCE_MS :
            pTDStretch->setSetting(settingId, value);
            return true;

        case SETTING_SEEKWINDOW_MS :
            pTDStretch->setSetting(settingId, value);
            return true;

        case SETTING_OVERLAP_MS :
            pTDStretch->setSetting(settingId, value);
            return true;

        default :
            return false;
    }
}

int SoundTouch::getSetting(int settingId) const
{
    if (pTDStretch == NULL) return -1;

    switch (settingId)
    {
        case SETTING_USE_AA_FILTER :
            return pRateTransposer->getSetting(settingId);

        case SETTING_AA_FILTER_LENGTH :
            return pRateTransposer->getSetting(settingId);

        case SETTING_USE_QUICKSEEK :
            return pTDStretch->getSetting(settingId);

        case SETTING_SEQUENCE_MS :
            return pTDStretch->getSetting(settingId);

        case SETTING_SEEKWINDOW_MS :
            return pTDStretch->getSetting(settingId);

        case SETTING_OVERLAP_MS :
            return pTDStretch->getSetting(settingId);

        case SETTING_NOMINAL_INPUT_SEQUENCE :
            return (int)(pTDStretch->getInputSampleRate() / 44100);

        case SETTING_NOMINAL_OUTPUT_SEQUENCE :
            return (int)(pTDStretch->getOutputSampleRate() / 44100);

        case SETTING_INITIAL_LATENCY :
            return pTDStretch->getLatencyMs();

        default :
            return -1;
    }
}

uint SoundTouch::numUnprocessedSamples() const
{
    if (pTDStretch)
    {
        return pTDStretch->numSamples();
    }
    return 0;
}

double SoundTouch::getInputOutputSampleRatio()
{
    if (rate <= 0) return 1.0;

    double ratio = (double)sampleRate / ((double)sampleRate * rate);
    return ratio * tempo;
}

int SoundTouch::isEmpty() const
{
    if (pTDStretch == NULL) return -1;

    if (pTDStretch->isEmpty()) return -1;

    return 0;
}
