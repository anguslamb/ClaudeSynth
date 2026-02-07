#import "RotaryKnob.h"
#import <QuartzCore/QuartzCore.h>

@implementation RotaryKnob {
    NSPoint lastMouseLocation;
    double startValue;
}

- (id)initWithFrame:(NSRect)frame {
    self = [super initWithFrame:frame];
    if (self) {
        _minValue = 0.0;
        _maxValue = 1.0;
        _bipolar = NO;
        [super setDoubleValue:1.0];
    }
    return self;
}

- (BOOL)acceptsFirstResponder {
    return YES;
}

- (void)drawRect:(NSRect)dirtyRect {
    [super drawRect:dirtyRect];

    NSRect bounds = [self bounds];
    CGFloat centerX = bounds.size.width / 2.0;
    CGFloat centerY = bounds.size.height / 2.0;
    CGFloat radius = MIN(bounds.size.width, bounds.size.height) / 2.0 - 4.0;

    // Draw outer circle (knob body)
    NSBezierPath *outerCircle = [NSBezierPath bezierPathWithOvalInRect:
        NSMakeRect(centerX - radius, centerY - radius, radius * 2, radius * 2)];

    // Gradient fill for 3D effect
    NSGradient *gradient = [[NSGradient alloc] initWithStartingColor:[NSColor colorWithWhite:0.4 alpha:1.0]
                                                         endingColor:[NSColor colorWithWhite:0.25 alpha:1.0]];
    [gradient drawInBezierPath:outerCircle angle:-90];

    // Draw inner circle (darker center)
    CGFloat innerRadius = radius * 0.7;
    NSBezierPath *innerCircle = [NSBezierPath bezierPathWithOvalInRect:
        NSMakeRect(centerX - innerRadius, centerY - innerRadius, innerRadius * 2, innerRadius * 2)];
    [[NSColor colorWithWhite:0.15 alpha:1.0] setFill];
    [innerCircle fill];

    // Draw border
    [[NSColor colorWithWhite:0.5 alpha:1.0] setStroke];
    [outerCircle setLineWidth:1.0];
    [outerCircle stroke];

    // Draw range markers
    if (self.bipolar) {
        // Bipolar: marks at min (225°), center (90°), max (315°)
        [self drawRangeMarkerAtAngle:225.0 centerX:centerX centerY:centerY radius:radius];
        [self drawRangeMarkerAtAngle:90.0 centerX:centerX centerY:centerY radius:radius]; // Center mark
        [self drawRangeMarkerAtAngle:315.0 centerX:centerX centerY:centerY radius:radius];
    } else {
        // Normal: marks at min (210°) and max (330°)
        [self drawRangeMarkerAtAngle:210.0 centerX:centerX centerY:centerY radius:radius];
        [self drawRangeMarkerAtAngle:330.0 centerX:centerX centerY:centerY radius:radius];
    }

    // Calculate indicator angle
    double normalizedValue = (self.doubleValue - self.minValue) / (self.maxValue - self.minValue);
    double angle;

    if (self.bipolar) {
        // Bipolar mode: center at 12 o'clock (90°)
        // Clockwise increases value: min at 225° (left), center at 90°, max at -45°/315° (right)
        angle = 90.0 - ((normalizedValue - 0.5) * 270.0);

        // Draw reference mark at 12 o'clock (center position)
        double centerAngleRad = 90.0 * M_PI / 180.0;
        CGFloat markLength = radius * 0.8;
        CGFloat markX = centerX + cos(centerAngleRad) * markLength;
        CGFloat markY = centerY + sin(centerAngleRad) * markLength;

        NSBezierPath *centerMark = [NSBezierPath bezierPath];
        [centerMark moveToPoint:NSMakePoint(centerX + cos(centerAngleRad) * (radius * 0.75),
                                            centerY + sin(centerAngleRad) * (radius * 0.75))];
        [centerMark lineToPoint:NSMakePoint(markX, markY)];
        [[NSColor colorWithWhite:0.6 alpha:0.5] setStroke];
        [centerMark setLineWidth:2.0];
        [centerMark stroke];
    } else {
        // Normal mode: 7 o'clock to 5 o'clock, sweeping across the top
        // Start at 210° (7:00), sweep through 90° (12:00) to 330° (5:00)
        // Total range: 240° going counter-clockwise (which appears clockwise on a clock)
        angle = 210.0 - (normalizedValue * 240.0);
    }

    double angleRad = angle * M_PI / 180.0;

    // Draw indicator line from center
    CGFloat indicatorLength = radius * 0.65;
    CGFloat indicatorX = centerX + cos(angleRad) * indicatorLength;
    CGFloat indicatorY = centerY + sin(angleRad) * indicatorLength;

    NSBezierPath *indicator = [NSBezierPath bezierPath];
    [indicator moveToPoint:NSMakePoint(centerX, centerY)];
    [indicator lineToPoint:NSMakePoint(indicatorX, indicatorY)];
    [[NSColor colorWithRed:0.3 green:0.6 blue:0.9 alpha:1.0] setStroke];
    [indicator setLineWidth:3.0];
    [indicator setLineCapStyle:NSLineCapStyleRound];
    [indicator stroke];

    // Draw center dot
    CGFloat dotRadius = 4.0;
    NSBezierPath *centerDot = [NSBezierPath bezierPathWithOvalInRect:
        NSMakeRect(centerX - dotRadius, centerY - dotRadius, dotRadius * 2, dotRadius * 2)];
    [[NSColor colorWithWhite:0.3 alpha:1.0] setFill];
    [centerDot fill];
}

