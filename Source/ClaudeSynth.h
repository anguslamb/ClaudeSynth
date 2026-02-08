#ifndef __ClaudeSynth_h__
#define __ClaudeSynth_h__

#include <AudioToolbox/AudioToolbox.h>
#include "SynthVoice.h"

static const int kNumVoices = 16;
static const int kNumModSlots = 4;

// Modulation Matrix Sources
enum ModSource {
    kModSource_None = 0,
    kModSource_LFO1 = 1,
    kModSource_LFO2 = 2,
    kModSource_FilterEnv = 3
};

// Modulation Matrix Destinations
enum ModDest {
    kModDest_None = 0,
    kModDest_FilterCutoff = 1,
    kModDest_FilterResonance = 2,
    kModDest_MasterVolume = 3,
    kModDest_Osc1_Detune = 4,
    kModDest_Osc1_Volume = 5,
    kModDest_Osc2_Detune = 6,
    kModDest_Osc2_Volume = 7,
    kModDest_Osc3_Detune = 8,
    kModDest_Osc3_Volume = 9
};

// Parameter IDs
enum {
    kParam_MasterVolume = 0,

    kParam_Osc1_Waveform = 1,
    kParam_Osc1_Octave = 2,
    kParam_Osc1_Detune = 3,
    kParam_Osc1_Volume = 4,

    kParam_Osc2_Waveform = 5,
    kParam_Osc2_Octave = 6,
    kParam_Osc2_Detune = 7,
    kParam_Osc2_Volume = 8,

    kParam_Osc3_Waveform = 9,
    kParam_Osc3_Octave = 10,
    kParam_Osc3_Detune = 11,
    kParam_Osc3_Volume = 12,

    kParam_FilterCutoff = 13,
    kParam_FilterResonance = 14,

    kParam_EnvAttack = 15,
    kParam_EnvDecay = 16,
    kParam_EnvSustain = 17,
    kParam_EnvRelease = 18,

    // Filter Envelope
    kParam_FilterEnvAttack = 19,
    kParam_FilterEnvDecay = 20,
    kParam_FilterEnvSustain = 21,
    kParam_FilterEnvRelease = 22,

    // LFO 1
    kParam_LFO1_Waveform = 23,
    kParam_LFO1_Rate = 24,

    // LFO 2
    kParam_LFO2_Waveform = 25,
    kParam_LFO2_Rate = 26,

    // Modulation Matrix (4 slots x 3 params each)
    kParam_ModSlot1_Source = 27,
    kParam_ModSlot1_Dest = 28,
    kParam_ModSlot1_Intensity = 29,

    kParam_ModSlot2_Source = 30,
    kParam_ModSlot2_Dest = 31,
    kParam_ModSlot2_Intensity = 32,

    kParam_ModSlot3_Source = 33,
    kParam_ModSlot3_Dest = 34,
    kParam_ModSlot3_Intensity = 35,

    kParam_ModSlot4_Source = 36,
    kParam_ModSlot4_Dest = 37,
    kParam_ModSlot4_Intensity = 38
};

struct OscillatorSettings {
    int waveform;
    int octave;
    float detune;  // in cents
    float volume;
};

struct ClaudeSynthData {
    AudioComponentPlugInInterface pluginInterface;  // Must be first!
    AudioComponentInstance componentInstance;
    SynthVoice voices[kNumVoices];
    Float64 sampleRate;
    AudioStreamBasicDescription streamFormat;
    UInt32 maxFramesPerSlice;
    float masterVolume;
    OscillatorSettings osc1;
    OscillatorSettings osc2;
    OscillatorSettings osc3;
    float filterCutoff;
    float filterResonance;
    float envAttack;
    float envDecay;
    float envSustain;
    float envRelease;

    // Filter Envelope (Global)
    float filterEnvAttack;
    float filterEnvDecay;
    float filterEnvSustain;
    float filterEnvRelease;
    float filterEnvLevel;
    EnvelopeStage filterEnvStage;
    float filterEnvReleaseStartLevel;
    int activeNoteCount;  // Track how many notes are currently held

    // LFO 1
    int lfo1Waveform;
    float lfo1Rate;
    double lfo1Phase;

    // LFO 2
    int lfo2Waveform;
    float lfo2Rate;
    double lfo2Phase;

    // Modulation Matrix
    struct ModSlot {
        int source;      // ModSource enum
        int destination; // ModDest enum
        float intensity; // 0.0 to 1.0
    } modSlots[kNumModSlots];
};

// Helper functions
SynthVoice* FindFreeVoice(ClaudeSynthData *data);
SynthVoice* FindVoiceForNote(ClaudeSynthData *data, int note);

#endif
