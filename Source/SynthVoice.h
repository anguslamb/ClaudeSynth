#ifndef __SynthVoice_h__
#define __SynthVoice_h__

#include <cmath>

enum Waveform {
    kWaveform_Sine = 0,
    kWaveform_Square = 1,
    kWaveform_Sawtooth = 2,
    kWaveform_Triangle = 3
};

class SynthVoice {
public:
    SynthVoice() : mNote(-1), mVelocity(0), mPhase(0.0), mActive(false), mWaveform(kWaveform_Sine) {}

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

    void SetWaveform(Waveform waveform) {
        mWaveform = waveform;
    }

    float RenderSample() {
        if (!mActive) return 0.0f;

        float sample = 0.0f;
        float normalizedPhase = mPhase / (2.0 * M_PI); // 0.0 to 1.0

        // Generate waveform sample based on selected type
        switch (mWaveform) {
            case kWaveform_Sine:
                sample = sin(mPhase);
                break;

            case kWaveform_Square:
                sample = (normalizedPhase < 0.5f) ? 1.0f : -1.0f;
                break;

            case kWaveform_Sawtooth:
                sample = 2.0f * normalizedPhase - 1.0f;
                break;

            case kWaveform_Triangle:
                if (normalizedPhase < 0.5f) {
                    sample = 4.0f * normalizedPhase - 1.0f;
                } else {
                    sample = -4.0f * normalizedPhase + 3.0f;
                }
                break;
        }

        // Apply velocity and scaling
        sample *= (mVelocity / 127.0f) * 0.5f;

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
    Waveform mWaveform;
};

#endif
