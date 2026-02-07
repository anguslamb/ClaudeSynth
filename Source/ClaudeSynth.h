#ifndef __ClaudeSynth_h__
#define __ClaudeSynth_h__

#include <AudioToolbox/AudioToolbox.h>
#include "SynthVoice.h"

static const int kNumVoices = 16;

struct ClaudeSynthData {
    AudioComponentPlugInInterface pluginInterface;  // Must be first!
    AudioComponentInstance componentInstance;
    SynthVoice voices[kNumVoices];
    Float64 sampleRate;
    AudioStreamBasicDescription streamFormat;
    UInt32 maxFramesPerSlice;
};

// Helper functions
SynthVoice* FindFreeVoice(ClaudeSynthData *data);
SynthVoice* FindVoiceForNote(ClaudeSynthData *data, int note);

#endif
