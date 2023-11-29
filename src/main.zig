
const c = @import("platform/c.zig");
const std = @import("std");
const window = @import("platform/window.zig");
const shader = @import("gl/shader.zig");
const texture = @import("gl/texture.zig");

const BlockVertexBuffer = @import("gl/buffer.zig").BlockVertexBuffer;
const BlockVertex = @import("gl/buffer.zig").BlockVertex;
const Color = @import("gl/buffer.zig").Color;
const Position = @import("gl/buffer.zig").Position;
const TextureCoord = @import("gl/buffer.zig").TextureCoord;

// const World = @import("world/world.zig").World;
// const Block = @import("world/block.zig").Block;

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
    
    // MARK: - Test ------------------------------------------------------------
    shader.terrain.bind();
    texture.terrain.bind();
    
    var test_rect = BlockVertexBuffer.create(std.heap.c_allocator);
    defer test_rect.destroy();
    
    try test_rect.vertices.appendSlice(&.{
        .{ .position = .{ .x = -0.5, .y =  0.5, .z = 0 }, .tex_coord = .{ .u = 0, .v = 0 } },
        .{ .position = .{ .x = -0.5, .y = -0.5, .z = 0 }, .tex_coord = .{ .u = 0, .v = 1 } },
        .{ .position = .{ .x =  0.5, .y =  0.5, .z = 0 }, .tex_coord = .{ .u = 1, .v = 0 } },
        .{ .position = .{ .x =  0.5, .y =  0.5, .z = 0 }, .tex_coord = .{ .u = 1, .v = 0 } },
        .{ .position = .{ .x = -0.5, .y = -0.5, .z = 0 }, .tex_coord = .{ .u = 0, .v = 1 } },
        .{ .position = .{ .x =  0.5, .y = -0.5, .z = 0 }, .tex_coord = .{ .u = 1, .v = 1 } }
    });
    test_rect.sync();
    
    // c.glActiveTexture(c.GL_TEXTURE0);
    const sampler = shader.terrain.getUniform("texture_id");
    c.glUniform1i(sampler, 0);
    
    // END: - Test -------------------------------------------------------------
    
    // Keep running until the program is requested to quit
    while (!window.shouldQuit()) {
        
        c.glClear(c.GL_COLOR_BUFFER_BIT | c.GL_DEPTH_BUFFER_BIT);
        
        test_rect.draw();
        
        window.swapBuffers();
    }
}
