#import "MatrixOscilloscope.h"
#import <pthread.h>

// Forward declare color helpers
@interface ClaudeSynthView : NSView
+ (NSColor *)matrixBackground;
+ (NSColor *)matrixBrightGreen;
+ (NSColor *)matrixMediumGreen;
+ (NSColor *)matrixDimGreen;
@end

@implementation MatrixOscilloscope {
    float *buffer;
    int bufferSize;
    int writeIndex;
    pthread_mutex_t bufferMutex;
    NSTimer *refreshTimer;
}

- (instancetype)initWithFrame:(NSRect)frame {
    self = [super initWithFrame:frame];
    if (self) {
        bufferSize = OSCILLOSCOPE_BUFFER_SIZE;
        buffer = (float *)calloc(bufferSize, sizeof(float));
        writeIndex = 0;
        pthread_mutex_init(&bufferMutex, NULL);

        // Refresh display at 30 FPS
        refreshTimer = [NSTimer scheduledTimerWithTimeInterval:1.0/30.0
                                                        target:self
                                                      selector:@selector(refresh:)
                                                      userInfo:nil
                                                       repeats:YES];
    }
    return self;
}

- (void)dealloc {
    [refreshTimer invalidate];
    pthread_mutex_destroy(&bufferMutex);
    free(buffer);
}

- (void)pushSamples:(const float *)samples count:(int)count {
    pthread_mutex_lock(&bufferMutex);

    for (int i = 0; i < count; i++) {
        buffer[writeIndex] = samples[i];
        writeIndex = (writeIndex + 1) % bufferSize;
    }

    pthread_mutex_unlock(&bufferMutex);
}

- (void)clear {
    pthread_mutex_lock(&bufferMutex);
    memset(buffer, 0, bufferSize * sizeof(float));
    writeIndex = 0;
    pthread_mutex_unlock(&bufferMutex);
    [self setNeedsDisplay:YES];
}

- (void)refresh:(NSTimer *)timer {
    [self setNeedsDisplay:YES];
}

- (void)drawRect:(NSRect)dirtyRect {
    [super drawRect:dirtyRect];

    NSRect bounds = [self bounds];

    // Draw background
    [[ClaudeSynthView matrixBackground] setFill];
    NSRectFill(bounds);

    // Draw border
    [[ClaudeSynthView matrixDimGreen] setStroke];
    NSBezierPath *border = [NSBezierPath bezierPathWithRect:NSInsetRect(bounds, 0.5, 0.5)];
    [border setLineWidth:1.0];
    [border stroke];

    // Draw grid lines
    [[ClaudeSynthView matrixDimGreen] setStroke];
    NSBezierPath *grid = [NSBezierPath bezierPath];
    [grid setLineWidth:0.5];

    // Horizontal center line
    CGFloat centerY = bounds.size.height / 2.0;
    [grid moveToPoint:NSMakePoint(0, centerY)];
    [grid lineToPoint:NSMakePoint(bounds.size.width, centerY)];

    // Vertical grid lines (4 divisions)
    for (int i = 1; i < 4; i++) {
        CGFloat x = (bounds.size.width / 4.0) * i;
        [grid moveToPoint:NSMakePoint(x, 0)];
        [grid lineToPoint:NSMakePoint(x, bounds.size.height)];
    }

    [grid stroke];

    // Draw waveform
    pthread_mutex_lock(&bufferMutex);

    if (writeIndex > 0) {
        NSBezierPath *waveform = [NSBezierPath bezierPath];
        [waveform setLineWidth:1.5];
        [waveform setLineCapStyle:NSLineCapStyleRound];
        [waveform setLineJoinStyle:NSLineJoinStyleRound];

        CGFloat xStep = bounds.size.width / (CGFloat)bufferSize;
        CGFloat yScale = bounds.size.height / 4.0;  // Scale for -1 to 1 range

        BOOL firstPoint = YES;
        for (int i = 0; i < bufferSize; i++) {
            int index = (writeIndex + i) % bufferSize;
            float sample = buffer[index];

            CGFloat x = i * xStep;
            CGFloat y = centerY - (sample * yScale);

            if (firstPoint) {
                [waveform moveToPoint:NSMakePoint(x, y)];
                firstPoint = NO;
            } else {
                [waveform lineToPoint:NSMakePoint(x, y)];
            }
        }

        [[ClaudeSynthView matrixBrightGreen] setStroke];
        [waveform stroke];
    }

    pthread_mutex_unlock(&bufferMutex);
}

@end
