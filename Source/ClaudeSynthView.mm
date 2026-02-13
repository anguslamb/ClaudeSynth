#import "ClaudeSynthView.h"
#import "ClaudeSynth.h"
#import "MatrixDropdown.h"
#import "MatrixCheckbox.h"
#import "MatrixSlider.h"
#import "MatrixLED.h"
#import "MatrixOscilloscope.h"

// Forward declare ClaudeSynthView's color methods for use in WaveformIconView
@interface ClaudeSynthView (MatrixTheme)
+ (NSColor *)matrixBackground;
+ (NSColor *)matrixBrightGreen;
+ (NSColor *)matrixMediumGreen;
+ (NSColor *)matrixDimGreen;
+ (NSColor *)matrixDarkGreen;
+ (NSColor *)matrixCyan;
+ (NSFont *)matrixFontOfSize:(CGFloat)size;
+ (NSFont *)matrixBoldFontOfSize:(CGFloat)size;
@end

// Helper view class for drawing waveform icons
@interface WaveformIconView : NSView
@property (nonatomic) int waveformType;
@end

@implementation WaveformIconView

- (void)drawRect:(NSRect)dirtyRect {
    [super drawRect:dirtyRect];

    NSRect bounds = [self bounds];
    CGFloat width = bounds.size.width;
    CGFloat height = bounds.size.height;

    NSBezierPath *path = [NSBezierPath bezierPath];
    [path setLineWidth:1.5];
    [path setLineCapStyle:NSLineCapStyleRound];
    [path setLineJoinStyle:NSLineJoinStyleRound];

    switch (self.waveformType) {
        case 0: // Sine
            for (int i = 0; i <= 20; i++) {
                CGFloat t = i / 20.0;
                CGFloat x = t * width;
                CGFloat y = height / 2.0 + (height / 2.5) * sin(t * M_PI * 2);
                if (i == 0) {
                    [path moveToPoint:NSMakePoint(x, y)];
                } else {
                    [path lineToPoint:NSMakePoint(x, y)];
                }
            }
            break;

        case 1: // Square
            [path moveToPoint:NSMakePoint(0, height * 0.8)];
            [path lineToPoint:NSMakePoint(width * 0.25, height * 0.8)];
            [path lineToPoint:NSMakePoint(width * 0.25, height * 0.2)];
            [path lineToPoint:NSMakePoint(width * 0.75, height * 0.2)];
            [path lineToPoint:NSMakePoint(width * 0.75, height * 0.8)];
            [path lineToPoint:NSMakePoint(width, height * 0.8)];
            break;

        case 2: // Sawtooth
            [path moveToPoint:NSMakePoint(0, height * 0.2)];
            [path lineToPoint:NSMakePoint(width * 0.5, height * 0.8)];
            [path lineToPoint:NSMakePoint(width * 0.5, height * 0.2)];
            [path lineToPoint:NSMakePoint(width, height * 0.8)];
            break;

        case 3: // Triangle
            [path moveToPoint:NSMakePoint(0, height * 0.5)];
            [path lineToPoint:NSMakePoint(width * 0.25, height * 0.2)];
            [path lineToPoint:NSMakePoint(width * 0.5, height * 0.5)];
            [path lineToPoint:NSMakePoint(width * 0.75, height * 0.8)];
            [path lineToPoint:NSMakePoint(width, height * 0.5)];
            break;
    }

    [[ClaudeSynthView matrixMediumGreen] setStroke];
    [path stroke];
}

@end

@interface ClaudeSynthView()
- (void)createOscillatorSection:(int)oscNum atX:(int)x;
- (void)createLFOSectionAtX:(int)x lfoNum:(int)lfoNum;
- (void)createModulationMatrixSection;
- (void)addWaveformIconsAtX:(int)x baseY:(int)baseY;
@end

@implementation ClaudeSynthView

// Matrix Theme Color Helpers
+ (NSColor *)matrixBackground {
    return [NSColor blackColor];
}

+ (NSColor *)matrixBrightGreen {
    return [NSColor colorWithRed:0.0 green:1.0 blue:0.0 alpha:1.0];  // #00FF00
}

+ (NSColor *)matrixMediumGreen {
    return [NSColor colorWithRed:0.0 green:0.67 blue:0.0 alpha:1.0];  // #00AA00
}

+ (NSColor *)matrixDimGreen {
    return [NSColor colorWithRed:0.0 green:0.4 blue:0.0 alpha:1.0];  // #006600
}

+ (NSColor *)matrixDarkGreen {
    return [NSColor colorWithRed:0.0 green:0.1 blue:0.0 alpha:1.0];  // #001A00
}

+ (NSColor *)matrixCyan {
    return [NSColor colorWithRed:0.0 green:1.0 blue:1.0 alpha:1.0];  // #00FFFF
}

+ (NSFont *)matrixFontOfSize:(CGFloat)size {
    NSFont *monacoFont = [NSFont fontWithName:@"Monaco" size:size];
    if (monacoFont) return monacoFont;

    // Fallback to system monospace font
    if (@available(macOS 10.15, *)) {
        return [NSFont monospacedSystemFontOfSize:size weight:NSFontWeightRegular];
    } else {
        return [NSFont fontWithName:@"Menlo" size:size] ?: [NSFont systemFontOfSize:size];
    }
}

+ (NSFont *)matrixBoldFontOfSize:(CGFloat)size {
    NSFont *monacoBoldFont = [NSFont fontWithName:@"Monaco-Bold" size:size];
    if (monacoBoldFont) return monacoBoldFont;

    // Fallback to system monospace font
    if (@available(macOS 10.15, *)) {
        return [NSFont monospacedSystemFontOfSize:size weight:NSFontWeightBold];
    } else {
        return [NSFont fontWithName:@"Menlo-Bold" size:size] ?: [NSFont boldSystemFontOfSize:size];
    }
}

