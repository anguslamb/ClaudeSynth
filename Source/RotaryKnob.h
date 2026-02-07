#import <Cocoa/Cocoa.h>

@interface RotaryKnob : NSControl

@property (nonatomic) double minValue;
@property (nonatomic) double maxValue;

- (id)initWithFrame:(NSRect)frame;

@end
