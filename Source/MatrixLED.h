#import <Cocoa/Cocoa.h>

@interface MatrixLED : NSView

@property (nonatomic, assign) float value;  // 0.0 to 1.0

- (instancetype)initWithFrame:(NSRect)frame;

@end
