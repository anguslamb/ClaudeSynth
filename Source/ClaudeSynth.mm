#include "ClaudeSynth.h"
#include "ClaudeSynthVersion.h"
#include "ClaudeSynthLogger.h"
#include <AudioToolbox/AudioToolbox.h>
#include <string.h>
#import "MatrixOscilloscope.h"

// Forward declarations
static OSStatus ClaudeSynth_Open(void *self, AudioUnit inUnit);
static OSStatus ClaudeSynth_Close(void *self);
static AudioComponentMethod ClaudeSynth_Lookup(SInt16 selector);
static OSStatus ClaudeSynth_Reset(void *self, AudioUnitScope inScope, AudioUnitElement inElement);
static OSStatus ClaudeSynth_Render(void *self, AudioUnitRenderActionFlags *ioActionFlags,
                                    const AudioTimeStamp *inTimeStamp, UInt32 inBusNumber,
                                    UInt32 inNumberFrames, AudioBufferList *ioData);
static OSStatus ClaudeSynth_MIDIEvent(void *self, UInt32 inStatus, UInt32 inData1,
                                       UInt32 inData2, UInt32 inStartFrame);
static OSStatus ClaudeSynth_GetPropertyInfo(void *self,
                                             AudioUnitPropertyID inID,
                                             AudioUnitScope inScope,
                                             AudioUnitElement inElement,
                                             UInt32 *outDataSize,
                                             UInt32 *outWritable);
static OSStatus ClaudeSynth_GetProperty(void *self,
                                         AudioUnitPropertyID inID,
                                         AudioUnitScope inScope,
                                         AudioUnitElement inElement,
                                         void *outData,
                                         UInt32 *ioDataSize);
static OSStatus ClaudeSynth_SetProperty(void *self,
                                         AudioUnitPropertyID inID,
                                         AudioUnitScope inScope,
                                         AudioUnitElement inElement,
                                         const void *inData,
                                         UInt32 inDataSize);
static OSStatus ClaudeSynth_Initialize(void *self);
static OSStatus ClaudeSynth_Uninitialize(void *self);
static OSStatus ClaudeSynth_Render(void *inRefCon,
                                    AudioUnitRenderActionFlags *ioActionFlags,
                                    const AudioTimeStamp *inTimeStamp,
                                    UInt32 inBusNumber,
                                    UInt32 inNumberFrames,
                                    AudioBufferList *ioData);
static OSStatus ClaudeSynth_MIDIEvent(void *inRefCon,
                                       UInt32 inStatus,
                                       UInt32 inData1,
                                       UInt32 inData2,
                                       UInt32 inStartFrame);
static OSStatus ClaudeSynth_SetParameter(void *self, AudioUnitParameterID inID,
                                          AudioUnitScope inScope, AudioUnitElement inElement,
                                          AudioUnitParameterValue inValue, UInt32 inBufferOffsetInFrames);
static OSStatus ClaudeSynth_GetParameter(void *self, AudioUnitParameterID inID,
                                          AudioUnitScope inScope, AudioUnitElement inElement,
                                          AudioUnitParameterValue *outValue);
static OSStatus ClaudeSynth_StartNote(void *self, MusicDeviceInstrumentID inInstrument,
                                       MusicDeviceGroupID inGroupID, NoteInstanceID *outNoteInstanceID,
                                       UInt32 inOffsetSampleFrame, const MusicDeviceNoteParams *inParams);
static OSStatus ClaudeSynth_StopNote(void *self, MusicDeviceGroupID inGroupID,
                                      NoteInstanceID inNoteInstanceID, UInt32 inOffsetSampleFrame);

// Factory function
extern "C" __attribute__((visibility("default"))) void *ClaudeSynthFactory(const AudioComponentDescription *inDesc) {
    ClaudeLog("Factory called");
    ClaudeSynthData *data = new ClaudeSynthData;
    memset(data, 0, sizeof(ClaudeSynthData));

    // Initialize plugin interface (must be first in struct!)
    data->pluginInterface.Open = ClaudeSynth_Open;
    data->pluginInterface.Close = ClaudeSynth_Close;
    data->pluginInterface.Lookup = ClaudeSynth_Lookup;
    data->pluginInterface.reserved = NULL;

    data->sampleRate = 44100.0;
    data->maxFramesPerSlice = 4096;

    // Initialize stream format
    data->streamFormat.mSampleRate = 44100.0;
    data->streamFormat.mFormatID = kAudioFormatLinearPCM;
    data->streamFormat.mFormatFlags = kAudioFormatFlagsNativeFloatPacked | kAudioFormatFlagIsNonInterleaved;
    data->streamFormat.mBytesPerPacket = sizeof(Float32);
    data->streamFormat.mFramesPerPacket = 1;
    data->streamFormat.mBytesPerFrame = sizeof(Float32);
    data->streamFormat.mChannelsPerFrame = 2;
    data->streamFormat.mBitsPerChannel = sizeof(Float32) * 8;

    // Initialize parameters
    data->masterVolume = 1.0f;

    // Oscillator 1 (active by default)
    data->osc1.waveform = kWaveform_Sine;
    data->osc1.octave = 0;
    data->osc1.detune = 0.0f;
    data->osc1.volume = 1.0f;

    // Oscillator 2 (silent by default)
    data->osc2.waveform = kWaveform_Sine;
    data->osc2.octave = 0;
    data->osc2.detune = 0.0f;
    data->osc2.volume = 0.0f;

    // Oscillator 3 (silent by default)
    data->osc3.waveform = kWaveform_Sine;
    data->osc3.octave = 0;
    data->osc3.detune = 0.0f;
    data->osc3.volume = 0.0f;

    data->filterCutoff = 20000.0f; // Wide open by default
    data->filterResonance = 0.7f; // Mild resonance by default

    // ADSR envelope defaults
    data->envAttack = 0.01f;   // 10ms attack
    data->envDecay = 0.3f;     // 300ms decay (increased for better UI clarity)
    data->envSustain = 0.7f;   // 70% sustain level
    data->envRelease = 0.3f;   // 300ms release

    // Filter envelope defaults (Global)
    data->filterEnvAttack = 0.01f;
    data->filterEnvDecay = 0.3f;   // 300ms decay (increased for better UI clarity)
    data->filterEnvSustain = 1.0f;  // Full sustain by default
    data->filterEnvRelease = 0.3f;
    data->filterEnvLevel = 0.0f;
    data->filterEnvStage = kEnvStage_Idle;
    data->filterEnvReleaseStartLevel = 0.0f;
    data->activeNoteCount = 0;

    // LFO 1 defaults
    data->lfo1Waveform = 0;     // Sine
    data->lfo1Rate = 5.0f;      // 5 Hz
    data->lfo1TempoSync = false;
    data->lfo1NoteDivision = 2; // 1/8 note
    data->lfo1Output = 0.0f;
    data->lfo1Phase = 0.0;

    // LFO 2 defaults
    data->lfo2Waveform = 0;     // Sine
    data->lfo2Rate = 3.0f;      // 3 Hz
    data->lfo2TempoSync = false;
    data->lfo2NoteDivision = 2; // 1/8 note
    data->lfo2Output = 0.0f;
    data->lfo2Phase = 0.0;

    // Initialize modulation matrix slots to empty
    for (int i = 0; i < kNumModSlots; i++) {
        data->modSlots[i].source = kModSource_None;
        data->modSlots[i].destination = kModDest_None;
        data->modSlots[i].intensity = 0.0f;
    }

    // Initialize effects parameters
    data->effectType = 0;           // None by default
    data->effectRate = 1.0f;        // 1 Hz
    data->effectIntensity = 0.5f;   // 50%
    data->effectLFOPhase = 0.0;

    // Initialize effect state
    data->chorusWritePos = 0;
    memset(data->chorusDelayBuffer, 0, sizeof(data->chorusDelayBuffer));

    data->phaserState1 = 0.0f;
    data->phaserState2 = 0.0f;
    data->phaserState3 = 0.0f;
    data->phaserState4 = 0.0f;
    data->phaserFeedbackSample = 0.0f;

    data->flangerWritePos = 0;
    memset(data->flangerDelayBuffer, 0, sizeof(data->flangerDelayBuffer));
    data->flangerFeedbackSample = 0.0f;

    // Initialize arpeggiator parameters
    data->arpEnable = 0;           // Off by default
    data->arpRate = 1;             // 1/8 note
    data->arpMode = 0;             // Up
    data->arpOctaves = 1;          // 1 octave
    data->arpGate = 0.9f;          // 90% gate

    // Initialize arpeggiator state
    data->heldNotesCount = 0;
    memset(data->heldNotes, -1, sizeof(data->heldNotes));
    data->arpCurrentStep = 0;
    data->arpPhaseAccumulator = 0.0;
    data->hostTempo = 120.0;       // Default tempo
    data->currentArpNote = -1;
    data->arpNoteActive = false;

    // Initialize oscilloscope pointer
    data->oscilloscope = NULL;

    ClaudeLog("Factory: initialized parameters");

    return &data->pluginInterface;
}

static OSStatus ClaudeSynth_Open(void *self, AudioUnit inUnit) {
    ClaudeLog("Open called");
    // Get data from plugin interface (pluginInterface is first member, so same pointer)
    ClaudeSynthData *data = (ClaudeSynthData *)self;

    data->componentInstance = inUnit;
    return noErr;
}

static OSStatus ClaudeSynth_Close(void *self) {
    ClaudeSynthData *data = (ClaudeSynthData *)self;

    delete data;
    return noErr;
}

static AudioComponentMethod ClaudeSynth_Lookup(SInt16 selector) {
    // Log all lookups to help debug arpeggiator issues
    const char *selectorName = "UNKNOWN";
    switch (selector) {
        case kAudioUnitInitializeSelect: selectorName = "Initialize"; break;
        case kMusicDeviceMIDIEventSelect: selectorName = "MIDIEvent"; break;
        case kMusicDeviceStartNoteSelect: selectorName = "StartNote"; break;
        case kMusicDeviceStopNoteSelect: selectorName = "StopNote"; break;
        case kAudioUnitRenderSelect: selectorName = "Render"; break;
        default: break;
    }
    ClaudeLog("Lookup: selector=%d (0x%X) [%s]", selector, selector, selectorName);

    switch (selector) {
        case kAudioUnitInitializeSelect:
            return (AudioComponentMethod)ClaudeSynth_Initialize;
        case kAudioUnitUninitializeSelect:
            return (AudioComponentMethod)ClaudeSynth_Uninitialize;
        case kAudioUnitGetPropertyInfoSelect:
            return (AudioComponentMethod)ClaudeSynth_GetPropertyInfo;
        case kAudioUnitGetPropertySelect:
            return (AudioComponentMethod)ClaudeSynth_GetProperty;
        case kAudioUnitSetPropertySelect:
            return (AudioComponentMethod)ClaudeSynth_SetProperty;
        case kAudioUnitRenderSelect:
            return (AudioComponentMethod)ClaudeSynth_Render;
        case kAudioUnitResetSelect:
            return (AudioComponentMethod)ClaudeSynth_Reset;
        case kMusicDeviceMIDIEventSelect:
            return (AudioComponentMethod)ClaudeSynth_MIDIEvent;
        case kAudioUnitSetParameterSelect:
            return (AudioComponentMethod)ClaudeSynth_SetParameter;
        case kAudioUnitGetParameterSelect:
            return (AudioComponentMethod)ClaudeSynth_GetParameter;
        case kMusicDeviceStartNoteSelect:
            return (AudioComponentMethod)ClaudeSynth_StartNote;
        case kMusicDeviceStopNoteSelect:
            return (AudioComponentMethod)ClaudeSynth_StopNote;
        default:
            return NULL;
    }
}

static OSStatus ClaudeSynth_Reset(void *self, AudioUnitScope inScope, AudioUnitElement inElement) {
    ClaudeSynthData *data = (ClaudeSynthData *)self;

    // Turn off all voices on reset
    for (int i = 0; i < kNumVoices; i++) {
        data->voices[i].NoteOff();
    }

    return noErr;
}

