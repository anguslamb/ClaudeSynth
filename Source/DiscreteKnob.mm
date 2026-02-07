#import "DiscreteKnob.h"
#import <QuartzCore/QuartzCore.h>

@implementation DiscreteKnob {
    NSPoint lastMouseLocation;
    int startPosition;
}

- (id)initWithFrame:(NSRect)frame {
    self = [super initWithFrame:frame];
    if (self) {
        _numberOfPositions = 4;
        _selectedPosition = 0;
        _labels = @[@"Sine", @"Square", @"Saw", @"Tri"];
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
    NSGradient *gradient = [[NSGradient alloc] initWithStartingColor:[NSColor colorWithWhite:0.35 alpha:1.0]
                                                         endingColor:[NSColor colorWithWhite:0.2 alpha:1.0]];
    [gradient drawInBezierPath:outerCircle angle:-90];

    // Draw position markers around the knob
    for (int i = 0; i < self.numberOfPositions; i++) {
        double angle = -135.0 + (i / (double)(self.numberOfPositions - 1)) * 270.0;
        double angleRad = angle * M_PI / 180.0;

        CGFloat markerRadius = radius + 8.0;
        CGFloat markerX = centerX + cos(angleRad) * markerRadius;
        CGFloat markerY = centerY + sin(angleRad) * markerRadius;

        NSBezierPath *marker = [NSBezierPath bezierPathWithOvalInRect:
            NSMakeRect(markerX - 2, markerY - 2, 4, 4)];

        if (i == self.selectedPosition) {
            [[NSColor colorWithRed:0.3 green:0.6 blue:0.9 alpha:1.0] setFill];
        } else {
            [[NSColor colorWithWhite:0.5 alpha:1.0] setFill];
        }
        [marker fill];
    }

    // Draw border
    [[NSColor colorWithWhite:0.5 alpha:1.0] setStroke];
    [outerCircle setLineWidth:1.0];
    [outerCircle stroke];

    // Draw inner circle (darker center)
    CGFloat innerRadius = radius * 0.65;
    NSBezierPath *innerCircle = [NSBezierPath bezierPathWithOvalInRect:
        NSMakeRect(centerX - innerRadius, centerY - innerRadius, innerRadius * 2, innerRadius * 2)];
    [[NSColor colorWithWhite:0.15 alpha:1.0] setFill];
    [innerCircle fill];

    // Calculate indicator angle for selected position
    double angle = -135.0 + (self.selectedPosition / (double)(self.numberOfPositions - 1)) * 270.0;
    double angleRad = angle * M_PI / 180.0;

    // Draw indicator line from center
    CGFloat indicatorLength = radius * 0.6;
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

    // Draw label below knob
    if (self.selectedPosition < self.labels.count) {
        NSString *label = self.labels[self.selectedPosition];
        NSDictionary *attributes = @{
            NSFontAttributeName: [NSFont systemFontOfSize:11],
            NSForegroundColorAttributeName: [NSColor whiteColor]
        };
        NSSize labelSize = [label sizeWithAttributes:attributes];
        NSPoint labelPoint = NSMakePoint(centerX - labelSize.width / 2.0, 5);
        [label drawAtPoint:labelPoint withAttributes:attributes];
    }
}

- (void)mouseDown:(NSEvent *)event {
    lastMouseLocation = [self convertPoint:[event locationInWindow] fromView:nil];
    startPosition = self.selectedPosition;
}

- (void)mouseDragged:(NSEvent *)event {
    NSPoint currentLocation = [self convertPoint:[event locationInWindow] fromView:nil];

    // Calculate vertical drag distance
    CGFloat deltaY = currentLocation.y - lastMouseLocation.y;

    // Sensitivity: 30 pixels per position
    int positionChange = (int)(deltaY / 30.0);
    int newPosition = startPosition + positionChange;

    // Clamp to valid range
    newPosition = MAX(0, MIN(self.numberOfPositions - 1, newPosition));

    if (newPosition != self.selectedPosition) {
        self.selectedPosition = newPosition;
        [self setNeedsDisplay:YES];

        // Send action
        [self sendAction:self.action to:self.target];
    }
}

- (void)setSelectedPosition:(int)position {
    _selectedPosition = MAX(0, MIN(self.numberOfPositions - 1, position));
    [self setNeedsDisplay:YES];
}

- (double)doubleValue {
    return (double)self.selectedPosition;
}

- (void)setDoubleValue:(double)value {
    self.selectedPosition = (int)round(value);
}

- (float)floatValue {
    return (float)self.selectedPosition;
}

- (void)setFloatValue:(float)value {
    self.selectedPosition = (int)roundf(value);
}

- (int)intValue {
    return self.selectedPosition;
}

- (void)setIntValue:(int)value {
    self.selectedPosition = value;
}

@end
