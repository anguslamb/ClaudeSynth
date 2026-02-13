#import "MatrixSlider.h"

// Forward declare color helpers
@interface ClaudeSynthView : NSView
+ (NSColor *)matrixBackground;
+ (NSColor *)matrixBrightGreen;
+ (NSColor *)matrixMediumGreen;
+ (NSColor *)matrixDimGreen;
+ (NSFont *)matrixFontOfSize:(CGFloat)size;
@end

@implementation MatrixSlider {
    NSPoint lastMouseLocation;
    double _doubleValue;
}

- (instancetype)initWithFrame:(NSRect)frame {
    self = [super initWithFrame:frame];
    if (self) {
        _minValue = 0.0;
        _maxValue = 1.0;
        _doubleValue = 0.0;
        _numberOfTickMarks = 0;
        _vertical = YES;
    }
    return self;
}

- (void)drawRect:(NSRect)dirtyRect {
    [super drawRect:dirtyRect];

    NSRect bounds = [self bounds];
    BOOL isVertical = bounds.size.height > bounds.size.width;

    if (isVertical) {
        [self drawVerticalSlider:bounds];
    } else {
        [self drawHorizontalSlider:bounds];
    }
}

- (void)drawVerticalSlider:(NSRect)bounds {
    CGFloat trackWidth = 4.0;
    CGFloat trackX = (bounds.size.width - trackWidth) / 2.0;
    CGFloat trackHeight = bounds.size.height - 20;
    CGFloat trackY = 10;

    // Draw track
    NSRect trackRect = NSMakeRect(trackX, trackY, trackWidth, trackHeight);
    [[NSColor colorWithRed:0.0 green:0.08 blue:0.0 alpha:1.0] setFill];
    NSRectFill(trackRect);

    [[ClaudeSynthView matrixDimGreen] setStroke];
    NSBezierPath *trackBorder = [NSBezierPath bezierPathWithRect:trackRect];
    [trackBorder setLineWidth:1.0];
    [trackBorder stroke];

    // Draw tick marks if specified
    if (_numberOfTickMarks > 1) {
        for (int i = 0; i < _numberOfTickMarks; i++) {
            CGFloat tickY = trackY + (trackHeight * i / (_numberOfTickMarks - 1));
            NSBezierPath *tick = [NSBezierPath bezierPath];
            [tick moveToPoint:NSMakePoint(trackX - 3, tickY)];
            [tick lineToPoint:NSMakePoint(trackX, tickY)];
            [[ClaudeSynthView matrixDimGreen] setStroke];
            [tick setLineWidth:1.0];
            [tick stroke];
        }
    }

    // Calculate thumb position
    double normalizedValue = (_doubleValue - _minValue) / (_maxValue - _minValue);
    CGFloat thumbY = trackY + (trackHeight * normalizedValue);

    // Draw filled track (from bottom to thumb)
    if (normalizedValue > 0) {
        NSRect filledRect = NSMakeRect(trackX + 1, trackY + 1, trackWidth - 2, (thumbY - trackY) - 1);
        [[ClaudeSynthView matrixMediumGreen] setFill];
        NSRectFill(filledRect);
    }

    // Draw thumb
    CGFloat thumbWidth = 12.0;
    CGFloat thumbHeight = 6.0;
    NSRect thumbRect = NSMakeRect(bounds.size.width / 2.0 - thumbWidth / 2.0,
                                   thumbY - thumbHeight / 2.0,
                                   thumbWidth, thumbHeight);

    [[ClaudeSynthView matrixBrightGreen] setFill];
    NSRectFill(thumbRect);

    [[ClaudeSynthView matrixMediumGreen] setStroke];
    NSBezierPath *thumbBorder = [NSBezierPath bezierPathWithRect:thumbRect];
    [thumbBorder setLineWidth:1.0];
    [thumbBorder stroke];
}

