/*****

 Проект «Ретро КР580» (https://github.com/chicherov/Retro80)
 Copyright © 2014-2026 Andrey Chicherov <andrey@chicherov.ru>

 Экран компьютера

*****/

#import "Display.h"
#import "DisplayRenderer.h"

#import "WindowController.h"

@implementation Display
{
	NSMutableData *data1;
	NSMutableData *data2;

	NSObject<TextScreen> __weak *textScreen;

	NSSize graphics;
	NSSize overlay;
	NSSize text;

	BOOL isSelected;
	NSRect selected;

	NSPoint mark;
	BOOL isMark;

	unsigned mode;

	BOOL gigaScreen;
	BOOL grayscale;
	BOOL tvnoise;

	id<DisplayRenderer> renderer;
}

- (uint32_t *)setupGraphicsWidth:(NSUInteger)width height:(NSUInteger)height
{
	@synchronized(self)
	{
		data1 = [NSMutableData dataWithLength:width*height*4];
		graphics.width = width;
		graphics.height = height;
		textScreen = nil;
		text = NSZeroSize;
		data2 = nil;
		overlay = NSZeroSize;

		dispatch_async(dispatch_get_main_queue(), ^{
			[(WindowController *) self.window.windowController resize];
		});

		isSelected = NO;
		selected = NSZeroRect;
		return data1.mutableBytes;
	}
}

- (uint32_t *)setupOverlayWidth:(NSUInteger)width height:(NSUInteger)height
{
	@synchronized(self)
	{
		data2 = [NSMutableData dataWithLength:width*height*4];
		overlay.width = width;
		overlay.height = height;
		return data2.mutableBytes;
	}
}

- (uint32_t *)setupTextWidth:(NSUInteger)width height:(NSUInteger)height cx:(NSUInteger)cx cy:(NSUInteger)cy textScreen:(NSObject<TextScreen> *)ts
{
	@synchronized(self)
	{
		[self setupGraphicsWidth:width*cx height:height*cy];
		textScreen = ts;
		text.width = width;
		text.height = height;
		return data1.mutableBytes;
	}
}

- (NSSize)size
{
	@synchronized(self)
	{
		return graphics;
	}
}

- (void)draw:(BOOL)page
{
	if (page)
	{
		if (data2 && (gigaScreen || graphics.width != overlay.width || graphics.height != overlay.height))
		{
			mode = 3;

			dispatch_async(dispatch_get_main_queue(), ^{
				[self setNeedsDisplay:YES];
			});
		}
		else
		{
			mode = 1;

			dispatch_async(dispatch_get_main_queue(), ^{
				[self setNeedsDisplay:YES];
			});
		}
	}
	else if (!gigaScreen)
	{
		mode = 2;

		dispatch_async(dispatch_get_main_queue(), ^{
			[self setNeedsDisplay:YES];
		});
	}
}

// ---------------------------------------------------------------------------------------------------------------------

- (void)drawRect:(NSRect)rect
{
	@synchronized(self)
	{
		DisplayFrame frame = {0};

		frame.resolution = graphics;
		frame.grayscale = grayscale;
		frame.tvnoise = tvnoise;

		if (((mode & 1) == 0 || data1) && ((mode & 2) == 0 || data2))
		{
			if (mode == 2)
			{
				frame.base = data2.bytes;
				frame.baseSize = overlay;
			}
			else
			{
				frame.base = data1.bytes;
				frame.baseSize = graphics;

				if (mode == 3)
				{
					frame.top = data2.bytes;
					frame.topSize = overlay;
				}
			}

			if (isSelected)
			{
				NSSize size = textScreen ? text : graphics;

				frame.isSelected = YES;
				frame.selection = NSMakeRect(selected.origin.x/size.width,
											 selected.origin.y/size.height,
											 selected.size.width/size.width,
											 selected.size.height/size.height);
			}
		}

		[renderer drawFrame:&frame];
	}
}

- (BOOL)validateMenuItem:(NSMenuItem *)menuItem
{
	if (sel_isEqual(menuItem.action, @selector(selectAll:)))
		return data1 != NULL;

	if (sel_isEqual(menuItem.action, @selector(copy:)))
		return isSelected;

	if (menuItem.action == @selector(gigaScreen:))
	{
		if (menuItem.tag)
		{
			menuItem.state = [[NSUserDefaults standardUserDefaults] boolForKey:@"gigaScreen"];
			return YES;
		}

		if (graphics.width == overlay.width && graphics.height == overlay.height)
		{
			menuItem.state = gigaScreen;
			return YES;
		}

		menuItem.state = NO;
		return NO;
	}

	if (menuItem.action == @selector(grayscale:))
	{
		if (menuItem.tag)
			menuItem.state = [[NSUserDefaults standardUserDefaults] boolForKey:@"grayscale"];
		else
			menuItem.state = grayscale;

		return YES;
	}

	if (menuItem.action == @selector(tvnoise:))
	{
		if (menuItem.tag)
		{
			menuItem.state = [[NSUserDefaults standardUserDefaults] boolForKey:@"tvnoise"];
			return YES;
		}

		menuItem.state = tvnoise && renderer.hasEffects;
		return renderer.hasEffects;
	}

	return NO;
}

