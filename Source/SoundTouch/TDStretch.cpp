////////////////////////////////////////////////////////////////////////////////
///
/// Stub implementation for TDStretch.cpp
///
////////////////////////////////////////////////////////////////////////////////

#include "TDStretch.h"

namespace soundtouch
{

class TDStretchImpl : public TDStretch
{
private:
    uint channels;
    uint sampleRate;

public:
    TDStretchImpl() : channels(0), sampleRate(44100) {}

    void setChannels(uint ch) override { channels = ch; }
    void setSampleRate(uint sr) override { sampleRate = sr; }
    void putSamples(const SAMPLETYPE *samples, uint numSamples) override {}
    uint receiveSamples(SAMPLETYPE *output, uint maxSamples) override { return 0; }
    void flush() override {}
    void clear() override {}
    bool setSetting(int settingId, int value) override { return false; }
    int getSetting(int settingId) const override { return -1; }
    uint numSamples() const override { return 0; }
    uint getInputSampleRate() const override { return sampleRate; }
    uint getOutputSampleRate() const override { return sampleRate; }
    int getLatencyMs() const override { return 0; }
    int isEmpty() const override { return 1; }
};

TDStretch *TDStretch::newInstance()
{
    return new TDStretchImpl();
}

}
