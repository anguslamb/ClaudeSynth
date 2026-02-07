// Debug version with test tone
// Replace the Render function with this to test audio output

static OSStatus ClaudeSynth_Render_Debug(void *self,
                                          AudioUnitRenderActionFlags *ioActionFlags,
                                          const AudioTimeStamp *inTimeStamp,
                                          UInt32 inBusNumber,
                                          UInt32 inNumberFrames,
                                          AudioBufferList *ioData) {
    ClaudeSynthData *data = (ClaudeSynthData *)self;

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
        right = left;
    }

    if (!left) {
        return kAudioUnitErr_InvalidParameter;
    }

    // OUTPUT TEST TONE: 440Hz sine wave at low volume
    static double phase = 0.0;
    double phaseIncrement = (440.0 / data->sampleRate) * 2.0 * M_PI;

    for (UInt32 frame = 0; frame < inNumberFrames; frame++) {
        float testTone = sin(phase) * 0.3f;  // 440Hz at 30% volume
        left[frame] = testTone;
        if (right != left) {
            right[frame] = testTone;
        }
        phase += phaseIncrement;
        if (phase >= 2.0 * M_PI) {
            phase -= 2.0 * M_PI;
        }
    }

    return noErr;
}

// To use this debug version:
// 1. Copy this function into ClaudeSynth.cpp
// 2. Replace ClaudeSynth_Render with ClaudeSynth_Render_Debug
// 3. Rebuild: make clean && make && make install
// 4. Load in Logic - you should hear a constant 440Hz tone
// 5. If you hear the tone, the audio path works - the issue is with MIDI
// 6. If you don't hear the tone, the audio rendering isn't being called
