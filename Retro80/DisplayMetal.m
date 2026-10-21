/*****

 Проект «Ретро КР580» (https://github.com/chicherov/Retro80)

 Отрисовка экрана компьютера через Metal

 *****/

#import <MetalKit/MetalKit.h>
#import <simd/simd.h>

#import "DisplayRenderer.h"

// Шейдеры компилируются при запуске: так не нужен отдельный шаг сборки
// .metal ни в Xcode, ни в CMake. tvnoiseFragment — перенос tvnoise.fs

static NSString *const shaderSource = @
"#include <metal_stdlib>\n"
"using namespace metal;\n"
"\n"
"struct VertexOut {\n"
"	float4 position [[position]];\n"
"	float2 texcoord;\n"
"};\n"
"\n"
"struct Uniforms {\n"
"	float2 resolution;\n"
"	float time;\n"
"	int grayscale;\n"
"	int blend;\n"
"	int linear;\n"
"};\n"
"\n"
"constexpr sampler nearestSampler(filter::nearest, address::clamp_to_edge);\n"
"constexpr sampler linearSampler(filter::linear, address::clamp_to_edge);\n"
"constexpr sampler tvnoiseSampler(filter::linear, address::repeat);\n"
"\n"
"static float3 gray(float3 c) {\n"
"	return float3(dot(c, float3(0.30, 0.59, 0.11)));\n"
"}\n"
"\n"
"// Прямоугольник на весь экран, треугольниками: (0, 0) текстуры — левый верхний угол\n"
"vertex VertexOut quadVertex(uint vid [[vertex_id]]) {\n"
"	const float2 pos[4] = { float2(-1, 1), float2(1, 1), float2(-1, -1), float2(1, -1) };\n"
"	VertexOut out;\n"
"	out.position = float4(pos[vid], 0, 1);\n"
"	out.texcoord = float2(pos[vid].x + 1, 1 - pos[vid].y) * 0.5;\n"
"	return out;\n"
"}\n"
"\n"
"vertex VertexOut selectionVertex(uint vid [[vertex_id]], constant float2 *pos [[buffer(0)]]) {\n"
"	VertexOut out;\n"
"	out.position = float4(pos[vid], 0, 1);\n"
"	out.texcoord = float2(0);\n"
"	return out;\n"
"}\n"
"\n"
"fragment float4 plainFragment(VertexOut in [[stage_in]],\n"
"                              texture2d<float> tex [[texture(0)]],\n"
"                              constant Uniforms &u [[buffer(0)]]) {\n"
"	float4 c = u.linear ? tex.sample(linearSampler, in.texcoord) : tex.sample(nearestSampler, in.texcoord);\n"
"	return float4(u.grayscale ? gray(c.rgb) : c.rgb, c.a);\n"
"}\n"
"\n"
"fragment float4 solidFragment(VertexOut in [[stage_in]]) {\n"
"	return float4(1.0, 1.0, 1.0, 0.5);\n"
"}\n"
"\n"
"static float4 shifted(texture2d<float> tex, float2 uv, float dx) {\n"
"	float4 c;\n"
"	c.r = tex.sample(tvnoiseSampler, float2(uv.x + dx, uv.y)).r;\n"
"	c.g = tex.sample(tvnoiseSampler, uv).g;\n"
"	c.b = tex.sample(tvnoiseSampler, float2(uv.x - dx, uv.y)).b;\n"
"	c.a = tex.sample(tvnoiseSampler, uv).a;\n"
"	return c;\n"
"}\n"
"\n"
"fragment float4 tvnoiseFragment(VertexOut in [[stage_in]],\n"
"                                texture2d<float> tex0 [[texture(0)]],\n"
"                                texture2d<float> tex1 [[texture(1)]],\n"
"                                constant Uniforms &u [[buffer(0)]]) {\n"
"	const float distortion = 0.1;\n"
"	const float zoom = 1.0;\n"
"	float2 texcoord = in.texcoord;\n"
"\n"
"	// radial distortion\n"
"	float2 uv = texcoord - 0.5;\n"
"	float dist = dot(uv, uv) * distortion;\n"
"	uv = 0.5 + (texcoord + uv * (1.0 + dist) * dist - 0.5) * zoom;\n"
"\n"
"	// subtle zoom in/out\n"
"	uv = 0.5 + (uv - 0.5) * (0.997 + 0.003 * sin(0.95 * u.time));\n"
"	uv = clamp(uv, 0.0, 1.0);\n"
"\n"
"	// rgb shift\n"
"	float dx = 1.0 / u.resolution.x;\n"
"	float4 col = shifted(tex0, uv, dx);\n"
"\n"
"	if (u.blend) {\n"
"		float4 c = shifted(tex1, uv, dx);\n"
"		col = mix(col, c, c.a);\n"
"	}\n"
"\n"
"	// scanline\n"
"	col *= 0.8 + 0.2 * sin(10.0 * u.time + texcoord.y * u.resolution.y * 8.0);\n"
"\n"
"	return float4(u.grayscale ? gray(col.rgb) : col.rgb, 1.0);\n"
"}\n";

