#import <Cocoa/Cocoa.h>

@interface ADSREnvelopeView : NSView

@property (nonatomic) float attack;      // 0.001 to 3.0 seconds
@property (nonatomic) float decay;       // 0.001 to 3.0 seconds
@property (nonatomic) float sustain;     // 0.0 to 1.0 level
@property (nonatomic) float releaseTime; // 0.001 to 3.0 seconds

@property (nonatomic, weak) id target;
@property (nonatomic) SEL action;

@end