- (IBAction)gigaScreen:(NSMenuItem *)menuItem
{
	@synchronized(self)
	{
		if (menuItem.tag)
			[NSUserDefaults.standardUserDefaults
				setBool:(gigaScreen = ![NSUserDefaults.standardUserDefaults boolForKey:@"gigaScreen"])
				 forKey:@"gigaScreen"];
		else
			gigaScreen = !gigaScreen;
	}
}

- (IBAction)grayscale:(NSMenuItem *)menuItem
{
	@synchronized(self)
	{
		if (menuItem.tag)
			[NSUserDefaults.standardUserDefaults
				setBool:(grayscale = ![NSUserDefaults.standardUserDefaults boolForKey:@"grayscale"])
				 forKey:@"grayscale"];
		else
			grayscale = !grayscale;
	}
}

- (IBAction)tvnoise:(NSMenuItem *)menuItem
{
	@synchronized(self)
	{
		if (menuItem.tag)
			[NSUserDefaults.standardUserDefaults
				setBool:(tvnoise = ![NSUserDefaults.standardUserDefaults boolForKey:@"tvnoise"])
				 forKey:@"tvnoise"];
		else
			tvnoise = !tvnoise;
	}
}

- (IBAction)selectAll:(NSMenuItem *)menuItem
{
	@synchronized(self)
	{
		isSelected = YES;
		selected.origin = NSZeroPoint;
		selected.size = textScreen ? text : graphics;
	}
}

- (void)mouseDown:(NSEvent *)theEvent
{
	@synchronized(self)
	{
		NSPoint point = [self convertPoint:theEvent.locationInWindow fromView:nil];
		NSSize size = textScreen ? text : graphics;

		mark.y = trunc(size.height - point.y/self.frame.size.height*size.height);
		mark.x = trunc(point.x/self.frame.size.width*size.width);

		isSelected = NO;
		isMark = YES;

		NSCharacterSet *isAlphaNumber = [NSCharacterSet alphanumericCharacterSet];

		if (textScreen && theEvent.clickCount == 2)
		{
			if ([isAlphaNumber characterIsMember:[textScreen unicharAtX:mark.x Y:mark.y]])
			{
				selected.size.height = 1;
				selected.size.width = 1;

				selected.origin = mark;
				isSelected = YES;

				while (selected.origin.x + selected.size.width < text.width)
				{
					unichar ch = [textScreen unicharAtX:selected.origin.x + selected.size.width Y:selected.origin.y];

					if ([isAlphaNumber characterIsMember:ch])
						selected.size.width += 1;
					else
						break;
				}

				while (selected.origin.x >= 1)
				{
					unichar ch = [textScreen unicharAtX:selected.origin.x - 1 Y:selected.origin.y];

					if ([isAlphaNumber characterIsMember:ch])
					{
						selected.size.width += 1;
						selected.origin.x -= 1;
					}
					else
						break;
				}

				mark = selected.origin;
			}
		}
	}
}

- (void)mouseUp:(NSEvent *)theEvent
{
	isMark = NO;
}

- (void)mouseDragged:(NSEvent *)theEvent
{
	if (isMark)
	{
		@synchronized(self)
		{
			NSPoint point = [self convertPoint:theEvent.locationInWindow fromView:nil];
			NSSize size = textScreen ? text : graphics;

			point.y = trunc(size.height - point.y/self.frame.size.height*size.height);
			point.x = trunc(point.x/self.frame.size.width*size.width);

			if (point.y < size.height && point.x < size.width)
			{
				if (point.y < mark.y)
				{
					selected.origin.y = point.y;
					selected.size.height = mark.y - point.y + 1;
				}
				else
				{
					selected.origin.y = mark.y;
					selected.size.height = point.y - mark.y + 1;
				}

				if (point.x < mark.x)
				{
					selected.origin.x = point.x;
					selected.size.width = mark.x - point.x + 1;
				}
				else
				{
					selected.origin.x = mark.x;
					selected.size.width = point.x - mark.x + 1;
				}

				isSelected = YES;
			}
		}
	}
}

- (void)keyDown:(NSEvent *)theEvent
{
	[super keyDown:theEvent];
	isSelected = NO;
}

