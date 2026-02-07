#import "ClaudeSynthView.h"
#import "ClaudeSynth.h"

@implementation ClaudeSynthView

- (id)initWithFrame:(NSRect)frame audioUnit:(AudioUnit)au {
    self = [super initWithFrame:NSMakeRect(0, 0, 900, 320)];
    if (self) {
        mAU = au;

        // Set dark background
        [self setWantsLayer:YES];
        self.layer.backgroundColor = [[NSColor colorWithWhite:0.15 alpha:1.0] CGColor];

        // Title label at top
        titleLabel = [[NSTextField alloc] initWithFrame:NSMakeRect(0, 280, 900, 30)];
        [titleLabel setStringValue:@"ClaudeSynth"];
        [titleLabel setAlignment:NSTextAlignmentCenter];
        [titleLabel setBezeled:NO];
        [titleLabel setDrawsBackground:NO];
        [titleLabel setEditable:NO];
        [titleLabel setSelectable:NO];
        [titleLabel setFont:[NSFont systemFontOfSize:20 weight:NSFontWeightBold]];
        [titleLabel setTextColor:[NSColor whiteColor]];
        [self addSubview:titleLabel];

        // Layout: 5 sections horizontally - Osc1, Osc2, Osc3, Filter, Master
        // Each section is 180 pixels wide
        int sectionWidth = 180;
        int osc1X = 0;
        int osc2X = 180;
        int osc3X = 360;
        int filterX = 540;
        int masterX = 720;

        // ===== OSCILLATOR 1 =====
        [self createOscillatorSection:1 atX:osc1X];

        // ===== OSCILLATOR 2 =====
        [self createOscillatorSection:2 atX:osc2X];

        // ===== OSCILLATOR 3 =====
        [self createOscillatorSection:3 atX:osc3X];

        // ===== FILTER SECTION =====
        filterLabel = [[NSTextField alloc] initWithFrame:NSMakeRect(filterX + 30, 255, 120, 20)];
        [filterLabel setStringValue:@"Filter"];
        [filterLabel setAlignment:NSTextAlignmentCenter];
        [filterLabel setBezeled:NO];
        [filterLabel setDrawsBackground:NO];
        [filterLabel setEditable:NO];
        [filterLabel setSelectable:NO];
        [filterLabel setFont:[NSFont systemFontOfSize:14 weight:NSFontWeightBold]];
        [filterLabel setTextColor:[NSColor whiteColor]];
        [self addSubview:filterLabel];

        // Filter Cutoff
        cutoffLabel = [[NSTextField alloc] initWithFrame:NSMakeRect(filterX + 30, 220, 120, 16)];
        [cutoffLabel setStringValue:@"Cutoff"];
        [cutoffLabel setAlignment:NSTextAlignmentCenter];
        [cutoffLabel setBezeled:NO];
        [cutoffLabel setDrawsBackground:NO];
        [cutoffLabel setEditable:NO];
        [cutoffLabel setSelectable:NO];
        [cutoffLabel setFont:[NSFont systemFontOfSize:11]];
        [cutoffLabel setTextColor:[NSColor colorWithWhite:0.7 alpha:1.0]];
        [self addSubview:cutoffLabel];

        cutoffKnob = [[RotaryKnob alloc] initWithFrame:NSMakeRect(filterX + 50, 150, 80, 80)];
        [cutoffKnob setMinValue:0.0];
        [cutoffKnob setMaxValue:1.0];

        AudioUnitParameterValue initialCutoff = 20000.0f;
        if (mAU) {
            AudioUnitGetParameter(mAU, kParam_FilterCutoff, kAudioUnitScope_Global, 0, &initialCutoff);
        }
        double cutoffPosition = log(initialCutoff / 20.0) / log(1000.0);
        [cutoffKnob setDoubleValue:cutoffPosition];

        [cutoffKnob setTarget:self];
        [cutoffKnob setAction:@selector(cutoffChanged:)];
        [cutoffKnob setContinuous:YES];
        [self addSubview:cutoffKnob];

        cutoffValueDisplay = [[NSTextField alloc] initWithFrame:NSMakeRect(filterX + 30, 130, 120, 16)];
        [cutoffValueDisplay setStringValue:[NSString stringWithFormat:@"%.0f Hz", initialCutoff]];
        [cutoffValueDisplay setAlignment:NSTextAlignmentCenter];
        [cutoffValueDisplay setBezeled:NO];
        [cutoffValueDisplay setDrawsBackground:NO];
        [cutoffValueDisplay setEditable:NO];
        [cutoffValueDisplay setSelectable:NO];
        [cutoffValueDisplay setFont:[NSFont systemFontOfSize:10]];
        [cutoffValueDisplay setTextColor:[NSColor colorWithWhite:0.6 alpha:1.0]];
        [self addSubview:cutoffValueDisplay];

        // Filter Resonance
        resonanceLabel = [[NSTextField alloc] initWithFrame:NSMakeRect(filterX + 30, 105, 120, 16)];
        [resonanceLabel setStringValue:@"Resonance"];
        [resonanceLabel setAlignment:NSTextAlignmentCenter];
        [resonanceLabel setBezeled:NO];
        [resonanceLabel setDrawsBackground:NO];
        [resonanceLabel setEditable:NO];
        [resonanceLabel setSelectable:NO];
        [resonanceLabel setFont:[NSFont systemFontOfSize:11]];
        [resonanceLabel setTextColor:[NSColor colorWithWhite:0.7 alpha:1.0]];
        [self addSubview:resonanceLabel];

        resonanceKnob = [[RotaryKnob alloc] initWithFrame:NSMakeRect(filterX + 50, 35, 80, 80)];
        [resonanceKnob setMinValue:0.5];
        [resonanceKnob setMaxValue:10.0];

        AudioUnitParameterValue initialResonance = 0.7f;
        if (mAU) {
            AudioUnitGetParameter(mAU, kParam_FilterResonance, kAudioUnitScope_Global, 0, &initialResonance);
        }
        [resonanceKnob setDoubleValue:initialResonance];

        [resonanceKnob setTarget:self];
        [resonanceKnob setAction:@selector(resonanceChanged:)];
        [resonanceKnob setContinuous:YES];
        [self addSubview:resonanceKnob];

        resonanceValueDisplay = [[NSTextField alloc] initWithFrame:NSMakeRect(filterX + 30, 15, 120, 16)];
        [resonanceValueDisplay setStringValue:[NSString stringWithFormat:@"Q: %.2f", initialResonance]];
        [resonanceValueDisplay setAlignment:NSTextAlignmentCenter];
        [resonanceValueDisplay setBezeled:NO];
        [resonanceValueDisplay setDrawsBackground:NO];
        [resonanceValueDisplay setEditable:NO];
        [resonanceValueDisplay setSelectable:NO];
        [resonanceValueDisplay setFont:[NSFont systemFontOfSize:10]];
        [resonanceValueDisplay setTextColor:[NSColor colorWithWhite:0.6 alpha:1.0]];
        [self addSubview:resonanceValueDisplay];

        // ===== MASTER VOLUME SECTION =====
        masterVolumeLabel = [[NSTextField alloc] initWithFrame:NSMakeRect(masterX + 30, 255, 120, 20)];
        [masterVolumeLabel setStringValue:@"Master"];
        [masterVolumeLabel setAlignment:NSTextAlignmentCenter];
        [masterVolumeLabel setBezeled:NO];
        [masterVolumeLabel setDrawsBackground:NO];
        [masterVolumeLabel setEditable:NO];
        [masterVolumeLabel setSelectable:NO];
        [masterVolumeLabel setFont:[NSFont systemFontOfSize:14 weight:NSFontWeightBold]];
        [masterVolumeLabel setTextColor:[NSColor whiteColor]];
        [self addSubview:masterVolumeLabel];

        NSTextField *volumeSubLabel = [[NSTextField alloc] initWithFrame:NSMakeRect(masterX + 30, 220, 120, 16)];
        [volumeSubLabel setStringValue:@"Volume"];
        [volumeSubLabel setAlignment:NSTextAlignmentCenter];
        [volumeSubLabel setBezeled:NO];
        [volumeSubLabel setDrawsBackground:NO];
        [volumeSubLabel setEditable:NO];
        [volumeSubLabel setSelectable:NO];
        [volumeSubLabel setFont:[NSFont systemFontOfSize:11]];
        [volumeSubLabel setTextColor:[NSColor colorWithWhite:0.7 alpha:1.0]];
        [self addSubview:volumeSubLabel];

        masterVolumeKnob = [[RotaryKnob alloc] initWithFrame:NSMakeRect(masterX + 50, 150, 80, 80)];
        [masterVolumeKnob setMinValue:0.0];
        [masterVolumeKnob setMaxValue:1.0];

        AudioUnitParameterValue initialMasterVolume = 1.0f;
        if (mAU) {
            AudioUnitGetParameter(mAU, kParam_MasterVolume, kAudioUnitScope_Global, 0, &initialMasterVolume);
        }
        [masterVolumeKnob setDoubleValue:initialMasterVolume];

        [masterVolumeKnob setTarget:self];
        [masterVolumeKnob setAction:@selector(masterVolumeChanged:)];
        [masterVolumeKnob setContinuous:YES];
        [self addSubview:masterVolumeKnob];

        masterVolumeDisplay = [[NSTextField alloc] initWithFrame:NSMakeRect(masterX + 30, 130, 120, 20)];
        [masterVolumeDisplay setStringValue:[NSString stringWithFormat:@"%.0f%%", initialMasterVolume * 100.0]];
        [masterVolumeDisplay setAlignment:NSTextAlignmentCenter];
        [masterVolumeDisplay setBezeled:NO];
        [masterVolumeDisplay setDrawsBackground:NO];
        [masterVolumeDisplay setEditable:NO];
        [masterVolumeDisplay setSelectable:NO];
        [masterVolumeDisplay setFont:[NSFont systemFontOfSize:14 weight:NSFontWeightMedium]];
        [masterVolumeDisplay setTextColor:[NSColor whiteColor]];
        [self addSubview:masterVolumeDisplay];

        // Start timer to poll for host automation updates
        updateTimer = [NSTimer scheduledTimerWithTimeInterval:0.1
                                                       target:self
                                                     selector:@selector(updateFromHost:)
                                                     userInfo:nil
                                                      repeats:YES];
    }
    return self;
}

