/*****

 Проект «Ретро КР580» (https://github.com/chicherov/Retro80)

 Отрисовка экрана компьютера

 *****/

// Кадр для отрисовки: нижний слой, необязательный верхний слой
// с альфа-смешиванием и выделение поверх них

typedef struct DisplayFrame
{
	const void *base;		// RGBA, NULL — очистить экран
	NSSize baseSize;

	const void *top;		// RGBA, NULL — без верхнего слоя
	NSSize topSize;

	NSSize resolution;		// размер графического экрана, для шейдера

	BOOL grayscale;
	BOOL tvnoise;

	BOOL isSelected;
	NSRect selection;		// в долях экрана, начало координат слева сверху

} DisplayFrame;

@protocol DisplayRenderer <NSObject>

// Доступен режим «старый телевизор»
@property(nonatomic, readonly) BOOL hasEffects;

- (void)drawFrame:(const DisplayFrame *)frame;

@end

// Под GNUstep; на Apple только компилируется, чтобы не сломать его незаметно
#pragma clang diagnostic push
#pragma clang diagnostic ignored "-Wdeprecated-declarations"
@interface DisplayGL : NSObject<DisplayRenderer>
- (instancetype)initWithView:(NSOpenGLView *)view;
@end
#pragma clang diagnostic pop

#ifndef GNUSTEP
@class MTKView;

@interface DisplayMetal : NSObject<DisplayRenderer>
- (instancetype)initWithView:(MTKView *)view;
@end
#endif
