/*****

 Проект «Ретро КР580» (https://github.com/chicherov/Retro80)

 Отрисовка экрана компьютера через OpenGL

 *****/

#ifndef GNUSTEP
// На Apple вместо него DisplayMetal, этот файл только компилируется
#define GL_SILENCE_DEPRECATION
#pragma clang diagnostic ignored "-Wdeprecated-declarations"
#import <OpenGL/gl.h>
#else
#define GL_GLEXT_PROTOTYPES
#import <GL/gl.h>
#import <GL/glext.h>
#endif

#import "DisplayRenderer.h"

static GLuint createShader(GLenum shaderType)
{
	NSString
		*file = [NSBundle.mainBundle pathForResource:@"tvnoise" ofType:shaderType == GL_VERTEX_SHADER ? @"vs" : @"fs"],
		*text = [NSString stringWithContentsOfFile:file encoding:NSASCIIStringEncoding error:NULL];

	const GLchar *source = (GLchar *) [text cStringUsingEncoding:NSASCIIStringEncoding];

	if (source == 0)
		return 0;

	GLuint shader = glCreateShader(shaderType);

	if (shader == 0)
		return 0;

	glShaderSource(shader, 1, &source, NULL);
	glCompileShader(shader);

#ifndef NDEBUG
	GLint logLength; glGetShaderiv(shader, GL_INFO_LOG_LENGTH, &logLength);

	if (logLength > 0)
	{
		GLchar *log = malloc((size_t) logLength);
		glGetShaderInfoLog(shader, logLength, &logLength, log);
		NSLog(@"Shader compilation failed:\n%s", log);
		free(log);
	}
#endif

	GLint status; glGetShaderiv(shader, GL_COMPILE_STATUS, &status);

	if (!status)
	{
		glDeleteShader(shader);
		return 0;
	}

	return shader;
}

static void drawQuad(void)
{
	glBegin(GL_QUADS);
	glTexCoord2f(0.0, 0.0); glVertex2f(-1.0,  1.0);
	glTexCoord2f(1.0, 0.0); glVertex2f( 1.0,  1.0);
	glTexCoord2f(1.0, 1.0); glVertex2f( 1.0, -1.0);
	glTexCoord2f(0.0, 1.0); glVertex2f(-1.0, -1.0);
	glEnd();
}

@implementation DisplayGL
{
	NSOpenGLView __weak *view;
	NSOpenGLContext *context;

	GLuint shaderProgram;
}

- (instancetype)initWithView:(NSOpenGLView *)openGLView
{
	if (self = [super init])
	{
		view = openGLView;
		context = openGLView.openGLContext;

#ifndef GNUSTEP
		[openGLView setWantsBestResolutionOpenGLSurface:YES];
		[context makeCurrentContext];
#endif

		GLuint fragmentShader = createShader(GL_FRAGMENT_SHADER);

		if (fragmentShader)
		{
			GLuint vertexShader = createShader(GL_VERTEX_SHADER);

			if (vertexShader)
			{
				shaderProgram = glCreateProgram();
				glAttachShader(shaderProgram, fragmentShader);
				glAttachShader(shaderProgram, vertexShader);
				glLinkProgram(shaderProgram);

#ifndef NDEBUG
				GLint logLength; glGetProgramiv(shaderProgram, GL_INFO_LOG_LENGTH, &logLength);

				if (logLength > 0)
				{
					GLchar *log = malloc((size_t) logLength);
					glGetProgramInfoLog(shaderProgram, logLength, &logLength, log);
					NSLog(@"Shader program linking failed:\n%s", log);
					free(log);
				}
#endif

				GLint status; glGetProgramiv(shaderProgram, GL_LINK_STATUS, &status);

				if (!status)
				{
					glDeleteProgram(shaderProgram);
					shaderProgram = 0;
				}

				glDeleteShader(vertexShader);
			}

			glDeleteShader(fragmentShader);
		}
	}

	return self;
}

- (BOOL)hasEffects
{
	return shaderProgram != 0;
}