- (void)createOscillatorSection:(int)oscNum atX:(int)x {
    NSTextField *label, *waveLabel, *octaveLabel, *octaveDisplay, *detuneLabel, *detuneDisplay, *volumeLabel, *volumeDisplay;
    DiscreteKnob *waveKnob;
    RotaryKnob *octaveKnob, *detuneKnob, *volumeKnob;

    // Section label
    label = [[NSTextField alloc] initWithFrame:NSMakeRect(x + 30, 255, 120, 20)];
    [label setStringValue:[NSString stringWithFormat:@"Oscillator %d", oscNum]];
    [label setAlignment:NSTextAlignmentCenter];
    [label setBezeled:NO];
    [label setDrawsBackground:NO];
    [label setEditable:NO];
    [label setSelectable:NO];
    [label setFont:[NSFont systemFontOfSize:14 weight:NSFontWeightBold]];
    [label setTextColor:[NSColor whiteColor]];
    [self addSubview:label];

    // Waveform
    waveLabel = [[NSTextField alloc] initWithFrame:NSMakeRect(x + 30, 220, 120, 16)];
    [waveLabel setStringValue:@"Waveform"];
    [waveLabel setAlignment:NSTextAlignmentCenter];
    [waveLabel setBezeled:NO];
    [waveLabel setDrawsBackground:NO];
    [waveLabel setEditable:NO];
    [waveLabel setSelectable:NO];
    [waveLabel setFont:[NSFont systemFontOfSize:10]];
    [waveLabel setTextColor:[NSColor colorWithWhite:0.7 alpha:1.0]];
    [self addSubview:waveLabel];

    waveKnob = [[DiscreteKnob alloc] initWithFrame:NSMakeRect(x + 50, 185, 80, 30)];

    AudioUnitParameterValue initialWaveform = 0.0f;
    AudioUnitParameterID waveformParamID = (oscNum == 1) ? kParam_Osc1_Waveform :
                                           (oscNum == 2) ? kParam_Osc2_Waveform : kParam_Osc3_Waveform;
    if (mAU) {
        AudioUnitGetParameter(mAU, waveformParamID, kAudioUnitScope_Global, 0, &initialWaveform);
    }
    [waveKnob setIntValue:(int)initialWaveform];

    [waveKnob setTarget:self];
    if (oscNum == 1) [waveKnob setAction:@selector(osc1WaveformChanged:)];
    else if (oscNum == 2) [waveKnob setAction:@selector(osc2WaveformChanged:)];
    else [waveKnob setAction:@selector(osc3WaveformChanged:)];
    [self addSubview:waveKnob];

    // Octave
    octaveLabel = [[NSTextField alloc] initWithFrame:NSMakeRect(x + 30, 160, 120, 16)];
    [octaveLabel setStringValue:@"Octave"];
    [octaveLabel setAlignment:NSTextAlignmentCenter];
    [octaveLabel setBezeled:NO];
    [octaveLabel setDrawsBackground:NO];
    [octaveLabel setEditable:NO];
    [octaveLabel setSelectable:NO];
    [octaveLabel setFont:[NSFont systemFontOfSize:10]];
    [octaveLabel setTextColor:[NSColor colorWithWhite:0.7 alpha:1.0]];
    [self addSubview:octaveLabel];

    octaveKnob = [[RotaryKnob alloc] initWithFrame:NSMakeRect(x + 50, 100, 80, 60)];
    [octaveKnob setMinValue:-2.0];
    [octaveKnob setMaxValue:2.0];
    [octaveKnob setBipolar:YES];

    AudioUnitParameterValue initialOctave = 0.0f;
    AudioUnitParameterID octaveParamID = (oscNum == 1) ? kParam_Osc1_Octave :
                                         (oscNum == 2) ? kParam_Osc2_Octave : kParam_Osc3_Octave;
    if (mAU) {
        AudioUnitGetParameter(mAU, octaveParamID, kAudioUnitScope_Global, 0, &initialOctave);
    }
    [octaveKnob setDoubleValue:initialOctave];

    [octaveKnob setTarget:self];
    if (oscNum == 1) [octaveKnob setAction:@selector(osc1OctaveChanged:)];
    else if (oscNum == 2) [octaveKnob setAction:@selector(osc2OctaveChanged:)];
    else [octaveKnob setAction:@selector(osc3OctaveChanged:)];
    [octaveKnob setContinuous:YES];
    [self addSubview:octaveKnob];

    octaveDisplay = [[NSTextField alloc] initWithFrame:NSMakeRect(x + 30, 80, 120, 16)];
    int octaveInt = (int)round(initialOctave);
    [octaveDisplay setStringValue:[NSString stringWithFormat:@"%+d", octaveInt]];
    [octaveDisplay setAlignment:NSTextAlignmentCenter];
    [octaveDisplay setBezeled:NO];
    [octaveDisplay setDrawsBackground:NO];
    [octaveDisplay setEditable:NO];
    [octaveDisplay setSelectable:NO];
    [octaveDisplay setFont:[NSFont systemFontOfSize:10]];
    [octaveDisplay setTextColor:[NSColor colorWithWhite:0.6 alpha:1.0]];
    [self addSubview:octaveDisplay];

    // Detune
    detuneLabel = [[NSTextField alloc] initWithFrame:NSMakeRect(x + 30, 60, 60, 16)];
    [detuneLabel setStringValue:@"Detune"];
    [detuneLabel setAlignment:NSTextAlignmentLeft];
    [detuneLabel setBezeled:NO];
    [detuneLabel setDrawsBackground:NO];
    [detuneLabel setEditable:NO];
    [detuneLabel setSelectable:NO];
    [detuneLabel setFont:[NSFont systemFontOfSize:10]];
    [detuneLabel setTextColor:[NSColor colorWithWhite:0.7 alpha:1.0]];
    [self addSubview:detuneLabel];

    detuneKnob = [[RotaryKnob alloc] initWithFrame:NSMakeRect(x + 30, 25, 50, 40)];
    [detuneKnob setMinValue:-100.0];
    [detuneKnob setMaxValue:100.0];
    [detuneKnob setBipolar:YES];

    AudioUnitParameterValue initialDetune = 0.0f;
    AudioUnitParameterID detuneParamID = (oscNum == 1) ? kParam_Osc1_Detune :
                                         (oscNum == 2) ? kParam_Osc2_Detune : kParam_Osc3_Detune;
    if (mAU) {
        AudioUnitGetParameter(mAU, detuneParamID, kAudioUnitScope_Global, 0, &initialDetune);
    }
    [detuneKnob setDoubleValue:initialDetune];

    [detuneKnob setTarget:self];
    if (oscNum == 1) [detuneKnob setAction:@selector(osc1DetuneChanged:)];
    else if (oscNum == 2) [detuneKnob setAction:@selector(osc2DetuneChanged:)];
    else [detuneKnob setAction:@selector(osc3DetuneChanged:)];
    [detuneKnob setContinuous:YES];
    [self addSubview:detuneKnob];

    detuneDisplay = [[NSTextField alloc] initWithFrame:NSMakeRect(x + 30, 5, 50, 16)];
    [detuneDisplay setStringValue:[NSString stringWithFormat:@"%+.0fc", initialDetune]];
    [detuneDisplay setAlignment:NSTextAlignmentCenter];
    [detuneDisplay setBezeled:NO];
    [detuneDisplay setDrawsBackground:NO];
    [detuneDisplay setEditable:NO];
    [detuneDisplay setSelectable:NO];
    [detuneDisplay setFont:[NSFont systemFontOfSize:9]];
    [detuneDisplay setTextColor:[NSColor colorWithWhite:0.6 alpha:1.0]];
    [self addSubview:detuneDisplay];

    // Volume
    volumeLabel = [[NSTextField alloc] initWithFrame:NSMakeRect(x + 100, 60, 60, 16)];
    [volumeLabel setStringValue:@"Volume"];
    [volumeLabel setAlignment:NSTextAlignmentLeft];
    [volumeLabel setBezeled:NO];
    [volumeLabel setDrawsBackground:NO];
    [volumeLabel setEditable:NO];
    [volumeLabel setSelectable:NO];
    [volumeLabel setFont:[NSFont systemFontOfSize:10]];
    [volumeLabel setTextColor:[NSColor colorWithWhite:0.7 alpha:1.0]];
    [self addSubview:volumeLabel];

    volumeKnob = [[RotaryKnob alloc] initWithFrame:NSMakeRect(x + 100, 25, 50, 40)];
    [volumeKnob setMinValue:0.0];
    [volumeKnob setMaxValue:1.0];

    AudioUnitParameterValue initialVolume = (oscNum == 1) ? 1.0f : 0.0f;
    AudioUnitParameterID volumeParamID = (oscNum == 1) ? kParam_Osc1_Volume :
                                         (oscNum == 2) ? kParam_Osc2_Volume : kParam_Osc3_Volume;
    if (mAU) {
        AudioUnitGetParameter(mAU, volumeParamID, kAudioUnitScope_Global, 0, &initialVolume);
    }
    [volumeKnob setDoubleValue:initialVolume];

    [volumeKnob setTarget:self];
    if (oscNum == 1) [volumeKnob setAction:@selector(osc1VolumeChanged:)];
    else if (oscNum == 2) [volumeKnob setAction:@selector(osc2VolumeChanged:)];
    else [volumeKnob setAction:@selector(osc3VolumeChanged:)];
    [volumeKnob setContinuous:YES];
    [self addSubview:volumeKnob];

    volumeDisplay = [[NSTextField alloc] initWithFrame:NSMakeRect(x + 100, 5, 50, 16)];
    [volumeDisplay setStringValue:[NSString stringWithFormat:@"%.0f%%", initialVolume * 100.0]];
    [volumeDisplay setAlignment:NSTextAlignmentCenter];
    [volumeDisplay setBezeled:NO];
    [volumeDisplay setDrawsBackground:NO];
    [volumeDisplay setEditable:NO];
    [volumeDisplay setSelectable:NO];
    [volumeDisplay setFont:[NSFont systemFontOfSize:9]];
    [volumeDisplay setTextColor:[NSColor colorWithWhite:0.6 alpha:1.0]];
    [self addSubview:volumeDisplay];

    // Store references based on oscillator number
    if (oscNum == 1) {
        osc1Label = label;
        osc1WaveformLabel = waveLabel;
        osc1WaveformKnob = waveKnob;
        osc1OctaveLabel = octaveLabel;
        osc1OctaveKnob = octaveKnob;
        osc1OctaveDisplay = octaveDisplay;
        osc1DetuneLabel = detuneLabel;
        osc1DetuneKnob = detuneKnob;
        osc1DetuneDisplay = detuneDisplay;
        osc1VolumeLabel = volumeLabel;
        osc1VolumeKnob = volumeKnob;
        osc1VolumeDisplay = volumeDisplay;
    } else if (oscNum == 2) {
        osc2Label = label;
        osc2WaveformLabel = waveLabel;
        osc2WaveformKnob = waveKnob;
        osc2OctaveLabel = octaveLabel;
        osc2OctaveKnob = octaveKnob;
        osc2OctaveDisplay = octaveDisplay;
        osc2DetuneLabel = detuneLabel;
        osc2DetuneKnob = detuneKnob;
        osc2DetuneDisplay = detuneDisplay;
        osc2VolumeLabel = volumeLabel;
        osc2VolumeKnob = volumeKnob;
        osc2VolumeDisplay = volumeDisplay;
    } else {
        osc3Label = label;
        osc3WaveformLabel = waveLabel;
        osc3WaveformKnob = waveKnob;
        osc3OctaveLabel = octaveLabel;
        osc3OctaveKnob = octaveKnob;
        osc3OctaveDisplay = octaveDisplay;
        osc3DetuneLabel = detuneLabel;
        osc3DetuneKnob = detuneKnob;
        osc3DetuneDisplay = detuneDisplay;
        osc3VolumeLabel = volumeLabel;
        osc3VolumeKnob = volumeKnob;
        osc3VolumeDisplay = volumeDisplay;
    }
}