static OSStatus ClaudeSynth_GetPropertyInfo(void *self,
                                             AudioUnitPropertyID inID,
                                             AudioUnitScope inScope,
                                             AudioUnitElement inElement,
                                             UInt32 *outDataSize,
                                             UInt32 *outWritable) {
    ClaudeLog("GetPropertyInfo: id=0x%X, scope=%d, element=%d", inID, inScope, inElement);
    switch (inID) {
        case kAudioUnitProperty_StreamFormat:
            if (outDataSize) *outDataSize = sizeof(AudioStreamBasicDescription);
            if (outWritable) *outWritable = 1;
            return noErr;

        case kAudioUnitProperty_SampleRate:
            if (outDataSize) *outDataSize = sizeof(Float64);
            if (outWritable) *outWritable = 1;
            return noErr;

        case kAudioUnitProperty_SetRenderCallback:
            if (outDataSize) *outDataSize = sizeof(AURenderCallbackStruct);
            if (outWritable) *outWritable = 1;
            return noErr;

        case kAudioUnitProperty_ElementCount:
            if (outDataSize) *outDataSize = sizeof(UInt32);
            if (outWritable) *outWritable = 0;
            return noErr;

        case kAudioUnitProperty_ParameterList:
            if (outDataSize) *outDataSize = sizeof(AudioUnitParameterID) * 47;
            if (outWritable) *outWritable = 0;
            return noErr;

        case kAudioUnitProperty_ParameterInfo:
            if (outDataSize) *outDataSize = sizeof(AudioUnitParameterInfo);
            if (outWritable) *outWritable = 0;
            return noErr;

        case kAudioUnitProperty_CocoaUI:
        case 3002: // kAudioUnitProperty_GetUIComponentList
            if (outDataSize) *outDataSize = sizeof(AudioUnitCocoaViewInfo);
            if (outWritable) *outWritable = 0;
            return noErr;

        case kAudioUnitProperty_MaximumFramesPerSlice:
            if (outDataSize) *outDataSize = sizeof(UInt32);
            if (outWritable) *outWritable = 1;
            return noErr;

        case kAudioUnitProperty_Latency:
            if (outDataSize) *outDataSize = sizeof(Float64);
            if (outWritable) *outWritable = 0;
            return noErr;

        case kAudioUnitProperty_TailTime:
            if (outDataSize) *outDataSize = sizeof(Float64);
            if (outWritable) *outWritable = 0;
            return noErr;

        case kAudioUnitProperty_SupportedNumChannels:
            if (outDataSize) *outDataSize = sizeof(AUChannelInfo) * 2;
            if (outWritable) *outWritable = 0;
            return noErr;

        case kAudioUnitProperty_ShouldAllocateBuffer:
            if (outDataSize) *outDataSize = sizeof(UInt32);
            if (outWritable) *outWritable = 1;
            return noErr;

        case kAudioUnitProperty_MIDIOutputCallbackInfo:
            if (outDataSize) *outDataSize = sizeof(CFArrayRef);
            if (outWritable) *outWritable = 0;
            return noErr;

        case kMusicDeviceProperty_InstrumentCount:
            if (outDataSize) *outDataSize = sizeof(UInt32);
            if (outWritable) *outWritable = 0;
            return noErr;

        case kAudioUnitProperty_AudioChannelLayout:
            // Return stereo layout for output scope
            if (inScope == kAudioUnitScope_Output) {
                if (outDataSize) *outDataSize = offsetof(AudioChannelLayout, mChannelDescriptions);
                if (outWritable) *outWritable = 0;
                return noErr;
            }
            return kAudioUnitErr_InvalidProperty;

        default:
            ClaudeLog("GetPropertyInfo: UNKNOWN property 0x%X returning InvalidProperty", (unsigned int)inID);
            return kAudioUnitErr_InvalidProperty;
    }
}

