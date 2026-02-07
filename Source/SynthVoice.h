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
    SynthVoice() : mNote(-1), mVelocity(0), mPhase(0.0), mActive(false), mWaveform(kWaveform_Sine),
                   mFilterCutoff(20000.0f), mFilterResonance(0.5f),
                   mLowpass(0.0f), mBandpass(0.0f),
                   mEnvelope(0.0f), mReleasing(false) {}

    void NoteOn(int note, int velocity, double sampleRate) {
        mNote = note;
        mVelocity = velocity;
        mSampleRate = sampleRate;
        mPhase = 0.0;
        mActive = true;
        mReleasing = false;

        // Reset filter state
        mLowpass = 0.0f;
        mBandpass = 0.0f;

        // Reset envelope
        mEnvelope = 0.0f;

        // Convert MIDI note to frequency: 440 * 2^((note-69)/12)
        mFrequency = 440.0 * pow(2.0, (note - 69) / 12.0);
    }

    void NoteOff() {
        mReleasing = true;
    }

    bool IsActive() const { return mActive; }
    int GetNote() const { return mNote; }

    void SetWaveform(Waveform waveform) {
        mWaveform = waveform;
    }

    void SetFilterCutoff(float cutoff) {
        mFilterCutoff = cutoff;
    }

    void SetFilterResonance(float resonance) {
        mFilterResonance = resonance;
    }

    float RenderSample() {
        if (!mActive) return 0.0f;

        // Update envelope
        const float attackTime = 0.005f;  // 5ms attack
        const float releaseTime = 0.05f;  // 50ms release

        if (mReleasing) {
            // Release phase - fade out
            float releaseRate = 1.0f / (releaseTime * mSampleRate);
            mEnvelope -= releaseRate;

            if (mEnvelope <= 0.0f) {
                mEnvelope = 0.0f;
                mActive = false;
                mNote = -1;
                return 0.0f;
            }
        } else {
            // Attack phase - fade in
            if (mEnvelope < 1.0f) {
                float attackRate = 1.0f / (attackTime * mSampleRate);
                mEnvelope += attackRate;
                if (mEnvelope > 1.0f) {
                    mEnvelope = 1.0f;
                }
            }
        }

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

        // Apply velocity and scaling (reduced from 0.5f to 0.15f to prevent clipping)
        sample *= (mVelocity / 127.0f) * 0.15f;

        // Apply envelope
        sample *= mEnvelope;

        // Apply low-pass filter (State Variable Filter)
        // Bypass filter if cutoff is very high (essentially "off")
        if (mFilterCutoff < mSampleRate * 0.4f) {
            float f = 2.0f * sinf(M_PI * mFilterCutoff / mSampleRate);

            // Clamp f to prevent instability
            f = fminf(f, 0.99f);

            float q = 1.0f / fmaxf(mFilterResonance, 0.5f);

            mLowpass = mLowpass + f * mBandpass;
            float highpass = sample - mLowpass - q * mBandpass;
            mBandpass = f * highpass + mBandpass;

            sample = mLowpass;
        }

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
    float mFilterCutoff;
    float mFilterResonance;
    float mLowpass;
    float mBandpass;
    float mEnvelope;
    bool mReleasing;
};

#endif
