#import <Cocoa/Cocoa.h>

@interface MatrixCheckbox : NSControl

@property (nonatomic, copy) NSString *title;
@property (nonatomic, assign) NSControlStateValue state;

- (instancetype)initWithFrame:(NSRect)frame;

@end