static OSStatus ClaudeSynth_GetProperty(void *self,
                                         AudioUnitPropertyID inID,
                                         AudioUnitScope inScope,
                                         AudioUnitElement inElement,
                                         void *outData,
                                         UInt32 *ioDataSize) {
    ClaudeSynthData *data = (ClaudeSynthData *)self;

    ClaudeLog("GetProperty: id=0x%X, scope=%d, element=%d", (unsigned int)inID, (int)inScope, (int)inElement);

    switch (inID) {
        case kAudioUnitProperty_StreamFormat:
            if (*ioDataSize < sizeof(AudioStreamBasicDescription))
                return kAudioUnitErr_InvalidParameter;
            memcpy(outData, &data->streamFormat, sizeof(AudioStreamBasicDescription));
            *ioDataSize = sizeof(AudioStreamBasicDescription);
            return noErr;

        case kAudioUnitProperty_SampleRate:
            if (*ioDataSize < sizeof(Float64))
                return kAudioUnitErr_InvalidParameter;
            *(Float64 *)outData = data->sampleRate;
            *ioDataSize = sizeof(Float64);
            return noErr;

        case kAudioUnitProperty_ElementCount:
            if (*ioDataSize < sizeof(UInt32))
                return kAudioUnitErr_InvalidParameter;
            // Music devices have 0 inputs, 1 output
            *(UInt32 *)outData = (inScope == kAudioUnitScope_Input) ? 0 : 1;
            *ioDataSize = sizeof(UInt32);
            return noErr;

        case kAudioUnitProperty_MaximumFramesPerSlice:
            if (*ioDataSize < sizeof(UInt32))
                return kAudioUnitErr_InvalidParameter;
            *(UInt32 *)outData = data->maxFramesPerSlice;
            *ioDataSize = sizeof(UInt32);
            return noErr;

        case kAudioUnitProperty_Latency:
            if (*ioDataSize < sizeof(Float64))
                return kAudioUnitErr_InvalidParameter;
            *(Float64 *)outData = 0.0;  // Zero latency
            *ioDataSize = sizeof(Float64);
            return noErr;

        case kAudioUnitProperty_TailTime:
            if (*ioDataSize < sizeof(Float64))
                return kAudioUnitErr_InvalidParameter;
            *(Float64 *)outData = 0.0;  // No tail
            *ioDataSize = sizeof(Float64);
            return noErr;

        case kAudioUnitProperty_SupportedNumChannels:
            if (*ioDataSize < sizeof(AUChannelInfo) * 2)
                return kAudioUnitErr_InvalidParameter;
            {
                AUChannelInfo *info = (AUChannelInfo *)outData;
                // Support stereo output with no input
                info[0].inChannels = 0;
                info[0].outChannels = 2;
                // Support mono output
                info[1].inChannels = 0;
                info[1].outChannels = 1;
                *ioDataSize = sizeof(AUChannelInfo) * 2;
            }
            return noErr;

        case kAudioUnitProperty_ClassInfo:
            // Return empty class info (no preset data)
            *ioDataSize = 0;
            return noErr;

        case kAudioUnitProperty_ParameterList:
            if (*ioDataSize < sizeof(AudioUnitParameterID) * 47)
                return kAudioUnitErr_InvalidParameter;
            {
                AudioUnitParameterID *paramList = (AudioUnitParameterID *)outData;
                paramList[0] = kParam_MasterVolume;
                paramList[1] = kParam_Osc1_Waveform;
                paramList[2] = kParam_Osc1_Octave;
                paramList[3] = kParam_Osc1_Detune;
                paramList[4] = kParam_Osc1_Volume;
                paramList[5] = kParam_Osc2_Waveform;
                paramList[6] = kParam_Osc2_Octave;
                paramList[7] = kParam_Osc2_Detune;
                paramList[8] = kParam_Osc2_Volume;
                paramList[9] = kParam_Osc3_Waveform;
                paramList[10] = kParam_Osc3_Octave;
                paramList[11] = kParam_Osc3_Detune;
                paramList[12] = kParam_Osc3_Volume;
                paramList[13] = kParam_FilterCutoff;
                paramList[14] = kParam_FilterResonance;
                paramList[15] = kParam_EnvAttack;
                paramList[16] = kParam_EnvDecay;
                paramList[17] = kParam_EnvSustain;
                paramList[18] = kParam_EnvRelease;
                paramList[19] = kParam_FilterEnvAttack;
                paramList[20] = kParam_FilterEnvDecay;
                paramList[21] = kParam_FilterEnvSustain;
                paramList[22] = kParam_FilterEnvRelease;
                paramList[23] = kParam_LFO1_Waveform;
                paramList[24] = kParam_LFO1_Rate;
                paramList[25] = kParam_LFO2_Waveform;
                paramList[26] = kParam_LFO2_Rate;
                paramList[27] = kParam_ModSlot1_Source;
                paramList[28] = kParam_ModSlot1_Dest;
                paramList[29] = kParam_ModSlot1_Intensity;
                paramList[30] = kParam_ModSlot2_Source;
                paramList[31] = kParam_ModSlot2_Dest;
                paramList[32] = kParam_ModSlot2_Intensity;
                paramList[33] = kParam_ModSlot3_Source;
                paramList[34] = kParam_ModSlot3_Dest;
                paramList[35] = kParam_ModSlot3_Intensity;
                paramList[36] = kParam_ModSlot4_Source;
                paramList[37] = kParam_ModSlot4_Dest;
                paramList[38] = kParam_ModSlot4_Intensity;
                paramList[39] = kParam_EffectType;
                paramList[40] = kParam_EffectRate;
                paramList[41] = kParam_EffectIntensity;
                paramList[42] = kParam_ArpEnable;
                paramList[43] = kParam_ArpRate;
                paramList[44] = kParam_ArpMode;
                paramList[45] = kParam_ArpOctaves;
                paramList[46] = kParam_ArpGate;
                *ioDataSize = sizeof(AudioUnitParameterID) * 47;
            }
            return noErr;

        case kAudioUnitProperty_ParameterInfo:
            if (*ioDataSize < sizeof(AudioUnitParameterInfo))
                return kAudioUnitErr_InvalidParameter;
            if (inScope != kAudioUnitScope_Global)
                return kAudioUnitErr_InvalidScope;
            {
                AudioUnitParameterInfo *info = (AudioUnitParameterInfo *)outData;
                memset(info, 0, sizeof(AudioUnitParameterInfo));
                info->flags = kAudioUnitParameterFlag_IsWritable |
                              kAudioUnitParameterFlag_IsReadable |
                              kAudioUnitParameterFlag_HasCFNameString;

                switch (inElement) {
                    case kParam_MasterVolume:
                        info->unit = kAudioUnitParameterUnit_LinearGain;
                        info->minValue = 0.0f;
                        info->maxValue = 1.0f;
                        info->defaultValue = 1.0f;
                        info->cfNameString = CFSTR("Master Volume");
                        break;

                    case kParam_Osc1_Waveform:
                        info->unit = kAudioUnitParameterUnit_Indexed;
                        info->minValue = 0.0f;
                        info->maxValue = 3.0f;
                        info->defaultValue = 0.0f;
                        info->cfNameString = CFSTR("Osc 1 Waveform");
                        break;

                    case kParam_Osc1_Octave:
                        info->unit = kAudioUnitParameterUnit_Generic;
                        info->minValue = -2.0f;
                        info->maxValue = 2.0f;
                        info->defaultValue = 0.0f;
                        info->cfNameString = CFSTR("Osc 1 Octave");
                        break;

                    case kParam_Osc1_Detune:
                        info->unit = kAudioUnitParameterUnit_Cents;
                        info->minValue = -100.0f;
                        info->maxValue = 100.0f;
                        info->defaultValue = 0.0f;
                        info->cfNameString = CFSTR("Osc 1 Detune");
                        break;

                    case kParam_Osc1_Volume:
                        info->unit = kAudioUnitParameterUnit_LinearGain;
                        info->minValue = 0.0f;
                        info->maxValue = 1.0f;
                        info->defaultValue = 1.0f;
                        info->cfNameString = CFSTR("Osc 1 Volume");
                        break;

                    case kParam_Osc2_Waveform:
                        info->unit = kAudioUnitParameterUnit_Indexed;
                        info->minValue = 0.0f;
                        info->maxValue = 3.0f;
                        info->defaultValue = 0.0f;
                        info->cfNameString = CFSTR("Osc 2 Waveform");
                        break;

                    case kParam_Osc2_Octave:
                        info->unit = kAudioUnitParameterUnit_Generic;
                        info->minValue = -2.0f;
                        info->maxValue = 2.0f;
                        info->defaultValue = 0.0f;
                        info->cfNameString = CFSTR("Osc 2 Octave");
                        break;

                    case kParam_Osc2_Detune:
                        info->unit = kAudioUnitParameterUnit_Cents;
                        info->minValue = -100.0f;
                        info->maxValue = 100.0f;
                        info->defaultValue = 0.0f;
                        info->cfNameString = CFSTR("Osc 2 Detune");
                        break;

                    case kParam_Osc2_Volume:
                        info->unit = kAudioUnitParameterUnit_LinearGain;
                        info->minValue = 0.0f;
                        info->maxValue = 1.0f;
                        info->defaultValue = 0.0f;
                        info->cfNameString = CFSTR("Osc 2 Volume");
                        break;

                    case kParam_Osc3_Waveform:
                        info->unit = kAudioUnitParameterUnit_Indexed;
                        info->minValue = 0.0f;
                        info->maxValue = 3.0f;
                        info->defaultValue = 0.0f;
                        info->cfNameString = CFSTR("Osc 3 Waveform");
                        break;

                    case kParam_Osc3_Octave:
                        info->unit = kAudioUnitParameterUnit_Generic;
                        info->minValue = -2.0f;
                        info->maxValue = 2.0f;
                        info->defaultValue = 0.0f;
                        info->cfNameString = CFSTR("Osc 3 Octave");
                        break;

                    case kParam_Osc3_Detune:
                        info->unit = kAudioUnitParameterUnit_Cents;
                        info->minValue = -100.0f;
                        info->maxValue = 100.0f;
                        info->defaultValue = 0.0f;
                        info->cfNameString = CFSTR("Osc 3 Detune");
                        break;

                    case kParam_Osc3_Volume:
                        info->unit = kAudioUnitParameterUnit_LinearGain;
                        info->minValue = 0.0f;
                        info->maxValue = 1.0f;
                        info->defaultValue = 0.0f;
                        info->cfNameString = CFSTR("Osc 3 Volume");
                        break;

                    case kParam_FilterCutoff:
                        info->unit = kAudioUnitParameterUnit_Hertz;
                        info->minValue = 20.0f;
                        info->maxValue = 20000.0f;
                        info->defaultValue = 20000.0f;
                        info->cfNameString = CFSTR("Filter Cutoff");
                        break;

                    case kParam_FilterResonance:
                        info->unit = kAudioUnitParameterUnit_Generic;
                        info->minValue = 0.5f;
                        info->maxValue = 10.0f;
                        info->defaultValue = 0.7f;
                        info->cfNameString = CFSTR("Filter Resonance");
                        break;

                    case kParam_EnvAttack:
                        info->unit = kAudioUnitParameterUnit_Seconds;
                        info->minValue = 0.001f;
                        info->maxValue = 3.0f;
                        info->defaultValue = 0.01f;
                        info->cfNameString = CFSTR("Env Attack");
                        break;

                    case kParam_EnvDecay:
                        info->unit = kAudioUnitParameterUnit_Seconds;
                        info->minValue = 0.001f;
                        info->maxValue = 3.0f;
                        info->defaultValue = 0.3f;
                        info->cfNameString = CFSTR("Env Decay");
                        break;

                    case kParam_EnvSustain:
                        info->unit = kAudioUnitParameterUnit_LinearGain;
                        info->minValue = 0.0f;
                        info->maxValue = 1.0f;
                        info->defaultValue = 0.7f;
                        info->cfNameString = CFSTR("Env Sustain");
                        break;

                    case kParam_EnvRelease:
                        info->unit = kAudioUnitParameterUnit_Seconds;
                        info->minValue = 0.001f;
                        info->maxValue = 3.0f;
                        info->defaultValue = 0.3f;
                        info->cfNameString = CFSTR("Env Release");
                        break;

                    // Filter Envelope
                    case kParam_FilterEnvAttack:
                        info->unit = kAudioUnitParameterUnit_Seconds;
                        info->minValue = 0.001f;
                        info->maxValue = 3.0f;
                        info->defaultValue = 0.01f;
                        info->cfNameString = CFSTR("Filter Env Attack");
                        break;

                    case kParam_FilterEnvDecay:
                        info->unit = kAudioUnitParameterUnit_Seconds;
                        info->minValue = 0.001f;
                        info->maxValue = 3.0f;
                        info->defaultValue = 0.3f;
                        info->cfNameString = CFSTR("Filter Env Decay");
                        break;

                    case kParam_FilterEnvSustain:
                        info->unit = kAudioUnitParameterUnit_LinearGain;
                        info->minValue = 0.0f;
                        info->maxValue = 1.0f;
                        info->defaultValue = 1.0f;
                        info->cfNameString = CFSTR("Filter Env Sustain");
                        break;

                    case kParam_FilterEnvRelease:
                        info->unit = kAudioUnitParameterUnit_Seconds;
                        info->minValue = 0.001f;
                        info->maxValue = 3.0f;
                        info->defaultValue = 0.3f;
                        info->cfNameString = CFSTR("Filter Env Release");
                        break;

                    case kParam_LFO1_Waveform:
                        info->unit = kAudioUnitParameterUnit_Indexed;
                        info->minValue = 0.0f;
                        info->maxValue = 3.0f;
                        info->defaultValue = 0.0f;
                        info->cfNameString = CFSTR("LFO 1 Waveform");
                        break;

                    case kParam_LFO1_Rate:
                        info->unit = kAudioUnitParameterUnit_Hertz;
                        info->minValue = 0.1f;
                        info->maxValue = 10.0f;
                        info->defaultValue = 5.0f;
                        info->cfNameString = CFSTR("LFO 1 Rate");
                        break;

                    case kParam_LFO1_TempoSync:
                        info->unit = kAudioUnitParameterUnit_Boolean;
                        info->minValue = 0.0f;
                        info->maxValue = 1.0f;
                        info->defaultValue = 0.0f;
                        info->cfNameString = CFSTR("LFO 1 Tempo Sync");
                        break;

                    case kParam_LFO1_NoteDivision:
                        info->unit = kAudioUnitParameterUnit_Indexed;
                        info->minValue = 0.0f;
                        info->maxValue = 14.0f;
                        info->defaultValue = 2.0f;  // 1/8 note
                        info->cfNameString = CFSTR("LFO 1 Note Division");
                        break;

                    case kParam_LFO2_Waveform:
                        info->unit = kAudioUnitParameterUnit_Indexed;
                        info->minValue = 0.0f;
                        info->maxValue = 3.0f;
                        info->defaultValue = 0.0f;
                        info->cfNameString = CFSTR("LFO 2 Waveform");
                        break;

                    case kParam_LFO2_Rate:
                        info->unit = kAudioUnitParameterUnit_Hertz;
                        info->minValue = 0.1f;
                        info->maxValue = 10.0f;
                        info->defaultValue = 3.0f;
                        info->cfNameString = CFSTR("LFO 2 Rate");
                        break;

                    case kParam_LFO2_TempoSync:
                        info->unit = kAudioUnitParameterUnit_Boolean;
                        info->minValue = 0.0f;
                        info->maxValue = 1.0f;
                        info->defaultValue = 0.0f;
                        info->cfNameString = CFSTR("LFO 2 Tempo Sync");
                        break;

                    case kParam_LFO2_NoteDivision:
                        info->unit = kAudioUnitParameterUnit_Indexed;
                        info->minValue = 0.0f;
                        info->maxValue = 14.0f;
                        info->defaultValue = 2.0f;  // 1/8 note
                        info->cfNameString = CFSTR("LFO 2 Note Division");
                        break;

                    // Modulation Matrix Slot 1
                    case kParam_ModSlot1_Source:
                        info->unit = kAudioUnitParameterUnit_Indexed;
                        info->minValue = 0.0f;
                        info->maxValue = 3.0f;
                        info->defaultValue = 0.0f;
                        info->cfNameString = CFSTR("Mod 1 Source");
                        break;

                    case kParam_ModSlot1_Dest:
                        info->unit = kAudioUnitParameterUnit_Indexed;
                        info->minValue = 0.0f;
                        info->maxValue = 9.0f;
                        info->defaultValue = 0.0f;
                        info->cfNameString = CFSTR("Mod 1 Destination");
                        break;

                    case kParam_ModSlot1_Intensity:
                        info->unit = kAudioUnitParameterUnit_Generic;
                        info->minValue = 0.0f;
                        info->maxValue = 1.0f;
                        info->defaultValue = 0.0f;
                        info->cfNameString = CFSTR("Mod 1 Intensity");
                        break;

                    // Modulation Matrix Slot 2
                    case kParam_ModSlot2_Source:
                        info->unit = kAudioUnitParameterUnit_Indexed;
                        info->minValue = 0.0f;
                        info->maxValue = 3.0f;
                        info->defaultValue = 0.0f;
                        info->cfNameString = CFSTR("Mod 2 Source");
                        break;

                    case kParam_ModSlot2_Dest:
                        info->unit = kAudioUnitParameterUnit_Indexed;
                        info->minValue = 0.0f;
                        info->maxValue = 9.0f;
                        info->defaultValue = 0.0f;
                        info->cfNameString = CFSTR("Mod 2 Destination");
                        break;

                    case kParam_ModSlot2_Intensity:
                        info->unit = kAudioUnitParameterUnit_Generic;
                        info->minValue = 0.0f;
                        info->maxValue = 1.0f;
                        info->defaultValue = 0.0f;
                        info->cfNameString = CFSTR("Mod 2 Intensity");
                        break;

                    // Modulation Matrix Slot 3
                    case kParam_ModSlot3_Source:
                        info->unit = kAudioUnitParameterUnit_Indexed;
                        info->minValue = 0.0f;
                        info->maxValue = 3.0f;
                        info->defaultValue = 0.0f;
                        info->cfNameString = CFSTR("Mod 3 Source");
                        break;

                    case kParam_ModSlot3_Dest:
                        info->unit = kAudioUnitParameterUnit_Indexed;
                        info->minValue = 0.0f;
                        info->maxValue = 9.0f;
                        info->defaultValue = 0.0f;
                        info->cfNameString = CFSTR("Mod 3 Destination");
                        break;

                    case kParam_ModSlot3_Intensity:
                        info->unit = kAudioUnitParameterUnit_Generic;
                        info->minValue = 0.0f;
                        info->maxValue = 1.0f;
                        info->defaultValue = 0.0f;
                        info->cfNameString = CFSTR("Mod 3 Intensity");
                        break;

                    // Modulation Matrix Slot 4
                    case kParam_ModSlot4_Source:
                        info->unit = kAudioUnitParameterUnit_Indexed;
                        info->minValue = 0.0f;
                        info->maxValue = 3.0f;
                        info->defaultValue = 0.0f;
                        info->cfNameString = CFSTR("Mod 4 Source");
                        break;

                    case kParam_ModSlot4_Dest:
                        info->unit = kAudioUnitParameterUnit_Indexed;
                        info->minValue = 0.0f;
                        info->maxValue = 9.0f;
                        info->defaultValue = 0.0f;
                        info->cfNameString = CFSTR("Mod 4 Destination");
                        break;

                    case kParam_ModSlot4_Intensity:
                        info->unit = kAudioUnitParameterUnit_Generic;
                        info->minValue = 0.0f;
                        info->maxValue = 1.0f;
                        info->defaultValue = 0.0f;
                        info->cfNameString = CFSTR("Mod 4 Intensity");
                        break;

                    case kParam_EffectType:
                        info->unit = kAudioUnitParameterUnit_Indexed;
                        info->minValue = 0.0f;
                        info->maxValue = 3.0f;
                        info->defaultValue = 0.0f;
                        info->cfNameString = CFSTR("Effect Type");
                        break;

                    case kParam_EffectRate:
                        info->unit = kAudioUnitParameterUnit_Hertz;
                        info->minValue = 0.1f;
                        info->maxValue = 10.0f;
                        info->defaultValue = 1.0f;
                        info->cfNameString = CFSTR("Effect Rate");
                        break;

                    case kParam_EffectIntensity:
                        info->unit = kAudioUnitParameterUnit_Generic;
                        info->minValue = 0.0f;
                        info->maxValue = 1.0f;
                        info->defaultValue = 0.5f;
                        info->cfNameString = CFSTR("Effect Intensity");
                        break;

                    case kParam_ArpEnable:
                        info->unit = kAudioUnitParameterUnit_Boolean;
                        info->minValue = 0.0f;
                        info->maxValue = 1.0f;
                        info->defaultValue = 0.0f;
                        info->cfNameString = CFSTR("Arpeggiator Enable");
                        break;

                    case kParam_ArpRate:
                        info->unit = kAudioUnitParameterUnit_Indexed;
                        info->minValue = 0.0f;
                        info->maxValue = 3.0f;
                        info->defaultValue = 1.0f;
                        info->cfNameString = CFSTR("Arpeggiator Rate");
                        break;

                    case kParam_ArpMode:
                        info->unit = kAudioUnitParameterUnit_Indexed;
                        info->minValue = 0.0f;
                        info->maxValue = 3.0f;
                        info->defaultValue = 0.0f;
                        info->cfNameString = CFSTR("Arpeggiator Mode");
                        break;

                    case kParam_ArpOctaves:
                        info->unit = kAudioUnitParameterUnit_Generic;
                        info->minValue = 1.0f;
                        info->maxValue = 4.0f;
                        info->defaultValue = 1.0f;
                        info->cfNameString = CFSTR("Arpeggiator Octaves");
                        break;

                    case kParam_ArpGate:
                        info->unit = kAudioUnitParameterUnit_Percent;
                        info->minValue = 0.1f;
                        info->maxValue = 1.0f;
                        info->defaultValue = 0.9f;
                        info->cfNameString = CFSTR("Arpeggiator Gate");
                        break;

                    case kParam_LFO1_Output:
                        info->unit = kAudioUnitParameterUnit_Generic;
                        info->minValue = 0.0f;
                        info->maxValue = 1.0f;
                        info->defaultValue = 0.0f;
                        info->flags = kAudioUnitParameterFlag_IsReadable;  // Read-only
                        info->cfNameString = CFSTR("LFO 1 Output");
                        break;

                    case kParam_LFO2_Output:
                        info->unit = kAudioUnitParameterUnit_Generic;
                        info->minValue = 0.0f;
                        info->maxValue = 1.0f;
                        info->defaultValue = 0.0f;
                        info->flags = kAudioUnitParameterFlag_IsReadable;  // Read-only
                        info->cfNameString = CFSTR("LFO 2 Output");
                        break;

                    default:
                        return kAudioUnitErr_InvalidParameter;
                }

                *ioDataSize = sizeof(AudioUnitParameterInfo);
                return noErr;
            }

        case kAudioUnitProperty_CocoaUI:
        case 3002: // kAudioUnitProperty_GetUIComponentList
            if (*ioDataSize < sizeof(AudioUnitCocoaViewInfo))
                return kAudioUnitErr_InvalidParameter;
            {
                AudioUnitCocoaViewInfo *viewInfo = (AudioUnitCocoaViewInfo *)outData;

                // Get the bundle containing this plugin
                CFBundleRef bundle = CFBundleGetBundleWithIdentifier(CFSTR("com.demo.audiounit.ClaudeSynth"));
                if (bundle) {
                    CFURLRef bundleURL = CFBundleCopyBundleURL(bundle);
                    viewInfo->mCocoaAUViewBundleLocation = bundleURL;

                    // Factory class name
                    CFStringRef factoryClassName = CFStringCreateWithCString(NULL, "ClaudeSynthViewFactory", kCFStringEncodingUTF8);
                    viewInfo->mCocoaAUViewClass[0] = factoryClassName;

                    *ioDataSize = sizeof(AudioUnitCocoaViewInfo);
                    return noErr;
                }
            }
            return kAudioUnitErr_InvalidProperty;

        case kAudioUnitProperty_ShouldAllocateBuffer:
            if (*ioDataSize < sizeof(UInt32))
                return kAudioUnitErr_InvalidParameter;
            // Music devices should allocate their own buffers
            *(UInt32 *)outData = 1;
            *ioDataSize = sizeof(UInt32);
            return noErr;

        case kAudioUnitProperty_MIDIOutputCallbackInfo:
            // Return empty array - we accept MIDI input but don't produce MIDI output
            if (*ioDataSize < sizeof(CFArrayRef))
                return kAudioUnitErr_InvalidParameter;
            *(CFArrayRef *)outData = CFArrayCreate(NULL, NULL, 0, &kCFTypeArrayCallBacks);
            *ioDataSize = sizeof(CFArrayRef);
            return noErr;

        case kMusicDeviceProperty_InstrumentCount:
            // We are a single instrument
            if (*ioDataSize < sizeof(UInt32))
                return kAudioUnitErr_InvalidParameter;
            *(UInt32 *)outData = 1;
            *ioDataSize = sizeof(UInt32);
            return noErr;

        case kAudioUnitProperty_AudioChannelLayout:
            // Return stereo layout for output scope
            if (inScope == kAudioUnitScope_Output) {
                if (*ioDataSize < offsetof(AudioChannelLayout, mChannelDescriptions))
                    return kAudioUnitErr_InvalidParameter;
                AudioChannelLayout *layout = (AudioChannelLayout *)outData;
                layout->mChannelLayoutTag = kAudioChannelLayoutTag_Stereo;
                layout->mChannelBitmap = 0;
                layout->mNumberChannelDescriptions = 0;
                *ioDataSize = offsetof(AudioChannelLayout, mChannelDescriptions);
                return noErr;
            }
            return kAudioUnitErr_InvalidProperty;

        case 0x3C: // kAudioUnitProperty_OfflineRender or similar
        case 0x18A8B: // kAudioUnitProperty_SupportsMPE
            // Return not supported for these
            return kAudioUnitErr_InvalidProperty;

        case kAudioUnitProperty_OfflineRender:
        case kAudioUnitProperty_FastDispatch:
        case kAudioUnitProperty_CPULoad:
        case kAudioUnitProperty_PresentPreset:
            // Optional properties - return not supported
            return kAudioUnitErr_InvalidProperty;

        // Parameter and UI-related properties
        case 0x1A: // kAudioUnitProperty_IconLocation
        case 0x1D: // kAudioUnitProperty_NickName
        case 0x42: // Unknown
        case 0x3A: // kAudioUnitProperty_ParameterValueStrings
        case 0x18: // kAudioUnitProperty_ElementName
            // No icon, nickname, or parameter strings for this simple plugin
            return kAudioUnitErr_InvalidProperty;

        default:
            ClaudeLog("GetProperty: UNKNOWN property 0x%X", (unsigned int)inID);
            return kAudioUnitErr_InvalidProperty;
    }
}

