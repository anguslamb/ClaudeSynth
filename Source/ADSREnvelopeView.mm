#import "ADSREnvelopeView.h"

@interface ClaudeSynthView : NSView
+ (NSColor *)matrixBrightGreen;
+ (NSColor *)matrixMediumGreen;
+ (NSColor *)matrixDimGreen;
+ (NSColor *)matrixDarkGreen;
+ (NSColor *)matrixBackground;
@end

typedef enum {
    kDragNone = 0,
    kDragAttack,
    kDragDecay,
    kDragSustain,
    kDragRelease
} DragMode;

@implementation ADSREnvelopeView {
    DragMode _dragMode;
    NSPoint _lastMousePoint;
}

- (instancetype)initWithFrame:(NSRect)frame {
    self = [super initWithFrame:frame];
    if (self) {
        _attack = 0.01f;
        _decay = 0.1f;
        _sustain = 0.7f;
        _releaseTime = 0.3f;
        _dragMode = kDragNone;
    }
    return self;
}

- (void)drawRect:(NSRect)dirtyRect {
    [super drawRect:dirtyRect];

    NSRect bounds = [self bounds];
    CGFloat width = bounds.size.width;
    CGFloat height = bounds.size.height;
    CGFloat padding = 10.0;
    CGFloat graphWidth = width - 2 * padding;
    CGFloat graphHeight = height - 2 * padding;

    // Draw background
    [[ClaudeSynthView matrixBackground] setFill];
    NSRectFill(bounds);

    // Calculate envelope points
    // Time scale: map 0-3 seconds to graph width
    CGFloat maxTime = 3.0f;
    CGFloat attackX = padding + (self.attack / maxTime) * graphWidth * 0.3f; // Use 30% of width for attack
    CGFloat decayX = attackX + (self.decay / maxTime) * graphWidth * 0.3f;   // Use 30% of width for decay
    CGFloat sustainX = decayX + graphWidth * 0.2f;                           // Use 20% of width for sustain
    CGFloat releaseX = sustainX + (self.releaseTime / maxTime) * graphWidth * 0.2f; // Use 20% of width for release

    // Y positions (inverted because NSView coordinates)
    CGFloat bottomY = padding;
    CGFloat topY = height - padding;
    CGFloat attackY = topY;
    CGFloat sustainY = bottomY + self.sustain * graphHeight;

    // Draw grid lines
    [[ClaudeSynthView matrixDimGreen] setStroke];
    NSBezierPath *gridPath = [NSBezierPath bezierPath];
    [gridPath setLineWidth:0.5];

    // Horizontal grid lines
    for (int i = 0; i <= 4; i++) {
        CGFloat y = bottomY + (i / 4.0) * graphHeight;
        [gridPath moveToPoint:NSMakePoint(padding, y)];
        [gridPath lineToPoint:NSMakePoint(width - padding, y)];
    }
    [gridPath stroke];

    // Draw envelope curve
    NSBezierPath *envelopePath = [NSBezierPath bezierPath];
    [envelopePath setLineWidth:2.0];
    [envelopePath setLineCapStyle:NSLineCapStyleRound];
    [envelopePath setLineJoinStyle:NSLineJoinStyleRound];

    // Start at origin
    [envelopePath moveToPoint:NSMakePoint(padding, bottomY)];

    // Attack phase
    [envelopePath lineToPoint:NSMakePoint(attackX, attackY)];

    // Decay phase
    [envelopePath lineToPoint:NSMakePoint(decayX, sustainY)];

    // Sustain phase
    [envelopePath lineToPoint:NSMakePoint(sustainX, sustainY)];

    // Release phase
    [envelopePath lineToPoint:NSMakePoint(releaseX, bottomY)];

    // Draw the envelope line
    [[ClaudeSynthView matrixBrightGreen] setStroke];
    [envelopePath stroke];

    // Draw draggable vertices (small green squares)
    CGFloat vertexSize = 6.0;  // Total size of the square
    CGFloat halfSize = vertexSize / 2.0;
    [[ClaudeSynthView matrixBrightGreen] setFill];  // Green to match line
    [[ClaudeSynthView matrixBrightGreen] setStroke];

    // Attack vertex
    NSBezierPath *attackVertex = [NSBezierPath bezierPathWithRect:
        NSMakeRect(attackX - halfSize, attackY - halfSize, vertexSize, vertexSize)];
    [attackVertex fill];

    // Decay/Sustain vertex
    NSBezierPath *decayVertex = [NSBezierPath bezierPathWithRect:
        NSMakeRect(decayX - halfSize, sustainY - halfSize, vertexSize, vertexSize)];
    [decayVertex fill];

    // Release vertex (at end of sustain, before release)
    NSBezierPath *releaseVertex = [NSBezierPath bezierPathWithRect:
        NSMakeRect(sustainX - halfSize, sustainY - halfSize, vertexSize, vertexSize)];
    [releaseVertex fill];

    // Release end vertex
    NSBezierPath *releaseEndVertex = [NSBezierPath bezierPathWithRect:
        NSMakeRect(releaseX - halfSize, bottomY - halfSize, vertexSize, vertexSize)];
    [releaseEndVertex fill];

    // Draw labels
    NSDictionary *labelAttrs = @{
        NSFontAttributeName: [NSFont fontWithName:@"Monaco" size:9] ?: [NSFont systemFontOfSize:9],
        NSForegroundColorAttributeName: [ClaudeSynthView matrixMediumGreen]
    };

    [@"A" drawAtPoint:NSMakePoint(attackX - 3, topY + 2) withAttributes:labelAttrs];
    [@"D" drawAtPoint:NSMakePoint(decayX - 3, sustainY + 2) withAttributes:labelAttrs];
    [@"S" drawAtPoint:NSMakePoint((decayX + sustainX) / 2 - 3, sustainY - 15) withAttributes:labelAttrs];
    [@"R" drawAtPoint:NSMakePoint(releaseX - 3, bottomY - 15) withAttributes:labelAttrs];
}

