#import "ClaudeSynthView.h"
#import "ClaudeSynth.h"

@implementation ClaudeSynthView

- (id)initWithFrame:(NSRect)frame audioUnit:(AudioUnit)au {
    self = [super initWithFrame:NSMakeRect(0, 0, 600, 180)];
    if (self) {
        mAU = au;

        // Set dark background
        [self setWantsLayer:YES];
        self.layer.backgroundColor = [[NSColor colorWithWhite:0.15 alpha:1.0] CGColor];

        // Title label at top
        titleLabel = [[NSTextField alloc] initWithFrame:NSMakeRect(0, 140, 600, 30)];
        [titleLabel setStringValue:@"ClaudeSynth"];
        [titleLabel setAlignment:NSTextAlignmentCenter];
        [titleLabel setBezeled:NO];
        [titleLabel setDrawsBackground:NO];
        [titleLabel setEditable:NO];
        [titleLabel setSelectable:NO];
        [titleLabel setFont:[NSFont systemFontOfSize:20 weight:NSFontWeightBold]];
        [titleLabel setTextColor:[NSColor whiteColor]];
        [self addSubview:titleLabel];

        // "Master Volume" label
        volumeLabel = [[NSTextField alloc] initWithFrame:NSMakeRect(10, 118, 120, 20)];
        [volumeLabel setStringValue:@"Master Volume"];
        [volumeLabel setAlignment:NSTextAlignmentCenter];
        [volumeLabel setBezeled:NO];
        [volumeLabel setDrawsBackground:NO];
        [volumeLabel setEditable:NO];
        [volumeLabel setSelectable:NO];
        [volumeLabel setFont:[NSFont systemFontOfSize:12]];
        [volumeLabel setTextColor:[NSColor colorWithWhite:0.7 alpha:1.0]];
        [self addSubview:volumeLabel];

        // Rotary knob control for volume
        volumeKnob = [[RotaryKnob alloc] initWithFrame:NSMakeRect(30, 35, 80, 80)];
        [volumeKnob setMinValue:0.0];
        [volumeKnob setMaxValue:1.0];

        // Get initial volume value from Audio Unit
        AudioUnitParameterValue initialVolume = 1.0f;
        if (mAU) {
            AudioUnitGetParameter(mAU, kParam_MasterVolume, kAudioUnitScope_Global, 0, &initialVolume);
        }
        [volumeKnob setDoubleValue:initialVolume];

        [volumeKnob setTarget:self];
        [volumeKnob setAction:@selector(volumeChanged:)];
        [volumeKnob setContinuous:YES];
        [self addSubview:volumeKnob];

        // "Waveform" label
        waveformLabel = [[NSTextField alloc] initWithFrame:NSMakeRect(160, 118, 120, 20)];
        [waveformLabel setStringValue:@"Waveform"];
        [waveformLabel setAlignment:NSTextAlignmentCenter];
        [waveformLabel setBezeled:NO];
        [waveformLabel setDrawsBackground:NO];
        [waveformLabel setEditable:NO];
        [waveformLabel setSelectable:NO];
        [waveformLabel setFont:[NSFont systemFontOfSize:12]];
        [waveformLabel setTextColor:[NSColor colorWithWhite:0.7 alpha:1.0]];
        [self addSubview:waveformLabel];

        // Discrete knob control for waveform
        waveformKnob = [[DiscreteKnob alloc] initWithFrame:NSMakeRect(180, 35, 80, 80)];

        // Get initial waveform value from Audio Unit
        AudioUnitParameterValue initialWaveform = 0.0f;
        if (mAU) {
            AudioUnitGetParameter(mAU, kParam_Waveform, kAudioUnitScope_Global, 0, &initialWaveform);
        }
        [waveformKnob setIntValue:(int)initialWaveform];

        [waveformKnob setTarget:self];
        [waveformKnob setAction:@selector(waveformChanged:)];
        [self addSubview:waveformKnob];

        // "Filter Cutoff" label
        cutoffLabel = [[NSTextField alloc] initWithFrame:NSMakeRect(310, 118, 120, 20)];
        [cutoffLabel setStringValue:@"Filter Cutoff"];
        [cutoffLabel setAlignment:NSTextAlignmentCenter];
        [cutoffLabel setBezeled:NO];
        [cutoffLabel setDrawsBackground:NO];
        [cutoffLabel setEditable:NO];
        [cutoffLabel setSelectable:NO];
        [cutoffLabel setFont:[NSFont systemFontOfSize:12]];
        [cutoffLabel setTextColor:[NSColor colorWithWhite:0.7 alpha:1.0]];
        [self addSubview:cutoffLabel];

        // Rotary knob control for filter cutoff (logarithmic)
        cutoffKnob = [[RotaryKnob alloc] initWithFrame:NSMakeRect(330, 40, 80, 80)];
        [cutoffKnob setMinValue:0.0];
        [cutoffKnob setMaxValue:1.0];

        // Get initial cutoff value from Audio Unit and convert to logarithmic position
        AudioUnitParameterValue initialCutoff = 20000.0f;
        if (mAU) {
            AudioUnitGetParameter(mAU, kParam_FilterCutoff, kAudioUnitScope_Global, 0, &initialCutoff);
        }
        // Convert Hz to 0-1 logarithmic: position = log(freq/20) / log(1000)
        double cutoffPosition = log(initialCutoff / 20.0) / log(1000.0);
        [cutoffKnob setDoubleValue:cutoffPosition];

        [cutoffKnob setTarget:self];
        [cutoffKnob setAction:@selector(cutoffChanged:)];
        [cutoffKnob setContinuous:YES];
        [self addSubview:cutoffKnob];

        // Cutoff value display
        cutoffValueDisplay = [[NSTextField alloc] initWithFrame:NSMakeRect(310, 20, 120, 16)];
        [cutoffValueDisplay setStringValue:[NSString stringWithFormat:@"%.0f Hz", initialCutoff]];
        [cutoffValueDisplay setAlignment:NSTextAlignmentCenter];
        [cutoffValueDisplay setBezeled:NO];
        [cutoffValueDisplay setDrawsBackground:NO];
        [cutoffValueDisplay setEditable:NO];
        [cutoffValueDisplay setSelectable:NO];
        [cutoffValueDisplay setFont:[NSFont systemFontOfSize:10]];
        [cutoffValueDisplay setTextColor:[NSColor colorWithWhite:0.6 alpha:1.0]];
        [self addSubview:cutoffValueDisplay];

        // "Filter Resonance" label
        resonanceLabel = [[NSTextField alloc] initWithFrame:NSMakeRect(460, 118, 120, 20)];
        [resonanceLabel setStringValue:@"Resonance"];
        [resonanceLabel setAlignment:NSTextAlignmentCenter];
        [resonanceLabel setBezeled:NO];
        [resonanceLabel setDrawsBackground:NO];
        [resonanceLabel setEditable:NO];
        [resonanceLabel setSelectable:NO];
        [resonanceLabel setFont:[NSFont systemFontOfSize:12]];
        [resonanceLabel setTextColor:[NSColor colorWithWhite:0.7 alpha:1.0]];
        [self addSubview:resonanceLabel];

        // Rotary knob control for filter resonance
        resonanceKnob = [[RotaryKnob alloc] initWithFrame:NSMakeRect(480, 40, 80, 80)];
        [resonanceKnob setMinValue:0.5];
        [resonanceKnob setMaxValue:10.0];

        // Get initial resonance value from Audio Unit
        AudioUnitParameterValue initialResonance = 0.7f;
        if (mAU) {
            AudioUnitGetParameter(mAU, kParam_FilterResonance, kAudioUnitScope_Global, 0, &initialResonance);
        }
        [resonanceKnob setDoubleValue:initialResonance];

        [resonanceKnob setTarget:self];
        [resonanceKnob setAction:@selector(resonanceChanged:)];
        [resonanceKnob setContinuous:YES];
        [self addSubview:resonanceKnob];

        // Resonance value display
        resonanceValueDisplay = [[NSTextField alloc] initWithFrame:NSMakeRect(460, 20, 120, 16)];
        [resonanceValueDisplay setStringValue:[NSString stringWithFormat:@"Q: %.2f", initialResonance]];
        [resonanceValueDisplay setAlignment:NSTextAlignmentCenter];
        [resonanceValueDisplay setBezeled:NO];
        [resonanceValueDisplay setDrawsBackground:NO];
        [resonanceValueDisplay setEditable:NO];
        [resonanceValueDisplay setSelectable:NO];
        [resonanceValueDisplay setFont:[NSFont systemFontOfSize:10]];
        [resonanceValueDisplay setTextColor:[NSColor colorWithWhite:0.6 alpha:1.0]];
        [self addSubview:resonanceValueDisplay];

        // Percentage display below volume knob
        percentageDisplay = [[NSTextField alloc] initWithFrame:NSMakeRect(10, 10, 120, 20)];
        [percentageDisplay setStringValue:[NSString stringWithFormat:@"%.0f%%", initialVolume * 100.0]];
        [percentageDisplay setAlignment:NSTextAlignmentCenter];
        [percentageDisplay setBezeled:NO];
        [percentageDisplay setDrawsBackground:NO];
        [percentageDisplay setEditable:NO];
        [percentageDisplay setSelectable:NO];
        [percentageDisplay setFont:[NSFont systemFontOfSize:14 weight:NSFontWeightMedium]];
        [percentageDisplay setTextColor:[NSColor whiteColor]];
        [self addSubview:percentageDisplay];

        // Start timer to poll for host automation updates
        updateTimer = [NSTimer scheduledTimerWithTimeInterval:0.1
                                                       target:self
                                                     selector:@selector(updateFromHost:)
                                                     userInfo:nil
                                                      repeats:YES];
    }
    return self;
}

