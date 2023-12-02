
const c = @import("platform/c.zig");
const std = @import("std");
const window = @import("platform/window.zig");
const shader = @import("gl/shader.zig");
const texture = @import("gl/texture.zig");

const TerrainVertexBuffer = @import("gl/buffer.zig").TerrainVertexBuffer;
const Vertex = TerrainVertexBuffer.Vertex;
const Matrix4x4 = @import("utilities/matrix.zig").Matrix4x4;

// const World = @import("world/world.zig").World;
const Block = @import("world/block.zig").Block;

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
    
    window.lockCursor(false);
    
    // MARK: - Test ------------------------------------------------------------
    shader.terrain.bind();
    texture.terrain.bind();
    
    var test_block = TerrainVertexBuffer.create(std.heap.c_allocator);
    defer test_block.destroy();
    
    try Block.dirt.mesh(.{}, &test_block);
    test_block.sync();
    
    // c.glActiveTexture(c.GL_TEXTURE0);
    const sampler = shader.terrain.getUniform("texture_id");
    const transform = shader.terrain.getUniform("transform");
    c.glUniform1i(sampler, 0);
    
    var t: f32 = 0;
    
    // Keep running until the program is requested to quit
    while (window.update()) {
        c.glClear(c.GL_COLOR_BUFFER_BIT | c.GL_DEPTH_BUFFER_BIT);
        
        const width: f32 = @floatFromInt(window.actual_width);
        const height: f32 = @floatFromInt(window.actual_height);
        const aspect = width / height;
        
        const mat = Matrix4x4.rotation(.Yaw, 45)
            .mul(&Matrix4x4.translation(0, 0, -3))
            .mul(&Matrix4x4.frustum(-aspect / 2, aspect / 2, -0.5, 0.5, 0.4, 1000));
            // .mul(&Matrix4x4.projection(width, height, 90, 0.01, 1000));
        
        c.glUniformMatrix4fv(transform, 1, c.GL_TRUE, @ptrCast(&mat.data));
        
        test_block.draw();
        t += 1;
        window.swapBuffers();
    }
}