typedef struct
{
	simd_float2 resolution;
	float time;
	int grayscale;
	int blend;
	int linear;

} Uniforms;

static id<MTLTexture> updateTexture(id<MTLDevice> device, __strong id<MTLTexture> *texture,
									const void *data, NSSize size)
{
	NSUInteger width = size.width, height = size.height;

	if (width == 0 || height == 0)
		return nil;

	if (*texture == nil || (*texture).width != width || (*texture).height != height)
	{
		MTLTextureDescriptor *descriptor = [MTLTextureDescriptor
			texture2DDescriptorWithPixelFormat:MTLPixelFormatRGBA8Unorm
										 width:width
										height:height
									 mipmapped:NO];

		descriptor.usage = MTLTextureUsageShaderRead;
		*texture = [device newTextureWithDescriptor:descriptor];
	}

	[*texture replaceRegion:MTLRegionMake2D(0, 0, width, height)
				mipmapLevel:0
				  withBytes:data
				bytesPerRow:width*4];

	return *texture;
}

@implementation DisplayMetal
{
	MTKView __weak *view;

	id<MTLDevice> device;
	id<MTLCommandQueue> queue;

	id<MTLRenderPipelineState> plainPipeline;
	id<MTLRenderPipelineState> blendPipeline;
	id<MTLRenderPipelineState> tvnoisePipeline;
	id<MTLRenderPipelineState> selectionPipeline;

	id<MTLTexture> baseTexture;
	id<MTLTexture> topTexture;

	id<MTLCommandBuffer> lastCommandBuffer;
	CFTimeInterval startTime;
}

- (id<MTLRenderPipelineState>)pipelineWithLibrary:(id<MTLLibrary>)library
										   vertex:(NSString *)vertex
										 fragment:(NSString *)fragment
											blend:(BOOL)blend
{
	MTLRenderPipelineDescriptor *descriptor = [[MTLRenderPipelineDescriptor alloc] init];
	descriptor.vertexFunction = [library newFunctionWithName:vertex];
	descriptor.fragmentFunction = [library newFunctionWithName:fragment];

	MTLRenderPipelineColorAttachmentDescriptor *attachment = descriptor.colorAttachments[0];
	attachment.pixelFormat = view.colorPixelFormat;

	// Экран непрозрачный: альфа из кадра влияет только на смешивание
	attachment.writeMask = MTLColorWriteMaskRed | MTLColorWriteMaskGreen | MTLColorWriteMaskBlue;

	if (blend)
	{
		attachment.blendingEnabled = YES;
		attachment.sourceRGBBlendFactor = MTLBlendFactorSourceAlpha;
		attachment.destinationRGBBlendFactor = MTLBlendFactorOneMinusSourceAlpha;
	}

	NSError *error = nil;
	id<MTLRenderPipelineState> pipeline = [device newRenderPipelineStateWithDescriptor:descriptor error:&error];

	if (pipeline == nil)
		NSLog(@"Metal pipeline %@ failed: %@", fragment, error);

	return pipeline;
}