- (id)initWithFrame:(NSRect)frame audioUnit:(AudioUnit)au {
    self = [super initWithFrame:NSMakeRect(0, 0, 1440, 520)];
    if (self) {
        mAU = au;

        // Force dark appearance for entire plugin (affects all system controls)
        if (@available(macOS 10.14, *)) {
            [self setAppearance:[NSAppearance appearanceNamed:NSAppearanceNameDarkAqua]];
        }

        // Set dark background
        [self setWantsLayer:YES];
        self.layer.backgroundColor = [[ClaudeSynthView matrixBackground] CGColor];

        // Title label at top
        titleLabel = [[NSTextField alloc] initWithFrame:NSMakeRect(0, 480, 1440, 30)];
        [titleLabel setStringValue:@"ClaudeSynth"];
        [titleLabel setAlignment:NSTextAlignmentCenter];
        [titleLabel setBezeled:NO];
        [titleLabel setDrawsBackground:NO];
        [titleLabel setEditable:NO];
        [titleLabel setSelectable:NO];
        [titleLabel setFont:[ClaudeSynthView matrixBoldFontOfSize:20]];
        [titleLabel setTextColor:[ClaudeSynthView matrixBrightGreen]];
        [self addSubview:titleLabel];

        // Version label at top right
        NSTextField *versionLabel = [[NSTextField alloc] initWithFrame:NSMakeRect(1330, 485, 100, 20)];
        [versionLabel setStringValue:@"v" CLAUDESYNTH_VERSION];
        [versionLabel setAlignment:NSTextAlignmentRight];
        [versionLabel setBezeled:NO];
        [versionLabel setDrawsBackground:NO];
        [versionLabel setEditable:NO];
        [versionLabel setSelectable:NO];
        [versionLabel setFont:[ClaudeSynthView matrixFontOfSize:9]];
        [versionLabel setTextColor:[ClaudeSynthView matrixDimGreen]];
        [self addSubview:versionLabel];

        // ===== VISUAL DIVIDERS =====
        NSColor *dividerColor = [ClaudeSynthView matrixDimGreen];

        // Horizontal divider separating top and bottom sections
        NSBox *horizontalDivider = [[NSBox alloc] initWithFrame:NSMakeRect(0, 190, 1440, 1)];
        [horizontalDivider setBoxType:NSBoxCustom];
        [horizontalDivider setBorderType:NSLineBorder];
        [horizontalDivider setBorderColor:dividerColor];
        [horizontalDivider setFillColor:dividerColor];
        [horizontalDivider setTitlePosition:NSNoTitle];
        [self addSubview:horizontalDivider];

        // Vertical dividers in top section
        // After Oscillators (between Osc3 and LFO1)
        NSBox *divider1 = [[NSBox alloc] initWithFrame:NSMakeRect(540, 200, 1, 280)];
        [divider1 setBoxType:NSBoxCustom];
        [divider1 setBorderType:NSLineBorder];
        [divider1 setBorderColor:dividerColor];
        [divider1 setFillColor:dividerColor];
        [divider1 setTitlePosition:NSNoTitle];
        [self addSubview:divider1];

        // Between LFOs and Filter
        NSBox *divider2 = [[NSBox alloc] initWithFrame:NSMakeRect(720, 200, 1, 280)];
        [divider2 setBoxType:NSBoxCustom];
        [divider2 setBorderType:NSLineBorder];
        [divider2 setBorderColor:dividerColor];
        [divider2 setFillColor:dividerColor];
        [divider2 setTitlePosition:NSNoTitle];
        [self addSubview:divider2];

        // Between Filter and Envelopes
        NSBox *divider3 = [[NSBox alloc] initWithFrame:NSMakeRect(900, 200, 1, 280)];
        [divider3 setBoxType:NSBoxCustom];
        [divider3 setBorderType:NSLineBorder];
        [divider3 setBorderColor:dividerColor];
        [divider3 setFillColor:dividerColor];
        [divider3 setTitlePosition:NSNoTitle];
        [self addSubview:divider3];

        // Between Envelopes and Master
        NSBox *divider4 = [[NSBox alloc] initWithFrame:NSMakeRect(1260, 200, 1, 280)];
        [divider4 setBoxType:NSBoxCustom];
        [divider4 setBorderType:NSLineBorder];
        [divider4 setBorderColor:dividerColor];
        [divider4 setFillColor:dividerColor];
        [divider4 setTitlePosition:NSNoTitle];
        [self addSubview:divider4];

        // Vertical divider in bottom section (between Modulation Matrix and Effects)
        NSBox *divider5 = [[NSBox alloc] initWithFrame:NSMakeRect(580, 10, 1, 170)];
        [divider5 setBoxType:NSBoxCustom];
        [divider5 setBorderType:NSLineBorder];
        [divider5 setBorderColor:dividerColor];
        [divider5 setFillColor:dividerColor];
        [divider5 setTitlePosition:NSNoTitle];
        [self addSubview:divider5];

        // Layout: 8 sections horizontally - Osc1, Osc2, Osc3, LFO1, LFO2, Filter, Envelope, Filter Env, Master
        // Each section is 180 pixels wide
        int sectionWidth = 180;
        int osc1X = 0;
        int osc2X = 180;
        int osc3X = 360;
        int lfo1X = 540;
        int lfo2X = 630;
        int filterX = 720;
        int envelopeX = 900;
        int filterEnvelopeX = 1080;
        int masterX = 1260;

        // ===== OSCILLATOR 1 =====
        [self createOscillatorSection:1 atX:osc1X];

        // ===== OSCILLATOR 2 =====
        [self createOscillatorSection:2 atX:osc2X];

        // ===== OSCILLATOR 3 =====
        [self createOscillatorSection:3 atX:osc3X];

        // ===== LFO 1 SECTION =====
        [self createLFOSectionAtX:lfo1X lfoNum:1];

        // ===== LFO 2 SECTION =====
        [self createLFOSectionAtX:lfo2X lfoNum:2];

        // ===== FILTER SECTION =====
        filterLabel = [[NSTextField alloc] initWithFrame:NSMakeRect(filterX + 30, 455, 120, 20)];
        [filterLabel setStringValue:@"Filter"];
        [filterLabel setAlignment:NSTextAlignmentCenter];
        [filterLabel setBezeled:NO];
        [filterLabel setDrawsBackground:NO];
        [filterLabel setEditable:NO];
        [filterLabel setSelectable:NO];
        [filterLabel setFont:[ClaudeSynthView matrixBoldFontOfSize:14]];
        [filterLabel setTextColor:[ClaudeSynthView matrixBrightGreen]];
        [self addSubview:filterLabel];

        // Filter Cutoff
        cutoffLabel = [[NSTextField alloc] initWithFrame:NSMakeRect(filterX + 30, 420, 120, 16)];
        [cutoffLabel setStringValue:@"Cutoff"];
        [cutoffLabel setAlignment:NSTextAlignmentCenter];
        [cutoffLabel setBezeled:NO];
        [cutoffLabel setDrawsBackground:NO];
        [cutoffLabel setEditable:NO];
        [cutoffLabel setSelectable:NO];
        [cutoffLabel setFont:[ClaudeSynthView matrixFontOfSize:11]];
        [cutoffLabel setTextColor:[ClaudeSynthView matrixMediumGreen]];
        [self addSubview:cutoffLabel];

        cutoffKnob = [[RotaryKnob alloc] initWithFrame:NSMakeRect(filterX + 50, 350, 80, 80)];
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

        cutoffValueDisplay = [[NSTextField alloc] initWithFrame:NSMakeRect(filterX + 30, 330, 120, 16)];
        [cutoffValueDisplay setStringValue:[NSString stringWithFormat:@"%.0f Hz", initialCutoff]];
        [cutoffValueDisplay setAlignment:NSTextAlignmentCenter];
        [cutoffValueDisplay setBezeled:NO];
        [cutoffValueDisplay setDrawsBackground:NO];
        [cutoffValueDisplay setEditable:NO];
        [cutoffValueDisplay setSelectable:NO];
        [cutoffValueDisplay setFont:[ClaudeSynthView matrixFontOfSize:10]];
        [cutoffValueDisplay setTextColor:[ClaudeSynthView matrixCyan]];
        [self addSubview:cutoffValueDisplay];

        // Filter Resonance
        resonanceLabel = [[NSTextField alloc] initWithFrame:NSMakeRect(filterX + 30, 305, 120, 16)];
        [resonanceLabel setStringValue:@"Resonance"];
        [resonanceLabel setAlignment:NSTextAlignmentCenter];
        [resonanceLabel setBezeled:NO];
        [resonanceLabel setDrawsBackground:NO];
        [resonanceLabel setEditable:NO];
        [resonanceLabel setSelectable:NO];
        [resonanceLabel setFont:[ClaudeSynthView matrixFontOfSize:11]];
        [resonanceLabel setTextColor:[ClaudeSynthView matrixMediumGreen]];
        [self addSubview:resonanceLabel];

        resonanceKnob = [[RotaryKnob alloc] initWithFrame:NSMakeRect(filterX + 50, 235, 80, 80)];
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

        resonanceValueDisplay = [[NSTextField alloc] initWithFrame:NSMakeRect(filterX + 30, 215, 120, 16)];
        [resonanceValueDisplay setStringValue:[NSString stringWithFormat:@"Q: %.2f", initialResonance]];
        [resonanceValueDisplay setAlignment:NSTextAlignmentCenter];
        [resonanceValueDisplay setBezeled:NO];
        [resonanceValueDisplay setDrawsBackground:NO];
        [resonanceValueDisplay setEditable:NO];
        [resonanceValueDisplay setSelectable:NO];
        [resonanceValueDisplay setFont:[ClaudeSynthView matrixFontOfSize:10]];
        [resonanceValueDisplay setTextColor:[ClaudeSynthView matrixCyan]];
        [self addSubview:resonanceValueDisplay];

        // ===== ENVELOPE SECTION =====
        envelopeLabel = [[NSTextField alloc] initWithFrame:NSMakeRect(envelopeX + 30, 455, 120, 20)];
        [envelopeLabel setStringValue:@"Envelope"];
        [envelopeLabel setAlignment:NSTextAlignmentCenter];
        [envelopeLabel setBezeled:NO];
        [envelopeLabel setDrawsBackground:NO];
        [envelopeLabel setEditable:NO];
        [envelopeLabel setSelectable:NO];
        [envelopeLabel setFont:[ClaudeSynthView matrixBoldFontOfSize:14]];
        [envelopeLabel setTextColor:[ClaudeSynthView matrixBrightGreen]];
        [self addSubview:envelopeLabel];

        // Get initial envelope values
        AudioUnitParameterValue initialAttack = 0.01f;
        AudioUnitParameterValue initialDecay = 0.1f;
        AudioUnitParameterValue initialSustain = 0.7f;
        AudioUnitParameterValue initialRelease = 0.3f;
        if (mAU) {
            AudioUnitGetParameter(mAU, kParam_EnvAttack, kAudioUnitScope_Global, 0, &initialAttack);
            AudioUnitGetParameter(mAU, kParam_EnvDecay, kAudioUnitScope_Global, 0, &initialDecay);
            AudioUnitGetParameter(mAU, kParam_EnvSustain, kAudioUnitScope_Global, 0, &initialSustain);
            AudioUnitGetParameter(mAU, kParam_EnvRelease, kAudioUnitScope_Global, 0, &initialRelease);
        }

        // Envelope graph
        envelopeView = [[ADSREnvelopeView alloc] initWithFrame:NSMakeRect(envelopeX + 10, 305, 160, 120)];
        [envelopeView setAttack:initialAttack];
        [envelopeView setDecay:initialDecay];
        [envelopeView setSustain:initialSustain];
        [envelopeView setReleaseTime:initialRelease];
        [envelopeView setTarget:self];
        [envelopeView setAction:@selector(envelopeChanged:)];
        [self addSubview:envelopeView];

        // Value displays below the graph
        attackDisplay = [[NSTextField alloc] initWithFrame:NSMakeRect(envelopeX + 10, 285, 40, 16)];
        [attackDisplay setStringValue:[NSString stringWithFormat:@"A:%dms", (int)(initialAttack * 1000)]];
        [attackDisplay setAlignment:NSTextAlignmentLeft];
        [attackDisplay setBezeled:NO];
        [attackDisplay setDrawsBackground:NO];
        [attackDisplay setEditable:NO];
        [attackDisplay setSelectable:NO];
        [attackDisplay setFont:[ClaudeSynthView matrixFontOfSize:9]];
        [attackDisplay setTextColor:[ClaudeSynthView matrixCyan]];
        [self addSubview:attackDisplay];

        decayDisplay = [[NSTextField alloc] initWithFrame:NSMakeRect(envelopeX + 50, 285, 40, 16)];
        [decayDisplay setStringValue:[NSString stringWithFormat:@"D:%dms", (int)(initialDecay * 1000)]];
        [decayDisplay setAlignment:NSTextAlignmentLeft];
        [decayDisplay setBezeled:NO];
        [decayDisplay setDrawsBackground:NO];
        [decayDisplay setEditable:NO];
        [decayDisplay setSelectable:NO];
        [decayDisplay setFont:[ClaudeSynthView matrixFontOfSize:9]];
        [decayDisplay setTextColor:[ClaudeSynthView matrixCyan]];
        [self addSubview:decayDisplay];

        sustainDisplay = [[NSTextField alloc] initWithFrame:NSMakeRect(envelopeX + 90, 285, 40, 16)];
        [sustainDisplay setStringValue:[NSString stringWithFormat:@"S:%.0f%%", initialSustain * 100]];
        [sustainDisplay setAlignment:NSTextAlignmentLeft];
        [sustainDisplay setBezeled:NO];
        [sustainDisplay setDrawsBackground:NO];
        [sustainDisplay setEditable:NO];
        [sustainDisplay setSelectable:NO];
        [sustainDisplay setFont:[ClaudeSynthView matrixFontOfSize:9]];
        [sustainDisplay setTextColor:[ClaudeSynthView matrixCyan]];
        [self addSubview:sustainDisplay];

        releaseDisplay = [[NSTextField alloc] initWithFrame:NSMakeRect(envelopeX + 130, 285, 40, 16)];
        [releaseDisplay setStringValue:[NSString stringWithFormat:@"R:%dms", (int)(initialRelease * 1000)]];
        [releaseDisplay setAlignment:NSTextAlignmentLeft];
        [releaseDisplay setBezeled:NO];
        [releaseDisplay setDrawsBackground:NO];
        [releaseDisplay setEditable:NO];
        [releaseDisplay setSelectable:NO];
        [releaseDisplay setFont:[ClaudeSynthView matrixFontOfSize:9]];
        [releaseDisplay setTextColor:[ClaudeSynthView matrixCyan]];
        [self addSubview:releaseDisplay];

        // ===== FILTER ENVELOPE SECTION =====
        filterEnvelopeLabel = [[NSTextField alloc] initWithFrame:NSMakeRect(filterEnvelopeX + 30, 455, 120, 20)];
        [filterEnvelopeLabel setStringValue:@"Filter Env"];
        [filterEnvelopeLabel setAlignment:NSTextAlignmentCenter];
        [filterEnvelopeLabel setBezeled:NO];
        [filterEnvelopeLabel setDrawsBackground:NO];
        [filterEnvelopeLabel setEditable:NO];
        [filterEnvelopeLabel setSelectable:NO];
        [filterEnvelopeLabel setFont:[ClaudeSynthView matrixBoldFontOfSize:14]];
        [filterEnvelopeLabel setTextColor:[ClaudeSynthView matrixBrightGreen]];
        [self addSubview:filterEnvelopeLabel];

        // Get initial filter envelope values
        AudioUnitParameterValue initialFilterAttack = 0.01f;
        AudioUnitParameterValue initialFilterDecay = 0.1f;
        AudioUnitParameterValue initialFilterSustain = 0.7f;
        AudioUnitParameterValue initialFilterRelease = 0.3f;
        if (mAU) {
            AudioUnitGetParameter(mAU, kParam_FilterEnvAttack, kAudioUnitScope_Global, 0, &initialFilterAttack);
            AudioUnitGetParameter(mAU, kParam_FilterEnvDecay, kAudioUnitScope_Global, 0, &initialFilterDecay);
            AudioUnitGetParameter(mAU, kParam_FilterEnvSustain, kAudioUnitScope_Global, 0, &initialFilterSustain);
            AudioUnitGetParameter(mAU, kParam_FilterEnvRelease, kAudioUnitScope_Global, 0, &initialFilterRelease);
        }

        // Filter envelope graph
        filterEnvelopeView = [[ADSREnvelopeView alloc] initWithFrame:NSMakeRect(filterEnvelopeX + 10, 305, 160, 120)];
        [filterEnvelopeView setAttack:initialFilterAttack];
        [filterEnvelopeView setDecay:initialFilterDecay];
        [filterEnvelopeView setSustain:initialFilterSustain];
        [filterEnvelopeView setReleaseTime:initialFilterRelease];
        [filterEnvelopeView setTarget:self];
        [filterEnvelopeView setAction:@selector(filterEnvelopeChanged:)];
        [self addSubview:filterEnvelopeView];

        // Value displays below the graph
        filterAttackDisplay = [[NSTextField alloc] initWithFrame:NSMakeRect(filterEnvelopeX + 10, 285, 40, 16)];
        [filterAttackDisplay setStringValue:[NSString stringWithFormat:@"A:%dms", (int)(initialFilterAttack * 1000)]];
        [filterAttackDisplay setAlignment:NSTextAlignmentLeft];
        [filterAttackDisplay setBezeled:NO];
        [filterAttackDisplay setDrawsBackground:NO];
        [filterAttackDisplay setEditable:NO];
        [filterAttackDisplay setSelectable:NO];
        [filterAttackDisplay setFont:[ClaudeSynthView matrixFontOfSize:9]];
        [filterAttackDisplay setTextColor:[ClaudeSynthView matrixCyan]];
        [self addSubview:filterAttackDisplay];

        filterDecayDisplay = [[NSTextField alloc] initWithFrame:NSMakeRect(filterEnvelopeX + 50, 285, 40, 16)];
        [filterDecayDisplay setStringValue:[NSString stringWithFormat:@"D:%dms", (int)(initialFilterDecay * 1000)]];
        [filterDecayDisplay setAlignment:NSTextAlignmentLeft];
        [filterDecayDisplay setBezeled:NO];
        [filterDecayDisplay setDrawsBackground:NO];
        [filterDecayDisplay setEditable:NO];
        [filterDecayDisplay setSelectable:NO];
        [filterDecayDisplay setFont:[ClaudeSynthView matrixFontOfSize:9]];
        [filterDecayDisplay setTextColor:[ClaudeSynthView matrixCyan]];
        [self addSubview:filterDecayDisplay];

        filterSustainDisplay = [[NSTextField alloc] initWithFrame:NSMakeRect(filterEnvelopeX + 90, 285, 40, 16)];
        [filterSustainDisplay setStringValue:[NSString stringWithFormat:@"S:%.0f%%", initialFilterSustain * 100]];
        [filterSustainDisplay setAlignment:NSTextAlignmentLeft];
        [filterSustainDisplay setBezeled:NO];
        [filterSustainDisplay setDrawsBackground:NO];
        [filterSustainDisplay setEditable:NO];
        [filterSustainDisplay setSelectable:NO];
        [filterSustainDisplay setFont:[ClaudeSynthView matrixFontOfSize:9]];
        [filterSustainDisplay setTextColor:[ClaudeSynthView matrixCyan]];
        [self addSubview:filterSustainDisplay];

        filterReleaseDisplay = [[NSTextField alloc] initWithFrame:NSMakeRect(filterEnvelopeX + 130, 285, 40, 16)];
        [filterReleaseDisplay setStringValue:[NSString stringWithFormat:@"R:%dms", (int)(initialFilterRelease * 1000)]];
        [filterReleaseDisplay setAlignment:NSTextAlignmentLeft];
        [filterReleaseDisplay setBezeled:NO];
        [filterReleaseDisplay setDrawsBackground:NO];
        [filterReleaseDisplay setEditable:NO];
        [filterReleaseDisplay setSelectable:NO];
        [filterReleaseDisplay setFont:[ClaudeSynthView matrixFontOfSize:9]];
        [filterReleaseDisplay setTextColor:[ClaudeSynthView matrixCyan]];
        [self addSubview:filterReleaseDisplay];

        // ===== MASTER VOLUME SECTION =====
        masterVolumeLabel = [[NSTextField alloc] initWithFrame:NSMakeRect(masterX + 30, 455, 120, 20)];
        [masterVolumeLabel setStringValue:@"Master"];
        [masterVolumeLabel setAlignment:NSTextAlignmentCenter];
        [masterVolumeLabel setBezeled:NO];
        [masterVolumeLabel setDrawsBackground:NO];
        [masterVolumeLabel setEditable:NO];
        [masterVolumeLabel setSelectable:NO];
        [masterVolumeLabel setFont:[ClaudeSynthView matrixBoldFontOfSize:14]];
        [masterVolumeLabel setTextColor:[ClaudeSynthView matrixBrightGreen]];
        [self addSubview:masterVolumeLabel];

        NSTextField *volumeSubLabel = [[NSTextField alloc] initWithFrame:NSMakeRect(masterX + 30, 420, 120, 16)];
        [volumeSubLabel setStringValue:@"Volume"];
        [volumeSubLabel setAlignment:NSTextAlignmentCenter];
        [volumeSubLabel setBezeled:NO];
        [volumeSubLabel setDrawsBackground:NO];
        [volumeSubLabel setEditable:NO];
        [volumeSubLabel setSelectable:NO];
        [volumeSubLabel setFont:[ClaudeSynthView matrixFontOfSize:11]];
        [volumeSubLabel setTextColor:[ClaudeSynthView matrixMediumGreen]];
        [self addSubview:volumeSubLabel];

        masterVolumeKnob = [[RotaryKnob alloc] initWithFrame:NSMakeRect(masterX + 50, 350, 80, 80)];
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

        masterVolumeDisplay = [[NSTextField alloc] initWithFrame:NSMakeRect(masterX + 30, 330, 120, 20)];
        [masterVolumeDisplay setStringValue:[NSString stringWithFormat:@"%.0f%%", initialMasterVolume * 100.0]];
        [masterVolumeDisplay setAlignment:NSTextAlignmentCenter];
        [masterVolumeDisplay setBezeled:NO];
        [masterVolumeDisplay setDrawsBackground:NO];
        [masterVolumeDisplay setEditable:NO];
        [masterVolumeDisplay setSelectable:NO];
        [masterVolumeDisplay setFont:[ClaudeSynthView matrixBoldFontOfSize:14]];
        [masterVolumeDisplay setTextColor:[ClaudeSynthView matrixBrightGreen]];
        [self addSubview:masterVolumeDisplay];

        // ===== MODULATION MATRIX SECTION =====
        [self createModulationMatrixSection];

        // ===== EFFECTS SECTION =====
        // Place in bottom section, to the right of modulation matrix
        int effectsX = 600;
        int effectsY = 10;

        // Section label
        NSTextField *effectsLabel = [[NSTextField alloc] initWithFrame:NSMakeRect(effectsX + 50, effectsY + 152, 200, 20)];
        [effectsLabel setStringValue:@"Effects"];
        [effectsLabel setAlignment:NSTextAlignmentCenter];
        [effectsLabel setBezeled:NO];
        [effectsLabel setDrawsBackground:NO];
        [effectsLabel setEditable:NO];
        [effectsLabel setSelectable:NO];
        [effectsLabel setFont:[ClaudeSynthView matrixBoldFontOfSize:14]];
        [effectsLabel setTextColor:[ClaudeSynthView matrixBrightGreen]];
        [self addSubview:effectsLabel];

        // Effect Type selector
        NSTextField *effectTypeLabel = [[NSTextField alloc] initWithFrame:NSMakeRect(effectsX + 50, effectsY + 135, 200, 16)];
        [effectTypeLabel setStringValue:@"Effect Type"];
        [effectTypeLabel setAlignment:NSTextAlignmentCenter];
        [effectTypeLabel setBezeled:NO];
        [effectTypeLabel setDrawsBackground:NO];
        [effectTypeLabel setEditable:NO];
        [effectTypeLabel setSelectable:NO];
        [effectTypeLabel setFont:[ClaudeSynthView matrixFontOfSize:11]];
        [effectTypeLabel setTextColor:[ClaudeSynthView matrixMediumGreen]];
        [self addSubview:effectTypeLabel];

        effectTypePopup = [[MatrixDropdown alloc] initWithFrame:NSMakeRect(effectsX + 70, effectsY + 110, 160, 25)];
        [effectTypePopup addItemWithTitle:@"None"];
        [effectTypePopup addItemWithTitle:@"Chorus"];
        [effectTypePopup addItemWithTitle:@"Phaser"];
        [effectTypePopup addItemWithTitle:@"Flanger"];
        [effectTypePopup setTarget:self];
        [effectTypePopup setAction:@selector(effectTypeChanged:)];

        AudioUnitParameterValue initialEffectType = 0.0f;
        if (mAU) {
            AudioUnitGetParameter(mAU, kParam_EffectType, kAudioUnitScope_Global, 0, &initialEffectType);
        }
        [effectTypePopup selectItemAtIndex:(int)initialEffectType];
        [self addSubview:effectTypePopup];

        // Rate knob
        NSTextField *rateLabel = [[NSTextField alloc] initWithFrame:NSMakeRect(effectsX + 20, effectsY + 75, 80, 16)];
        [rateLabel setStringValue:@"Rate"];
        [rateLabel setAlignment:NSTextAlignmentCenter];
        [rateLabel setBezeled:NO];
        [rateLabel setDrawsBackground:NO];
        [rateLabel setEditable:NO];
        [rateLabel setSelectable:NO];
        [rateLabel setFont:[ClaudeSynthView matrixFontOfSize:11]];
        [rateLabel setTextColor:[ClaudeSynthView matrixMediumGreen]];
        [self addSubview:rateLabel];

        effectRateKnob = [[RotaryKnob alloc] initWithFrame:NSMakeRect(effectsX + 35, effectsY + 25, 50, 50)];
        [effectRateKnob setMinValue:0.1];
        [effectRateKnob setMaxValue:10.0];

        AudioUnitParameterValue initialRate = 1.0f;
        if (mAU) {
            AudioUnitGetParameter(mAU, kParam_EffectRate, kAudioUnitScope_Global, 0, &initialRate);
        }
        [effectRateKnob setDoubleValue:initialRate];
        [effectRateKnob setTarget:self];
        [effectRateKnob setAction:@selector(effectRateChanged:)];
        [effectRateKnob setContinuous:YES];
        [self addSubview:effectRateKnob];

        effectRateDisplay = [[NSTextField alloc] initWithFrame:NSMakeRect(effectsX + 20, effectsY + 5, 80, 16)];
        [effectRateDisplay setStringValue:[NSString stringWithFormat:@"%.1f Hz", initialRate]];
        [effectRateDisplay setAlignment:NSTextAlignmentCenter];
        [effectRateDisplay setBezeled:NO];
        [effectRateDisplay setDrawsBackground:NO];
        [effectRateDisplay setEditable:NO];
        [effectRateDisplay setSelectable:NO];
        [effectRateDisplay setFont:[ClaudeSynthView matrixFontOfSize:10]];
        [effectRateDisplay setTextColor:[ClaudeSynthView matrixCyan]];
        [self addSubview:effectRateDisplay];

        // Intensity knob
        NSTextField *intensityLabel = [[NSTextField alloc] initWithFrame:NSMakeRect(effectsX + 160, effectsY + 75, 80, 16)];
        [intensityLabel setStringValue:@"Intensity"];
        [intensityLabel setAlignment:NSTextAlignmentCenter];
        [intensityLabel setBezeled:NO];
        [intensityLabel setDrawsBackground:NO];
        [intensityLabel setEditable:NO];
        [intensityLabel setSelectable:NO];
        [intensityLabel setFont:[ClaudeSynthView matrixFontOfSize:11]];
        [intensityLabel setTextColor:[ClaudeSynthView matrixMediumGreen]];
        [self addSubview:intensityLabel];

        effectIntensityKnob = [[RotaryKnob alloc] initWithFrame:NSMakeRect(effectsX + 175, effectsY + 25, 50, 50)];
        [effectIntensityKnob setMinValue:0.0];
        [effectIntensityKnob setMaxValue:1.0];

        AudioUnitParameterValue initialIntensity = 0.5f;
        if (mAU) {
            AudioUnitGetParameter(mAU, kParam_EffectIntensity, kAudioUnitScope_Global, 0, &initialIntensity);
        }
        [effectIntensityKnob setDoubleValue:initialIntensity];
        [effectIntensityKnob setTarget:self];
        [effectIntensityKnob setAction:@selector(effectIntensityChanged:)];
        [effectIntensityKnob setContinuous:YES];
        [self addSubview:effectIntensityKnob];

        effectIntensityDisplay = [[NSTextField alloc] initWithFrame:NSMakeRect(effectsX + 160, effectsY + 5, 80, 16)];
        [effectIntensityDisplay setStringValue:[NSString stringWithFormat:@"%.0f%%", initialIntensity * 100.0]];
        [effectIntensityDisplay setAlignment:NSTextAlignmentCenter];
        [effectIntensityDisplay setBezeled:NO];
        [effectIntensityDisplay setDrawsBackground:NO];
        [effectIntensityDisplay setEditable:NO];
        [effectIntensityDisplay setSelectable:NO];
        [effectIntensityDisplay setFont:[ClaudeSynthView matrixFontOfSize:10]];
        [effectIntensityDisplay setTextColor:[ClaudeSynthView matrixCyan]];
        [self addSubview:effectIntensityDisplay];

        // ===== ARPEGGIATOR SECTION =====
        int arpX = 850;
        int arpY = 10;

        // Section label
        NSTextField *arpLabel = [[NSTextField alloc] initWithFrame:NSMakeRect(arpX + 70, arpY + 152, 200, 20)];
        [arpLabel setStringValue:@"Arpeggiator"];
        [arpLabel setAlignment:NSTextAlignmentCenter];
        [arpLabel setBezeled:NO];
        [arpLabel setDrawsBackground:NO];
        [arpLabel setEditable:NO];
        [arpLabel setSelectable:NO];
        [arpLabel setFont:[ClaudeSynthView matrixBoldFontOfSize:14]];
        [arpLabel setTextColor:[ClaudeSynthView matrixBrightGreen]];
        [self addSubview:arpLabel];

        // Enable button
        arpEnableButton = [[MatrixCheckbox alloc] initWithFrame:NSMakeRect(arpX + 130, arpY + 130, 80, 20)];
        [arpEnableButton setTitle:@"Enable"];
        AudioUnitParameterValue initialArpEnable = 0.0f;
        if (mAU) {
            AudioUnitGetParameter(mAU, kParam_ArpEnable, kAudioUnitScope_Global, 0, &initialArpEnable);
        }
        [arpEnableButton setState:(initialArpEnable > 0.5f) ? NSControlStateValueOn : NSControlStateValueOff];
        [arpEnableButton setTarget:self];
        [arpEnableButton setAction:@selector(arpEnableChanged:)];
        [self addSubview:arpEnableButton];

        // Rate popup
        NSTextField *rateLabel2 = [[NSTextField alloc] initWithFrame:NSMakeRect(arpX + 10, arpY + 105, 80, 16)];
        [rateLabel2 setStringValue:@"Rate"];
        [rateLabel2 setAlignment:NSTextAlignmentCenter];
        [rateLabel2 setBezeled:NO];
        [rateLabel2 setDrawsBackground:NO];
        [rateLabel2 setEditable:NO];
        [rateLabel2 setSelectable:NO];
        [rateLabel2 setFont:[ClaudeSynthView matrixFontOfSize:11]];
        [rateLabel2 setTextColor:[ClaudeSynthView matrixMediumGreen]];
        [self addSubview:rateLabel2];

        arpRatePopup = [[MatrixDropdown alloc] initWithFrame:NSMakeRect(arpX + 10, arpY + 80, 80, 25)];
        [arpRatePopup addItemWithTitle:@"1/4"];
        [arpRatePopup addItemWithTitle:@"1/8"];
        [arpRatePopup addItemWithTitle:@"1/16"];
        [arpRatePopup addItemWithTitle:@"1/32"];
        AudioUnitParameterValue initialArpRate = 1.0f;
        if (mAU) {
            AudioUnitGetParameter(mAU, kParam_ArpRate, kAudioUnitScope_Global, 0, &initialArpRate);
        }
        [arpRatePopup selectItemAtIndex:(int)initialArpRate];
        [arpRatePopup setTarget:self];
        [arpRatePopup setAction:@selector(arpRateChanged:)];
        [self addSubview:arpRatePopup];

        // Mode popup
        NSTextField *modeLabel = [[NSTextField alloc] initWithFrame:NSMakeRect(arpX + 110, arpY + 105, 80, 16)];
        [modeLabel setStringValue:@"Mode"];
        [modeLabel setAlignment:NSTextAlignmentCenter];
        [modeLabel setBezeled:NO];
        [modeLabel setDrawsBackground:NO];
        [modeLabel setEditable:NO];
        [modeLabel setSelectable:NO];
        [modeLabel setFont:[ClaudeSynthView matrixFontOfSize:11]];
        [modeLabel setTextColor:[ClaudeSynthView matrixMediumGreen]];
        [self addSubview:modeLabel];

        arpModePopup = [[MatrixDropdown alloc] initWithFrame:NSMakeRect(arpX + 110, arpY + 80, 90, 25)];
        [arpModePopup addItemWithTitle:@"Up"];
        [arpModePopup addItemWithTitle:@"Down"];
        [arpModePopup addItemWithTitle:@"Up/Down"];
        [arpModePopup addItemWithTitle:@"Random"];
        AudioUnitParameterValue initialArpMode = 0.0f;
        if (mAU) {
            AudioUnitGetParameter(mAU, kParam_ArpMode, kAudioUnitScope_Global, 0, &initialArpMode);
        }
        [arpModePopup selectItemAtIndex:(int)initialArpMode];
        [arpModePopup setTarget:self];
        [arpModePopup setAction:@selector(arpModeChanged:)];
        [self addSubview:arpModePopup];

        // Octaves popup
        NSTextField *octavesLabel = [[NSTextField alloc] initWithFrame:NSMakeRect(arpX + 220, arpY + 105, 80, 16)];
        [octavesLabel setStringValue:@"Octaves"];
        [octavesLabel setAlignment:NSTextAlignmentCenter];
        [octavesLabel setBezeled:NO];
        [octavesLabel setDrawsBackground:NO];
        [octavesLabel setEditable:NO];
        [octavesLabel setSelectable:NO];
        [octavesLabel setFont:[ClaudeSynthView matrixFontOfSize:11]];
        [octavesLabel setTextColor:[ClaudeSynthView matrixMediumGreen]];
        [self addSubview:octavesLabel];

        arpOctavesPopup = [[MatrixDropdown alloc] initWithFrame:NSMakeRect(arpX + 230, arpY + 80, 60, 25)];
        [arpOctavesPopup addItemWithTitle:@"1"];
        [arpOctavesPopup addItemWithTitle:@"2"];
        [arpOctavesPopup addItemWithTitle:@"3"];
        [arpOctavesPopup addItemWithTitle:@"4"];
        AudioUnitParameterValue initialArpOctaves = 1.0f;
        if (mAU) {
            AudioUnitGetParameter(mAU, kParam_ArpOctaves, kAudioUnitScope_Global, 0, &initialArpOctaves);
        }
        [arpOctavesPopup selectItemAtIndex:(int)initialArpOctaves - 1];
        [arpOctavesPopup setTarget:self];
        [arpOctavesPopup setAction:@selector(arpOctavesChanged:)];
        [self addSubview:arpOctavesPopup];

        // Gate knob
        NSTextField *gateLabel = [[NSTextField alloc] initWithFrame:NSMakeRect(arpX + 130, arpY + 50, 80, 16)];
        [gateLabel setStringValue:@"Gate"];
        [gateLabel setAlignment:NSTextAlignmentCenter];
        [gateLabel setBezeled:NO];
        [gateLabel setDrawsBackground:NO];
        [gateLabel setEditable:NO];
        [gateLabel setSelectable:NO];
        [gateLabel setFont:[ClaudeSynthView matrixFontOfSize:11]];
        [gateLabel setTextColor:[ClaudeSynthView matrixMediumGreen]];
        [self addSubview:gateLabel];

        arpGateKnob = [[RotaryKnob alloc] initWithFrame:NSMakeRect(arpX + 145, arpY, 50, 50)];
        [arpGateKnob setMinValue:0.1];
        [arpGateKnob setMaxValue:1.0];
        AudioUnitParameterValue initialArpGate = 0.9f;
        if (mAU) {
            AudioUnitGetParameter(mAU, kParam_ArpGate, kAudioUnitScope_Global, 0, &initialArpGate);
        }
        [arpGateKnob setDoubleValue:initialArpGate];
        [arpGateKnob setTarget:self];
        [arpGateKnob setAction:@selector(arpGateChanged:)];
        [arpGateKnob setContinuous:YES];
        [self addSubview:arpGateKnob];

        arpGateDisplay = [[NSTextField alloc] initWithFrame:NSMakeRect(arpX + 130, arpY - 20, 80, 16)];
        [arpGateDisplay setStringValue:[NSString stringWithFormat:@"%.0f%%", initialArpGate * 100.0]];
        [arpGateDisplay setAlignment:NSTextAlignmentCenter];
        [arpGateDisplay setBezeled:NO];
        [arpGateDisplay setDrawsBackground:NO];
        [arpGateDisplay setEditable:NO];
        [arpGateDisplay setSelectable:NO];
        [arpGateDisplay setFont:[ClaudeSynthView matrixFontOfSize:10]];
        [arpGateDisplay setTextColor:[ClaudeSynthView matrixCyan]];
        [self addSubview:arpGateDisplay];

        // ===== OSCILLOSCOPE =====
        // Position in bottom right corner
        oscilloscope = [[MatrixOscilloscope alloc] initWithFrame:NSMakeRect(1150, 10, 280, 150)];
        [self addSubview:oscilloscope];

        // Set oscilloscope pointer in audio unit
        void *oscopePtr = (__bridge void *)oscilloscope;
        AudioUnitSetProperty(mAU, kClaudeSynthProperty_Oscilloscope, kAudioUnitScope_Global, 0, &oscopePtr, sizeof(void *));

        // Start timer to poll for host automation updates
        updateTimer = [NSTimer scheduledTimerWithTimeInterval:0.1
                                                       target:self
                                                     selector:@selector(updateFromHost:)
                                                     userInfo:nil
                                                      repeats:YES];
    }
    return self;
}

