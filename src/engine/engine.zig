
const std = @import("std");
const c = @import("c.zig");

pub const math = @import("math.zig");
pub const noise = @import("noise.zig");
pub const graphics = @import("graphics.zig");

pub const Window = struct {
    window: *c.SDL_Window,
    context: c.SDL_GLContext,
    width: i32,
    height: i32,
    
    pub var shared: *Window = undefined;
    
    const initial_width = 800;
    const initial_height = 600;
    
    pub fn init(name: [:0]const u8) !Window {
        if (c.SDL_Init(c.SDL_INIT_VIDEO) != 0) return error.InitializingSDL;
        _ = c.IMG_Init(c.IMG_INIT_PNG);
        _ = c.SDL_GL_LoadLibrary(null);
        
        const window = c.SDL_CreateWindow(
            name,
            c.SDL_WINDOWPOS_CENTERED,
            c.SDL_WINDOWPOS_CENTERED,
            initial_width, initial_height,
            c.SDL_WINDOW_ALLOW_HIGHDPI |
            c.SDL_WINDOW_OPENGL |
            c.SDL_WINDOW_RESIZABLE
        ) orelse return error.CreatingWindow;
        
        _ = c.SDL_SetWindowMinimumSize(window, initial_width, initial_height);
        
        _ = c.SDL_GL_SetAttribute(c.SDL_GL_CONTEXT_MAJOR_VERSION, 4);
        _ = c.SDL_GL_SetAttribute(c.SDL_GL_CONTEXT_MINOR_VERSION, 1);
        _ = c.SDL_GL_SetAttribute(
            c.SDL_GL_CONTEXT_PROFILE_MASK, c.SDL_GL_CONTEXT_PROFILE_CORE
        );
        _ = c.SDL_GL_SetAttribute(c.SDL_GL_DOUBLEBUFFER, 1);
        _ = c.SDL_GL_SetAttribute(c.SDL_GL_DEPTH_SIZE, 24);
        _ = c.SDL_GL_SetSwapInterval(1);
        
        const context = c.SDL_GL_CreateContext(window);
        
        _ = c.gladLoadGLLoader(&c.SDL_GL_GetProcAddress);
        
        std.log.debug(
            \\OpenGL initialized successfully.
            \\- Vendor: {s}
            \\- Version: {s}
            \\- Renderer: {s}
            \\- GLSL: {s}
            \\
            , .{
                c.glGetString(c.GL_VENDOR),
                c.glGetString(c.GL_VERSION),
                c.glGetString(c.GL_RENDERER),
                c.glGetString(c.GL_SHADING_LANGUAGE_VERSION)
            }
        );
        
        // OpenGL boilerplate
        var boilerplate: u32 = undefined;
        c.glGenVertexArrays(1, &boilerplate);
        c.glBindVertexArray(boilerplate);
        c.glEnableVertexAttribArray(boilerplate);
        
        c.glClearColor(0.0, 0.0, 0.0, 1.0);
        c.glEnable(c.GL_DEPTH_TEST);
        c.glEnable(c.GL_CULL_FACE);
        c.glEnable(c.GL_BLEND);
        c.glBlendFunc(c.GL_SRC_ALPHA, c.GL_ONE_MINUS_SRC_ALPHA);
        
        var w: i32 = undefined;
        var h: i32 = undefined;
        c.SDL_GL_GetDrawableSize(window, &w, &h);
        
        input.init();
        
        return .{
            .window = window,
            .context = context,
            .width = w,
            .height = h
        };
    }
    
    pub fn deinit(self: Window) void {
        c.SDL_GL_DeleteContext(self.context);
        c.SDL_DestroyWindow(self.window);
        c.IMG_Quit();
        c.SDL_Quit();
    }
    
    var event: c.SDL_Event = undefined;
    
    pub fn update(self: *Window) bool {
        c.SDL_GL_GetDrawableSize(self.window, &self.width, &self.height);
        
        Window.shared = self;
        
        while (c.SDL_PollEvent(&event) > 0) {
            switch (event.type) {
                c.SDL_QUIT => return false,
                else => break
            }
        }
        return true;
    }
    
    pub fn lockCursor(self: *Window, value: bool) void {
        _ = self;
        if (value) _ = c.SDL_SetRelativeMouseMode(1)
        else _ = c.SDL_SetRelativeMouseMode(0);
    }

    pub fn swapBuffers(self: *Window) void {
        c.SDL_GL_SwapWindow(self.window);
    }
    
    pub fn clear(self: *Window) void {
        _ = self;
        c.glClear(c.GL_COLOR_BUFFER_BIT | c.GL_DEPTH_BUFFER_BIT);
    }
};

pub const input = struct {
    var keymap: [*c]const u8 = undefined;
    
    fn init() void {
        keymap = c.SDL_GetKeyboardState(null);
    }
    
    pub inline fn relativeMouse() packed struct { x: f32, y: f32 } {
        var x: i32 = undefined;
        var y: i32 = undefined;
        _ = c.SDL_GetRelativeMouseState(&x, &y);
        const fx: f32 = @floatFromInt(x);
        const fy: f32 = @floatFromInt(y);
        return .{ .x = fx, .y = fy };
    }
    
    pub inline fn key(comptime name: Key) bool {
        return switch (name) {
            .w => keymap[c.SDL_SCANCODE_W],
            .a => keymap[c.SDL_SCANCODE_A],
            .s => keymap[c.SDL_SCANCODE_S],
            .d => keymap[c.SDL_SCANCODE_D],
            
            .left_shift => keymap[c.SDL_SCANCODE_LSHIFT],
            .space => keymap[c.SDL_SCANCODE_SPACE],
            
            else => std.debug.panic("Unimplemented input: {any}", .{ name })
        } == 1;
    }
    
    pub const Key = enum {
        a, b, c, d, e, f,
        g, h, i, j, k, l,
        m, n, o, p, q, r,
        s, t, u, v, w, x,
        y, z,
        
        num_1, num_2,
        num_3, num_4,
        num_5, num_6,
        num_7, num_8,
        num_9, num_0,
        
        space,
        left_shift,
        right_shift,
        
        left_mouse,
        right_mouse
    };
};

pub const Color = packed struct {
    r: f32 = 0,
    g: f32 = 0,
    b: f32 = 0,
    a: f32 = 1,
    
    pub const white = Color { .r = 1, .g = 1, .b = 1, .a = 1 };
    pub const black = Color { .r = 0, .g = 0, .b = 0, .a = 1 };
};