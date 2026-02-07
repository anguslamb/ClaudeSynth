#import <Cocoa/Cocoa.h>
#import <AudioUnit/AudioUnit.h>
#import <AudioUnit/AUCocoaUIView.h>
#import <AudioToolbox/AudioToolbox.h>
#import "RotaryKnob.h"
#import "DiscreteKnob.h"

@interface ClaudeSynthView : NSView
{
    AudioUnit mAU;
    RotaryKnob *volumeKnob;
    DiscreteKnob *waveformKnob;
    RotaryKnob *cutoffKnob;
    RotaryKnob *resonanceKnob;
    NSTextField *titleLabel;
    NSTextField *volumeLabel;
    NSTextField *waveformLabel;
    NSTextField *cutoffLabel;
    NSTextField *resonanceLabel;
    NSTextField *cutoffValueDisplay;
    NSTextField *resonanceValueDisplay;
    NSTextField *percentageDisplay;
    NSTimer *updateTimer;
}

- (id)initWithFrame:(NSRect)frame audioUnit:(AudioUnit)au;
- (void)volumeChanged:(id)sender;
- (void)waveformChanged:(id)sender;
- (void)cutoffChanged:(id)sender;
- (void)resonanceChanged:(id)sender;
- (void)updateFromHost:(NSTimer *)timer;

@end
