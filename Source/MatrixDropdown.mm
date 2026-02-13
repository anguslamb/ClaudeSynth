#import "MatrixDropdown.h"

// Forward declare color helpers
@interface ClaudeSynthView : NSView
+ (NSColor *)matrixBackground;
+ (NSColor *)matrixBrightGreen;
+ (NSColor *)matrixMediumGreen;
+ (NSColor *)matrixDimGreen;
+ (NSFont *)matrixFontOfSize:(CGFloat)size;
@end

@interface MatrixDropdown()
@property (nonatomic, strong) NSMutableArray<NSString *> *mutableItems;
@property (nonatomic, assign) BOOL isHighlighted;
@property (nonatomic, assign) NSInteger controlTag;
@end

@implementation MatrixDropdown

- (instancetype)initWithFrame:(NSRect)frame {
    self = [super initWithFrame:frame];
    if (self) {
        _mutableItems = [NSMutableArray array];
        _selectedIndex = 0;
        _isHighlighted = NO;
        _controlTag = 0;
    }
    return self;
}

- (void)addItemWithTitle:(NSString *)title {
    [self.mutableItems addObject:title];
}

- (void)selectItemAtIndex:(NSInteger)index {
    if (index >= 0 && index < self.mutableItems.count) {
        _selectedIndex = index;
        [self setNeedsDisplay:YES];
    }
}

- (NSInteger)indexOfSelectedItem {
    return _selectedIndex;
}

- (NSArray<NSString *> *)items {
    return [self.mutableItems copy];
}

- (void)setTag:(NSInteger)tag {
    _controlTag = tag;
}

- (NSInteger)tag {
    return _controlTag;
}

- (void)drawRect:(NSRect)dirtyRect {
    [super drawRect:dirtyRect];

    NSRect bounds = [self bounds];

    // Draw background
    [[NSColor colorWithRed:0.0 green:0.08 blue:0.0 alpha:1.0] setFill];
    NSRectFill(bounds);

    // Draw border
    NSBezierPath *border = [NSBezierPath bezierPathWithRect:NSInsetRect(bounds, 0.5, 0.5)];
    if (_isHighlighted) {
        [[ClaudeSynthView matrixBrightGreen] setStroke];
    } else {
        [[ClaudeSynthView matrixMediumGreen] setStroke];
    }
    [border setLineWidth:1.0];
    [border stroke];

    // Draw selected item text
    if (_selectedIndex >= 0 && _selectedIndex < self.mutableItems.count) {
        NSString *selectedText = self.mutableItems[_selectedIndex];
        NSDictionary *attrs = @{
            NSFontAttributeName: [ClaudeSynthView matrixFontOfSize:11],
            NSForegroundColorAttributeName: [ClaudeSynthView matrixBrightGreen]
        };

        NSSize textSize = [selectedText sizeWithAttributes:attrs];
        CGFloat textX = 8;
        CGFloat textY = (bounds.size.height - textSize.height) / 2.0;
        [selectedText drawAtPoint:NSMakePoint(textX, textY) withAttributes:attrs];
    }

    // Draw dropdown arrow
    CGFloat arrowX = bounds.size.width - 18;
    CGFloat arrowY = bounds.size.height / 2.0;

    NSBezierPath *arrow = [NSBezierPath bezierPath];
    [arrow moveToPoint:NSMakePoint(arrowX, arrowY - 2)];
    [arrow lineToPoint:NSMakePoint(arrowX + 6, arrowY - 2)];
    [arrow lineToPoint:NSMakePoint(arrowX + 3, arrowY + 2)];
    [arrow closePath];

    [[ClaudeSynthView matrixMediumGreen] setFill];
    [arrow fill];
}

- (void)mouseDown:(NSEvent *)event {
    _isHighlighted = YES;
    [self setNeedsDisplay:YES];

    [self showMenu];

    _isHighlighted = NO;
    [self setNeedsDisplay:YES];
}

- (void)showMenu {
    if (self.mutableItems.count == 0) return;

    // Create custom menu
    NSMenu *menu = [[NSMenu alloc] initWithTitle:@""];
    [menu setFont:[ClaudeSynthView matrixFontOfSize:11]];

    // Force dark appearance on menu
    if (@available(macOS 10.14, *)) {
        [menu setAppearance:[NSAppearance appearanceNamed:NSAppearanceNameDarkAqua]];
    }

    // Add menu items with custom styling
    for (NSInteger i = 0; i < self.mutableItems.count; i++) {
        NSString *title = self.mutableItems[i];
        NSMenuItem *item = [[NSMenuItem alloc] initWithTitle:title action:@selector(menuItemSelected:) keyEquivalent:@""];
        [item setTarget:self];
        [item setTag:i];

        // Style the menu item
        NSDictionary *attrs = @{
            NSFontAttributeName: [ClaudeSynthView matrixFontOfSize:11],
            NSForegroundColorAttributeName: [ClaudeSynthView matrixBrightGreen]
        };
        [item setAttributedTitle:[[NSAttributedString alloc] initWithString:title attributes:attrs]];

        // Mark selected item
        if (i == _selectedIndex) {
            [item setState:NSControlStateValueOn];
        }

        [menu addItem:item];
    }

    // Show menu below the control
    NSRect frame = [self frame];
    NSPoint menuOrigin = [self convertPoint:NSMakePoint(0, 0) toView:nil];
    menuOrigin = [[self window] convertPointToScreen:menuOrigin];
    menuOrigin.y -= 5; // Slight offset

    [menu popUpMenuPositioningItem:nil atLocation:menuOrigin inView:nil];
}

- (void)menuItemSelected:(NSMenuItem *)sender {
    _selectedIndex = [sender tag];
    [self setNeedsDisplay:YES];

    // Send action to target
    if (self.target && self.action) {
        [NSApp sendAction:self.action to:self.target from:self];
    }
}

- (BOOL)acceptsFirstResponder {
    return YES;
}

@end