- (instancetype)initWithView:(MTKView *)mtkView
{
	if (self = [super init])
	{
		view = mtkView;

		if ((device = mtkView.device) == nil)
			return nil;

		queue = [device newCommandQueue];

		NSError *error = nil;
		id<MTLLibrary> library = [device newLibraryWithSource:shaderSource options:nil error:&error];

		if (library == nil)
		{
			NSLog(@"Metal shader compilation failed: %@", error);
			return nil;
		}

		plainPipeline = [self pipelineWithLibrary:library vertex:@"quadVertex" fragment:@"plainFragment" blend:NO];
		blendPipeline = [self pipelineWithLibrary:library vertex:@"quadVertex" fragment:@"plainFragment" blend:YES];
		tvnoisePipeline = [self pipelineWithLibrary:library vertex:@"quadVertex" fragment:@"tvnoiseFragment" blend:NO];
		selectionPipeline = [self pipelineWithLibrary:library vertex:@"selectionVertex" fragment:@"solidFragment" blend:YES];

		if (plainPipeline == nil || blendPipeline == nil || selectionPipeline == nil)
			return nil;

		mtkView.clearColor = MTLClearColorMake(0.0, 0.0, 0.0, 1.0);
		startTime = CACurrentMediaTime();
	}

	return self;
}

- (BOOL)hasEffects
{
	return tvnoisePipeline != nil;
}

- (void)drawFrame:(const DisplayFrame *)frame
{
	MTKView *mtkView = view;

	// Текстуры используются повторно: прошлый кадр должен дочитать их до перезаписи
	[lastCommandBuffer waitUntilCompleted];

	MTLRenderPassDescriptor *pass = mtkView.currentRenderPassDescriptor;
	id<CAMetalDrawable> drawable = mtkView.currentDrawable;

	if (pass == nil || drawable == nil)
		return;

	id<MTLCommandBuffer> commandBuffer = [queue commandBuffer];
	id<MTLRenderCommandEncoder> encoder = [commandBuffer renderCommandEncoderWithDescriptor:pass];

	id<MTLTexture> base = frame->base ? updateTexture(device, &baseTexture, frame->base, frame->baseSize) : nil;

	if (base)
	{
		id<MTLTexture> top = frame->top ? updateTexture(device, &topTexture, frame->top, frame->topSize) : nil;

		Uniforms uniforms = {
			.resolution = simd_make_float2(frame->resolution.width, frame->resolution.height),
			.time = (float) (CACurrentMediaTime() - startTime),
			.grayscale = frame->grayscale,
			.blend = top != nil,
			.linear = frame->tvnoise
		};

		[encoder setFragmentBytes:&uniforms length:sizeof(uniforms) atIndex:0];

		if (frame->tvnoise && tvnoisePipeline)
		{
			[encoder setRenderPipelineState:tvnoisePipeline];
			[encoder setFragmentTexture:base atIndex:0];
			[encoder setFragmentTexture:top ?: base atIndex:1];
			[encoder drawPrimitives:MTLPrimitiveTypeTriangleStrip vertexStart:0 vertexCount:4];
		}
		else
		{
			[encoder setRenderPipelineState:plainPipeline];
			[encoder setFragmentTexture:base atIndex:0];
			[encoder drawPrimitives:MTLPrimitiveTypeTriangleStrip vertexStart:0 vertexCount:4];

			if (top)
			{
				[encoder setRenderPipelineState:blendPipeline];
				[encoder setFragmentTexture:top atIndex:0];
				[encoder drawPrimitives:MTLPrimitiveTypeTriangleStrip vertexStart:0 vertexCount:4];
			}
		}

		if (frame->isSelected)
		{
			NSRect sel = frame->selection;

			simd_float2 pos[4] = {
				simd_make_float2(NSMinX(sel)*2 - 1, 1 - NSMinY(sel)*2),
				simd_make_float2(NSMaxX(sel)*2 - 1, 1 - NSMinY(sel)*2),
				simd_make_float2(NSMinX(sel)*2 - 1, 1 - NSMaxY(sel)*2),
				simd_make_float2(NSMaxX(sel)*2 - 1, 1 - NSMaxY(sel)*2)
			};

			[encoder setRenderPipelineState:selectionPipeline];
			[encoder setVertexBytes:pos length:sizeof(pos) atIndex:0];
			[encoder drawPrimitives:MTLPrimitiveTypeTriangleStrip vertexStart:0 vertexCount:4];
		}
	}

	[encoder endEncoding];
	[commandBuffer presentDrawable:drawable];
	[commandBuffer commit];

	lastCommandBuffer = commandBuffer;
}

@end
