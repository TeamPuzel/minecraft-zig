//! This module is intended to provide a place for window state.

const std = @import("std");
const c = @import("c.zig");

pub const name = "Minecraft";
const initial_width = 800;
const initial_height = 600;

threadlocal var window: *c.SDL_Window = undefined;
threadlocal var context: c.SDL_GLContext = undefined;
var event: c.SDL_Event = undefined;

pub var actual_width: i32 = 0;
pub var actual_height: i32 = 0;

/// Sets up all critical global and external state required to support
/// OpenGL rendering.
pub fn init() !void {
    // Initialize SDL libraries
    _ = c.SDL_Init(c.SDL_INIT_VIDEO);
    _ = c.IMG_Init(c.IMG_INIT_PNG);
    _ = c.SDL_GL_LoadLibrary(null);
    
    // Create the window
    window = c.SDL_CreateWindow(
        name,
        c.SDL_WINDOWPOS_UNDEFINED,
        c.SDL_WINDOWPOS_UNDEFINED,
        initial_width,
        initial_height,
        c.SDL_WINDOW_ALLOW_HIGHDPI |
        c.SDL_WINDOW_OPENGL |
        c.SDL_WINDOW_ALWAYS_ON_TOP |
        c.SDL_WINDOW_RESIZABLE
    ) orelse return error.CreatingWindow;
    
    // Generic SDL settings
    // _ = c.SDL_SetRelativeMouseMode(1);
    _ = c.SDL_SetWindowMinimumSize(window, initial_width, initial_height);
    
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
    // c.glEnable(c.GL_CULL_FACE);
}

/// Deconstructs all window and library state.
pub fn deinit() void {
    c.SDL_GL_DeleteContext(context);
    c.SDL_DestroyWindow(window);
    c.IMG_Quit();
    c.SDL_Quit();
}

/// Updates all window state and returns true if the application
/// was not requested to quit.
pub fn update() bool {
    // Update the OpenGL context dimensions.
    c.SDL_GL_GetDrawableSize(window, &actual_width, &actual_height);
    // c.glViewport(0, 0, actual_width, actual_width);
    
    // Check if the program should begin termination
    while (c.SDL_PollEvent(&event) > 0) {
        switch (event.type) {
            c.SDL_QUIT => return false,
            else => break
        }
    }
    return true;
}

pub fn lockCursor(value: bool) void {
    if (value) _ = c.SDL_SetRelativeMouseMode(1)
    else _ = c.SDL_SetRelativeMouseMode(0);
}

pub fn swapBuffers() void {
    c.SDL_GL_SwapWindow(window);
}