- (void)dealloc {
    [updateTimer invalidate];
}

// Master Volume
- (void)masterVolumeChanged:(id)sender {
    float value = [masterVolumeKnob floatValue];
    if (mAU) {
        AudioUnitSetParameter(mAU, kParam_MasterVolume, kAudioUnitScope_Global, 0, value, 0);
    }
    [masterVolumeDisplay setStringValue:[NSString stringWithFormat:@"%.0f%%", value * 100.0]];
}

// Oscillator 1
- (void)osc1WaveformChanged:(id)sender {
    int value = [osc1WaveformKnob intValue];
    if (mAU) {
        AudioUnitSetParameter(mAU, kParam_Osc1_Waveform, kAudioUnitScope_Global, 0, (float)value, 0);
    }
}

- (void)osc1OctaveChanged:(id)sender {
    float value = [osc1OctaveKnob floatValue];
    int intValue = (int)round(value);
    if (mAU) {
        AudioUnitSetParameter(mAU, kParam_Osc1_Octave, kAudioUnitScope_Global, 0, (float)intValue, 0);
    }
    [osc1OctaveDisplay setStringValue:[NSString stringWithFormat:@"%+d", intValue]];
}

- (void)osc1DetuneChanged:(id)sender {
    float value = [osc1DetuneKnob floatValue];
    if (mAU) {
        AudioUnitSetParameter(mAU, kParam_Osc1_Detune, kAudioUnitScope_Global, 0, value, 0);
    }
    [osc1DetuneDisplay setStringValue:[NSString stringWithFormat:@"%+.0fc", value]];
}