- (void)dealloc {
    [updateTimer invalidate];
}

- (void)volumeChanged:(id)sender {
    float value = [volumeKnob floatValue];

    // Update the Audio Unit parameter
    if (mAU) {
        AudioUnitSetParameter(mAU, kParam_MasterVolume, kAudioUnitScope_Global, 0, value, 0);
    }

    // Update percentage display
    [percentageDisplay setStringValue:[NSString stringWithFormat:@"%.0f%%", value * 100.0]];
}

- (void)waveformChanged:(id)sender {
    int value = [waveformKnob intValue];

    // Update the Audio Unit parameter
    if (mAU) {
        AudioUnitSetParameter(mAU, kParam_Waveform, kAudioUnitScope_Global, 0, (float)value, 0);
    }
}

- (void)cutoffChanged:(id)sender {
    // Get knob position (0-1) and convert to logarithmic frequency
    float position = [cutoffKnob floatValue];

    // freq = 20 * pow(1000, position) gives range 20-20000 Hz
    float frequency = 20.0f * powf(1000.0f, position);

    // Update the Audio Unit parameter
    if (mAU) {
        AudioUnitSetParameter(mAU, kParam_FilterCutoff, kAudioUnitScope_Global, 0, frequency, 0);
    }

    // Update value display
    if (frequency >= 1000.0f) {
        [cutoffValueDisplay setStringValue:[NSString stringWithFormat:@"%.1f kHz", frequency / 1000.0f]];
    } else {
        [cutoffValueDisplay setStringValue:[NSString stringWithFormat:@"%.0f Hz", frequency]];
    }
}