- (void)drawFrame:(const DisplayFrame *)frame
{
#ifndef GNUSTEP
	NSRect backingBounds = [view convertRectToBacking:[view bounds]];
#else
	NSRect backingBounds = [view bounds];
#endif
	glViewport(0, 0, backingBounds.size.width, backingBounds.size.height);

	if (frame->base)
	{
		BOOL shader = frame->tvnoise && shaderProgram;

		if (frame->grayscale && !shader)
		{
			glMatrixMode(GL_COLOR);
			glPushMatrix();

			static float mat[] = {
				0.30, 0.30, 0.30, 0.00,
				0.59, 0.59, 0.58, 0.00,
				0.11, 0.11, 0.11, 0.00,
				0.00, 0.00, 0.00, 1.00
			};

			glLoadMatrixf(mat);

			glMatrixMode(GL_MODELVIEW);
		}

		glEnable(GL_TEXTURE_2D);

		GLuint tex[2];
		glGenTextures(2, tex);

		glActiveTexture(GL_TEXTURE0);
		glBindTexture(GL_TEXTURE_2D, tex[0]);
		glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_MIN_FILTER, frame->tvnoise ? GL_LINEAR : GL_NEAREST);
		glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_MAG_FILTER, frame->tvnoise ? GL_LINEAR : GL_NEAREST);

		glTexImage2D(GL_TEXTURE_2D,
					 0,
					 GL_RGBA,
					 (GLsizei) frame->baseSize.width,
					 (GLsizei) frame->baseSize.height,
					 0,
					 GL_RGBA,
					 GL_UNSIGNED_BYTE,
					 frame->base);

		if (frame->top)
		{
			glBindTexture(GL_TEXTURE_2D, tex[1]);
			glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_MIN_FILTER, frame->tvnoise ? GL_LINEAR : GL_NEAREST);
			glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_MAG_FILTER, frame->tvnoise ? GL_LINEAR : GL_NEAREST);

			glTexImage2D(GL_TEXTURE_2D,
						 0,
						 GL_RGBA,
						 (GLsizei) frame->topSize.width,
						 (GLsizei) frame->topSize.height,
						 0,
						 GL_RGBA,
						 GL_UNSIGNED_BYTE,
						 frame->top);
		}

		if (frame->grayscale && !shader)
		{
			glMatrixMode(GL_COLOR);
			glPopMatrix();

			glMatrixMode(GL_MODELVIEW);
		}

		if (shader)
		{
			glUseProgram(shaderProgram);

			GLint location;

			if ((location = glGetUniformLocation(shaderProgram, "time")) != -1)
				glUniform1f(location, (float) [[NSProcessInfo processInfo] systemUptime]);

			if ((location = glGetUniformLocation(shaderProgram, "resolution")) != -1)
				glUniform2f(location, frame->resolution.width, frame->resolution.height);

			if ((location = glGetUniformLocation(shaderProgram, "grayscale")) != -1)
				glUniform1i(location, frame->grayscale);

			if ((location = glGetUniformLocation(shaderProgram, "tex0")) != -1)
			{
				glActiveTexture(GL_TEXTURE0);
				glBindTexture(GL_TEXTURE_2D, tex[0]);
				glUniform1i(location, 0);
			}

			if ((location = glGetUniformLocation(shaderProgram, "blend")) != -1)
				glUniform1i(location, frame->top != NULL);

			if (frame->top && (location = glGetUniformLocation(shaderProgram, "tex1")) != -1)
			{
				glActiveTexture(GL_TEXTURE1);
				glBindTexture(GL_TEXTURE_2D, tex[1]);
				glUniform1i(location, 1);
			}

			drawQuad();

			glUseProgram(0);
		}

		else
		{
			glActiveTexture(GL_TEXTURE0);
			glBindTexture(GL_TEXTURE_2D, tex[0]);

			drawQuad();

			if (frame->top)
			{
				glEnable(GL_BLEND);
				glBlendFunc(GL_SRC_ALPHA, GL_ONE_MINUS_SRC_ALPHA);

				glBindTexture(GL_TEXTURE_2D, tex[1]);

				drawQuad();

				glDisable(GL_BLEND);
			}
		}

		glActiveTexture(0);

		glBindTexture(GL_TEXTURE_2D, 0);
		glDeleteTextures(2, tex);
		glDisable(GL_TEXTURE_2D);

		if (frame->isSelected)
		{
			NSRect sel = frame->selection;

			glEnable(GL_BLEND);
			glBlendFunc(GL_SRC_ALPHA, GL_ONE_MINUS_SRC_ALPHA);

			glColor4f(1.0, 1.0, 1.0, 0.5);

			glBegin(GL_QUADS);
			glVertex2f(NSMinX(sel)*2 - 1, 1 - NSMinY(sel)*2);
			glVertex2f(NSMaxX(sel)*2 - 1, 1 - NSMinY(sel)*2);
			glVertex2f(NSMaxX(sel)*2 - 1, 1 - NSMaxY(sel)*2);
			glVertex2f(NSMinX(sel)*2 - 1, 1 - NSMaxY(sel)*2);
			glEnd();

			glColor4f(1.0, 1.0, 1.0, 1.0);
			glDisable(GL_BLEND);
		}
	}
	else
	{
		glClear(GL_COLOR_BUFFER_BIT);
	}

	[context flushBuffer];
	glFlush();
}

- (void)dealloc
{
	if (shaderProgram)
	{
#ifndef GNUSTEP
		[context makeCurrentContext];
#endif
		glDeleteProgram(shaderProgram);
	}
}

@end
