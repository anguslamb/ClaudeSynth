#import <Cocoa/Cocoa.h>
#import <AudioUnit/AudioUnit.h>
#import <AudioUnit/AUCocoaUIView.h>
#import <AudioToolbox/AudioToolbox.h>

@interface ClaudeSynthView : NSView
{
    AudioUnit mAU;
}

- (id)initWithFrame:(NSRect)frame audioUnit:(AudioUnit)au;

@end
