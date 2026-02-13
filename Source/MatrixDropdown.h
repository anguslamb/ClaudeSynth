#import <Cocoa/Cocoa.h>

@interface MatrixDropdown : NSControl

@property (nonatomic, strong) NSArray<NSString *> *items;
@property (nonatomic, assign) NSInteger selectedIndex;

- (void)addItemWithTitle:(NSString *)title;
- (void)selectItemAtIndex:(NSInteger)index;
- (NSInteger)indexOfSelectedItem;

@end
