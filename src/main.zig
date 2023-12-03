
const c = @import("platform/c.zig");
const std = @import("std");
const window = @import("platform/window.zig");
const shader = @import("gl/shader.zig");
const texture = @import("gl/texture.zig");

const World = @import("world/world.zig").World;

pub fn main() !void {
    // The window module sets up an SDL window and the OpenGL context
    try window.init();
    defer window.deinit();
    
    // With OpenGL ready, the shader module compiles all the shaders
    try shader.init();
    defer shader.deinit();
    
    // The texture module loads and converts all texture assets to 8 bit RGBA
    // and moves them onto the gpu (deleting the data on the cpu side)
    try texture.init();
    defer texture.deinit();
    
    window.lockCursor(true);
    
    var world = try World.generate();
    
    // Keep running until the program is requested to quit
    while (window.update()) {
        c.glClear(c.GL_COLOR_BUFFER_BIT | c.GL_DEPTH_BUFFER_BIT);
        world.update();
        world.draw();
        window.swapBuffers();
    }
}