- (void)drawHorizontalSlider:(NSRect)bounds {
    CGFloat trackHeight = 4.0;
    CGFloat trackY = (bounds.size.height - trackHeight) / 2.0;
    CGFloat trackWidth = bounds.size.width - 20;
    CGFloat trackX = 10;

    // Draw track
    NSRect trackRect = NSMakeRect(trackX, trackY, trackWidth, trackHeight);
    [[NSColor colorWithRed:0.0 green:0.08 blue:0.0 alpha:1.0] setFill];
    NSRectFill(trackRect);

    [[ClaudeSynthView matrixDimGreen] setStroke];
    NSBezierPath *trackBorder = [NSBezierPath bezierPathWithRect:trackRect];
    [trackBorder setLineWidth:1.0];
    [trackBorder stroke];

    // Calculate thumb position
    double normalizedValue = (_doubleValue - _minValue) / (_maxValue - _minValue);
    CGFloat thumbX = trackX + (trackWidth * normalizedValue);

    // Draw filled track (from left to thumb)
    if (normalizedValue > 0) {
        NSRect filledRect = NSMakeRect(trackX + 1, trackY + 1, (thumbX - trackX) - 1, trackHeight - 2);
        [[ClaudeSynthView matrixMediumGreen] setFill];
        NSRectFill(filledRect);
    }

    // Draw thumb
    CGFloat thumbWidth = 6.0;
    CGFloat thumbHeight = 12.0;
    NSRect thumbRect = NSMakeRect(thumbX - thumbWidth / 2.0,
                                   bounds.size.height / 2.0 - thumbHeight / 2.0,
                                   thumbWidth, thumbHeight);

    [[ClaudeSynthView matrixBrightGreen] setFill];
    NSRectFill(thumbRect);

    [[ClaudeSynthView matrixMediumGreen] setStroke];
    NSBezierPath *thumbBorder = [NSBezierPath bezierPathWithRect:thumbRect];
    [thumbBorder setLineWidth:1.0];
    [thumbBorder stroke];
}

- (void)mouseDown:(NSEvent *)event {
    lastMouseLocation = [self convertPoint:[event locationInWindow] fromView:nil];
    [self updateValueFromMouseLocation:lastMouseLocation];
}

- (void)mouseDragged:(NSEvent *)event {
    NSPoint currentLocation = [self convertPoint:[event locationInWindow] fromView:nil];
    [self updateValueFromMouseLocation:currentLocation];
    lastMouseLocation = currentLocation;
}

- (void)updateValueFromMouseLocation:(NSPoint)location {
    NSRect bounds = [self bounds];
    BOOL isVertical = bounds.size.height > bounds.size.width;

    double normalizedValue;
    if (isVertical) {
        CGFloat trackHeight = bounds.size.height - 20;
        CGFloat trackY = 10;
        normalizedValue = (location.y - trackY) / trackHeight;
    } else {
        CGFloat trackWidth = bounds.size.width - 20;
        CGFloat trackX = 10;
        normalizedValue = (location.x - trackX) / trackWidth;
    }

    // Clamp to 0-1
    normalizedValue = fmax(0.0, fmin(1.0, normalizedValue));

    // Snap to tick marks if specified
    if (_numberOfTickMarks > 1) {
        int tickIndex = (int)round(normalizedValue * (_numberOfTickMarks - 1));
        normalizedValue = tickIndex / (double)(_numberOfTickMarks - 1);
    }

    // Convert to actual value
    double newValue = _minValue + (normalizedValue * (_maxValue - _minValue));

    if (newValue != _doubleValue) {
        _doubleValue = newValue;
        [self setNeedsDisplay:YES];

        // Send action
        if (self.target && self.action) {
            [NSApp sendAction:self.action to:self.target from:self];
        }
    }
}

- (double)doubleValue {
    return _doubleValue;
}

- (void)setDoubleValue:(double)value {
    _doubleValue = fmax(_minValue, fmin(_maxValue, value));
    [self setNeedsDisplay:YES];
}

- (float)floatValue {
    return (float)_doubleValue;
}

- (void)setFloatValue:(float)value {
    self.doubleValue = value;
}

- (int)intValue {
    return (int)round(_doubleValue);
}

- (void)setIntValue:(int)value {
    self.doubleValue = value;
}

- (BOOL)acceptsFirstResponder {
    return YES;
}

@end
