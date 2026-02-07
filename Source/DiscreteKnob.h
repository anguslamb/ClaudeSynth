#import <Cocoa/Cocoa.h>

@interface DiscreteKnob : NSControl

@property (nonatomic) int numberOfPositions;
@property (nonatomic) int selectedPosition;
@property (nonatomic, strong) NSArray<NSString *> *labels;

- (id)initWithFrame:(NSRect)frame;

@end
