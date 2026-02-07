#import "ClaudeSynthView.h"

@implementation ClaudeSynthView

- (id)initWithFrame:(NSRect)frame audioUnit:(AudioUnit)au {
    self = [super initWithFrame:frame];
    if (self) {
        mAU = au;

        // Set background color
        [self setWantsLayer:YES];
        self.layer.backgroundColor = [[NSColor colorWithWhite:0.2 alpha:1.0] CGColor];

        // Create label
        NSTextField *label = [[NSTextField alloc] initWithFrame:NSMakeRect(0, 0, frame.size.width, frame.size.height)];
        [label setStringValue:@"ClaudeSynth"];
        [label setAlignment:NSTextAlignmentCenter];
        [label setBezeled:NO];
        [label setDrawsBackground:NO];
        [label setEditable:NO];
        [label setSelectable:NO];
        [label setFont:[NSFont systemFontOfSize:24 weight:NSFontWeightBold]];
        [label setTextColor:[NSColor whiteColor]];
        [self addSubview:label];
    }
    return self;
}

@end

// Factory function for creating the view
@interface ClaudeSynthViewFactory : NSObject <AUCocoaUIBase>
@end

@implementation ClaudeSynthViewFactory

- (unsigned)interfaceVersion {
    return 0;
}

- (NSString *)description {
    return @"ClaudeSynth UI";
}

- (NSView *)uiViewForAudioUnit:(AudioUnit)inAudioUnit withSize:(NSSize)inPreferredSize {
    // Create view with a reasonable default size
    NSRect frame = NSMakeRect(0, 0, 400, 200);
    if (inPreferredSize.width > 0 && inPreferredSize.height > 0) {
        frame.size = inPreferredSize;
    }

    ClaudeSynthView *view = [[ClaudeSynthView alloc] initWithFrame:frame audioUnit:inAudioUnit];
    return view;
}

@end

// Export the factory function
extern "C" {
    __attribute__((visibility("default")))
    void *ClaudeSynthViewFactory_Factory(CFAllocatorRef allocator, CFUUIDRef typeID) {
        return [[ClaudeSynthViewFactory alloc] init];
    }
}
