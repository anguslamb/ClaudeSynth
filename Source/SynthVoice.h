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

enum EnvelopeStage {
    kEnvStage_Idle,
    kEnvStage_Attack,
    kEnvStage_Decay,
    kEnvStage_Sustain,
    kEnvStage_Release
};

class SynthVoice {
public:
    SynthVoice() : mNote(-1), mVelocity(0), mActive(false),
                   mFilterCutoff(20000.0f), mFilterResonance(0.5f),
                   mLowpass(0.0f), mBandpass(0.0f),
                   mEnvelopeLevel(0.0f), mEnvStage(kEnvStage_Idle), mReleaseStartLevel(0.0f),
                   mEnvAttack(0.01f), mEnvDecay(0.1f), mEnvSustain(0.7f), mEnvRelease(0.3f),
                   mFilterEnvelopeLevel(0.0f), mFilterEnvStage(kEnvStage_Idle), mFilterReleaseStartLevel(0.0f),
                   mFilterEnvAttack(0.01f), mFilterEnvDecay(0.1f), mFilterEnvSustain(0.7f), mFilterEnvRelease(0.3f) {
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
        bool wasIdle = (mEnvStage == kEnvStage_Idle);
        bool noteChanged = (note != mNote);

        mNote = note;
        mVelocity = velocity;
        mSampleRate = sampleRate;
        mActive = true;

        // Reset phases and filter state if voice was idle OR if note changed
        // This prevents clicks when retriggering the same note, but ensures
        // clean filter response when switching to a different note
        if (wasIdle || noteChanged) {
            mOsc1.phase = 0.0;
            mOsc2.phase = 0.0;
            mOsc3.phase = 0.0;
            mLowpass = 0.0f;
            mBandpass = 0.0f;
        }

        // Reset amplitude envelope level only if voice was idle
        // This prevents clicks when retriggering
        if (wasIdle) {
            mEnvelopeLevel = 0.0f;
        }
        // Otherwise keep amplitude envelope level for smooth retriggering

        // Always reset filter envelope level for immediate retriggering
        // (filter envelope modulation doesn't cause clicks like amplitude does)
        mFilterEnvelopeLevel = 0.0f;

        // Start both envelopes at attack stage
        mEnvStage = kEnvStage_Attack;
        mFilterEnvStage = kEnvStage_Attack;

        // Convert MIDI note to frequency: 440 * 2^((note-69)/12)
        mBaseFrequency = 440.0 * pow(2.0, (note - 69) / 12.0);
    }

    void NoteOff() {
        // Enter release stage and store current level for linear release (both envelopes)
        mEnvStage = kEnvStage_Release;
        mReleaseStartLevel = mEnvelopeLevel;
        mFilterEnvStage = kEnvStage_Release;
        mFilterReleaseStartLevel = mFilterEnvelopeLevel;
    }

