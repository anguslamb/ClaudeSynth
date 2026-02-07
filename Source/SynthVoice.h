#ifndef __SynthVoice_h__
#define __SynthVoice_h__

#include <cmath>

class SynthVoice {
public:
    SynthVoice() : mNote(-1), mVelocity(0), mPhase(0.0), mActive(false) {}

    void NoteOn(int note, int velocity, double sampleRate) {
        mNote = note;
        mVelocity = velocity;
        mSampleRate = sampleRate;
        mPhase = 0.0;
        mActive = true;

        // Convert MIDI note to frequency: 440 * 2^((note-69)/12)
        mFrequency = 440.0 * pow(2.0, (note - 69) / 12.0);
    }

    void NoteOff() {
        mActive = false;
        mNote = -1;
    }

    bool IsActive() const { return mActive; }
    int GetNote() const { return mNote; }

    float RenderSample() {
        if (!mActive) return 0.0f;

        // Generate sine wave sample
        float sample = sin(mPhase) * (mVelocity / 127.0f) * 0.5f;

        // Advance phase
        mPhase += (mFrequency / mSampleRate) * 2.0 * M_PI;

        // Wrap phase to avoid numerical issues
        if (mPhase >= 2.0 * M_PI) {
            mPhase -= 2.0 * M_PI;
        }

        return sample;
    }

private:
    int mNote;
    int mVelocity;
    double mPhase;
    double mFrequency;
    double mSampleRate;
    bool mActive;
};

#endif