- (void)osc1VolumeChanged:(id)sender {
    float value = [osc1VolumeKnob floatValue];
    if (mAU) {
        AudioUnitSetParameter(mAU, kParam_Osc1_Volume, kAudioUnitScope_Global, 0, value, 0);
    }
    [osc1VolumeDisplay setStringValue:[NSString stringWithFormat:@"%.0f%%", value * 100.0]];
}

// Oscillator 2
- (void)osc2WaveformChanged:(id)sender {
    int value = [osc2WaveformKnob intValue];
    if (mAU) {
        AudioUnitSetParameter(mAU, kParam_Osc2_Waveform, kAudioUnitScope_Global, 0, (float)value, 0);
    }
}

- (void)osc2OctaveChanged:(id)sender {
    float value = [osc2OctaveKnob floatValue];
    int intValue = (int)round(value);
    if (mAU) {
        AudioUnitSetParameter(mAU, kParam_Osc2_Octave, kAudioUnitScope_Global, 0, (float)intValue, 0);
    }
    [osc2OctaveDisplay setStringValue:[NSString stringWithFormat:@"%+d", intValue]];
}

- (void)osc2DetuneChanged:(id)sender {
    float value = [osc2DetuneKnob floatValue];
    if (mAU) {
        AudioUnitSetParameter(mAU, kParam_Osc2_Detune, kAudioUnitScope_Global, 0, value, 0);
    }
    [osc2DetuneDisplay setStringValue:[NSString stringWithFormat:@"%+.0fc", value]];
}