- (void)mouseDown:(NSEvent *)event {
    NSPoint point = [self convertPoint:[event locationInWindow] fromView:nil];

    NSRect bounds = [self bounds];
    CGFloat width = bounds.size.width;
    CGFloat height = bounds.size.height;
    CGFloat padding = 10.0;
    CGFloat graphWidth = width - 2 * padding;
    CGFloat graphHeight = height - 2 * padding;

    // Calculate vertex positions
    CGFloat maxTime = 3.0f;
    CGFloat attackX = padding + (self.attack / maxTime) * graphWidth * 0.3f;
    CGFloat decayX = attackX + (self.decay / maxTime) * graphWidth * 0.3f;
    CGFloat sustainX = decayX + graphWidth * 0.2f;
    CGFloat releaseX = sustainX + (self.releaseTime / maxTime) * graphWidth * 0.2f;

    CGFloat bottomY = padding;
    CGFloat topY = height - padding;
    CGFloat attackY = topY;
    CGFloat sustainY = bottomY + self.sustain * graphHeight;

    CGFloat hitRadius = 12.0;  // Larger hit area for easier clicking

    // Check which vertex was clicked
    if (fabs(point.x - attackX) < hitRadius && fabs(point.y - attackY) < hitRadius) {
        _dragMode = kDragAttack;
    } else if (fabs(point.x - decayX) < hitRadius && fabs(point.y - sustainY) < hitRadius) {
        _dragMode = kDragDecay;
    } else if (fabs(point.x - sustainX) < hitRadius && fabs(point.y - sustainY) < hitRadius) {
        _dragMode = kDragSustain;
    } else if (fabs(point.x - releaseX) < hitRadius && fabs(point.y - bottomY) < hitRadius) {
        _dragMode = kDragRelease;
    } else {
        _dragMode = kDragNone;
    }

    _lastMousePoint = point;
}

- (void)mouseDragged:(NSEvent *)event {
    if (_dragMode == kDragNone) return;

    NSPoint point = [self convertPoint:[event locationInWindow] fromView:nil];

    NSRect bounds = [self bounds];
    CGFloat width = bounds.size.width;
    CGFloat height = bounds.size.height;
    CGFloat padding = 10.0;
    CGFloat graphWidth = width - 2 * padding;
    CGFloat graphHeight = height - 2 * padding;
    CGFloat maxTime = 3.0f;

    CGFloat deltaX = point.x - _lastMousePoint.x;
    CGFloat deltaY = point.y - _lastMousePoint.y;

    BOOL changed = NO;

    switch (_dragMode) {
        case kDragAttack: {
            // Attack: drag horizontally to change time
            float deltaTime = (deltaX / (graphWidth * 0.3f)) * maxTime;
            self.attack = fmaxf(0.001f, fminf(3.0f, self.attack + deltaTime));
            changed = YES;
            break;
        }
        case kDragDecay: {
            // Decay: drag horizontally for time, vertically for sustain level
            float deltaTime = (deltaX / (graphWidth * 0.3f)) * maxTime;
            self.decay = fmaxf(0.001f, fminf(3.0f, self.decay + deltaTime));

            float deltaLevel = deltaY / graphHeight;
            self.sustain = fmaxf(0.0f, fminf(1.0f, self.sustain + deltaLevel));
            changed = YES;
            break;
        }
        case kDragSustain: {
            // Sustain: drag vertically only to change level
            float deltaLevel = deltaY / graphHeight;
            self.sustain = fmaxf(0.0f, fminf(1.0f, self.sustain + deltaLevel));
            changed = YES;
            break;
        }
        case kDragRelease: {
            // Release: drag horizontally to change time
            float deltaTime = (deltaX / (graphWidth * 0.2f)) * maxTime;
            self.releaseTime = fmaxf(0.001f, fminf(3.0f, self.releaseTime + deltaTime));
            changed = YES;
            break;
        }
        default:
            break;
    }

    if (changed) {
        [self setNeedsDisplay:YES];

        // Send action
        if (self.target && self.action) {
            [NSApp sendAction:self.action to:self.target from:self];
        }
    }

    _lastMousePoint = point;
}

- (void)mouseUp:(NSEvent *)event {
    _dragMode = kDragNone;
}

@end