- (void)addWaveformIconsAtX:(int)x baseY:(int)baseY {
    CGFloat iconWidth = 25.0;
    CGFloat iconHeight = 12.0;
    CGFloat spacing = 20.0; // Vertical spacing between icons

    // Add 4 waveform icons (Sine, Square, Sawtooth, Triangle)
    for (int i = 0; i < 4; i++) {
        CGFloat yPos = baseY + (i * spacing) - (iconHeight / 2.0);

        WaveformIconView *iconView = [[WaveformIconView alloc] initWithFrame:NSMakeRect(x, yPos, iconWidth, iconHeight)];
        iconView.waveformType = i;
        [self addSubview:iconView];
    }
}

- (void)createOscillatorSection:(int)oscNum atX:(int)x {
    NSTextField *label, *waveLabel, *octaveLabel, *octaveDisplay, *detuneLabel, *detuneDisplay, *volumeLabel, *volumeDisplay;
    MatrixSlider *waveKnob;
    RotaryKnob *octaveKnob, *detuneKnob, *volumeKnob;

    // Section label
    label = [[NSTextField alloc] initWithFrame:NSMakeRect(x + 30, 455, 120, 20)];
    [label setStringValue:[NSString stringWithFormat:@"Osc %d", oscNum]];
    [label setAlignment:NSTextAlignmentCenter];
    [label setBezeled:NO];
    [label setDrawsBackground:NO];
    [label setEditable:NO];
    [label setSelectable:NO];
    [label setFont:[ClaudeSynthView matrixBoldFontOfSize:14]];
    [label setTextColor:[ClaudeSynthView matrixBrightGreen]];
    [self addSubview:label];

    // Waveform section (left side)
    waveLabel = [[NSTextField alloc] initWithFrame:NSMakeRect(x + 10, 420, 70, 16)];
    [waveLabel setStringValue:@"Waveform"];
    [waveLabel setAlignment:NSTextAlignmentCenter];
    [waveLabel setBezeled:NO];
    [waveLabel setDrawsBackground:NO];
    [waveLabel setEditable:NO];
    [waveLabel setSelectable:NO];
    [waveLabel setFont:[ClaudeSynthView matrixFontOfSize:10]];
    [waveLabel setTextColor:[ClaudeSynthView matrixMediumGreen]];
    [self addSubview:waveLabel];

    // Add waveform icons
    [self addWaveformIconsAtX:x + 15 baseY:350];

    // Vertical slider (right of icons)
    waveKnob = [[MatrixSlider alloc] initWithFrame:NSMakeRect(x + 45, 350, 20, 60)];
    [waveKnob setMinValue:0];
    [waveKnob setMaxValue:3];
    [waveKnob setNumberOfTickMarks:4];

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
    [waveKnob setContinuous:YES];
    [self addSubview:waveKnob];

    // Octave section (right side, next to waveform)
    octaveLabel = [[NSTextField alloc] initWithFrame:NSMakeRect(x + 85, 420, 80, 16)];
    [octaveLabel setStringValue:@"Octave"];
    [octaveLabel setAlignment:NSTextAlignmentCenter];
    [octaveLabel setBezeled:NO];
    [octaveLabel setDrawsBackground:NO];
    [octaveLabel setEditable:NO];
    [octaveLabel setSelectable:NO];
    [octaveLabel setFont:[ClaudeSynthView matrixFontOfSize:10]];
    [octaveLabel setTextColor:[ClaudeSynthView matrixMediumGreen]];
    [self addSubview:octaveLabel];

    octaveKnob = [[RotaryKnob alloc] initWithFrame:NSMakeRect(x + 100, 355, 50, 50)];
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

    octaveDisplay = [[NSTextField alloc] initWithFrame:NSMakeRect(x + 85, 335, 80, 16)];
    int octaveInt = (int)round(initialOctave);
    [octaveDisplay setStringValue:[NSString stringWithFormat:@"%+d", octaveInt]];
    [octaveDisplay setAlignment:NSTextAlignmentCenter];
    [octaveDisplay setBezeled:NO];
    [octaveDisplay setDrawsBackground:NO];
    [octaveDisplay setEditable:NO];
    [octaveDisplay setSelectable:NO];
    [octaveDisplay setFont:[ClaudeSynthView matrixFontOfSize:10]];
    [octaveDisplay setTextColor:[ClaudeSynthView matrixCyan]];
    [self addSubview:octaveDisplay];

    // Detune (bottom left)
    detuneLabel = [[NSTextField alloc] initWithFrame:NSMakeRect(x + 15, 300, 60, 16)];
    [detuneLabel setStringValue:@"Detune"];
    [detuneLabel setAlignment:NSTextAlignmentCenter];
    [detuneLabel setBezeled:NO];
    [detuneLabel setDrawsBackground:NO];
    [detuneLabel setEditable:NO];
    [detuneLabel setSelectable:NO];
    [detuneLabel setFont:[ClaudeSynthView matrixFontOfSize:10]];
    [detuneLabel setTextColor:[ClaudeSynthView matrixMediumGreen]];
    [self addSubview:detuneLabel];

    detuneKnob = [[RotaryKnob alloc] initWithFrame:NSMakeRect(x + 20, 245, 50, 50)];
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

    detuneDisplay = [[NSTextField alloc] initWithFrame:NSMakeRect(x + 15, 225, 60, 16)];
    [detuneDisplay setStringValue:[NSString stringWithFormat:@"%+.0fc", initialDetune]];
    [detuneDisplay setAlignment:NSTextAlignmentCenter];
    [detuneDisplay setBezeled:NO];
    [detuneDisplay setDrawsBackground:NO];
    [detuneDisplay setEditable:NO];
    [detuneDisplay setSelectable:NO];
    [detuneDisplay setFont:[ClaudeSynthView matrixFontOfSize:9]];
    [detuneDisplay setTextColor:[ClaudeSynthView matrixCyan]];
    [self addSubview:detuneDisplay];

    // Volume (bottom right)
    volumeLabel = [[NSTextField alloc] initWithFrame:NSMakeRect(x + 95, 300, 60, 16)];
    [volumeLabel setStringValue:@"Volume"];
    [volumeLabel setAlignment:NSTextAlignmentCenter];
    [volumeLabel setBezeled:NO];
    [volumeLabel setDrawsBackground:NO];
    [volumeLabel setEditable:NO];
    [volumeLabel setSelectable:NO];
    [volumeLabel setFont:[ClaudeSynthView matrixFontOfSize:10]];
    [volumeLabel setTextColor:[ClaudeSynthView matrixMediumGreen]];
    [self addSubview:volumeLabel];

    volumeKnob = [[RotaryKnob alloc] initWithFrame:NSMakeRect(x + 100, 245, 50, 50)];
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

    volumeDisplay = [[NSTextField alloc] initWithFrame:NSMakeRect(x + 95, 225, 60, 16)];
    [volumeDisplay setStringValue:[NSString stringWithFormat:@"%.0f%%", initialVolume * 100.0]];
    [volumeDisplay setAlignment:NSTextAlignmentCenter];
    [volumeDisplay setBezeled:NO];
    [volumeDisplay setDrawsBackground:NO];
    [volumeDisplay setEditable:NO];
    [volumeDisplay setSelectable:NO];
    [volumeDisplay setFont:[ClaudeSynthView matrixFontOfSize:9]];
    [volumeDisplay setTextColor:[ClaudeSynthView matrixCyan]];
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

- (void)createLFOSectionAtX:(int)x lfoNum:(int)lfoNum {
    // Section label
    NSTextField *label = [[NSTextField alloc] initWithFrame:NSMakeRect(x, 455, 90, 20)];
    [label setStringValue:[NSString stringWithFormat:@"LFO %d", lfoNum]];
    [label setAlignment:NSTextAlignmentCenter];
    [label setBezeled:NO];
    [label setDrawsBackground:NO];
    [label setEditable:NO];
    [label setSelectable:NO];
    [label setFont:[ClaudeSynthView matrixBoldFontOfSize:12]];
    [label setTextColor:[ClaudeSynthView matrixBrightGreen]];
    [self addSubview:label];

    // Waveform selector
    NSTextField *waveformLabel = [[NSTextField alloc] initWithFrame:NSMakeRect(x + 5, 420, 80, 16)];
    [waveformLabel setStringValue:@"Waveform"];
    [waveformLabel setAlignment:NSTextAlignmentCenter];
    [waveformLabel setBezeled:NO];
    [waveformLabel setDrawsBackground:NO];
    [waveformLabel setEditable:NO];
    [waveformLabel setSelectable:NO];
    [waveformLabel setFont:[ClaudeSynthView matrixFontOfSize:10]];
    [waveformLabel setTextColor:[ClaudeSynthView matrixMediumGreen]];
    [self addSubview:waveformLabel];

    // Add small waveform icons
    CGFloat iconWidth = 20.0;
    CGFloat iconHeight = 10.0;
    CGFloat spacing = 15.0;
    for (int i = 0; i < 4; i++) {
        CGFloat yPos = 370 + (i * spacing);
        WaveformIconView *iconView = [[WaveformIconView alloc] initWithFrame:NSMakeRect(x + 10, yPos, iconWidth, iconHeight)];
        iconView.waveformType = i;
        [self addSubview:iconView];
    }

    MatrixSlider *waveformKnob = [[MatrixSlider alloc] initWithFrame:NSMakeRect(x + 35, 370, 20, 45)];
    [waveformKnob setMinValue:0];
    [waveformKnob setMaxValue:3];
    [waveformKnob setNumberOfTickMarks:4];

    AudioUnitParameterID waveformParamID = (lfoNum == 1) ? kParam_LFO1_Waveform : kParam_LFO2_Waveform;
    AudioUnitParameterValue initialWaveform = 0.0f;
    if (mAU) {
        AudioUnitGetParameter(mAU, waveformParamID, kAudioUnitScope_Global, 0, &initialWaveform);
    }
    [waveformKnob setIntValue:(int)initialWaveform];
    [waveformKnob setTarget:self];
    if (lfoNum == 1) {
        [waveformKnob setAction:@selector(lfo1WaveformChanged:)];
        lfoWaveformKnob = waveformKnob;
    } else {
        [waveformKnob setAction:@selector(lfo2WaveformChanged:)];
        lfo2WaveformKnob = waveformKnob;
    }
    [waveformKnob setContinuous:YES];
    [self addSubview:waveformKnob];

    // Rate knob
    NSTextField *rateLabel = [[NSTextField alloc] initWithFrame:NSMakeRect(x + 5, 335, 35, 16)];
    [rateLabel setStringValue:@"Rate"];
    [rateLabel setAlignment:NSTextAlignmentLeft];
    [rateLabel setBezeled:NO];
    [rateLabel setDrawsBackground:NO];
    [rateLabel setEditable:NO];
    [rateLabel setSelectable:NO];
    [rateLabel setFont:[ClaudeSynthView matrixFontOfSize:10]];
    [rateLabel setTextColor:[ClaudeSynthView matrixMediumGreen]];
    [self addSubview:rateLabel];

    RotaryKnob *rateKnob = [[RotaryKnob alloc] initWithFrame:NSMakeRect(x + 20, 275, 50, 50)];
    [rateKnob setMinValue:0.1];
    [rateKnob setMaxValue:20.0];

    AudioUnitParameterID rateParamID = (lfoNum == 1) ? kParam_LFO1_Rate : kParam_LFO2_Rate;
    AudioUnitParameterValue initialRate = (lfoNum == 1) ? 5.0f : 3.0f;
    if (mAU) {
        AudioUnitGetParameter(mAU, rateParamID, kAudioUnitScope_Global, 0, &initialRate);
    }
    [rateKnob setDoubleValue:initialRate];
    [rateKnob setTarget:self];

    NSTextField *rateDisplay = [[NSTextField alloc] initWithFrame:NSMakeRect(x + 5, 255, 80, 16)];
    [rateDisplay setStringValue:[NSString stringWithFormat:@"%.1f Hz", initialRate]];
    [rateDisplay setAlignment:NSTextAlignmentCenter];
    [rateDisplay setBezeled:NO];
    [rateDisplay setDrawsBackground:NO];
    [rateDisplay setEditable:NO];
    [rateDisplay setSelectable:NO];
    [rateDisplay setFont:[ClaudeSynthView matrixFontOfSize:10]];
    [rateDisplay setTextColor:[ClaudeSynthView matrixCyan]];
    [self addSubview:rateDisplay];

    if (lfoNum == 1) {
        [rateKnob setAction:@selector(lfo1RateChanged:)];
        lfoRateKnob = rateKnob;
        lfoRateDisplay = rateDisplay;
    } else {
        [rateKnob setAction:@selector(lfo2RateChanged:)];
        lfo2RateKnob = rateKnob;
        lfo2RateDisplay = rateDisplay;
    }
    [rateKnob setContinuous:YES];
    [self addSubview:rateKnob];

    // Tempo sync checkbox
    MatrixCheckbox *tempoSyncCheckbox = [[MatrixCheckbox alloc] initWithFrame:NSMakeRect(x + 5, 230, 80, 18)];
    [tempoSyncCheckbox setTitle:@"Sync"];

    AudioUnitParameterID tempoSyncParamID = (lfoNum == 1) ? kParam_LFO1_TempoSync : kParam_LFO2_TempoSync;
    AudioUnitParameterValue initialTempoSync = 0.0f;
    if (mAU) {
        AudioUnitGetParameter(mAU, tempoSyncParamID, kAudioUnitScope_Global, 0, &initialTempoSync);
    }
    [tempoSyncCheckbox setState:(initialTempoSync > 0.5f) ? NSControlStateValueOn : NSControlStateValueOff];
    [tempoSyncCheckbox setTarget:self];

    // Note division dropdown
    MatrixDropdown *noteDivisionDropdown = [[MatrixDropdown alloc] initWithFrame:NSMakeRect(x + 5, 205, 80, 20)];
    [noteDivisionDropdown addItemWithTitle:@"1/32"];
    [noteDivisionDropdown addItemWithTitle:@"1/16"];
    [noteDivisionDropdown addItemWithTitle:@"1/8"];
    [noteDivisionDropdown addItemWithTitle:@"1/4"];
    [noteDivisionDropdown addItemWithTitle:@"1/2"];
    [noteDivisionDropdown addItemWithTitle:@"1/1"];
    [noteDivisionDropdown addItemWithTitle:@"1/32T"];
    [noteDivisionDropdown addItemWithTitle:@"1/16T"];
    [noteDivisionDropdown addItemWithTitle:@"1/8T"];
    [noteDivisionDropdown addItemWithTitle:@"1/4T"];
    [noteDivisionDropdown addItemWithTitle:@"1/2T"];
    [noteDivisionDropdown addItemWithTitle:@"1/16."];
    [noteDivisionDropdown addItemWithTitle:@"1/8."];
    [noteDivisionDropdown addItemWithTitle:@"1/4."];
    [noteDivisionDropdown addItemWithTitle:@"1/2."];

    AudioUnitParameterID noteDivisionParamID = (lfoNum == 1) ? kParam_LFO1_NoteDivision : kParam_LFO2_NoteDivision;
    AudioUnitParameterValue initialNoteDivision = 2.0f;  // 1/8 note
    if (mAU) {
        AudioUnitGetParameter(mAU, noteDivisionParamID, kAudioUnitScope_Global, 0, &initialNoteDivision);
    }
    [noteDivisionDropdown selectItemAtIndex:(int)initialNoteDivision];
    [noteDivisionDropdown setTarget:self];

    // LED indicator (next to Rate label)
    MatrixLED *led = [[MatrixLED alloc] initWithFrame:NSMakeRect(x + 42, 337, 12, 12)];
    [self addSubview:led];

    // Initially hide note division dropdown if tempo sync is off
    [noteDivisionDropdown setHidden:(initialTempoSync < 0.5f)];

    if (lfoNum == 1) {
        [tempoSyncCheckbox setAction:@selector(lfo1TempoSyncChanged:)];
        [noteDivisionDropdown setAction:@selector(lfo1NoteDivisionChanged:)];
        lfo1TempoSyncCheckbox = tempoSyncCheckbox;
        lfo1NoteDivisionDropdown = noteDivisionDropdown;
        lfo1LED = led;
    } else {
        [tempoSyncCheckbox setAction:@selector(lfo2TempoSyncChanged:)];
        [noteDivisionDropdown setAction:@selector(lfo2NoteDivisionChanged:)];
        lfo2TempoSyncCheckbox = tempoSyncCheckbox;
        lfo2NoteDivisionDropdown = noteDivisionDropdown;
        lfo2LED = led;
    }

    [self addSubview:tempoSyncCheckbox];
    [self addSubview:noteDivisionDropdown];
}

- (void)createModulationMatrixSection {
    // Section label
    NSTextField *matrixLabel = [[NSTextField alloc] initWithFrame:NSMakeRect(50, 162, 1160, 20)];
    [matrixLabel setStringValue:@"Modulation Matrix"];
    [matrixLabel setAlignment:NSTextAlignmentLeft];
    [matrixLabel setBezeled:NO];
    [matrixLabel setDrawsBackground:NO];
    [matrixLabel setEditable:NO];
    [matrixLabel setSelectable:NO];
    [matrixLabel setFont:[ClaudeSynthView matrixBoldFontOfSize:14]];
    [matrixLabel setTextColor:[ClaudeSynthView matrixBrightGreen]];
    [self addSubview:matrixLabel];

    // Column headers
    NSTextField *sourceHeader = [[NSTextField alloc] initWithFrame:NSMakeRect(80, 142, 150, 16)];
    [sourceHeader setStringValue:@"Source"];
    [sourceHeader setAlignment:NSTextAlignmentCenter];
    [sourceHeader setBezeled:NO];
    [sourceHeader setDrawsBackground:NO];
    [sourceHeader setEditable:NO];
    [sourceHeader setSelectable:NO];
    [sourceHeader setFont:[ClaudeSynthView matrixBoldFontOfSize:11]];
    [sourceHeader setTextColor:[ClaudeSynthView matrixMediumGreen]];
    [self addSubview:sourceHeader];

    NSTextField *destHeader = [[NSTextField alloc] initWithFrame:NSMakeRect(240, 142, 200, 16)];
    [destHeader setStringValue:@"Destination"];
    [destHeader setAlignment:NSTextAlignmentCenter];
    [destHeader setBezeled:NO];
    [destHeader setDrawsBackground:NO];
    [destHeader setEditable:NO];
    [destHeader setSelectable:NO];
    [destHeader setFont:[ClaudeSynthView matrixBoldFontOfSize:11]];
    [destHeader setTextColor:[ClaudeSynthView matrixMediumGreen]];
    [self addSubview:destHeader];

    NSTextField *intensityHeader = [[NSTextField alloc] initWithFrame:NSMakeRect(450, 142, 100, 16)];
    [intensityHeader setStringValue:@"Intensity"];
    [intensityHeader setAlignment:NSTextAlignmentCenter];
    [intensityHeader setBezeled:NO];
    [intensityHeader setDrawsBackground:NO];
    [intensityHeader setEditable:NO];
    [intensityHeader setSelectable:NO];
    [intensityHeader setFont:[ClaudeSynthView matrixBoldFontOfSize:11]];
    [intensityHeader setTextColor:[ClaudeSynthView matrixMediumGreen]];
    [self addSubview:intensityHeader];

    // Create 4 modulation slots with tighter spacing
    for (int slot = 0; slot < 4; slot++) {
        int yPos = 117 - (slot * 30);

        // Slot number label
        NSTextField *slotLabel = [[NSTextField alloc] initWithFrame:NSMakeRect(50, yPos + 10, 20, 16)];
        [slotLabel setStringValue:[NSString stringWithFormat:@"%d", slot + 1]];
        [slotLabel setAlignment:NSTextAlignmentCenter];
        [slotLabel setBezeled:NO];
        [slotLabel setDrawsBackground:NO];
        [slotLabel setEditable:NO];
        [slotLabel setSelectable:NO];
        [slotLabel setFont:[ClaudeSynthView matrixFontOfSize:11]];
        [slotLabel setTextColor:[ClaudeSynthView matrixCyan]];
        [self addSubview:slotLabel];

        // Source popup
        MatrixDropdown *sourcePopup = [[MatrixDropdown alloc] initWithFrame:NSMakeRect(80, yPos, 150, 25)];
        [sourcePopup addItemWithTitle:@"None"];
        [sourcePopup addItemWithTitle:@"LFO 1"];
        [sourcePopup addItemWithTitle:@"LFO 2"];
        [sourcePopup addItemWithTitle:@"Filter Env"];
        [sourcePopup setTarget:self];
        [sourcePopup setTag:slot];
        [sourcePopup setAction:@selector(modSourceChanged:)];

        AudioUnitParameterID sourceParamID = kParam_ModSlot1_Source + (slot * 3);
        AudioUnitParameterValue initialSource = 0.0f;
        if (mAU) {
            AudioUnitGetParameter(mAU, sourceParamID, kAudioUnitScope_Global, 0, &initialSource);
        }
        [sourcePopup selectItemAtIndex:(int)initialSource];
        [self addSubview:sourcePopup];

        // Destination popup
        MatrixDropdown *destPopup = [[MatrixDropdown alloc] initWithFrame:NSMakeRect(240, yPos, 200, 25)];
        [destPopup addItemWithTitle:@"None"];
        [destPopup addItemWithTitle:@"Filter Cutoff"];
        [destPopup addItemWithTitle:@"Filter Resonance"];
        [destPopup addItemWithTitle:@"Master Volume"];
        [destPopup addItemWithTitle:@"Osc 1 Detune"];
        [destPopup addItemWithTitle:@"Osc 1 Volume"];
        [destPopup addItemWithTitle:@"Osc 2 Detune"];
        [destPopup addItemWithTitle:@"Osc 2 Volume"];
        [destPopup addItemWithTitle:@"Osc 3 Detune"];
        [destPopup addItemWithTitle:@"Osc 3 Volume"];
        [destPopup setTarget:self];
        [destPopup setTag:slot];
        [destPopup setAction:@selector(modDestChanged:)];

        AudioUnitParameterID destParamID = kParam_ModSlot1_Dest + (slot * 3);
        AudioUnitParameterValue initialDest = 0.0f;
        if (mAU) {
            AudioUnitGetParameter(mAU, destParamID, kAudioUnitScope_Global, 0, &initialDest);
        }
        [destPopup selectItemAtIndex:(int)initialDest];
        [self addSubview:destPopup];

        // Intensity knob (smaller)
        RotaryKnob *intensityKnob = [[RotaryKnob alloc] initWithFrame:NSMakeRect(475, yPos - 5, 40, 40)];
        [intensityKnob setMinValue:0.0];
        [intensityKnob setMaxValue:1.0];
        [intensityKnob setTarget:self];
        [intensityKnob setTag:slot];
        [intensityKnob setAction:@selector(modIntensityChanged:)];

        AudioUnitParameterID intensityParamID = kParam_ModSlot1_Intensity + (slot * 3);
        AudioUnitParameterValue initialIntensity = 0.0f;
        if (mAU) {
            AudioUnitGetParameter(mAU, intensityParamID, kAudioUnitScope_Global, 0, &initialIntensity);
        }
        [intensityKnob setDoubleValue:initialIntensity];
        [intensityKnob setContinuous:YES];
        [self addSubview:intensityKnob];

        // Intensity display
        NSTextField *intensityDisplay = [[NSTextField alloc] initWithFrame:NSMakeRect(520, yPos + 5, 40, 16)];
        [intensityDisplay setStringValue:[NSString stringWithFormat:@"%.0f%%", initialIntensity * 100.0]];
        [intensityDisplay setAlignment:NSTextAlignmentCenter];
        [intensityDisplay setBezeled:NO];
        [intensityDisplay setDrawsBackground:NO];
        [intensityDisplay setEditable:NO];
        [intensityDisplay setSelectable:NO];
        [intensityDisplay setFont:[ClaudeSynthView matrixFontOfSize:9]];
        [intensityDisplay setTextColor:[ClaudeSynthView matrixCyan]];
        [intensityDisplay setTag:1000 + slot];  // Use unique tag base to avoid conflicts
        [self addSubview:intensityDisplay];
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

// Envelope
// Envelope
- (void)envelopeChanged:(id)sender {
    ADSREnvelopeView *env = (ADSREnvelopeView *)sender;

    float attack = env.attack;
    float decay = env.decay;
    float sustain = env.sustain;
    float release = env.releaseTime;

    if (mAU) {
        AudioUnitSetParameter(mAU, kParam_EnvAttack, kAudioUnitScope_Global, 0, attack, 0);
        AudioUnitSetParameter(mAU, kParam_EnvDecay, kAudioUnitScope_Global, 0, decay, 0);
        AudioUnitSetParameter(mAU, kParam_EnvSustain, kAudioUnitScope_Global, 0, sustain, 0);
        AudioUnitSetParameter(mAU, kParam_EnvRelease, kAudioUnitScope_Global, 0, release, 0);
    }

    // Update displays
    if (attack >= 1.0f) {
        [attackDisplay setStringValue:[NSString stringWithFormat:@"A:%.1fs", attack]];
    } else {
        [attackDisplay setStringValue:[NSString stringWithFormat:@"A:%dms", (int)(attack * 1000)]];
    }

    if (decay >= 1.0f) {
        [decayDisplay setStringValue:[NSString stringWithFormat:@"D:%.1fs", decay]];
    } else {
        [decayDisplay setStringValue:[NSString stringWithFormat:@"D:%dms", (int)(decay * 1000)]];
    }

    [sustainDisplay setStringValue:[NSString stringWithFormat:@"S:%.0f%%", sustain * 100]];

    if (release >= 1.0f) {
        [releaseDisplay setStringValue:[NSString stringWithFormat:@"R:%.1fs", release]];
    } else {
        [releaseDisplay setStringValue:[NSString stringWithFormat:@"R:%dms", (int)(release * 1000)]];
    }
}

// Filter Envelope
- (void)filterEnvelopeChanged:(id)sender {
    ADSREnvelopeView *env = (ADSREnvelopeView *)sender;

    float attack = env.attack;
    float decay = env.decay;
    float sustain = env.sustain;
    float release = env.releaseTime;

    if (mAU) {
        AudioUnitSetParameter(mAU, kParam_FilterEnvAttack, kAudioUnitScope_Global, 0, attack, 0);
        AudioUnitSetParameter(mAU, kParam_FilterEnvDecay, kAudioUnitScope_Global, 0, decay, 0);
        AudioUnitSetParameter(mAU, kParam_FilterEnvSustain, kAudioUnitScope_Global, 0, sustain, 0);
        AudioUnitSetParameter(mAU, kParam_FilterEnvRelease, kAudioUnitScope_Global, 0, release, 0);
    }

    // Update displays
    if (attack >= 1.0f) {
        [filterAttackDisplay setStringValue:[NSString stringWithFormat:@"A:%.1fs", attack]];
    } else {
        [filterAttackDisplay setStringValue:[NSString stringWithFormat:@"A:%dms", (int)(attack * 1000)]];
    }

    if (decay >= 1.0f) {
        [filterDecayDisplay setStringValue:[NSString stringWithFormat:@"D:%.1fs", decay]];
    } else {
        [filterDecayDisplay setStringValue:[NSString stringWithFormat:@"D:%dms", (int)(decay * 1000)]];
    }

    [filterSustainDisplay setStringValue:[NSString stringWithFormat:@"S:%.0f%%", sustain * 100]];

    if (release >= 1.0f) {
        [filterReleaseDisplay setStringValue:[NSString stringWithFormat:@"R:%.1fs", release]];
    } else {
        [filterReleaseDisplay setStringValue:[NSString stringWithFormat:@"R:%dms", (int)(release * 1000)]];
    }
}

// LFO 1
- (void)lfo1WaveformChanged:(id)sender {
    int value = [lfoWaveformKnob intValue];
    if (mAU) {
        AudioUnitSetParameter(mAU, kParam_LFO1_Waveform, kAudioUnitScope_Global, 0, (float)value, 0);
    }
}

- (void)lfo1RateChanged:(id)sender {
    float value = [lfoRateKnob floatValue];
    if (mAU) {
        AudioUnitSetParameter(mAU, kParam_LFO1_Rate, kAudioUnitScope_Global, 0, value, 0);
    }
    [lfoRateDisplay setStringValue:[NSString stringWithFormat:@"%.1f Hz", value]];
}

- (void)lfo1TempoSyncChanged:(id)sender {
    BOOL enabled = ([lfo1TempoSyncCheckbox state] == NSControlStateValueOn);
    if (mAU) {
        AudioUnitSetParameter(mAU, kParam_LFO1_TempoSync, kAudioUnitScope_Global, 0, enabled ? 1.0f : 0.0f, 0);
    }
    // Show/hide note division dropdown
    [lfo1NoteDivisionDropdown setHidden:!enabled];
    // Show/hide rate knob and display
    [lfoRateKnob setHidden:enabled];
    [lfoRateDisplay setHidden:enabled];
}

- (void)lfo1NoteDivisionChanged:(id)sender {
    int value = (int)[lfo1NoteDivisionDropdown indexOfSelectedItem];
    if (mAU) {
        AudioUnitSetParameter(mAU, kParam_LFO1_NoteDivision, kAudioUnitScope_Global, 0, (float)value, 0);
    }
}

// LFO 2
- (void)lfo2WaveformChanged:(id)sender {
    int value = [lfo2WaveformKnob intValue];
    if (mAU) {
        AudioUnitSetParameter(mAU, kParam_LFO2_Waveform, kAudioUnitScope_Global, 0, (float)value, 0);
    }
}

- (void)lfo2RateChanged:(id)sender {
    float value = [lfo2RateKnob floatValue];
    if (mAU) {
        AudioUnitSetParameter(mAU, kParam_LFO2_Rate, kAudioUnitScope_Global, 0, value, 0);
    }
    [lfo2RateDisplay setStringValue:[NSString stringWithFormat:@"%.1f Hz", value]];
}

- (void)lfo2TempoSyncChanged:(id)sender {
    BOOL enabled = ([lfo2TempoSyncCheckbox state] == NSControlStateValueOn);
    if (mAU) {
        AudioUnitSetParameter(mAU, kParam_LFO2_TempoSync, kAudioUnitScope_Global, 0, enabled ? 1.0f : 0.0f, 0);
    }
    // Show/hide note division dropdown
    [lfo2NoteDivisionDropdown setHidden:!enabled];
    // Show/hide rate knob and display
    [lfo2RateKnob setHidden:enabled];
    [lfo2RateDisplay setHidden:enabled];
}

- (void)lfo2NoteDivisionChanged:(id)sender {
    int value = (int)[lfo2NoteDivisionDropdown indexOfSelectedItem];
    if (mAU) {
        AudioUnitSetParameter(mAU, kParam_LFO2_NoteDivision, kAudioUnitScope_Global, 0, (float)value, 0);
    }
}

// Modulation Matrix
- (void)modSourceChanged:(id)sender {
    MatrixDropdown *popup = (MatrixDropdown *)sender;
    int slot = (int)[popup tag];
    int value = (int)[popup indexOfSelectedItem];
    if (mAU) {
        AudioUnitParameterID paramID = kParam_ModSlot1_Source + (slot * 3);
        AudioUnitSetParameter(mAU, paramID, kAudioUnitScope_Global, 0, (float)value, 0);
    }
}

- (void)modDestChanged:(id)sender {
    MatrixDropdown *popup = (MatrixDropdown *)sender;
    int slot = (int)[popup tag];
    int value = (int)[popup indexOfSelectedItem];
    if (mAU) {
        AudioUnitParameterID paramID = kParam_ModSlot1_Dest + (slot * 3);
        AudioUnitSetParameter(mAU, paramID, kAudioUnitScope_Global, 0, (float)value, 0);
    }
}

- (void)modIntensityChanged:(id)sender {
    RotaryKnob *knob = (RotaryKnob *)sender;
    int slot = (int)[knob tag];
    float value = [knob floatValue];
    if (mAU) {
        AudioUnitParameterID paramID = kParam_ModSlot1_Intensity + (slot * 3);
        AudioUnitSetParameter(mAU, paramID, kAudioUnitScope_Global, 0, value, 0);
    }

    // Update the corresponding display (using unique tag 1000 + slot)
    for (NSView *subview in [self subviews]) {
        if ([subview isKindOfClass:[NSTextField class]] && [subview tag] == (1000 + slot)) {
            NSTextField *display = (NSTextField *)subview;
            [display setStringValue:[NSString stringWithFormat:@"%.0f%%", value * 100.0]];
            break;
        }
    }
}

- (void)effectTypeChanged:(id)sender {
    int value = (int)[effectTypePopup indexOfSelectedItem];
    if (mAU) {
        AudioUnitSetParameter(mAU, kParam_EffectType, kAudioUnitScope_Global, 0, (float)value, 0);
    }
}

- (void)effectRateChanged:(id)sender {
    float value = [effectRateKnob floatValue];
    if (mAU) {
        AudioUnitSetParameter(mAU, kParam_EffectRate, kAudioUnitScope_Global, 0, value, 0);
    }
    [effectRateDisplay setStringValue:[NSString stringWithFormat:@"%.1f Hz", value]];
}

- (void)effectIntensityChanged:(id)sender {
    float value = [effectIntensityKnob floatValue];
    if (mAU) {
        AudioUnitSetParameter(mAU, kParam_EffectIntensity, kAudioUnitScope_Global, 0, value, 0);
    }
    [effectIntensityDisplay setStringValue:[NSString stringWithFormat:@"%.0f%%", value * 100.0]];
}

- (void)arpEnableChanged:(id)sender {
    float value = ([arpEnableButton state] == NSControlStateValueOn) ? 1.0f : 0.0f;
    if (mAU) {
        AudioUnitSetParameter(mAU, kParam_ArpEnable, kAudioUnitScope_Global, 0, value, 0);
    }
}

- (void)arpRateChanged:(id)sender {
    int value = (int)[arpRatePopup indexOfSelectedItem];
    if (mAU) {
        AudioUnitSetParameter(mAU, kParam_ArpRate, kAudioUnitScope_Global, 0, (float)value, 0);
    }
}

- (void)arpModeChanged:(id)sender {
    int value = (int)[arpModePopup indexOfSelectedItem];
    if (mAU) {
        AudioUnitSetParameter(mAU, kParam_ArpMode, kAudioUnitScope_Global, 0, (float)value, 0);
    }
}

- (void)arpOctavesChanged:(id)sender {
    int value = (int)[arpOctavesPopup indexOfSelectedItem] + 1;  // 1-4 octaves
    if (mAU) {
        AudioUnitSetParameter(mAU, kParam_ArpOctaves, kAudioUnitScope_Global, 0, (float)value, 0);
    }
}

- (void)arpGateChanged:(id)sender {
    float value = [arpGateKnob floatValue];
    if (mAU) {
        AudioUnitSetParameter(mAU, kParam_ArpGate, kAudioUnitScope_Global, 0, value, 0);
    }
    [arpGateDisplay setStringValue:[NSString stringWithFormat:@"%.0f%%", value * 100.0]];
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

    // Update envelope parameters
    AudioUnitParameterValue attack, decay, sustain, release;
    BOOL envChanged = NO;
    if (AudioUnitGetParameter(mAU, kParam_EnvAttack, kAudioUnitScope_Global, 0, &attack) == noErr &&
        AudioUnitGetParameter(mAU, kParam_EnvDecay, kAudioUnitScope_Global, 0, &decay) == noErr &&
        AudioUnitGetParameter(mAU, kParam_EnvSustain, kAudioUnitScope_Global, 0, &sustain) == noErr &&
        AudioUnitGetParameter(mAU, kParam_EnvRelease, kAudioUnitScope_Global, 0, &release) == noErr) {

        if (fabs(attack - envelopeView.attack) > 0.001f ||
            fabs(decay - envelopeView.decay) > 0.001f ||
            fabs(sustain - envelopeView.sustain) > 0.001f ||
            fabs(release - envelopeView.releaseTime) > 0.001f) {

            envelopeView.attack = attack;
            envelopeView.decay = decay;
            envelopeView.sustain = sustain;
            envelopeView.releaseTime = release;
            [envelopeView setNeedsDisplay:YES];

            // Update displays
            if (attack >= 1.0f) {
                [attackDisplay setStringValue:[NSString stringWithFormat:@"A:%.1fs", attack]];
            } else {
                [attackDisplay setStringValue:[NSString stringWithFormat:@"A:%dms", (int)(attack * 1000)]];
            }
            if (decay >= 1.0f) {
                [decayDisplay setStringValue:[NSString stringWithFormat:@"D:%.1fs", decay]];
            } else {
                [decayDisplay setStringValue:[NSString stringWithFormat:@"D:%dms", (int)(decay * 1000)]];
            }
            [sustainDisplay setStringValue:[NSString stringWithFormat:@"S:%.0f%%", sustain * 100]];
            if (release >= 1.0f) {
                [releaseDisplay setStringValue:[NSString stringWithFormat:@"R:%.1fs", release]];
            } else {
                [releaseDisplay setStringValue:[NSString stringWithFormat:@"R:%dms", (int)(release * 1000)]];
            }
        }
    }

    // Update filter envelope parameters
    if (AudioUnitGetParameter(mAU, kParam_FilterEnvAttack, kAudioUnitScope_Global, 0, &attack) == noErr &&
        AudioUnitGetParameter(mAU, kParam_FilterEnvDecay, kAudioUnitScope_Global, 0, &decay) == noErr &&
        AudioUnitGetParameter(mAU, kParam_FilterEnvSustain, kAudioUnitScope_Global, 0, &sustain) == noErr &&
        AudioUnitGetParameter(mAU, kParam_FilterEnvRelease, kAudioUnitScope_Global, 0, &release) == noErr) {

        if (fabs(attack - filterEnvelopeView.attack) > 0.001f ||
            fabs(decay - filterEnvelopeView.decay) > 0.001f ||
            fabs(sustain - filterEnvelopeView.sustain) > 0.001f ||
            fabs(release - filterEnvelopeView.releaseTime) > 0.001f) {

            filterEnvelopeView.attack = attack;
            filterEnvelopeView.decay = decay;
            filterEnvelopeView.sustain = sustain;
            filterEnvelopeView.releaseTime = release;
            [filterEnvelopeView setNeedsDisplay:YES];

            // Update displays
            if (attack >= 1.0f) {
                [filterAttackDisplay setStringValue:[NSString stringWithFormat:@"A:%.1fs", attack]];
            } else {
                [filterAttackDisplay setStringValue:[NSString stringWithFormat:@"A:%dms", (int)(attack * 1000)]];
            }
            if (decay >= 1.0f) {
                [filterDecayDisplay setStringValue:[NSString stringWithFormat:@"D:%.1fs", decay]];
            } else {
                [filterDecayDisplay setStringValue:[NSString stringWithFormat:@"D:%dms", (int)(decay * 1000)]];
            }
            [filterSustainDisplay setStringValue:[NSString stringWithFormat:@"S:%.0f%%", sustain * 100]];
            if (release >= 1.0f) {
                [filterReleaseDisplay setStringValue:[NSString stringWithFormat:@"R:%.1fs", release]];
            } else {
                [filterReleaseDisplay setStringValue:[NSString stringWithFormat:@"R:%dms", (int)(release * 1000)]];
            }
        }
    }

    // Update LFO 1 parameters
    if (AudioUnitGetParameter(mAU, kParam_LFO1_Waveform, kAudioUnitScope_Global, 0, &value) == noErr) {
        if ((int)value != [lfoWaveformKnob intValue]) {
            [lfoWaveformKnob setIntValue:(int)value];
        }
    }
    if (AudioUnitGetParameter(mAU, kParam_LFO1_Rate, kAudioUnitScope_Global, 0, &value) == noErr) {
        if (fabs(value - [lfoRateKnob floatValue]) > 0.01f) {
            [lfoRateKnob setFloatValue:value];
            [lfoRateDisplay setStringValue:[NSString stringWithFormat:@"%.1f Hz", value]];
        }
    }

    // Update LFO 2 parameters
    if (AudioUnitGetParameter(mAU, kParam_LFO2_Waveform, kAudioUnitScope_Global, 0, &value) == noErr) {
        if ((int)value != [lfo2WaveformKnob intValue]) {
            [lfo2WaveformKnob setIntValue:(int)value];
        }
    }
    if (AudioUnitGetParameter(mAU, kParam_LFO2_Rate, kAudioUnitScope_Global, 0, &value) == noErr) {
        if (fabs(value - [lfo2RateKnob floatValue]) > 0.01f) {
            [lfo2RateKnob setFloatValue:value];
            [lfo2RateDisplay setStringValue:[NSString stringWithFormat:@"%.1f Hz", value]];
        }
    }

    // Update effects parameters
    if (AudioUnitGetParameter(mAU, kParam_EffectType, kAudioUnitScope_Global, 0, &value) == noErr) {
        if ((int)value != [effectTypePopup indexOfSelectedItem]) {
            [effectTypePopup selectItemAtIndex:(int)value];
        }
    }
    if (AudioUnitGetParameter(mAU, kParam_EffectRate, kAudioUnitScope_Global, 0, &value) == noErr) {
        if (fabs(value - [effectRateKnob floatValue]) > 0.01f) {
            [effectRateKnob setFloatValue:value];
            [effectRateDisplay setStringValue:[NSString stringWithFormat:@"%.1f Hz", value]];
        }
    }
    if (AudioUnitGetParameter(mAU, kParam_EffectIntensity, kAudioUnitScope_Global, 0, &value) == noErr) {
        if (fabs(value - [effectIntensityKnob floatValue]) > 0.01f) {
            [effectIntensityKnob setFloatValue:value];
            [effectIntensityDisplay setStringValue:[NSString stringWithFormat:@"%.0f%%", value * 100.0]];
        }
    }

    // Note: Modulation matrix parameters are not polled in updateFromHost
    // since they are typically only changed by the user via the UI

    // Update LFO indicators
    if (AudioUnitGetParameter(mAU, kParam_LFO1_Output, kAudioUnitScope_Global, 0, &value) == noErr) {
        [lfo1LED setValue:value];
    }
    if (AudioUnitGetParameter(mAU, kParam_LFO2_Output, kAudioUnitScope_Global, 0, &value) == noErr) {
        [lfo2LED setValue:value];
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