- (void)osc2VolumeChanged:(id)sender {
    float value = [osc2VolumeKnob floatValue];
    if (mAU) {
        AudioUnitSetParameter(mAU, kParam_Osc2_Volume, kAudioUnitScope_Global, 0, value, 0);
    }
    [osc2VolumeDisplay setStringValue:[NSString stringWithFormat:@"%.0f%%", value * 100.0]];
}

// Oscillator 3
- (void)osc3WaveformChanged:(id)sender {
    int value = [osc3WaveformKnob intValue];
    if (mAU) {
        AudioUnitSetParameter(mAU, kParam_Osc3_Waveform, kAudioUnitScope_Global, 0, (float)value, 0);
    }
}

- (void)osc3OctaveChanged:(id)sender {
    float value = [osc3OctaveKnob floatValue];
    int intValue = (int)round(value);
    if (mAU) {
        AudioUnitSetParameter(mAU, kParam_Osc3_Octave, kAudioUnitScope_Global, 0, (float)intValue, 0);
    }
    [osc3OctaveDisplay setStringValue:[NSString stringWithFormat:@"%+d", intValue]];
}

- (void)osc3DetuneChanged:(id)sender {
    float value = [osc3DetuneKnob floatValue];
    if (mAU) {
        AudioUnitSetParameter(mAU, kParam_Osc3_Detune, kAudioUnitScope_Global, 0, value, 0);
    }
    [osc3DetuneDisplay setStringValue:[NSString stringWithFormat:@"%+.0fc", value]];
}

