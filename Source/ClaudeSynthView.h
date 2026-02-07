#import <Cocoa/Cocoa.h>
#import <AudioUnit/AudioUnit.h>
#import <AudioUnit/AUCocoaUIView.h>
#import <AudioToolbox/AudioToolbox.h>

@interface ClaudeSynthView : NSView
{
    AudioUnit mAU;
    NSSlider *volumeKnob;
    NSTextField *titleLabel;
    NSTextField *volumeLabel;
    NSTextField *percentageDisplay;
    NSTimer *updateTimer;
}

- (id)initWithFrame:(NSRect)frame audioUnit:(AudioUnit)au;
- (void)volumeChanged:(id)sender;
- (void)updateFromHost:(NSTimer *)timer;

@end
