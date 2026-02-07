#include "ClaudeSynth.h"
#include "ClaudeSynthVersion.h"
#include "ClaudeSynthLogger.h"
#include <AudioToolbox/AudioToolbox.h>
#include <string.h>

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
    ClaudeLog("Lookup: selector=%d (0x%X)", selector, selector);
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
            if (outDataSize) *outDataSize = sizeof(AudioUnitParameterID) * 15;
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
            if (*ioDataSize < sizeof(AudioUnitParameterID) * 15)
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
                *ioDataSize = sizeof(AudioUnitParameterID) * 15;
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

        case 0x3C: // kAudioUnitProperty_OfflineRender or similar
        case 0x1E: // kAudioUnitProperty_AudioChannelLayout
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
        float sample = 0.0f;

        for (int voice = 0; voice < kNumVoices; voice++) {
            if (data->voices[voice].IsActive()) {
                sample += data->voices[voice].RenderSample();
            }
        }

        // Apply master volume and output to both channels
        float volumedSample = sample * data->masterVolume;
        left[frame] = volumedSample;
        if (right != left) {
            right[frame] = volumedSample;
        }
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
                SynthVoice *voice = FindFreeVoice(data);
                ClaudeLog("  -> FindFreeVoice returned %p", voice);
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
                    ClaudeLog("  -> Voice allocated for note %d", noteNumber);
                } else {
                    ClaudeLog("  -> ERROR: FindFreeVoice returned NULL!");
                }
            } else {
                SynthVoice *voice = FindVoiceForNote(data, noteNumber);
                if (voice) {
                    voice->NoteOff();
                    ClaudeLog("  -> Note off (vel=0) for note %d", noteNumber);
                } else {
                    ClaudeLog("  -> Note off (vel=0) for note %d - voice not found!", noteNumber);
                }
            }
            break;

        case 0x80: // Note Off
            {
                SynthVoice *voice = FindVoiceForNote(data, noteNumber);
                if (voice) {
                    voice->NoteOff();
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
        SynthVoice *voice = FindFreeVoice(data);
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
    }

    return noErr;
}

static OSStatus ClaudeSynth_StopNote(void *self, MusicDeviceGroupID inGroupID,
                                      NoteInstanceID inNoteInstanceID, UInt32 inOffsetSampleFrame) {
    ClaudeSynthData *data = (ClaudeSynthData *)self;

    ClaudeLog("StopNote: instanceID=%d, offset=%d", (int)inNoteInstanceID, inOffsetSampleFrame);

    // Convert instance ID back to voice index
    if (inNoteInstanceID > 0 && inNoteInstanceID <= kNumVoices) {
        int voiceIndex = inNoteInstanceID - 1;
        data->voices[voiceIndex].NoteOff();
    }

    return noErr;
}