static OSStatus ClaudeSynth_SetProperty(void *self,
                                         AudioUnitPropertyID inID,
                                         AudioUnitScope inScope,
                                         AudioUnitElement inElement,
                                         const void *inData,
                                         UInt32 inDataSize) {
    ClaudeSynthData *data = (ClaudeSynthData *)self;

    ClaudeLog("SetProperty: id=0x%X, scope=%d, element=%d", (unsigned int)inID, (int)inScope, (int)inElement);

    switch (inID) {
        case kAudioUnitProperty_StreamFormat:
            if (inDataSize < sizeof(AudioStreamBasicDescription))
                return kAudioUnitErr_InvalidParameter;
            memcpy(&data->streamFormat, inData, sizeof(AudioStreamBasicDescription));
            data->sampleRate = data->streamFormat.mSampleRate;
            return noErr;

        case kAudioUnitProperty_SampleRate:
            if (inDataSize < sizeof(Float64))
                return kAudioUnitErr_InvalidParameter;
            data->sampleRate = *(const Float64 *)inData;
            data->streamFormat.mSampleRate = data->sampleRate;
            return noErr;

        case kAudioUnitProperty_MaximumFramesPerSlice:
            if (inDataSize < sizeof(UInt32))
                return kAudioUnitErr_InvalidParameter;
            data->maxFramesPerSlice = *(const UInt32 *)inData;
            ClaudeLog("MaxFramesPerSlice set to %d", data->maxFramesPerSlice);
            return noErr;

        case kAudioUnitProperty_SetRenderCallback:
            // Music devices don't need an explicit render callback
            return noErr;

        case kAudioUnitProperty_MakeConnection:
        case kAudioUnitProperty_SetExternalBuffer:
        case kAudioUnitProperty_ScheduledFileIDs:
        case kAudioUnitProperty_ScheduledFileRegion:
        case kAudioUnitProperty_ScheduledFilePrime:
        case kAudioUnitProperty_ScheduledFileBufferSizeFrames:
        case kAudioUnitProperty_ScheduleAudioSlice:
            // Not applicable for music devices - silently accept
            return noErr;

        case 0x2E: // HostCallbacks
        case 0x28: // ContextName
        case 0x19: // RenderQuality
        case kAudioUnitProperty_OfflineRender:
        case kAudioUnitProperty_BypassEffect:
            // Accept but ignore these properties
            return noErr;

        case kAudioUnitProperty_ClassInfo:
        case kAudioUnitProperty_PresentPreset:
            // Preset management - not implemented yet
            return noErr;

        // Parameter-related properties - accept silently since we have no parameters
        case 0x1B: // kAudioUnitProperty_DependentParameters
        case 0x41: // Unknown parameter-related
        case 0x3F5: // Unknown parameter-related
            return noErr;

        case kClaudeSynthProperty_Oscilloscope:
            if (inDataSize < sizeof(void *))
                return kAudioUnitErr_InvalidParameter;
            data->oscilloscope = *(void * const *)inData;
            ClaudeLog("SetProperty: oscilloscope pointer set to %p", data->oscilloscope);
            return noErr;

        default:
            ClaudeLog("SetProperty: UNKNOWN property 0x%X", (unsigned int)inID);
            return kAudioUnitErr_InvalidProperty;
    }
}

static OSStatus ClaudeSynth_Initialize(void *self) {
    ClaudeSynthData *data = (ClaudeSynthData *)self;
    ClaudeLog("Initialize called, sample rate = %f", data->sampleRate);

    // Update sample rate for all voices when initialized
    for (int i = 0; i < kNumVoices; i++) {
        data->voices[i].NoteOff();
    }

    return noErr;
}

static OSStatus ClaudeSynth_Uninitialize(void *self) {
    ClaudeSynthData *data = (ClaudeSynthData *)self;

    // Turn off all voices
    for (int i = 0; i < kNumVoices; i++) {
        data->voices[i].NoteOff();
    }
    return noErr;
}

// Chorus Effect - creates a doubling/thickening effect
static float ProcessChorusEffect(ClaudeSynthData *data, float inputSample, float lfoValue) {
    // Write input to delay buffer
    data->chorusDelayBuffer[data->chorusWritePos] = inputSample;

    // Calculate delay time with reduced depth for smoother modulation
    float baseDelaySamples = 0.015f * data->sampleRate;  // 15ms base
    float modDepthSamples = 0.002f * data->sampleRate;   // ±2ms modulation
    float delayTimeSamples = baseDelaySamples + (lfoValue * modDepthSamples);

    // Calculate read position with proper wrapping
    float readPosFloat = (float)data->chorusWritePos - delayTimeSamples;
    while (readPosFloat < 0.0f) {
        readPosFloat += ClaudeSynthData::kChorusDelayBufferSize;
    }
    while (readPosFloat >= ClaudeSynthData::kChorusDelayBufferSize) {
        readPosFloat -= ClaudeSynthData::kChorusDelayBufferSize;
    }

    // Linear interpolation between samples
    int readPos1 = (int)readPosFloat;
    int readPos2 = (readPos1 + 1) % ClaudeSynthData::kChorusDelayBufferSize;
    float frac = readPosFloat - (float)readPos1;

    float delayedSample = data->chorusDelayBuffer[readPos1] * (1.0f - frac) +
                          data->chorusDelayBuffer[readPos2] * frac;

    // Mix dry and wet signals (classic chorus uses 50/50 mix)
    float wetAmount = data->effectIntensity;
    float output = inputSample * (1.0f - wetAmount * 0.5f) + delayedSample * wetAmount * 0.5f;

    // Advance write position
    data->chorusWritePos = (data->chorusWritePos + 1) % ClaudeSynthData::kChorusDelayBufferSize;

    return output;
}