    void Kill() {
        // Immediately stop the voice (for voice stealing/retriggering)
        mActive = false;
        mNote = -1;
        mEnvStage = kEnvStage_Idle;
        mEnvelopeLevel = 0.0f;
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

    void SetEnvelope(float attack, float decay, float sustain, float release) {
        mEnvAttack = attack;
        mEnvDecay = decay;
        mEnvSustain = sustain;
        mEnvRelease = release;
    }

    void SetFilterEnvelope(float attack, float decay, float sustain, float release) {
        mFilterEnvAttack = attack;
        mFilterEnvDecay = decay;
        mFilterEnvSustain = sustain;
        mFilterEnvRelease = release;
    }

    float GetFilterEnvelopeLevel() const { return mFilterEnvelopeLevel; }

    struct ModulationValues {
        float filterCutoffMod;
        float filterResonanceMod;
        float masterVolumeMod;
        float osc1DetuneMod;
        float osc1VolumeMod;
        float osc2DetuneMod;
        float osc2VolumeMod;
        float osc3DetuneMod;
        float osc3VolumeMod;
    };

    float RenderSample(const ModulationValues& modValues) {
        if (!mActive) return 0.0f;

        // Generate and mix three oscillators with modulated volumes
        float mixedSample = 0.0f;

        // Oscillator 1
        float osc1Vol = fmaxf(0.0f, fminf(1.0f, mOsc1.volume + modValues.osc1VolumeMod));
        if (osc1Vol > 0.0f) {
            float osc1Sample = GenerateOscillatorSample(mOsc1);
            mixedSample += osc1Sample * osc1Vol;
        }

        // Oscillator 2
        float osc2Vol = fmaxf(0.0f, fminf(1.0f, mOsc2.volume + modValues.osc2VolumeMod));
        if (osc2Vol > 0.0f) {
            float osc2Sample = GenerateOscillatorSample(mOsc2);
            mixedSample += osc2Sample * osc2Vol;
        }

        // Oscillator 3
        float osc3Vol = fmaxf(0.0f, fminf(1.0f, mOsc3.volume + modValues.osc3VolumeMod));
        if (osc3Vol > 0.0f) {
            float osc3Sample = GenerateOscillatorSample(mOsc3);
            mixedSample += osc3Sample * osc3Vol;
        }

        // Apply velocity and scaling (reduced from 0.5f to 0.15f to prevent clipping)
        mixedSample *= (mVelocity / 127.0f) * 0.15f;

        float sample = mixedSample;

        // Apply modulated filter cutoff
        float modulatedCutoff = mFilterCutoff + modValues.filterCutoffMod;
        modulatedCutoff = fmaxf(20.0f, fminf(modulatedCutoff, mSampleRate * 0.5f)); // Clamp

        // Apply modulated filter resonance
        float modulatedResonance = fmaxf(0.5f, fminf(10.0f, mFilterResonance + modValues.filterResonanceMod));

        // Apply low-pass filter (State Variable Filter)
        // Bypass filter if cutoff is very high (essentially "off")
        if (modulatedCutoff < mSampleRate * 0.4f) {
            float f = 2.0f * sinf(M_PI * modulatedCutoff / mSampleRate);

            // Clamp f to prevent instability
            f = fminf(f, 0.99f);

            float q = 1.0f / fmaxf(modulatedResonance, 0.5f);

            mLowpass = mLowpass + f * mBandpass;
            float highpass = sample - mLowpass - q * mBandpass;
            mBandpass = f * highpass + mBandpass;

            sample = mLowpass;
        }

        // Apply ADSR envelope (after filter, before master volume)
        UpdateEnvelope();
        UpdateFilterEnvelope();
        sample *= mEnvelopeLevel;

        // Apply master volume modulation
        float modulatedMasterVol = fmaxf(0.0f, fminf(1.0f, 1.0f + modValues.masterVolumeMod));
        sample *= modulatedMasterVol;

        // Advance phases for all oscillators with modulated detune
        AdvanceOscillatorPhase(mOsc1, modValues.osc1DetuneMod);
        AdvanceOscillatorPhase(mOsc2, modValues.osc2DetuneMod);
        AdvanceOscillatorPhase(mOsc3, modValues.osc3DetuneMod);

        return sample;
    }

private:
    void UpdateEnvelope() {
        switch (mEnvStage) {
            case kEnvStage_Idle:
                mEnvelopeLevel = 0.0f;
                break;

            case kEnvStage_Attack:
                if (mEnvAttack > 0.0001f) {
                    float attackRate = 1.0f / (mEnvAttack * mSampleRate);
                    mEnvelopeLevel += attackRate;
                    if (mEnvelopeLevel >= 1.0f) {
                        mEnvelopeLevel = 1.0f;
                        mEnvStage = kEnvStage_Decay;
                    }
                } else {
                    // Instant attack
                    mEnvelopeLevel = 1.0f;
                    mEnvStage = kEnvStage_Decay;
                }
                break;

            case kEnvStage_Decay:
                if (mEnvDecay > 0.0001f) {
                    float decayRate = (1.0f - mEnvSustain) / (mEnvDecay * mSampleRate);
                    mEnvelopeLevel -= decayRate;
                    if (mEnvelopeLevel <= mEnvSustain) {
                        mEnvelopeLevel = mEnvSustain;
                        mEnvStage = kEnvStage_Sustain;
                    }
                } else {
                    // Instant decay
                    mEnvelopeLevel = mEnvSustain;
                    mEnvStage = kEnvStage_Sustain;
                }
                break;

            case kEnvStage_Sustain:
                mEnvelopeLevel = mEnvSustain;
                break;

            case kEnvStage_Release:
                if (mEnvRelease > 0.0001f) {
                    // Linear decay from release start level to 0
                    float releaseRate = mReleaseStartLevel / (mEnvRelease * mSampleRate);
                    mEnvelopeLevel -= releaseRate;
                    if (mEnvelopeLevel <= 0.0f) {
                        mEnvelopeLevel = 0.0f;
                        mEnvStage = kEnvStage_Idle;
                        mActive = false;
                        mNote = -1;
                    }
                } else {
                    // Instant release
                    mEnvelopeLevel = 0.0f;
                    mEnvStage = kEnvStage_Idle;
                    mActive = false;
                    mNote = -1;
                }
                break;
        }
    }

    void UpdateFilterEnvelope() {
        switch (mFilterEnvStage) {
            case kEnvStage_Idle:
                mFilterEnvelopeLevel = 0.0f;
                break;

            case kEnvStage_Attack:
                if (mFilterEnvAttack > 0.0001f) {
                    float attackRate = 1.0f / (mFilterEnvAttack * mSampleRate);
                    mFilterEnvelopeLevel += attackRate;
                    if (mFilterEnvelopeLevel >= 1.0f) {
                        mFilterEnvelopeLevel = 1.0f;
                        mFilterEnvStage = kEnvStage_Decay;
                    }
                } else {
                    mFilterEnvelopeLevel = 1.0f;
                    mFilterEnvStage = kEnvStage_Decay;
                }
                break;

            case kEnvStage_Decay:
                if (mFilterEnvDecay > 0.0001f) {
                    float decayRate = (1.0f - mFilterEnvSustain) / (mFilterEnvDecay * mSampleRate);
                    mFilterEnvelopeLevel -= decayRate;
                    if (mFilterEnvelopeLevel <= mFilterEnvSustain) {
                        mFilterEnvelopeLevel = mFilterEnvSustain;
                        mFilterEnvStage = kEnvStage_Sustain;
                    }
                } else {
                    mFilterEnvelopeLevel = mFilterEnvSustain;
                    mFilterEnvStage = kEnvStage_Sustain;
                }
                break;

            case kEnvStage_Sustain:
                mFilterEnvelopeLevel = mFilterEnvSustain;
                break;

            case kEnvStage_Release:
                if (mFilterEnvRelease > 0.0001f) {
                    float releaseRate = mFilterReleaseStartLevel / (mFilterEnvRelease * mSampleRate);
                    mFilterEnvelopeLevel -= releaseRate;
                    if (mFilterEnvelopeLevel <= 0.0f) {
                        mFilterEnvelopeLevel = 0.0f;
                        mFilterEnvStage = kEnvStage_Idle;
                    }
                } else {
                    mFilterEnvelopeLevel = 0.0f;
                    mFilterEnvStage = kEnvStage_Idle;
                }
                break;
        }
    }

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

    void AdvanceOscillatorPhase(OscillatorState& osc, float detuneMod) {
        // Calculate frequency with octave and detune
        // Octave: multiply frequency by 2^octave
        // Detune: multiply frequency by 2^(cents/1200)
        double octaveMultiplier = pow(2.0, osc.octave);
        double totalDetune = osc.detune + detuneMod;
        double detuneMultiplier = pow(2.0, totalDetune / 1200.0);
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
    float mEnvelopeLevel;
    EnvelopeStage mEnvStage;
    float mReleaseStartLevel;
    float mEnvAttack;
    float mEnvDecay;
    float mEnvSustain;
    float mEnvRelease;

    // Filter Envelope
    float mFilterEnvelopeLevel;
    EnvelopeStage mFilterEnvStage;
    float mFilterReleaseStartLevel;
    float mFilterEnvAttack;
    float mFilterEnvDecay;
    float mFilterEnvSustain;
    float mFilterEnvRelease;
};

#endif
