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
    data->waveform = 0; // Sine wave by default
    ClaudeLog("Factory: initialized masterVolume to %f, waveform to %d", data->masterVolume, data->waveform);

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
            if (outDataSize) *outDataSize = sizeof(AudioUnitParameterID) * 2;
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

        default:
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
            if (*ioDataSize < sizeof(AudioUnitParameterID) * 2)
                return kAudioUnitErr_InvalidParameter;
            {
                AudioUnitParameterID *paramList = (AudioUnitParameterID *)outData;
                paramList[0] = kParam_MasterVolume;
                paramList[1] = kParam_Waveform;
                *ioDataSize = sizeof(AudioUnitParameterID) * 2;
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

                if (inElement == kParam_MasterVolume) {
                    info->flags = kAudioUnitParameterFlag_IsWritable |
                                  kAudioUnitParameterFlag_IsReadable |
                                  kAudioUnitParameterFlag_HasCFNameString;
                    info->unit = kAudioUnitParameterUnit_LinearGain;
                    info->minValue = 0.0f;
                    info->maxValue = 1.0f;
                    info->defaultValue = 1.0f;
                    info->cfNameString = CFStringCreateWithCString(NULL, "Master Volume", kCFStringEncodingUTF8);
                    *ioDataSize = sizeof(AudioUnitParameterInfo);
                    return noErr;
                } else if (inElement == kParam_Waveform) {
                    info->flags = kAudioUnitParameterFlag_IsWritable |
                                  kAudioUnitParameterFlag_IsReadable |
                                  kAudioUnitParameterFlag_HasCFNameString;
                    info->unit = kAudioUnitParameterUnit_Indexed;
                    info->minValue = 0.0f;
                    info->maxValue = 3.0f;
                    info->defaultValue = 0.0f;
                    info->cfNameString = CFStringCreateWithCString(NULL, "Waveform", kCFStringEncodingUTF8);
                    *ioDataSize = sizeof(AudioUnitParameterInfo);
                    return noErr;
                }
            }
            return kAudioUnitErr_InvalidParameter;

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

        case 0x3C: // kAudioUnitProperty_OfflineRender or similar
        case 0x1E: // kAudioUnitProperty_AudioChannelLayout
        case 0x40: // kAudioUnitProperty_ShouldAllocateBuffer
        case 0x18A8B: // kAudioUnitProperty_SupportsMPE
            // Return not supported for these
            return kAudioUnitErr_InvalidProperty;

        case kAudioUnitProperty_OfflineRender:
        case kAudioUnitProperty_FastDispatch:
        case kAudioUnitProperty_CPULoad:
        case kAudioUnitProperty_PresentPreset:
            // Optional properties - return not supported
            return kAudioUnitErr_InvalidProperty;

        // Parameter and UI-related properties for plugins with no parameters/UI
        case 0x1A: // kAudioUnitProperty_IconLocation
        case 0x1D: // kAudioUnitProperty_NickName
        case 0x2F: // Unknown
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
            if (velocity > 0) {
                SynthVoice *voice = FindFreeVoice(data);
                if (voice) {
                    voice->NoteOn(noteNumber, velocity, data->sampleRate);
                }
            } else {
                SynthVoice *voice = FindVoiceForNote(data, noteNumber);
                if (voice) {
                    voice->NoteOff();
                }
            }
            break;

        case 0x80: // Note Off
            {
                SynthVoice *voice = FindVoiceForNote(data, noteNumber);
                if (voice) {
                    voice->NoteOff();
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

static OSStatus ClaudeSynth_SetParameter(void *self, AudioUnitParameterID inID,
                                          AudioUnitScope inScope, AudioUnitElement inElement,
                                          AudioUnitParameterValue inValue, UInt32 inBufferOffsetInFrames) {
    ClaudeSynthData *data = (ClaudeSynthData *)self;

    ClaudeLog("SetParameter: id=%d, scope=%d, value=%f", inID, inScope, inValue);

    if (inScope != kAudioUnitScope_Global)
        return kAudioUnitErr_InvalidScope;

    if (inID == kParam_MasterVolume) {
        data->masterVolume = inValue;
        ClaudeLog("SetParameter: masterVolume set to %f", data->masterVolume);
        return noErr;
    }

    if (inID == kParam_Waveform) {
        data->waveform = (int)inValue;
        ClaudeLog("SetParameter: waveform set to %d", data->waveform);

        // Update all voices with new waveform
        for (int i = 0; i < kNumVoices; i++) {
            data->voices[i].SetWaveform((Waveform)data->waveform);
        }
        return noErr;
    }

    return kAudioUnitErr_InvalidParameter;
}

static OSStatus ClaudeSynth_GetParameter(void *self, AudioUnitParameterID inID,
                                          AudioUnitScope inScope, AudioUnitElement inElement,
                                          AudioUnitParameterValue *outValue) {
    ClaudeSynthData *data = (ClaudeSynthData *)self;

    if (inScope != kAudioUnitScope_Global)
        return kAudioUnitErr_InvalidScope;

    if (inID == kParam_MasterVolume) {
        *outValue = data->masterVolume;
        ClaudeLog("GetParameter: returning masterVolume=%f", data->masterVolume);
        return noErr;
    }

    if (inID == kParam_Waveform) {
        *outValue = (float)data->waveform;
        ClaudeLog("GetParameter: returning waveform=%d", data->waveform);
        return noErr;
    }

    return kAudioUnitErr_InvalidParameter;
}
