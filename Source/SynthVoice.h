#ifndef __SynthVoice_h__
#define __SynthVoice_h__

#include <cmath>

enum Waveform {
    kWaveform_Sine = 0,
    kWaveform_Square = 1,
    kWaveform_Sawtooth = 2,
    kWaveform_Triangle = 3
};

struct OscillatorState {
    int waveform;
    int octave;
    float detune;
    float volume;
    double phase;
};

class SynthVoice {
public:
    SynthVoice() : mNote(-1), mVelocity(0), mActive(false),
                   mFilterCutoff(20000.0f), mFilterResonance(0.5f),
                   mLowpass(0.0f), mBandpass(0.0f),
                   mEnvelope(0.0f), mReleasing(false) {
        // Initialize oscillator 1
        mOsc1.waveform = kWaveform_Sine;
        mOsc1.octave = 0;
        mOsc1.detune = 0.0f;
        mOsc1.volume = 1.0f;
        mOsc1.phase = 0.0;

        // Initialize oscillator 2 (volume 0 by default)
        mOsc2.waveform = kWaveform_Sine;
        mOsc2.octave = 0;
        mOsc2.detune = 0.0f;
        mOsc2.volume = 0.0f;
        mOsc2.phase = 0.0;

        // Initialize oscillator 3 (volume 0 by default)
        mOsc3.waveform = kWaveform_Sine;
        mOsc3.octave = 0;
        mOsc3.detune = 0.0f;
        mOsc3.volume = 0.0f;
        mOsc3.phase = 0.0;
    }

    void NoteOn(int note, int velocity, double sampleRate) {
        mNote = note;
        mVelocity = velocity;
        mSampleRate = sampleRate;
        mOsc1.phase = 0.0;
        mOsc2.phase = 0.0;
        mOsc3.phase = 0.0;
        mActive = true;
        mReleasing = false;

        // Reset filter state
        mLowpass = 0.0f;
        mBandpass = 0.0f;

        // Reset envelope
        mEnvelope = 0.0f;

        // Convert MIDI note to frequency: 440 * 2^((note-69)/12)
        mBaseFrequency = 440.0 * pow(2.0, (note - 69) / 12.0);
    }

    void NoteOff() {
        mReleasing = true;
    }

    bool IsActive() const { return mActive; }
    int GetNote() const { return mNote; }

    void SetOscillator1(int waveform, int octave, float detune, float volume) {
        mOsc1.waveform = waveform;
        mOsc1.octave = octave;
        mOsc1.detune = detune;
        mOsc1.volume = volume;
    }

    void SetOscillator2(int waveform, int octave, float detune, float volume) {
        mOsc2.waveform = waveform;
        mOsc2.octave = octave;
        mOsc2.detune = detune;
        mOsc2.volume = volume;
    }

    void SetOscillator3(int waveform, int octave, float detune, float volume) {
        mOsc3.waveform = waveform;
        mOsc3.octave = octave;
        mOsc3.detune = detune;
        mOsc3.volume = volume;
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

        // Generate and mix three oscillators
        float mixedSample = 0.0f;

        // Oscillator 1
        if (mOsc1.volume > 0.0f) {
            float osc1Sample = GenerateOscillatorSample(mOsc1);
            mixedSample += osc1Sample * mOsc1.volume;
        }

        // Oscillator 2
        if (mOsc2.volume > 0.0f) {
            float osc2Sample = GenerateOscillatorSample(mOsc2);
            mixedSample += osc2Sample * mOsc2.volume;
        }

        // Oscillator 3
        if (mOsc3.volume > 0.0f) {
            float osc3Sample = GenerateOscillatorSample(mOsc3);
            mixedSample += osc3Sample * mOsc3.volume;
        }

        // Apply velocity and scaling (reduced from 0.5f to 0.15f to prevent clipping)
        mixedSample *= (mVelocity / 127.0f) * 0.15f;

        // Apply envelope
        mixedSample *= mEnvelope;

        float sample = mixedSample;

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

        // Advance phases for all oscillators
        AdvanceOscillatorPhase(mOsc1);
        AdvanceOscillatorPhase(mOsc2);
        AdvanceOscillatorPhase(mOsc3);

        return sample;
    }

private:
    float GenerateOscillatorSample(const OscillatorState& osc) {
        float normalizedPhase = osc.phase / (2.0 * M_PI); // 0.0 to 1.0
        float sample = 0.0f;

        // Generate waveform based on type
        switch (osc.waveform) {
            case kWaveform_Sine:
                sample = sin(osc.phase);
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

        return sample;
    }

    void AdvanceOscillatorPhase(OscillatorState& osc) {
        // Calculate frequency with octave and detune
        // Octave: multiply frequency by 2^octave
        // Detune: multiply frequency by 2^(cents/1200)
        double octaveMultiplier = pow(2.0, osc.octave);
        double detuneMultiplier = pow(2.0, osc.detune / 1200.0);
        double frequency = mBaseFrequency * octaveMultiplier * detuneMultiplier;

        // Advance phase
        osc.phase += (frequency / mSampleRate) * 2.0 * M_PI;

        // Wrap phase to avoid numerical issues
        if (osc.phase >= 2.0 * M_PI) {
            osc.phase -= 2.0 * M_PI;
        }
    }

    int mNote;
    int mVelocity;
    double mBaseFrequency;
    double mSampleRate;
    bool mActive;
    OscillatorState mOsc1;
    OscillatorState mOsc2;
    OscillatorState mOsc3;
    float mFilterCutoff;
    float mFilterResonance;
    float mLowpass;
    float mBandpass;
    float mEnvelope;
    bool mReleasing;
};

#endif
