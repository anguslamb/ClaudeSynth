#import "ClaudeSynthView.h"
#import "ClaudeSynth.h"

@implementation ClaudeSynthView

- (id)initWithFrame:(NSRect)frame audioUnit:(AudioUnit)au {
    self = [super initWithFrame:NSMakeRect(0, 0, 400, 180)];
    if (self) {
        mAU = au;

        // Set dark background
        [self setWantsLayer:YES];
        self.layer.backgroundColor = [[NSColor colorWithWhite:0.15 alpha:1.0] CGColor];

        // Title label at top
        titleLabel = [[NSTextField alloc] initWithFrame:NSMakeRect(0, 140, 400, 30)];
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
        volumeLabel = [[NSTextField alloc] initWithFrame:NSMakeRect(20, 118, 150, 20)];
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
        volumeKnob = [[RotaryKnob alloc] initWithFrame:NSMakeRect(55, 35, 80, 80)];
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
        waveformLabel = [[NSTextField alloc] initWithFrame:NSMakeRect(230, 118, 150, 20)];
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
        waveformKnob = [[DiscreteKnob alloc] initWithFrame:NSMakeRect(265, 35, 80, 80)];

        // Get initial waveform value from Audio Unit
        AudioUnitParameterValue initialWaveform = 0.0f;
        if (mAU) {
            AudioUnitGetParameter(mAU, kParam_Waveform, kAudioUnitScope_Global, 0, &initialWaveform);
        }
        [waveformKnob setIntValue:(int)initialWaveform];

        [waveformKnob setTarget:self];
        [waveformKnob setAction:@selector(waveformChanged:)];
        [self addSubview:waveformKnob];

        // Percentage display below volume knob
        percentageDisplay = [[NSTextField alloc] initWithFrame:NSMakeRect(20, 10, 150, 20)];
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
