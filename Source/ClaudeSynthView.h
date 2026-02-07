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
    NSTextField *titleLabel;
    NSTextField *volumeLabel;
    NSTextField *waveformLabel;
    NSTextField *percentageDisplay;
    NSTimer *updateTimer;
}

- (id)initWithFrame:(NSRect)frame audioUnit:(AudioUnit)au;
- (void)volumeChanged:(id)sender;
- (void)waveformChanged:(id)sender;
- (void)updateFromHost:(NSTimer *)timer;

@end
