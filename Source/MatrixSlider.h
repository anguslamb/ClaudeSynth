#import <Cocoa/Cocoa.h>

@interface MatrixSlider : NSControl

@property (nonatomic, assign) double minValue;
@property (nonatomic, assign) double maxValue;
@property (nonatomic, assign) NSInteger numberOfTickMarks;
@property (nonatomic, assign) BOOL vertical;

- (instancetype)initWithFrame:(NSRect)frame;
- (float)floatValue;
- (void)setFloatValue:(float)value;
- (int)intValue;
- (void)setIntValue:(int)value;

@end