- (void)resonanceChanged:(id)sender {
    float value = [resonanceKnob floatValue];

    // Update the Audio Unit parameter
    if (mAU) {
        AudioUnitSetParameter(mAU, kParam_FilterResonance, kAudioUnitScope_Global, 0, value, 0);
    }

    // Update value display
    [resonanceValueDisplay setStringValue:[NSString stringWithFormat:@"Q: %.2f", value]];
}

- (void)updateFromHost:(NSTimer *)timer {
    // Poll the Audio Unit for parameter changes (e.g., from host automation)
    if (mAU) {
        // Update volume knob
        AudioUnitParameterValue volumeValue;
        OSStatus status = AudioUnitGetParameter(mAU, kParam_MasterVolume, kAudioUnitScope_Global, 0, &volumeValue);

        if (status == noErr) {
            float currentVolumeValue = [volumeKnob floatValue];

            // Only update UI if value changed (avoid feedback loop)
            if (fabs(volumeValue - currentVolumeValue) > 0.001f) {
                [volumeKnob setFloatValue:volumeValue];
                [percentageDisplay setStringValue:[NSString stringWithFormat:@"%.0f%%", volumeValue * 100.0]];
            }
        }

        // Update waveform knob
        AudioUnitParameterValue waveformValue;
        status = AudioUnitGetParameter(mAU, kParam_Waveform, kAudioUnitScope_Global, 0, &waveformValue);

        if (status == noErr) {
            int currentWaveformValue = [waveformKnob intValue];

            // Only update UI if value changed
            if ((int)waveformValue != currentWaveformValue) {
                [waveformKnob setIntValue:(int)waveformValue];
            }
        }

        // Update cutoff knob
        AudioUnitParameterValue cutoffValue;
        status = AudioUnitGetParameter(mAU, kParam_FilterCutoff, kAudioUnitScope_Global, 0, &cutoffValue);

        if (status == noErr) {
            // Convert Hz to logarithmic position
            double cutoffPosition = log(cutoffValue / 20.0) / log(1000.0);
            float currentCutoffPosition = [cutoffKnob floatValue];

            // Only update UI if value changed
            if (fabs(cutoffPosition - currentCutoffPosition) > 0.01f) {
                [cutoffKnob setFloatValue:cutoffPosition];

                // Update display
                if (cutoffValue >= 1000.0f) {
                    [cutoffValueDisplay setStringValue:[NSString stringWithFormat:@"%.1f kHz", cutoffValue / 1000.0f]];
                } else {
                    [cutoffValueDisplay setStringValue:[NSString stringWithFormat:@"%.0f Hz", cutoffValue]];
                }
            }
        }

        // Update resonance knob
        AudioUnitParameterValue resonanceValue;
        status = AudioUnitGetParameter(mAU, kParam_FilterResonance, kAudioUnitScope_Global, 0, &resonanceValue);

        if (status == noErr) {
            float currentResonanceValue = [resonanceKnob floatValue];

            // Only update UI if value changed
            if (fabs(resonanceValue - currentResonanceValue) > 0.01f) {
                [resonanceKnob setFloatValue:resonanceValue];
                [resonanceValueDisplay setStringValue:[NSString stringWithFormat:@"Q: %.2f", resonanceValue]];
            }
        }
    }
}

@end

// Factory function for creating the view
@interface ClaudeSynthViewFactory : NSObject <AUCocoaUIBase>
@end

@implementation ClaudeSynthViewFactory

- (unsigned)interfaceVersion {
    return 0;
}

- (NSString *)description {
    return @"ClaudeSynth UI";
}

- (NSView *)uiViewForAudioUnit:(AudioUnit)inAudioUnit withSize:(NSSize)inPreferredSize {
    ClaudeSynthView *view = [[ClaudeSynthView alloc] initWithFrame:NSZeroRect audioUnit:inAudioUnit];
    return view;
}

@end

// Export the factory function
extern "C" {
    __attribute__((visibility("default")))
    void *ClaudeSynthViewFactory_Factory(CFAllocatorRef allocator, CFUUIDRef typeID) {
        return (__bridge_retained void *)[[ClaudeSynthViewFactory alloc] init];
    }
}