// Phaser Effect - creates sweeping notch filter effect
static float ProcessPhaserEffect(ClaudeSynthData *data, float inputSample, float lfoValue) {
    float centerFreq = 200.0f + (lfoValue * 0.5f + 0.5f) * 1800.0f;

    float omega = M_PI * centerFreq / data->sampleRate;
    float tanOmega = tanf(omega);
    float a = (tanOmega - 1.0f) / (tanOmega + 1.0f);

    float stage1 = a * inputSample + data->phaserState1;
    data->phaserState1 = inputSample - a * stage1;

    float stage2 = a * stage1 + data->phaserState2;
    data->phaserState2 = stage1 - a * stage2;

    float stage3 = a * stage2 + data->phaserState3;
    data->phaserState3 = stage2 - a * stage3;

    float stage4 = a * stage3 + data->phaserState4;
    data->phaserState4 = stage3 - a * stage4;

    float feedback = data->effectIntensity * 0.7f;
    float phasedSignal = stage4 + data->phaserFeedbackSample * feedback;
    data->phaserFeedbackSample = phasedSignal;

    float output = inputSample + phasedSignal * 0.5f;

    return output;
}

// Flanger Effect - creates jet plane whoosh effect
static float ProcessFlangerEffect(ClaudeSynthData *data, float inputSample, float lfoValue) {
    // Apply feedback with softer limiting
    float feedback = data->effectIntensity * 0.7f;  // Reduced from 0.9 to prevent harsh distortion
    float inputWithFeedback = inputSample + data->flangerFeedbackSample * feedback;

    // Soft clipping to prevent harsh distortion
    if (inputWithFeedback > 1.0f) inputWithFeedback = 1.0f;
    if (inputWithFeedback < -1.0f) inputWithFeedback = -1.0f;

    data->flangerDelayBuffer[data->flangerWritePos] = inputWithFeedback;

    // Calculate delay time (sweeps from 1ms to 4ms)
    float minDelay = 0.001f * data->sampleRate;  // 1ms
    float maxDelay = 0.004f * data->sampleRate;  // 4ms
    float delayTimeSamples = minDelay + (lfoValue * 0.5f + 0.5f) * (maxDelay - minDelay);

    // Calculate read position with proper wrapping
    float readPosFloat = (float)data->flangerWritePos - delayTimeSamples;
    while (readPosFloat < 0.0f) {
        readPosFloat += ClaudeSynthData::kFlangerDelayBufferSize;
    }
    while (readPosFloat >= ClaudeSynthData::kFlangerDelayBufferSize) {
        readPosFloat -= ClaudeSynthData::kFlangerDelayBufferSize;
    }

    // Linear interpolation
    int readPos1 = (int)readPosFloat;
    int readPos2 = (readPos1 + 1) % ClaudeSynthData::kFlangerDelayBufferSize;
    float frac = readPosFloat - (float)readPos1;

    float delayedSample = data->flangerDelayBuffer[readPos1] * (1.0f - frac) +
                          data->flangerDelayBuffer[readPos2] * frac;

    data->flangerFeedbackSample = delayedSample;

    // Mix dry and wet
    float output = inputSample * 0.5f + delayedSample * 0.5f;

    // Advance write position
    data->flangerWritePos = (data->flangerWritePos + 1) % ClaudeSynthData::kFlangerDelayBufferSize;

    return output;
}

// Update global filter envelope
static void UpdateGlobalFilterEnvelope(ClaudeSynthData *data) {
    switch (data->filterEnvStage) {
        case kEnvStage_Idle:
            data->filterEnvLevel = 0.0f;
            break;

        case kEnvStage_Attack:
            if (data->filterEnvAttack > 0.0001f) {
                float attackRate = 1.0f / (data->filterEnvAttack * data->sampleRate);
                data->filterEnvLevel += attackRate;
                if (data->filterEnvLevel >= 1.0f) {
                    data->filterEnvLevel = 1.0f;
                    data->filterEnvStage = kEnvStage_Decay;
                }
            } else {
                data->filterEnvLevel = 1.0f;
                data->filterEnvStage = kEnvStage_Decay;
            }
            break;

        case kEnvStage_Decay:
            if (data->filterEnvDecay > 0.0001f) {
                float decayRate = (1.0f - data->filterEnvSustain) / (data->filterEnvDecay * data->sampleRate);
                data->filterEnvLevel -= decayRate;
                if (data->filterEnvLevel <= data->filterEnvSustain) {
                    data->filterEnvLevel = data->filterEnvSustain;
                    data->filterEnvStage = kEnvStage_Sustain;
                }
            } else {
                data->filterEnvLevel = data->filterEnvSustain;
                data->filterEnvStage = kEnvStage_Sustain;
            }
            break;

        case kEnvStage_Sustain:
            data->filterEnvLevel = data->filterEnvSustain;
            break;

        case kEnvStage_Release:
            if (data->filterEnvRelease > 0.0001f) {
                float releaseRate = data->filterEnvReleaseStartLevel / (data->filterEnvRelease * data->sampleRate);
                data->filterEnvLevel -= releaseRate;
                if (data->filterEnvLevel <= 0.0f) {
                    data->filterEnvLevel = 0.0f;
                    data->filterEnvStage = kEnvStage_Idle;
                }
            } else {
                data->filterEnvLevel = 0.0f;
                data->filterEnvStage = kEnvStage_Idle;
            }
            break;
    }
}

// Helper function to sort held notes (for arpeggiator)
static void SortHeldNotes(int *notes, int count) {
    // Simple bubble sort (fine for small arrays)
    for (int i = 0; i < count - 1; i++) {
        for (int j = 0; j < count - i - 1; j++) {
            if (notes[j] > notes[j + 1]) {
                int temp = notes[j];
                notes[j] = notes[j + 1];
                notes[j + 1] = temp;
            }
        }
    }
}

// Generate arpeggio note at current step
static int GetArpNote(ClaudeSynthData *data) {
    if (data->heldNotesCount == 0) return -1;

    // Sort held notes for consistent ordering
    int sortedNotes[ClaudeSynthData::kMaxArpNotes];
    for (int i = 0; i < data->heldNotesCount; i++) {
        sortedNotes[i] = data->heldNotes[i];
    }
    SortHeldNotes(sortedNotes, data->heldNotesCount);

    // Calculate total notes including octaves
    int totalNotes = data->heldNotesCount * data->arpOctaves;
    int step = data->arpCurrentStep % totalNotes;

    int note = -1;
    switch (data->arpMode) {
        case 0: // Up
            {
                int octave = step / data->heldNotesCount;
                int noteIndex = step % data->heldNotesCount;
                note = sortedNotes[noteIndex] + (octave * 12);
            }
            break;

        case 1: // Down
            {
                int reverseStep = totalNotes - 1 - step;
                int octave = reverseStep / data->heldNotesCount;
                int noteIndex = reverseStep % data->heldNotesCount;
                note = sortedNotes[noteIndex] + (octave * 12);
            }
            break;

        case 2: // Up/Down (non-repeating peaks)
            {
                int upDownLength = (totalNotes * 2) - 2;
                if (upDownLength < 1) upDownLength = 1;
                int pos = step % upDownLength;

                if (pos < totalNotes) {
                    // Going up
                    int octave = pos / data->heldNotesCount;
                    int noteIndex = pos % data->heldNotesCount;
                    note = sortedNotes[noteIndex] + (octave * 12);
                } else {
                    // Going down
                    int downPos = upDownLength - pos;
                    int octave = downPos / data->heldNotesCount;
                    int noteIndex = downPos % data->heldNotesCount;
                    note = sortedNotes[noteIndex] + (octave * 12);
                }
            }
            break;

        case 3: // Random
            {
                int randomStep = rand() % totalNotes;
                int octave = randomStep / data->heldNotesCount;
                int noteIndex = randomStep % data->heldNotesCount;
                note = sortedNotes[noteIndex] + (octave * 12);
            }
            break;
    }

    return note;
}

// Calculate LFO frequency from note division and tempo
// Note divisions: 0=1/32, 1=1/16, 2=1/8, 3=1/4, 4=1/2, 5=1/1,
//                 6=1/32T, 7=1/16T, 8=1/8T, 9=1/4T, 10=1/2T,
//                 11=1/16., 12=1/8., 13=1/4., 14=1/2.
static double GetLFOFrequencyFromDivision(int division, double tempo) {
    double beatsPerSecond = tempo / 60.0;
    double cyclesPerBeat = 1.0;

    switch (division) {
        case 0: cyclesPerBeat = 8.0; break;      // 1/32
        case 1: cyclesPerBeat = 4.0; break;      // 1/16
        case 2: cyclesPerBeat = 2.0; break;      // 1/8
        case 3: cyclesPerBeat = 1.0; break;      // 1/4
        case 4: cyclesPerBeat = 0.5; break;      // 1/2
        case 5: cyclesPerBeat = 0.25; break;     // 1/1 (whole note)
        case 6: cyclesPerBeat = 12.0; break;     // 1/32 triplet
        case 7: cyclesPerBeat = 6.0; break;      // 1/16 triplet
        case 8: cyclesPerBeat = 3.0; break;      // 1/8 triplet
        case 9: cyclesPerBeat = 1.5; break;      // 1/4 triplet
        case 10: cyclesPerBeat = 0.75; break;    // 1/2 triplet
        case 11: cyclesPerBeat = 6.0; break;     // 1/16 dotted
        case 12: cyclesPerBeat = 3.0; break;     // 1/8 dotted
        case 13: cyclesPerBeat = 1.5; break;     // 1/4 dotted
        case 14: cyclesPerBeat = 0.75; break;    // 1/2 dotted
        default: cyclesPerBeat = 1.0; break;
    }

    return beatsPerSecond * cyclesPerBeat;
}

