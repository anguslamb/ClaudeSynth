#ifndef __ClaudeSynth_h__
#define __ClaudeSynth_h__

#include <AudioToolbox/AudioToolbox.h>
#include "SynthVoice.h"

static const int kNumVoices = 16;

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
    kParam_EnvRelease = 18
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
};

// Helper functions
SynthVoice* FindFreeVoice(ClaudeSynthData *data);
SynthVoice* FindVoiceForNote(ClaudeSynthData *data, int note);

#endif
