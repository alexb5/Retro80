#import <objc/runtime.h>

// -[NSLayoutConstraint setConstant:] есть не во всех версиях GNUstep, а реализация
// в категории подменила бы настоящую. Поэтому заглушка добавляется, только если метода нет

static void setConstantStub(id self, SEL _cmd, CGFloat constant) { }

@interface NSLayoutConstraint (GNUstepStub)
@end

@implementation NSLayoutConstraint (GNUstepStub)
+ (void)load
{
	char types[16];
	snprintf(types, sizeof(types), "%s%s%s%s", @encode(void), @encode(id), @encode(SEL), @encode(CGFloat));
	class_addMethod(self, @selector(setConstant:), (IMP) setConstantStub, types);
}
@end

@implementation NSMenuItem (GNUstep)
- (void)setHidden:(BOOL)hidden {}
- (BOOL)hidden { return NO; }
@end

@implementation NSDocument (GNUstep)
- (BOOL)inViewingMode { return NO; }
@end