static OSStatus ClaudeSynth_Render(void *self,
                                    AudioUnitRenderActionFlags *ioActionFlags,
                                    const AudioTimeStamp *inTimeStamp,
                                    UInt32 inBusNumber,
                                    UInt32 inNumberFrames,
                                    AudioBufferList *ioData) {
    ClaudeSynthData *data = (ClaudeSynthData *)self;

    static int renderCount = 0;
    if (renderCount++ < 5) {
        ClaudeLog("Render called: frames=%d, buffers=%d", inNumberFrames, ioData ? ioData->mNumberBuffers : 0);
    }

    // Ensure we have output buffers
    if (!ioData || ioData->mNumberBuffers == 0) {
        return kAudioUnitErr_InvalidParameter;
    }

    // Get output buffers
    float *left = (float *)ioData->mBuffers[0].mData;
    float *right = NULL;

    if (ioData->mNumberBuffers > 1) {
        right = (float *)ioData->mBuffers[1].mData;
    } else {
        right = left; // Mono output
    }

    if (!left) {
        return kAudioUnitErr_InvalidParameter;
    }

    // Clear output buffers
    memset(left, 0, inNumberFrames * sizeof(float));
    if (right != left) {
        memset(right, 0, inNumberFrames * sizeof(float));
    }

    // Render all active voices
    for (UInt32 frame = 0; frame < inNumberFrames; frame++) {
        // Calculate global LFO 1 value for this frame
        double lfo1Frequency = data->lfo1Rate;
        if (data->lfo1TempoSync) {
            lfo1Frequency = GetLFOFrequencyFromDivision(data->lfo1NoteDivision, data->hostTempo);
        }
        double lfo1PhaseIncrement = (lfo1Frequency / data->sampleRate) * 2.0 * M_PI;
        data->lfo1Phase += lfo1PhaseIncrement;
        if (data->lfo1Phase >= 2.0 * M_PI) {
            data->lfo1Phase -= 2.0 * M_PI;
        }

        // Generate LFO 1 waveform output (-1 to 1)
        float lfo1Value = 0.0f;
        float normalizedPhase1 = data->lfo1Phase / (2.0 * M_PI);
        switch (data->lfo1Waveform) {
            case 0: // Sine
                lfo1Value = sinf(data->lfo1Phase);
                break;
            case 1: // Square
                lfo1Value = (normalizedPhase1 < 0.5f) ? 1.0f : -1.0f;
                break;
            case 2: // Sawtooth
                lfo1Value = 2.0f * normalizedPhase1 - 1.0f;
                break;
            case 3: // Triangle
                lfo1Value = (normalizedPhase1 < 0.5f) ?
                           (4.0f * normalizedPhase1 - 1.0f) :
                           (-4.0f * normalizedPhase1 + 3.0f);
                break;
        }

        // Store LFO 1 output for indicator (convert from -1..1 to 0..1)
        data->lfo1Output = (lfo1Value + 1.0f) * 0.5f;

        // Calculate global LFO 2 value for this frame
        double lfo2Frequency = data->lfo2Rate;
        if (data->lfo2TempoSync) {
            lfo2Frequency = GetLFOFrequencyFromDivision(data->lfo2NoteDivision, data->hostTempo);
        }
        double lfo2PhaseIncrement = (lfo2Frequency / data->sampleRate) * 2.0 * M_PI;
        data->lfo2Phase += lfo2PhaseIncrement;
        if (data->lfo2Phase >= 2.0 * M_PI) {
            data->lfo2Phase -= 2.0 * M_PI;
        }

        // Generate LFO 2 waveform output (-1 to 1)
        float lfo2Value = 0.0f;
        float normalizedPhase2 = data->lfo2Phase / (2.0 * M_PI);
        switch (data->lfo2Waveform) {
            case 0: // Sine
                lfo2Value = sinf(data->lfo2Phase);
                break;
            case 1: // Square
                lfo2Value = (normalizedPhase2 < 0.5f) ? 1.0f : -1.0f;
                break;
            case 2: // Sawtooth
                lfo2Value = 2.0f * normalizedPhase2 - 1.0f;
                break;
            case 3: // Triangle
                lfo2Value = (normalizedPhase2 < 0.5f) ?
                           (4.0f * normalizedPhase2 - 1.0f) :
                           (-4.0f * normalizedPhase2 + 3.0f);
                break;
        }

        // Store LFO 2 output for indicator (convert from -1..1 to 0..1)
        data->lfo2Output = (lfo2Value + 1.0f) * 0.5f;

        // Update global filter envelope (applies to all voices)
        UpdateGlobalFilterEnvelope(data);
        float filterEnvValue = data->filterEnvLevel;

        // Process arpeggiator
        if (data->arpEnable && data->heldNotesCount > 0) {
            // Get host tempo (default to 120 BPM if not available)
            double tempo = 120.0;
            if (inTimeStamp && (inTimeStamp->mFlags & kAudioTimeStampSMPTETimeValid)) {
                // Try to get tempo from host - this varies by host
                // For now, use default tempo (proper tempo sync would require additional host property queries)
            }
            data->hostTempo = tempo;

            // Calculate samples per step based on tempo and rate
            // Rate: 0=1/4, 1=1/8, 2=1/16, 3=1/32
            double beatsPerSecond = tempo / 60.0;
            double stepsPerBeat = 1.0;
            switch (data->arpRate) {
                case 0: stepsPerBeat = 1.0; break;  // Quarter notes
                case 1: stepsPerBeat = 2.0; break;  // Eighth notes
                case 2: stepsPerBeat = 4.0; break;  // Sixteenth notes
                case 3: stepsPerBeat = 8.0; break;  // Thirty-second notes
            }
            double stepsPerSecond = beatsPerSecond * stepsPerBeat;
            double samplesPerStep = data->sampleRate / stepsPerSecond;
            double gateLength = samplesPerStep * data->arpGate;

            // Advance phase accumulator
            data->arpPhaseAccumulator += 1.0;

            // Check if it's time for a new step
            if (data->arpPhaseAccumulator >= samplesPerStep) {
                data->arpPhaseAccumulator -= samplesPerStep;

                // Stop previous arp note
                if (data->arpNoteActive && data->currentArpNote >= 0) {
                    SynthVoice *voice = FindVoiceForNote(data, data->currentArpNote);
                    if (voice) {
                        voice->NoteOff();
                    }
                    data->arpNoteActive = false;
                }

                // Get next note and start it
                int nextNote = GetArpNote(data);
                if (nextNote >= 0 && nextNote < 128) {
                    SynthVoice *voice = FindFreeVoice(data);
                    if (!voice) {
                        // Steal oldest voice if none free
                        voice = &data->voices[0];
                    }

                    if (voice) {
                        voice->NoteOn(nextNote, 100, data->sampleRate);  // Use velocity 100
                        voice->SetOscillator1(data->osc1.waveform, data->osc1.octave,
                                             data->osc1.detune, data->osc1.volume);
                        voice->SetOscillator2(data->osc2.waveform, data->osc2.octave,
                                             data->osc2.detune, data->osc2.volume);
                        voice->SetOscillator3(data->osc3.waveform, data->osc3.octave,
                                             data->osc3.detune, data->osc3.volume);
                        voice->SetFilterCutoff(data->filterCutoff);
                        voice->SetFilterResonance(data->filterResonance);
                        voice->SetEnvelope(data->envAttack, data->envDecay,
                                          data->envSustain, data->envRelease);

                        data->currentArpNote = nextNote;
                        data->arpNoteActive = true;
                    }
                }

                // Advance to next step
                data->arpCurrentStep++;
            }

            // Handle gate (note off before next step)
            if (data->arpNoteActive && data->arpPhaseAccumulator >= gateLength) {
                if (data->currentArpNote >= 0) {
                    SynthVoice *voice = FindVoiceForNote(data, data->currentArpNote);
                    if (voice) {
                        voice->NoteOff();
                    }
                }
            }
        } else if (data->arpEnable && data->heldNotesCount == 0) {
            // Stop current arp note when all notes are released
            if (data->arpNoteActive && data->currentArpNote >= 0) {
                SynthVoice *voice = FindVoiceForNote(data, data->currentArpNote);
                if (voice) {
                    voice->NoteOff();
                }
                data->arpNoteActive = false;
            }
            // Reset arpeggiator state
            data->arpCurrentStep = 0;
            data->arpPhaseAccumulator = 0.0;
            data->currentArpNote = -1;
        } else if (!data->arpEnable) {
            // Reset arpeggiator state when disabled
            data->arpCurrentStep = 0;
            data->arpPhaseAccumulator = 0.0;
            data->currentArpNote = -1;
            data->arpNoteActive = false;
        }

        // Process modulation matrix
        SynthVoice::ModulationValues modValues = {0};

        for (int slot = 0; slot < kNumModSlots; slot++) {
            const ClaudeSynthData::ModSlot& modSlot = data->modSlots[slot];

            // Get source value
            float sourceValue = 0.0f;
            switch (modSlot.source) {
                case kModSource_LFO1:
                    sourceValue = lfo1Value;
                    break;
                case kModSource_LFO2:
                    sourceValue = lfo2Value;
                    break;
                case kModSource_FilterEnv:
                    sourceValue = filterEnvValue;
                    break;
                default:
                    sourceValue = 0.0f;
                    break;
            }

            // Apply intensity and route to destination
            float modulationAmount = sourceValue * modSlot.intensity;

            switch (modSlot.destination) {
                case kModDest_FilterCutoff:
                    modValues.filterCutoffMod += modulationAmount * 10000.0f; // Scale to Hz
                    break;
                case kModDest_FilterResonance:
                    modValues.filterResonanceMod += modulationAmount * 5.0f; // Scale to Q
                    break;
                case kModDest_MasterVolume:
                    modValues.masterVolumeMod += modulationAmount * 0.5f; // Scale to +/- 0.5
                    break;
                case kModDest_Osc1_Detune:
                    modValues.osc1DetuneMod += modulationAmount * 100.0f; // Scale to cents
                    break;
                case kModDest_Osc1_Volume:
                    modValues.osc1VolumeMod += modulationAmount * 0.5f; // Scale to +/- 0.5
                    break;
                case kModDest_Osc2_Detune:
                    modValues.osc2DetuneMod += modulationAmount * 100.0f;
                    break;
                case kModDest_Osc2_Volume:
                    modValues.osc2VolumeMod += modulationAmount * 0.5f;
                    break;
                case kModDest_Osc3_Detune:
                    modValues.osc3DetuneMod += modulationAmount * 100.0f;
                    break;
                case kModDest_Osc3_Volume:
                    modValues.osc3VolumeMod += modulationAmount * 0.5f;
                    break;
                default:
                    break;
            }
        }

        float sample = 0.0f;
        bool hasActiveVoices = false;

        for (int voice = 0; voice < kNumVoices; voice++) {
            if (data->voices[voice].IsActive()) {
                sample += data->voices[voice].RenderSample(modValues);
                hasActiveVoices = true;
            }
        }

        // Apply effects before master volume (only if there are active voices or recent audio)
        if (data->effectType > 0 && (hasActiveVoices || fabs(sample) > 0.00001f)) {
            // Update effect LFO
            double effectLFOIncrement = (data->effectRate / data->sampleRate) * 2.0 * M_PI;
            data->effectLFOPhase += effectLFOIncrement;
            if (data->effectLFOPhase >= 2.0 * M_PI) {
                data->effectLFOPhase -= 2.0 * M_PI;
            }
            float lfoValue = sinf(data->effectLFOPhase);  // -1 to +1

            // Apply selected effect
            if (data->effectType == 1) {
                sample = ProcessChorusEffect(data, sample, lfoValue);
            } else if (data->effectType == 2) {
                sample = ProcessPhaserEffect(data, sample, lfoValue);
            } else if (data->effectType == 3) {
                sample = ProcessFlangerEffect(data, sample, lfoValue);
            }
        } else if (data->effectType > 0) {
            // Clear effect buffers when no audio to prevent noise buildup
            if (data->effectType == 1) {
                // Chorus: write silence to buffer
                data->chorusDelayBuffer[data->chorusWritePos] = 0.0f;
                data->chorusWritePos = (data->chorusWritePos + 1) % ClaudeSynthData::kChorusDelayBufferSize;
            } else if (data->effectType == 2) {
                // Phaser: gradually decay state
                data->phaserFeedbackSample *= 0.99f;
            } else if (data->effectType == 3) {
                // Flanger: write silence to buffer
                data->flangerDelayBuffer[data->flangerWritePos] = 0.0f;
                data->flangerWritePos = (data->flangerWritePos + 1) % ClaudeSynthData::kFlangerDelayBufferSize;
                data->flangerFeedbackSample *= 0.99f;
            }
        }

        // Apply master volume and output to both channels
        float volumedSample = sample * data->masterVolume;
        left[frame] = volumedSample;
        if (right != left) {
            right[frame] = volumedSample;
        }
    }

    // Push samples to oscilloscope for visualization
    if (data->oscilloscope) {
        MatrixOscilloscope *scope = (__bridge MatrixOscilloscope *)data->oscilloscope;
        [scope pushSamples:left count:(int)inNumberFrames];
    }

    return noErr;
}

