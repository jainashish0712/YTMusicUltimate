////////////////////////////////////////////////////////////////////////////////
///
/// Stub implementation for TDStretch class
///
////////////////////////////////////////////////////////////////////////////////

#ifndef TDStretch_H
#define TDStretch_H

#include "STTypes.h"

namespace soundtouch
{

class TDStretch
{
public:
    virtual ~TDStretch() {}

    static TDStretch *newInstance();

    virtual void setChannels(uint channels) = 0;
    virtual void setSampleRate(uint srate) = 0;
    virtual void putSamples(const SAMPLETYPE *samples, uint numSamples) = 0;
    virtual uint receiveSamples(SAMPLETYPE *output, uint maxSamples) = 0;
    virtual void flush() = 0;
    virtual void clear() = 0;
    virtual bool setSetting(int settingId, int value) = 0;
    virtual int getSetting(int settingId) const = 0;
    virtual uint numSamples() const = 0;
    virtual uint getInputSampleRate() const = 0;
    virtual uint getOutputSampleRate() const = 0;
    virtual int getLatencyMs() const = 0;
    virtual int isEmpty() const = 0;
};

}

#endif