- (IBAction)copy:(NSMenuItem *)menuItem
{
	@synchronized(self)
	{
		if (isSelected)
		{
			NSPasteboard *pasteBoard = [NSPasteboard generalPasteboard];

			if (textScreen)
			{
				NSMutableString *string = [[NSMutableString alloc] init];

				for (unsigned y = selected.origin.y; y < selected.origin.y + selected.size.height; y++)
				{
					int count = 0;

					for (unsigned x = selected.origin.x; x < selected.origin.x + selected.size.width; x++)
					{
						unichar ch = [textScreen unicharAtX:x Y:y];

						if (ch == ' ')
							count++;
						else
							count = 0;

						[string appendString:[NSString stringWithCharacters:&ch length:1]];
					}

					if (selected.size.height > 1)
					{
						if (count)
							[string deleteCharactersInRange:NSMakeRange(string.length - count, count)];

						[string appendString:@"\n"];
					}
				}

				[pasteBoard declareTypes:@[NSPasteboardTypeString, NSPasteboardTypeTIFF] owner:nil];
				[pasteBoard setString:string forType:NSPasteboardTypeString];

				selected.origin.x = selected.origin.x*graphics.width/text.width;
				selected.origin.y = selected.origin.y*graphics.height/text.height;

				selected.size.width = selected.size.width*graphics.width/text.width;
				selected.size.height = selected.size.height*graphics.height/text.height;
			}

			else
			{
				[pasteBoard declareTypes:@[NSPasteboardTypeTIFF] owner:nil];
			}

			NSRect rect = NSIntersectionRect(selected, NSMakeRect(0, 0, graphics.width, graphics.height));

			NSBitmapImageRep *image = [[NSBitmapImageRep alloc]
				initWithBitmapDataPlanes:NULL
							  pixelsWide:rect.size.width
							  pixelsHigh:rect.size.height
						   bitsPerSample:8
						 samplesPerPixel:3
								hasAlpha:NO
								isPlanar:NO
						  colorSpaceName:NSDeviceRGBColorSpace
							 bytesPerRow:0
							bitsPerPixel:0];

			if (image && data1)
			{
				NSUInteger gw = graphics.width, gh = graphics.height;
				NSUInteger ow = overlay.width, oh = overlay.height;

				const uint8_t *base = data1.bytes;
				const uint8_t *top = NULL;

				if (data2 && (gigaScreen || gw != ow || gh != oh))
					top = data2.bytes;

				for (NSUInteger y = 0; y < rect.size.height; y++)
				{
					uint8_t *dst = image.bitmapData + y*image.bytesPerRow;
					NSUInteger gy = rect.origin.y + y;

					for (NSUInteger x = 0; x < rect.size.width; x++, dst += 3)
					{
						NSUInteger gx = rect.origin.x + x;
						const uint8_t *src = base + (gy*gw + gx)*4;

						if (top)
						{
							// Верхний слой растягивается до размера нижнего по ближайшему пикселю
							const uint8_t *src2 = top + ((gy*2 + 1)*oh/(gh*2)*ow + (gx*2 + 1)*ow/(gw*2))*4;
							unsigned alpha = src2[3];

							for (int c = 0; c < 3; c++)
								dst[c] = (uint8_t) ((src2[c]*alpha + src[c]*(255 - alpha) + 127)/255);
						}
						else
						{
							dst[0] = src[0];
							dst[1] = src[1];
							dst[2] = src[2];
						}
					}
				}
			}

			if (image)
				[pasteBoard setData:[image TIFFRepresentation]
							forType:NSPasteboardTypeTIFF];

			isSelected = NO;
		}
	}
}

// ---------------------------------------------------------------------------------------------------------------------

- (void)awakeFromNib
{
	gigaScreen = [NSUserDefaults.standardUserDefaults boolForKey:@"gigaScreen"];
	grayscale = [NSUserDefaults.standardUserDefaults boolForKey:@"grayscale"];
	tvnoise = [NSUserDefaults.standardUserDefaults boolForKey:@"tvnoise"];

	mode = 1;

#ifndef GNUSTEP
	// Перерисовка только по setNeedsDisplay:, как у NSOpenGLView
	self.device = MTLCreateSystemDefaultDevice();
	self.paused = YES;
	self.enableSetNeedsDisplay = YES;
	self.layer.opaque = YES;

	// Без пересчёта в профиль монитора, как у NSOpenGLView: палитры подобраны под это
	self.colorspace = nil;

	renderer = [[DisplayMetal alloc] initWithView:self];
#else
	renderer = [[DisplayGL alloc] initWithView:self];
#endif
}

- (void)dealloc
{
#ifndef NDEBUG
	NSLog(@"%@ dealloc", NSStringFromClass(self.class));
#endif
}

@end