static OSStatus ClaudeSynth_MIDIEvent(void *self,
                                       UInt32 inStatus,
                                       UInt32 inData1,
                                       UInt32 inData2,
                                       UInt32 inStartFrame) {
    ClaudeSynthData *data = (ClaudeSynthData *)self;

    UInt8 status = inStatus & 0xF0;
    UInt8 noteNumber = inData1 & 0x7F;
    UInt8 velocity = inData2 & 0x7F;

    ClaudeLog("MIDI Event: status=0x%02X, note=%d, vel=%d", status, noteNumber, velocity);

    switch (status) {
        case 0x90: // Note On
            ClaudeLog("  -> Case 0x90 matched, velocity=%d", velocity);
            if (velocity > 0) {
                // If arpeggiator is enabled, add note to held notes list
                if (data->arpEnable) {
                    bool alreadyHeld = false;
                    for (int i = 0; i < data->heldNotesCount; i++) {
                        if (data->heldNotes[i] == noteNumber) {
                            alreadyHeld = true;
                            break;
                        }
                    }

                    if (!alreadyHeld && data->heldNotesCount < ClaudeSynthData::kMaxArpNotes) {
                        data->heldNotes[data->heldNotesCount] = noteNumber;
                        data->heldNotesCount++;
                        ClaudeLog("  -> Added note %d to arpeggiator (count=%d)", noteNumber, data->heldNotesCount);

                        // Reset arpeggiator step when first note is pressed
                        if (data->heldNotesCount == 1) {
                            data->arpCurrentStep = 0;
                            data->arpPhaseAccumulator = 0.0;
                        }
                    }
                    break;  // Don't trigger voice directly
                }

                // Normal (non-arpeggiator) note handling
                // Check if this note is already playing
                SynthVoice *existingVoice = FindVoiceForNote(data, noteNumber);
                SynthVoice *voice = nullptr;

                if (existingVoice) {
                    // Retrigger the existing voice (restarts envelope from current level)
                    voice = existingVoice;
                    ClaudeLog("  -> Retriggering existing voice for note %d", noteNumber);
                } else {
                    // Allocate a new voice
                    voice = FindFreeVoice(data);
                    ClaudeLog("  -> FindFreeVoice returned %p", voice);
                }

                if (voice) {
                    voice->NoteOn(noteNumber, velocity, data->sampleRate);
                    voice->SetOscillator1(data->osc1.waveform, data->osc1.octave,
                                         data->osc1.detune, data->osc1.volume);
                    voice->SetOscillator2(data->osc2.waveform, data->osc2.octave,
                                         data->osc2.detune, data->osc2.volume);
                    voice->SetOscillator3(data->osc3.waveform, data->osc3.octave,
                                         data->osc3.detune, data->osc3.volume);
                    voice->SetFilterCutoff(data->filterCutoff);
                    voice->SetFilterResonance(data->filterResonance);
                    voice->SetEnvelope(data->envAttack, data->envDecay,
                                      data->envSustain, data->envRelease);

                    // Increment active note count and trigger global filter envelope if idle
                    data->activeNoteCount++;
                    if (data->filterEnvStage == kEnvStage_Idle || data->filterEnvStage == kEnvStage_Release) {
                        data->filterEnvLevel = 0.0f;  // Reset to 0 for clean attack
                        data->filterEnvStage = kEnvStage_Attack;
                    }

                    ClaudeLog("  -> Voice configured for note %d", noteNumber);
                } else {
                    ClaudeLog("  -> ERROR: FindFreeVoice returned NULL!");
                }
            } else {
                // If arpeggiator is enabled, remove note from held notes list
                if (data->arpEnable) {
                    for (int i = 0; i < data->heldNotesCount; i++) {
                        if (data->heldNotes[i] == noteNumber) {
                            // Remove note by shifting array
                            for (int j = i; j < data->heldNotesCount - 1; j++) {
                                data->heldNotes[j] = data->heldNotes[j + 1];
                            }
                            data->heldNotesCount--;
                            ClaudeLog("  -> Removed note %d from arpeggiator (count=%d)", noteNumber, data->heldNotesCount);

                            // If this was the currently playing arp note, stop it
                            if (data->currentArpNote == noteNumber && data->arpNoteActive) {
                                SynthVoice *voice = FindVoiceForNote(data, noteNumber);
                                if (voice) {
                                    voice->NoteOff();
                                    ClaudeLog("  -> Stopped currently playing arp note %d", noteNumber);
                                }
                                data->arpNoteActive = false;
                            }
                            break;
                        }
                    }
                    break;  // Don't handle voice directly
                }

                // Normal note off handling
                SynthVoice *voice = FindVoiceForNote(data, noteNumber);
                if (voice) {
                    voice->NoteOff();

                    // Decrement active note count and trigger global filter envelope release if last note
                    data->activeNoteCount--;
                    if (data->activeNoteCount <= 0) {
                        data->activeNoteCount = 0;
                        data->filterEnvStage = kEnvStage_Release;
                        data->filterEnvReleaseStartLevel = data->filterEnvLevel;
                    }

                    ClaudeLog("  -> Note off (vel=0) for note %d", noteNumber);
                } else {
                    ClaudeLog("  -> Note off (vel=0) for note %d - voice not found!", noteNumber);
                }
            }
            break;

        case 0x80: // Note Off
            {
                // If arpeggiator is enabled, remove note from held notes list
                if (data->arpEnable) {
                    for (int i = 0; i < data->heldNotesCount; i++) {
                        if (data->heldNotes[i] == noteNumber) {
                            // Remove note by shifting array
                            for (int j = i; j < data->heldNotesCount - 1; j++) {
                                data->heldNotes[j] = data->heldNotes[j + 1];
                            }
                            data->heldNotesCount--;
                            ClaudeLog("  -> Removed note %d from arpeggiator (count=%d)", noteNumber, data->heldNotesCount);

                            // If this was the currently playing arp note, stop it
                            if (data->currentArpNote == noteNumber && data->arpNoteActive) {
                                SynthVoice *voice = FindVoiceForNote(data, noteNumber);
                                if (voice) {
                                    voice->NoteOff();
                                    ClaudeLog("  -> Stopped currently playing arp note %d", noteNumber);
                                }
                                data->arpNoteActive = false;
                            }
                            break;
                        }
                    }
                    break;  // Don't handle voice directly
                }

                // Normal note off handling
                SynthVoice *voice = FindVoiceForNote(data, noteNumber);
                if (voice) {
                    voice->NoteOff();

                    // Decrement active note count and trigger global filter envelope release if last note
                    data->activeNoteCount--;
                    if (data->activeNoteCount <= 0) {
                        data->activeNoteCount = 0;
                        data->filterEnvStage = kEnvStage_Release;
                        data->filterEnvReleaseStartLevel = data->filterEnvLevel;
                    }

                    ClaudeLog("  -> Note off for note %d", noteNumber);
                } else {
                    ClaudeLog("  -> Note off for note %d - voice not found!", noteNumber);
                }
            }
            break;
    }

    return noErr;
}

// Helper functions
SynthVoice* FindFreeVoice(ClaudeSynthData *data) {
    for (int i = 0; i < kNumVoices; i++) {
        if (!data->voices[i].IsActive()) {
            return &data->voices[i];
        }
    }
    return &data->voices[0];
}

SynthVoice* FindVoiceForNote(ClaudeSynthData *data, int note) {
    for (int i = 0; i < kNumVoices; i++) {
        if (data->voices[i].IsActive() && data->voices[i].GetNote() == note) {
            return &data->voices[i];
        }
    }
    return nullptr;
}

static void UpdateAllVoices(ClaudeSynthData *data) {
    for (int i = 0; i < kNumVoices; i++) {
        data->voices[i].SetOscillator1(data->osc1.waveform, data->osc1.octave,
                                       data->osc1.detune, data->osc1.volume);
        data->voices[i].SetOscillator2(data->osc2.waveform, data->osc2.octave,
                                       data->osc2.detune, data->osc2.volume);
        data->voices[i].SetOscillator3(data->osc3.waveform, data->osc3.octave,
                                       data->osc3.detune, data->osc3.volume);
        data->voices[i].SetFilterCutoff(data->filterCutoff);
        data->voices[i].SetFilterResonance(data->filterResonance);
        data->voices[i].SetEnvelope(data->envAttack, data->envDecay,
                                    data->envSustain, data->envRelease);
        // Filter envelope is now global, not per-voice
    }
}

static OSStatus ClaudeSynth_SetParameter(void *self, AudioUnitParameterID inID,
                                          AudioUnitScope inScope, AudioUnitElement inElement,
                                          AudioUnitParameterValue inValue, UInt32 inBufferOffsetInFrames) {
    ClaudeSynthData *data = (ClaudeSynthData *)self;

    if (inScope != kAudioUnitScope_Global)
        return kAudioUnitErr_InvalidScope;

    switch (inID) {
        case kParam_MasterVolume:
            data->masterVolume = inValue;
            return noErr;

        case kParam_Osc1_Waveform:
            data->osc1.waveform = (int)inValue;
            UpdateAllVoices(data);
            return noErr;

        case kParam_Osc1_Octave:
            data->osc1.octave = (int)inValue;
            UpdateAllVoices(data);
            return noErr;

        case kParam_Osc1_Detune:
            data->osc1.detune = inValue;
            UpdateAllVoices(data);
            return noErr;

        case kParam_Osc1_Volume:
            data->osc1.volume = inValue;
            UpdateAllVoices(data);
            return noErr;

        case kParam_Osc2_Waveform:
            data->osc2.waveform = (int)inValue;
            UpdateAllVoices(data);
            return noErr;

        case kParam_Osc2_Octave:
            data->osc2.octave = (int)inValue;
            UpdateAllVoices(data);
            return noErr;

        case kParam_Osc2_Detune:
            data->osc2.detune = inValue;
            UpdateAllVoices(data);
            return noErr;

        case kParam_Osc2_Volume:
            data->osc2.volume = inValue;
            UpdateAllVoices(data);
            return noErr;

        case kParam_Osc3_Waveform:
            data->osc3.waveform = (int)inValue;
            UpdateAllVoices(data);
            return noErr;

        case kParam_Osc3_Octave:
            data->osc3.octave = (int)inValue;
            UpdateAllVoices(data);
            return noErr;

        case kParam_Osc3_Detune:
            data->osc3.detune = inValue;
            UpdateAllVoices(data);
            return noErr;

        case kParam_Osc3_Volume:
            data->osc3.volume = inValue;
            UpdateAllVoices(data);
            return noErr;

        case kParam_FilterCutoff:
            data->filterCutoff = inValue;
            UpdateAllVoices(data);
            return noErr;

        case kParam_FilterResonance:
            data->filterResonance = inValue;
            UpdateAllVoices(data);
            return noErr;

        case kParam_EnvAttack:
            data->envAttack = inValue;
            UpdateAllVoices(data);
            return noErr;

        case kParam_EnvDecay:
            data->envDecay = inValue;
            UpdateAllVoices(data);
            return noErr;

        case kParam_EnvSustain:
            data->envSustain = inValue;
            UpdateAllVoices(data);
            return noErr;

        case kParam_EnvRelease:
            data->envRelease = inValue;
            UpdateAllVoices(data);
            return noErr;

        // Filter Envelope
        case kParam_FilterEnvAttack:
            data->filterEnvAttack = inValue;
            UpdateAllVoices(data);
            return noErr;

        case kParam_FilterEnvDecay:
            data->filterEnvDecay = inValue;
            UpdateAllVoices(data);
            return noErr;

        case kParam_FilterEnvSustain:
            data->filterEnvSustain = inValue;
            UpdateAllVoices(data);
            return noErr;

        case kParam_FilterEnvRelease:
            data->filterEnvRelease = inValue;
            UpdateAllVoices(data);
            return noErr;

        // LFO 1
        case kParam_LFO1_Waveform:
            data->lfo1Waveform = (int)inValue;
            return noErr;

        case kParam_LFO1_Rate:
            data->lfo1Rate = inValue;
            return noErr;

        case kParam_LFO1_TempoSync:
            data->lfo1TempoSync = (inValue > 0.5f);
            return noErr;

        case kParam_LFO1_NoteDivision:
            data->lfo1NoteDivision = (int)inValue;
            return noErr;

        // LFO 2
        case kParam_LFO2_Waveform:
            data->lfo2Waveform = (int)inValue;
            return noErr;

        case kParam_LFO2_Rate:
            data->lfo2Rate = inValue;
            return noErr;

        case kParam_LFO2_TempoSync:
            data->lfo2TempoSync = (inValue > 0.5f);
            return noErr;

        case kParam_LFO2_NoteDivision:
            data->lfo2NoteDivision = (int)inValue;
            return noErr;

        // Modulation Matrix Slot 1
        case kParam_ModSlot1_Source:
            data->modSlots[0].source = (int)inValue;
            return noErr;

        case kParam_ModSlot1_Dest:
            data->modSlots[0].destination = (int)inValue;
            return noErr;

        case kParam_ModSlot1_Intensity:
            data->modSlots[0].intensity = inValue;
            return noErr;

        // Modulation Matrix Slot 2
        case kParam_ModSlot2_Source:
            data->modSlots[1].source = (int)inValue;
            return noErr;

        case kParam_ModSlot2_Dest:
            data->modSlots[1].destination = (int)inValue;
            return noErr;

        case kParam_ModSlot2_Intensity:
            data->modSlots[1].intensity = inValue;
            return noErr;

        // Modulation Matrix Slot 3
        case kParam_ModSlot3_Source:
            data->modSlots[2].source = (int)inValue;
            return noErr;

        case kParam_ModSlot3_Dest:
            data->modSlots[2].destination = (int)inValue;
            return noErr;

        case kParam_ModSlot3_Intensity:
            data->modSlots[2].intensity = inValue;
            return noErr;

        // Modulation Matrix Slot 4
        case kParam_ModSlot4_Source:
            data->modSlots[3].source = (int)inValue;
            return noErr;

        case kParam_ModSlot4_Dest:
            data->modSlots[3].destination = (int)inValue;
            return noErr;

        case kParam_ModSlot4_Intensity:
            data->modSlots[3].intensity = inValue;
            return noErr;

        case kParam_EffectType:
            data->effectType = (int)inValue;
            return noErr;

        case kParam_EffectRate:
            data->effectRate = inValue;
            return noErr;

        case kParam_EffectIntensity:
            data->effectIntensity = inValue;
            return noErr;

        case kParam_ArpEnable:
            data->arpEnable = (int)inValue;
            // Reset arpeggiator state when enabling/disabling
            if (!data->arpEnable) {
                data->arpCurrentStep = 0;
                data->arpPhaseAccumulator = 0.0;
                data->currentArpNote = -1;
                data->arpNoteActive = false;
            }
            return noErr;

        case kParam_ArpRate:
            data->arpRate = (int)inValue;
            return noErr;

        case kParam_ArpMode:
            data->arpMode = (int)inValue;
            return noErr;

        case kParam_ArpOctaves:
            data->arpOctaves = (int)inValue;
            return noErr;

        case kParam_ArpGate:
            data->arpGate = inValue;
            return noErr;

        default:
            return kAudioUnitErr_InvalidParameter;
    }
}

