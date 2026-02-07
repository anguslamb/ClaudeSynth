#import <Cocoa/Cocoa.h>

@interface RotaryKnob : NSControl

@property (nonatomic) double minValue;
@property (nonatomic) double maxValue;
@property (nonatomic) BOOL bipolar;  // If YES, center value is at 12 o'clock

- (id)initWithFrame:(NSRect)frame;

@end
