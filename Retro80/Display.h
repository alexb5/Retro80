/*****

 Проект «Ретро КР580» (https://github.com/chicherov/Retro80)
 Copyright © 2014-2018 Andrey Chicherov <chicherov@mac.com>

 Экран компьютера

 *****/

#import "Digit.h"

#ifndef GNUSTEP
#import <MetalKit/MetalKit.h>
#endif

@protocol TextScreen
- (unichar)unicharAtX:(unsigned)x Y:(unsigned)y;
@end

#ifndef GNUSTEP
@interface Display : MTKView
#else
@interface Display : NSOpenGLView
#endif

@property IBOutlet Digit *digit1;
@property IBOutlet Digit *digit2;
@property IBOutlet Digit *digit3;
@property IBOutlet Digit *digit4;
@property IBOutlet Digit *digit5;
@property IBOutlet Digit *digit6;

- (uint32_t *)setupGraphicsWidth:(NSUInteger)width
						  height:(NSUInteger)height;

- (uint32_t *)setupOverlayWidth:(NSUInteger)width
						 height:(NSUInteger)height;

- (uint32_t *)setupTextWidth:(NSUInteger)width
					  height:(NSUInteger)height
						  cx:(NSUInteger)cx
						  cy:(NSUInteger)cy
				  textScreen:(NSObject<TextScreen> *)textScreen;

- (void)draw:(BOOL)page;

- (NSSize)size;

@end
