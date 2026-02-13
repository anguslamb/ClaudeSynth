#import "MatrixLED.h"

// Forward declare color helpers
@interface ClaudeSynthView : NSView
+ (NSColor *)matrixBrightGreen;
+ (NSColor *)matrixDimGreen;
+ (NSColor *)matrixDarkGreen;
@end

@implementation MatrixLED

- (instancetype)initWithFrame:(NSRect)frame {
    self = [super initWithFrame:frame];
    if (self) {
        _value = 0.0f;
    }
    return self;
}

- (void)drawRect:(NSRect)dirtyRect {
    [super drawRect:dirtyRect];

    NSRect bounds = [self bounds];
    CGFloat size = MIN(bounds.size.width, bounds.size.height);
    CGFloat centerX = bounds.size.width / 2.0;
    CGFloat centerY = bounds.size.height / 2.0;
    CGFloat radius = size / 2.0 - 2.0;

    // Draw outer circle (border)
    NSBezierPath *outer = [NSBezierPath bezierPathWithOvalInRect:
        NSMakeRect(centerX - radius, centerY - radius, radius * 2, radius * 2)];

    [[ClaudeSynthView matrixDimGreen] setStroke];
    [outer setLineWidth:1.0];
    [outer stroke];

    // Draw inner circle (glow based on value)
    CGFloat innerRadius = radius - 2.0;
    NSBezierPath *inner = [NSBezierPath bezierPathWithOvalInRect:
        NSMakeRect(centerX - innerRadius, centerY - innerRadius, innerRadius * 2, innerRadius * 2)];

    // Interpolate between dark green and bright green based on value
    CGFloat brightness = _value;  // 0.0 to 1.0
    NSColor *fillColor = [NSColor colorWithRed:0.0
                                         green:0.1 + (0.9 * brightness)  // 0.1 to 1.0
                                          blue:0.0
                                         alpha:1.0];
    [fillColor setFill];
    [inner fill];

    // Add glow effect when bright
    if (_value > 0.5f) {
        NSShadow *glow = [[NSShadow alloc] init];
        [glow setShadowColor:[ClaudeSynthView matrixBrightGreen]];
        [glow setShadowBlurRadius:5.0 * _value];
        [glow setShadowOffset:NSMakeSize(0, 0)];

        [NSGraphicsContext saveGraphicsState];
        [glow set];
        [[ClaudeSynthView matrixBrightGreen] setFill];
        [inner fill];
        [NSGraphicsContext restoreGraphicsState];
    }
}

- (void)setValue:(float)value {
    _value = fmaxf(0.0f, fminf(1.0f, value));
    [self setNeedsDisplay:YES];
}

@end
