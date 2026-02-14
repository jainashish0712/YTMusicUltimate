////////////////////////////////////////////////////////////////////////////////
///
/// Stub implementation for RateTransposer class
///
////////////////////////////////////////////////////////////////////////////////

#ifndef RateTransposer_H
#define RateTransposer_H

#include "STTypes.h"

namespace soundtouch
{

class RateTransposer
{
public:
    RateTransposer();
    virtual ~RateTransposer() {}

    virtual void setChannels(uint channels) {}
    virtual void setSampleRate(uint srate) {}
    virtual void putSamples(const SAMPLETYPE *samples, uint numSamples) {}
    virtual uint receiveSamples(SAMPLETYPE *output, uint maxSamples) { return 0; }
    virtual void flush() {}
    virtual void clear() {}
    virtual bool setSetting(int settingId, int value) { return false; }
    virtual int getSetting(int settingId) const { return -1; }
};

}

#endif