- (void)drawRangeMarkerAtAngle:(double)angle centerX:(CGFloat)centerX centerY:(CGFloat)centerY radius:(CGFloat)radius {
    double angleRad = angle * M_PI / 180.0;

    // Draw a small line on the outer edge
    CGFloat outerRadius = radius + 2.0;
    CGFloat innerRadius = radius - 2.0;

    CGFloat outerX = centerX + cos(angleRad) * outerRadius;
    CGFloat outerY = centerY + sin(angleRad) * outerRadius;
    CGFloat innerX = centerX + cos(angleRad) * innerRadius;
    CGFloat innerY = centerY + sin(angleRad) * innerRadius;

    NSBezierPath *marker = [NSBezierPath bezierPath];
    [marker moveToPoint:NSMakePoint(innerX, innerY)];
    [marker lineToPoint:NSMakePoint(outerX, outerY)];
    [[NSColor colorWithWhite:0.6 alpha:0.7] setStroke];
    [marker setLineWidth:2.0];
    [marker setLineCapStyle:NSLineCapStyleRound];
    [marker stroke];
}

- (void)mouseDown:(NSEvent *)event {
    lastMouseLocation = [self convertPoint:[event locationInWindow] fromView:nil];
    startValue = self.doubleValue;
}

- (void)mouseDragged:(NSEvent *)event {
    NSPoint currentLocation = [self convertPoint:[event locationInWindow] fromView:nil];

    // Calculate vertical drag distance
    CGFloat deltaY = currentLocation.y - lastMouseLocation.y;

    // Sensitivity: 100 pixels = full range
    double sensitivity = (self.maxValue - self.minValue) / 100.0;
    double newValue = self.doubleValue + (deltaY * sensitivity);

    // Clamp to min/max
    newValue = MAX(self.minValue, MIN(self.maxValue, newValue));

    if (newValue != self.doubleValue) {
        self.doubleValue = newValue;
        [self setNeedsDisplay:YES];

        // Send action
        [self sendAction:self.action to:self.target];
    }

    lastMouseLocation = currentLocation;
}

- (void)setDoubleValue:(double)value {
    value = MAX(self.minValue, MIN(self.maxValue, value));
    [super setDoubleValue:value];
    [self setNeedsDisplay:YES];
}

- (double)doubleValue {
    return [super doubleValue];
}

- (float)floatValue {
    return (float)self.doubleValue;
}

- (void)setFloatValue:(float)value {
    self.doubleValue = value;
}

@end
