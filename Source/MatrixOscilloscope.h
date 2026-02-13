#import <Cocoa/Cocoa.h>

#define OSCILLOSCOPE_BUFFER_SIZE 512

@interface MatrixOscilloscope : NSView

- (instancetype)initWithFrame:(NSRect)frame;
- (void)pushSamples:(const float *)samples count:(int)count;
- (void)clear;

@end