- (void)osc3VolumeChanged:(id)sender {
    float value = [osc3VolumeKnob floatValue];
    if (mAU) {
        AudioUnitSetParameter(mAU, kParam_Osc3_Volume, kAudioUnitScope_Global, 0, value, 0);
    }
    [osc3VolumeDisplay setStringValue:[NSString stringWithFormat:@"%.0f%%", value * 100.0]];
}

// Filter
- (void)cutoffChanged:(id)sender {
    float position = [cutoffKnob floatValue];
    float frequency = 20.0f * powf(1000.0f, position);

    if (mAU) {
        AudioUnitSetParameter(mAU, kParam_FilterCutoff, kAudioUnitScope_Global, 0, frequency, 0);
    }

    if (frequency >= 1000.0f) {
        [cutoffValueDisplay setStringValue:[NSString stringWithFormat:@"%.1f kHz", frequency / 1000.0f]];
    } else {
        [cutoffValueDisplay setStringValue:[NSString stringWithFormat:@"%.0f Hz", frequency]];
    }
}

- (void)resonanceChanged:(id)sender {
    float value = [resonanceKnob floatValue];

    if (mAU) {
        AudioUnitSetParameter(mAU, kParam_FilterResonance, kAudioUnitScope_Global, 0, value, 0);
    }

    [resonanceValueDisplay setStringValue:[NSString stringWithFormat:@"Q: %.2f", value]];
}

