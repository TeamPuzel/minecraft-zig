
const c = @import("platform/c.zig");
const std = @import("std");
const window = @import("platform/window.zig");

const Shader = @import("gl/shader.zig").Shader;
const Texture = @import("gl/texture.zig").Texture;
const World = @import("world/world.zig").World;

pub fn main() !void {
    try window.init();
    defer window.deinit();
    
    try Shader.init();
    defer Shader.deinit();
    
    try Texture.init();
    defer Texture.deinit();
    
    window.lockCursor(true);
    var world = try World.generate();
    defer world.deinit();
    
    c.glClearColor(0.6, 0.8, 0.9, 1.0);
    
    while (window.update()) {
        c.glClear(c.GL_COLOR_BUFFER_BIT | c.GL_DEPTH_BUFFER_BIT);
        world.update();
        world.draw();
        window.swapBuffers();
    }
}
