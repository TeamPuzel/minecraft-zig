const std = @import("std");
const c = @import("core/c.zig");
const assets = @import("assets/assets.zig");
const engine = @import("core/engine.zig");
const game = @import("game.zig");

const TGAConstPtr = engine.image.TGAConstPtr;
const World = game.World;
const Shader = engine.graphics.Shader;
const Texture = engine.graphics.Texture;
const VertexBuffer = engine.graphics.VertexBuffer;

const terrain = TGAConstPtr { .raw = assets.terrain_tga };

pub fn main() !void {
    try engine.init("Minecraft");
    defer engine.deinit();
    
    try initRenderState();
    defer deinitRenderState();
    
    engine.lockCursor(true);
    
    var world = try World.init();
    defer world.deinit();
    
    engine.graphics.setClearColor(.{ .r = 0.52, .g = 0.67, .b = 0.97 });
    
    while (engine.update()) {
        engine.clear();
        
        world.update();
        try render(world);
        
        engine.swapBuffers();
    }
}

pub const BlockVertex = packed struct {
    position: BlockVertex.Position,
    tex_coord: TextureCoord,
    color: engine.Color = engine.Color.white,
    
    pub const Position = packed struct { x: f32, y: f32, z: f32 };
    pub const TextureCoord = packed struct { u: f32, v: f32 };
    
    pub inline fn init(x: f32, y: f32, z: f32, u: f32, v: f32, r: f32, g: f32, b: f32, a: f32) BlockVertex {
        return .{
            .position = .{ .x = x, .y = y, .z = z },
            .tex_coord = .{ .u = u, .v = v },
            .color = .{ .r = r, .g = g, .b = b, .a = a }
        };
    }
};

var terrain_shader: Shader = undefined;
var terrain_texture: Texture = undefined;
var terrain_buffer: VertexBuffer(BlockVertex) = undefined;

fn initRenderState() !void {
    terrain_shader = try Shader.create(assets.terrain_vs, assets.terrain_fs);
    terrain_texture = try Texture.createFrom(terrain);
    terrain_buffer = VertexBuffer(BlockVertex).create(std.heap.c_allocator);
}

fn deinitRenderState() void {
    terrain_shader.destroy();
    terrain_texture.destroy();
}

fn render(world: *const World) !void {
    const new_vertices = try world.getUnifiedMesh();
    terrain_buffer.vertices.deinit();
    terrain_buffer.vertices = new_vertices;
    
    terrain_shader.bind();
    terrain_texture.bind();
    terrain_buffer.sync();
    
    const sampler = terrain_shader.getUniform("texture_id");
    const transform = terrain_shader.getUniform("transform");
    c.glUniform1i(sampler, 0);
    c.glUniformMatrix4fv(transform, 1, c.GL_TRUE, @ptrCast(&world.getPrimaryMatrix()));
    
    terrain_buffer.draw();
}
