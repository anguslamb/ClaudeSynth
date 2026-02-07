#ifndef __ClaudeSynth_h__
#define __ClaudeSynth_h__

#include <AudioToolbox/AudioToolbox.h>
#include "SynthVoice.h"

static const int kNumVoices = 16;

// Parameter IDs
enum {
    kParam_MasterVolume = 0,
    kParam_Waveform = 1,
    kParam_FilterCutoff = 2,
    kParam_FilterResonance = 3
};

struct ClaudeSynthData {
    AudioComponentPlugInInterface pluginInterface;  // Must be first!
    AudioComponentInstance componentInstance;
    SynthVoice voices[kNumVoices];
    Float64 sampleRate;
    AudioStreamBasicDescription streamFormat;
    UInt32 maxFramesPerSlice;
    float masterVolume;
    int waveform;
    float filterCutoff;
    float filterResonance;
};

// Helper functions
SynthVoice* FindFreeVoice(ClaudeSynthData *data);
SynthVoice* FindVoiceForNote(ClaudeSynthData *data, int note);

#endif