- (void)updateFromHost:(NSTimer *)timer {
    if (!mAU) return;

    // Update master volume
    AudioUnitParameterValue value;
    if (AudioUnitGetParameter(mAU, kParam_MasterVolume, kAudioUnitScope_Global, 0, &value) == noErr) {
        if (fabs(value - [masterVolumeKnob floatValue]) > 0.001f) {
            [masterVolumeKnob setFloatValue:value];
            [masterVolumeDisplay setStringValue:[NSString stringWithFormat:@"%.0f%%", value * 100.0]];
        }
    }

    // Update oscillator 1 parameters
    if (AudioUnitGetParameter(mAU, kParam_Osc1_Waveform, kAudioUnitScope_Global, 0, &value) == noErr) {
        if ((int)value != [osc1WaveformKnob intValue]) {
            [osc1WaveformKnob setIntValue:(int)value];
        }
    }
    if (AudioUnitGetParameter(mAU, kParam_Osc1_Volume, kAudioUnitScope_Global, 0, &value) == noErr) {
        if (fabs(value - [osc1VolumeKnob floatValue]) > 0.001f) {
            [osc1VolumeKnob setFloatValue:value];
            [osc1VolumeDisplay setStringValue:[NSString stringWithFormat:@"%.0f%%", value * 100.0]];
        }
    }

    // Update oscillator 2 parameters
    if (AudioUnitGetParameter(mAU, kParam_Osc2_Waveform, kAudioUnitScope_Global, 0, &value) == noErr) {
        if ((int)value != [osc2WaveformKnob intValue]) {
            [osc2WaveformKnob setIntValue:(int)value];
        }
    }
    if (AudioUnitGetParameter(mAU, kParam_Osc2_Volume, kAudioUnitScope_Global, 0, &value) == noErr) {
        if (fabs(value - [osc2VolumeKnob floatValue]) > 0.001f) {
            [osc2VolumeKnob setFloatValue:value];
            [osc2VolumeDisplay setStringValue:[NSString stringWithFormat:@"%.0f%%", value * 100.0]];
        }
    }

    // Update oscillator 3 parameters
    if (AudioUnitGetParameter(mAU, kParam_Osc3_Waveform, kAudioUnitScope_Global, 0, &value) == noErr) {
        if ((int)value != [osc3WaveformKnob intValue]) {
            [osc3WaveformKnob setIntValue:(int)value];
        }
    }
    if (AudioUnitGetParameter(mAU, kParam_Osc3_Volume, kAudioUnitScope_Global, 0, &value) == noErr) {
        if (fabs(value - [osc3VolumeKnob floatValue]) > 0.001f) {
            [osc3VolumeKnob setFloatValue:value];
            [osc3VolumeDisplay setStringValue:[NSString stringWithFormat:@"%.0f%%", value * 100.0]];
        }
    }

    // Update filter parameters
    if (AudioUnitGetParameter(mAU, kParam_FilterCutoff, kAudioUnitScope_Global, 0, &value) == noErr) {
        double cutoffPosition = log(value / 20.0) / log(1000.0);
        if (fabs(cutoffPosition - [cutoffKnob floatValue]) > 0.01f) {
            [cutoffKnob setFloatValue:cutoffPosition];
            if (value >= 1000.0f) {
                [cutoffValueDisplay setStringValue:[NSString stringWithFormat:@"%.1f kHz", value / 1000.0f]];
            } else {
                [cutoffValueDisplay setStringValue:[NSString stringWithFormat:@"%.0f Hz", value]];
            }
        }
    }

    if (AudioUnitGetParameter(mAU, kParam_FilterResonance, kAudioUnitScope_Global, 0, &value) == noErr) {
        if (fabs(value - [resonanceKnob floatValue]) > 0.01f) {
            [resonanceKnob setFloatValue:value];
            [resonanceValueDisplay setStringValue:[NSString stringWithFormat:@"Q: %.2f", value]];
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
