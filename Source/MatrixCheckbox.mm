#import "MatrixCheckbox.h"

// Forward declare color helpers
@interface ClaudeSynthView : NSView
+ (NSColor *)matrixBackground;
+ (NSColor *)matrixBrightGreen;
+ (NSColor *)matrixMediumGreen;
+ (NSColor *)matrixDimGreen;
+ (NSFont *)matrixFontOfSize:(CGFloat)size;
@end

@implementation MatrixCheckbox

- (instancetype)initWithFrame:(NSRect)frame {
    self = [super initWithFrame:frame];
    if (self) {
        _state = NSControlStateValueOff;
        _title = @"";
    }
    return self;
}

- (void)drawRect:(NSRect)dirtyRect {
    [super drawRect:dirtyRect];

    NSRect bounds = [self bounds];
    CGFloat boxSize = 14.0;
    CGFloat boxY = (bounds.size.height - boxSize) / 2.0;

    // Draw checkbox box
    NSRect boxRect = NSMakeRect(2, boxY, boxSize, boxSize);

    // Background
    [[NSColor colorWithRed:0.0 green:0.08 blue:0.0 alpha:1.0] setFill];
    NSRectFill(boxRect);

    // Border
    NSBezierPath *border = [NSBezierPath bezierPathWithRect:NSInsetRect(boxRect, 0.5, 0.5)];
    [[ClaudeSynthView matrixMediumGreen] setStroke];
    [border setLineWidth:1.0];
    [border stroke];

    // Draw checkmark if checked
    if (_state == NSControlStateValueOn) {
        NSBezierPath *check = [NSBezierPath bezierPath];
        [check setLineWidth:2.0];
        [check setLineCapStyle:NSLineCapStyleRound];
        [check setLineJoinStyle:NSLineJoinStyleRound];

        // Draw checkmark
        CGFloat checkX = boxRect.origin.x + 3;
        CGFloat checkY = boxRect.origin.y + 6;
        [check moveToPoint:NSMakePoint(checkX, checkY)];
        [check lineToPoint:NSMakePoint(checkX + 3, checkY - 3)];
        [check lineToPoint:NSMakePoint(checkX + 8, checkY + 4)];

        [[ClaudeSynthView matrixBrightGreen] setStroke];
        [check stroke];
    }

    // Draw label
    if (_title.length > 0) {
        NSDictionary *attrs = @{
            NSFontAttributeName: [ClaudeSynthView matrixFontOfSize:11],
            NSForegroundColorAttributeName: [ClaudeSynthView matrixMediumGreen]
        };

        CGFloat textX = boxRect.origin.x + boxSize + 6;
        NSSize textSize = [_title sizeWithAttributes:attrs];
        CGFloat textY = (bounds.size.height - textSize.height) / 2.0;
        [_title drawAtPoint:NSMakePoint(textX, textY) withAttributes:attrs];
    }
}

- (void)mouseDown:(NSEvent *)event {
    // Toggle state
    _state = (_state == NSControlStateValueOn) ? NSControlStateValueOff : NSControlStateValueOn;
    [self setNeedsDisplay:YES];

    // Send action
    if (self.target && self.action) {
        [NSApp sendAction:self.action to:self.target from:self];
    }
}

- (void)setState:(NSControlStateValue)state {
    _state = state;
    [self setNeedsDisplay:YES];
}

- (void)setTitle:(NSString *)title {
    _title = [title copy];
    [self setNeedsDisplay:YES];
}

- (BOOL)acceptsFirstResponder {
    return YES;
}

@end
