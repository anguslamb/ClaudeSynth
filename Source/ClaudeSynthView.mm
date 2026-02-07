#import "ClaudeSynthView.h"
#import "ClaudeSynth.h"

@implementation ClaudeSynthView

- (id)initWithFrame:(NSRect)frame audioUnit:(AudioUnit)au {
    self = [super initWithFrame:NSMakeRect(0, 0, 300, 180)];
    if (self) {
        mAU = au;

        // Set dark background
        [self setWantsLayer:YES];
        self.layer.backgroundColor = [[NSColor colorWithWhite:0.15 alpha:1.0] CGColor];

        // Title label at top
        titleLabel = [[NSTextField alloc] initWithFrame:NSMakeRect(0, 140, 300, 30)];
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
        volumeLabel = [[NSTextField alloc] initWithFrame:NSMakeRect(0, 118, 300, 20)];
        [volumeLabel setStringValue:@"Master Volume"];
        [volumeLabel setAlignment:NSTextAlignmentCenter];
        [volumeLabel setBezeled:NO];
        [volumeLabel setDrawsBackground:NO];
        [volumeLabel setEditable:NO];
        [volumeLabel setSelectable:NO];
        [volumeLabel setFont:[NSFont systemFontOfSize:12]];
        [volumeLabel setTextColor:[NSColor colorWithWhite:0.7 alpha:1.0]];
        [self addSubview:volumeLabel];

        // Rotary knob control
        volumeKnob = [[RotaryKnob alloc] initWithFrame:NSMakeRect(110, 35, 80, 80)];
        [volumeKnob setMinValue:0.0];
        [volumeKnob setMaxValue:1.0];

        // Get initial value from Audio Unit
        AudioUnitParameterValue initialValue = 1.0f;
        if (mAU) {
            AudioUnitGetParameter(mAU, kParam_MasterVolume, kAudioUnitScope_Global, 0, &initialValue);
        }
        [volumeKnob setDoubleValue:initialValue];

        [volumeKnob setTarget:self];
        [volumeKnob setAction:@selector(volumeChanged:)];
        [volumeKnob setContinuous:YES];
        [self addSubview:volumeKnob];

        // Percentage display below knob
        percentageDisplay = [[NSTextField alloc] initWithFrame:NSMakeRect(0, 10, 300, 20)];
        [percentageDisplay setStringValue:[NSString stringWithFormat:@"%.0f%%", initialValue * 100.0]];
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

- (void)updateFromHost:(NSTimer *)timer {
    // Poll the Audio Unit for parameter changes (e.g., from host automation)
    if (mAU) {
        AudioUnitParameterValue value;
        OSStatus status = AudioUnitGetParameter(mAU, kParam_MasterVolume, kAudioUnitScope_Global, 0, &value);

        if (status == noErr) {
            float currentKnobValue = [volumeKnob floatValue];

            // Only update UI if value changed (avoid feedback loop)
            if (fabs(value - currentKnobValue) > 0.001f) {
                [volumeKnob setFloatValue:value];
                [percentageDisplay setStringValue:[NSString stringWithFormat:@"%.0f%%", value * 100.0]];
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
