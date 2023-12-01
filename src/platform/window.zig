//! This module is intended to provide a place for window state.

const std = @import("std");
const c = @import("c.zig");

pub const window_name = "Minecraft";
pub const window_width = 800;
pub const window_height = 600;

var window: *c.SDL_Window = undefined;
var context: c.SDL_GLContext = undefined;
var event: c.SDL_Event = undefined;

pub var ctx_width: i32 = 0;
pub var ctx_height: i32 = 0;

/// Sets up all critical global and external state required to support
/// OpenGL rendering.
pub fn init() !void {
    // Initialize SDL libraries
    _ = c.SDL_Init(c.SDL_INIT_VIDEO);
    _ = c.IMG_Init(c.IMG_INIT_PNG);
    _ = c.SDL_GL_LoadLibrary(null);
    
    // Create the window
    window = c.SDL_CreateWindow(
        window_name,
        c.SDL_WINDOWPOS_UNDEFINED,
        c.SDL_WINDOWPOS_UNDEFINED,
        window_width,
        window_height,
        c.SDL_WINDOW_ALLOW_HIGHDPI |
        c.SDL_WINDOW_OPENGL |
        c.SDL_WINDOW_ALWAYS_ON_TOP |
        c.SDL_WINDOW_RESIZABLE
    ) orelse return error.CreatingWindow;
    
    // Generic SDL settings
    // _ = c.SDL_SetRelativeMouseMode(1);
    _ = c.SDL_SetWindowMinimumSize(window, window_width, window_height);
    
    // Configure the OpenGL context
    _ = c.SDL_GL_SetAttribute(c.SDL_GL_CONTEXT_MAJOR_VERSION, 4);
    _ = c.SDL_GL_SetAttribute(c.SDL_GL_CONTEXT_MINOR_VERSION, 1);
    _ = c.SDL_GL_SetAttribute(
        c.SDL_GL_CONTEXT_PROFILE_MASK, c.SDL_GL_CONTEXT_PROFILE_CORE
    );
    _ = c.SDL_GL_SetAttribute(c.SDL_GL_DOUBLEBUFFER, 1);
    _ = c.SDL_GL_SetAttribute(c.SDL_GL_DEPTH_SIZE, 24);
    _ = c.SDL_GL_SetSwapInterval(1);
    
    context = c.SDL_GL_CreateContext(window);
    
    // Load modern OpenGL features
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
    
    // OpenGL boilerplate, literally useless
    var boilerplate: u32 = undefined;
    c.glGenVertexArrays(1, &boilerplate);
    c.glBindVertexArray(boilerplate);
    c.glEnableVertexAttribArray(boilerplate);
    
    // Generic OpenGL settings
    c.glClearColor(0.0, 0.0, 0.0, 1.0);
    c.glEnable(c.GL_DEPTH_TEST);
    c.glEnable(c.GL_CULL_FACE);
}

/// Deconstructs all window and library state.
pub fn deinit() void {
    c.SDL_GL_DeleteContext(context);
    c.SDL_DestroyWindow(window);
    c.IMG_Quit();
    c.SDL_Quit();
}

/// Updates all window state and returns true if the application
/// was requested to quit.
pub fn shouldQuit() bool {
    // Update the OpenGL context dimensions.
    c.SDL_GL_GetDrawableSize(window, &ctx_width, &ctx_width);
    c.glViewport(0, 0, ctx_width, ctx_width);
    
    // Check if the program should begin termination
    while (c.SDL_PollEvent(&event) > 0) {
        switch (event.type) {
            c.SDL_QUIT => return true,
            else => break
        }
    }
    return false;
}

pub fn lockCursor(value: bool) void {
    if (value) _ = c.SDL_SetRelativeMouseMode(1)
    else _ = c.SDL_SetRelativeMouseMode(0);
}

pub fn swapBuffers() void {
    c.SDL_GL_SwapWindow(window);
}