static OSStatus ClaudeSynth_GetParameter(void *self, AudioUnitParameterID inID,
                                          AudioUnitScope inScope, AudioUnitElement inElement,
                                          AudioUnitParameterValue *outValue) {
    ClaudeSynthData *data = (ClaudeSynthData *)self;

    if (inScope != kAudioUnitScope_Global)
        return kAudioUnitErr_InvalidScope;

    switch (inID) {
        case kParam_MasterVolume:
            *outValue = data->masterVolume;
            return noErr;

        case kParam_Osc1_Waveform:
            *outValue = (float)data->osc1.waveform;
            return noErr;

        case kParam_Osc1_Octave:
            *outValue = (float)data->osc1.octave;
            return noErr;

        case kParam_Osc1_Detune:
            *outValue = data->osc1.detune;
            return noErr;

        case kParam_Osc1_Volume:
            *outValue = data->osc1.volume;
            return noErr;

        case kParam_Osc2_Waveform:
            *outValue = (float)data->osc2.waveform;
            return noErr;

        case kParam_Osc2_Octave:
            *outValue = (float)data->osc2.octave;
            return noErr;

        case kParam_Osc2_Detune:
            *outValue = data->osc2.detune;
            return noErr;

        case kParam_Osc2_Volume:
            *outValue = data->osc2.volume;
            return noErr;

        case kParam_Osc3_Waveform:
            *outValue = (float)data->osc3.waveform;
            return noErr;

        case kParam_Osc3_Octave:
            *outValue = (float)data->osc3.octave;
            return noErr;

        case kParam_Osc3_Detune:
            *outValue = data->osc3.detune;
            return noErr;

        case kParam_Osc3_Volume:
            *outValue = data->osc3.volume;
            return noErr;

        case kParam_FilterCutoff:
            *outValue = data->filterCutoff;
            return noErr;

        case kParam_FilterResonance:
            *outValue = data->filterResonance;
            return noErr;

        case kParam_EnvAttack:
            *outValue = data->envAttack;
            return noErr;

        case kParam_EnvDecay:
            *outValue = data->envDecay;
            return noErr;

        case kParam_EnvSustain:
            *outValue = data->envSustain;
            return noErr;

        case kParam_EnvRelease:
            *outValue = data->envRelease;
            return noErr;

        // Filter Envelope
        case kParam_FilterEnvAttack:
            *outValue = data->filterEnvAttack;
            return noErr;

        case kParam_FilterEnvDecay:
            *outValue = data->filterEnvDecay;
            return noErr;

        case kParam_FilterEnvSustain:
            *outValue = data->filterEnvSustain;
            return noErr;

        case kParam_FilterEnvRelease:
            *outValue = data->filterEnvRelease;
            return noErr;

        // LFO 1
        case kParam_LFO1_Waveform:
            *outValue = (float)data->lfo1Waveform;
            return noErr;

        case kParam_LFO1_Rate:
            *outValue = data->lfo1Rate;
            return noErr;

        case kParam_LFO1_TempoSync:
            *outValue = data->lfo1TempoSync ? 1.0f : 0.0f;
            return noErr;

        case kParam_LFO1_NoteDivision:
            *outValue = (float)data->lfo1NoteDivision;
            return noErr;

        // LFO 2
        case kParam_LFO2_Waveform:
            *outValue = (float)data->lfo2Waveform;
            return noErr;

        case kParam_LFO2_Rate:
            *outValue = data->lfo2Rate;
            return noErr;

        case kParam_LFO2_TempoSync:
            *outValue = data->lfo2TempoSync ? 1.0f : 0.0f;
            return noErr;

        case kParam_LFO2_NoteDivision:
            *outValue = (float)data->lfo2NoteDivision;
            return noErr;

        // Modulation Matrix Slot 1
        case kParam_ModSlot1_Source:
            *outValue = (float)data->modSlots[0].source;
            return noErr;

        case kParam_ModSlot1_Dest:
            *outValue = (float)data->modSlots[0].destination;
            return noErr;

        case kParam_ModSlot1_Intensity:
            *outValue = data->modSlots[0].intensity;
            return noErr;

        // Modulation Matrix Slot 2
        case kParam_ModSlot2_Source:
            *outValue = (float)data->modSlots[1].source;
            return noErr;

        case kParam_ModSlot2_Dest:
            *outValue = (float)data->modSlots[1].destination;
            return noErr;

        case kParam_ModSlot2_Intensity:
            *outValue = data->modSlots[1].intensity;
            return noErr;

        // Modulation Matrix Slot 3
        case kParam_ModSlot3_Source:
            *outValue = (float)data->modSlots[2].source;
            return noErr;

        case kParam_ModSlot3_Dest:
            *outValue = (float)data->modSlots[2].destination;
            return noErr;

        case kParam_ModSlot3_Intensity:
            *outValue = data->modSlots[2].intensity;
            return noErr;

        // Modulation Matrix Slot 4
        case kParam_ModSlot4_Source:
            *outValue = (float)data->modSlots[3].source;
            return noErr;

        case kParam_ModSlot4_Dest:
            *outValue = (float)data->modSlots[3].destination;
            return noErr;

        case kParam_ModSlot4_Intensity:
            *outValue = data->modSlots[3].intensity;
            return noErr;

        case kParam_EffectType:
            *outValue = (float)data->effectType;
            return noErr;

        case kParam_EffectRate:
            *outValue = data->effectRate;
            return noErr;

        case kParam_EffectIntensity:
            *outValue = data->effectIntensity;
            return noErr;

        case kParam_ArpEnable:
            *outValue = (float)data->arpEnable;
            return noErr;

        case kParam_ArpRate:
            *outValue = (float)data->arpRate;
            return noErr;

        case kParam_ArpMode:
            *outValue = (float)data->arpMode;
            return noErr;

        case kParam_ArpOctaves:
            *outValue = (float)data->arpOctaves;
            return noErr;

        case kParam_ArpGate:
            *outValue = data->arpGate;
            return noErr;

        case kParam_LFO1_Output:
            *outValue = data->lfo1Output;
            return noErr;

        case kParam_LFO2_Output:
            *outValue = data->lfo2Output;
            return noErr;

        default:
            return kAudioUnitErr_InvalidParameter;
    }
}

static OSStatus ClaudeSynth_StartNote(void *self, MusicDeviceInstrumentID inInstrument,
                                       MusicDeviceGroupID inGroupID, NoteInstanceID *outNoteInstanceID,
                                       UInt32 inOffsetSampleFrame, const MusicDeviceNoteParams *inParams) {
    ClaudeSynthData *data = (ClaudeSynthData *)self;

    if (!inParams) return kAudioUnitErr_InvalidParameter;

    UInt8 noteNumber = (UInt8)inParams->mPitch;
    UInt8 velocity = (UInt8)inParams->mVelocity;

    ClaudeLog("StartNote: note=%d, vel=%d, offset=%d", noteNumber, velocity, inOffsetSampleFrame);

    if (velocity > 0) {
        // If arpeggiator is enabled, add note to held notes list instead of playing directly
        if (data->arpEnable) {
            // Check if note is already in the list
            bool alreadyHeld = false;
            for (int i = 0; i < data->heldNotesCount; i++) {
                if (data->heldNotes[i] == noteNumber) {
                    alreadyHeld = true;
                    break;
                }
            }

            // Add note if not already held and we have space
            if (!alreadyHeld && data->heldNotesCount < ClaudeSynthData::kMaxArpNotes) {
                data->heldNotes[data->heldNotesCount] = noteNumber;
                data->heldNotesCount++;
                ClaudeLog("  -> Added note %d to arpeggiator (count=%d)", noteNumber, data->heldNotesCount);
            }

            // Reset arpeggiator step when first note is pressed
            if (data->heldNotesCount == 1) {
                data->arpCurrentStep = 0;
                data->arpPhaseAccumulator = 0.0;
            }

            return noErr;  // Don't trigger voice directly when arpeggiator is on
        }

        // Normal (non-arpeggiator) note handling
        // Check if this note is already playing
        SynthVoice *existingVoice = FindVoiceForNote(data, noteNumber);
        SynthVoice *voice = nullptr;

        if (existingVoice) {
            // Retrigger the existing voice (restarts envelope from current level)
            voice = existingVoice;
            ClaudeLog("  -> Retriggering existing voice for note %d", noteNumber);
        } else {
            // Allocate a new voice
            voice = FindFreeVoice(data);
            ClaudeLog("  -> Allocated new voice for note %d", noteNumber);
        }

        if (voice) {
            voice->NoteOn(noteNumber, velocity, data->sampleRate);
            voice->SetOscillator1(data->osc1.waveform, data->osc1.octave,
                                 data->osc1.detune, data->osc1.volume);
            voice->SetOscillator2(data->osc2.waveform, data->osc2.octave,
                                 data->osc2.detune, data->osc2.volume);
            voice->SetOscillator3(data->osc3.waveform, data->osc3.octave,
                                 data->osc3.detune, data->osc3.volume);
            voice->SetFilterCutoff(data->filterCutoff);
            voice->SetFilterResonance(data->filterResonance);
            voice->SetEnvelope(data->envAttack, data->envDecay,
                              data->envSustain, data->envRelease);

            // Increment active note count and trigger global filter envelope if idle
            data->activeNoteCount++;
            if (data->filterEnvStage == kEnvStage_Idle || data->filterEnvStage == kEnvStage_Release) {
                data->filterEnvLevel = 0.0f;  // Reset to 0 for clean attack
                data->filterEnvStage = kEnvStage_Attack;
            }

            // Return note instance ID (use voice index + 1 to avoid 0)
            if (outNoteInstanceID) {
                for (int i = 0; i < kNumVoices; i++) {
                    if (&data->voices[i] == voice) {
                        *outNoteInstanceID = i + 1;
                        break;
                    }
                }
            }
        }
    } else {
        // velocity == 0 is treated as note off (some MIDI sources use this)
        SynthVoice *voice = FindVoiceForNote(data, noteNumber);
        if (voice) {
            voice->NoteOff();

            // Decrement active note count and trigger global filter envelope release if last note
            data->activeNoteCount--;
            if (data->activeNoteCount <= 0) {
                data->activeNoteCount = 0;
                data->filterEnvStage = kEnvStage_Release;
                data->filterEnvReleaseStartLevel = data->filterEnvLevel;
            }

            ClaudeLog("  -> Note off (vel=0) for note %d", noteNumber);
        }
    }

    return noErr;
}

static OSStatus ClaudeSynth_StopNote(void *self, MusicDeviceGroupID inGroupID,
                                      NoteInstanceID inNoteInstanceID, UInt32 inOffsetSampleFrame) {
    ClaudeSynthData *data = (ClaudeSynthData *)self;

    ClaudeLog("StopNote: instanceID=%d, offset=%d", (int)inNoteInstanceID, inOffsetSampleFrame);

    // Convert instance ID back to voice index and verify the voice is still active
    if (inNoteInstanceID > 0 && inNoteInstanceID <= kNumVoices) {
        int voiceIndex = inNoteInstanceID - 1;

        // Only stop the voice if it's actually active (prevents stopping wrong voice if stolen)
        if (data->voices[voiceIndex].IsActive()) {
            data->voices[voiceIndex].NoteOff();

            // Decrement active note count and trigger global filter envelope release if last note
            data->activeNoteCount--;
            if (data->activeNoteCount <= 0) {
                data->activeNoteCount = 0;
                data->filterEnvStage = kEnvStage_Release;
                data->filterEnvReleaseStartLevel = data->filterEnvLevel;
            }

            ClaudeLog("  -> Stopped voice %d", voiceIndex);
        } else {
            ClaudeLog("  -> Voice %d not active (already released or stolen)", voiceIndex);
        }
    }

    return noErr;
}
