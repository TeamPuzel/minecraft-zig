
const c = @import("c.zig");

const Image = @import("image.zig").Image;

pub const Application = struct {    
    _window: *c.SDL_Window,
    _context: c.SDL_GLContext,
    _event: c.SDL_Event = undefined,
    
    pub fn init(name: [:0]const u8, w: i32, h: i32) !Application {
        _ = c.SDL_Init(c.SDL_INIT_VIDEO);
        _ = c.IMG_Init(c.IMG_INIT_PNG);
        _ = c.SDL_GL_LoadLibrary(null);
        
        const window = c.SDL_CreateWindow(
            name.ptr,
            c.SDL_WINDOWPOS_UNDEFINED,
            c.SDL_WINDOWPOS_UNDEFINED,
            w, h,
            c.SDL_WINDOW_ALLOW_HIGHDPI |
            c.SDL_WINDOW_OPENGL |
            c.SDL_WINDOW_ALWAYS_ON_TOP |
            c.SDL_WINDOW_RESIZABLE
        ) orelse return error.CreatingWindow;
        
        _ = c.SDL_SetRelativeMouseMode(1);
        
        // OpenGL
        _ = c.SDL_GL_SetAttribute(c.SDL_GL_CONTEXT_MAJOR_VERSION, 1);
        _ = c.SDL_GL_SetAttribute(c.SDL_GL_CONTEXT_MINOR_VERSION, 1);
        _ = c.SDL_GL_SetAttribute(
            c.SDL_GL_CONTEXT_PROFILE_MASK, c.SDL_GL_CONTEXT_PROFILE_COMPATIBILITY
        );
        _ = c.SDL_GL_SetAttribute(c.SDL_GL_DOUBLEBUFFER, 1);
        _ = c.SDL_GL_SetSwapInterval(1);
        
        const context = c.SDL_GL_CreateContext(window);
        
        c.glColor3f(1, 1, 1);
        c.glClearColor(0.0, 0.0, 0.0, 1.0);
        c.glEnable(c.GL_DEPTH_TEST);
        c.glEnable(c.GL_TEXTURE_2D);
        c.glEnable(c.GL_CULL_FACE);
        
        return .{            
            ._window = window,
            ._context = context
        };
    }
    
    pub fn deinit(self: *Application) void {
        c.SDL_GL_DeleteContext(self._context);
        c.SDL_DestroyWindow(self._window);
        c.IMG_Quit();
        c.SDL_Quit();
    }
    
    pub fn shouldQuit(self: *Application) bool {
        while (c.SDL_PollEvent(&self._event) > 0) {
            switch (self._event.type) {
                c.SDL_QUIT => return true,
                else => break
            }
        }
        return false;
    }
    
    pub fn getActualSize(self: *Application) packed struct { width: i32, height: i32 } {
        var w: i32 = undefined;
        var h: i32 = undefined;
        c.SDL_GL_GetDrawableSize(self._window, &w, &h);
        return .{ .width = w, .height = h };
    }
    
    pub fn lockCursor(self: *Application, v: bool) void {
        _ = self;
        if (v) c.SDL_SetRelativeMouseMode(1)
        else c.SDL_SetRelativeMouseMode(0);
    }
    
    pub fn pngToRGBA(self: *Application, bytes: []const u8) Image {
        _ = self;
        const rw = c.SDL_RWFromConstMem(bytes.ptr, @intCast(bytes.len));
        const temp_surface = c.IMG_Load_RW(rw, 0);
        defer c.SDL_FreeSurface(temp_surface);
        const surface = c.SDL_ConvertSurfaceFormat(temp_surface, c.SDL_PIXELFORMAT_RGBA32, 0);
        
        _ = c.SDL_RWclose(rw);
        return .{
            .width = surface.*.w,
            .height = surface.*.h,
            .pixels = @ptrCast(@alignCast(surface.*.pixels)),
            ._surface = surface
        };
    }
    
    pub fn swapBuffers(self: *Application) void {
        c.SDL_GL_SwapWindow(self._window);
    }
};