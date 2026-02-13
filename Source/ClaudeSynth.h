#ifndef __ClaudeSynth_h__
#define __ClaudeSynth_h__

#include <AudioToolbox/AudioToolbox.h>
#include "SynthVoice.h"

#define CLAUDESYNTH_VERSION "1.0.0"

// Custom property for oscilloscope
#define kClaudeSynthProperty_Oscilloscope 65536

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
    kParam_LFO1_TempoSync = 47,      // 0=Off, 1=On
    kParam_LFO1_NoteDivision = 48,   // 0-11 (note divisions when tempo synced)

    // LFO 2
    kParam_LFO2_Waveform = 25,
    kParam_LFO2_Rate = 26,
    kParam_LFO2_TempoSync = 49,      // 0=Off, 1=On
    kParam_LFO2_NoteDivision = 50,   // 0-11 (note divisions when tempo synced)

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
    kParam_ModSlot4_Intensity = 38,

    // Effects parameters
    kParam_EffectType = 39,      // 0=None, 1=Chorus, 2=Phaser, 3=Flanger
    kParam_EffectRate = 40,      // 0.1 to 10 Hz
    kParam_EffectIntensity = 41, // 0.0 to 1.0

    // Arpeggiator parameters
    kParam_ArpEnable = 42,       // 0=Off, 1=On
    kParam_ArpRate = 43,         // 0=1/4, 1=1/8, 2=1/16, 3=1/32
    kParam_ArpMode = 44,         // 0=Up, 1=Down, 2=UpDown, 3=Random
    kParam_ArpOctaves = 45,      // 1-4 octaves
    kParam_ArpGate = 46,         // 0.0 to 1.0 (gate length)

    // LFO Output (read-only for UI indicators)
    kParam_LFO1_Output = 51,     // 0.0 to 1.0 (current LFO value for LED)
    kParam_LFO2_Output = 52      // 0.0 to 1.0 (current LFO value for LED)
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
    bool lfo1TempoSync;
    int lfo1NoteDivision;
    float lfo1Output;  // Current LFO value for indicator

    // LFO 2
    int lfo2Waveform;
    float lfo2Rate;
    double lfo2Phase;
    bool lfo2TempoSync;
    int lfo2NoteDivision;
    float lfo2Output;  // Current LFO value for indicator

    // Modulation Matrix
    struct ModSlot {
        int source;      // ModSource enum
        int destination; // ModDest enum
        float intensity; // 0.0 to 1.0
    } modSlots[kNumModSlots];

    // Effects Section
    int effectType;         // 0=None, 1=Chorus, 2=Phaser, 3=Flanger
    float effectRate;       // LFO rate: 0.1 to 10 Hz
    float effectIntensity;  // Effect depth: 0.0 to 1.0
    double effectLFOPhase;  // LFO phase accumulator

    // Chorus state
    static const int kChorusDelayBufferSize = 2048;  // Enough for 42ms at 48kHz
    float chorusDelayBuffer[kChorusDelayBufferSize];
    int chorusWritePos;

    // Phaser state (4 all-pass filters)
    float phaserState1, phaserState2, phaserState3, phaserState4;
    float phaserFeedbackSample;

    // Flanger state
    static const int kFlangerDelayBufferSize = 1024;  // Enough for 21ms at 48kHz
    float flangerDelayBuffer[kFlangerDelayBufferSize];
    int flangerWritePos;
    float flangerFeedbackSample;

    // Arpeggiator state
    int arpEnable;
    int arpRate;         // 0=1/4, 1=1/8, 2=1/16, 3=1/32
    int arpMode;         // 0=Up, 1=Down, 2=UpDown, 3=Random
    int arpOctaves;      // 1-4
    float arpGate;       // 0.0 to 1.0

    static const int kMaxArpNotes = 16;
    int heldNotes[kMaxArpNotes];  // MIDI note numbers currently held
    int heldNotesCount;
    int arpCurrentStep;
    double arpPhaseAccumulator;
    double hostTempo;    // BPM from host
    int currentArpNote;  // Currently playing arp note (-1 if none)
    bool arpNoteActive;  // Is an arp note currently playing

    // Oscilloscope (stored as void* to avoid Objective-C in header)
    void *oscilloscope;
};

// Helper functions
SynthVoice* FindFreeVoice(ClaudeSynthData *data);
SynthVoice* FindVoiceForNote(ClaudeSynthData *data, int note);

#endif
