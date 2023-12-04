//! This module contains various types of buffers and their vertices.

const std = @import("std");
const c = @import("../platform/c.zig");

const Texture = @import("texture.zig").Texture;
const Shader = @import("shader.zig").Shader;
const Matrix4x4 = @import("../math/matrix.zig").Matrix4x4;

/// A vertex buffer optimized for caching terrain on the gpu and only
/// synchronizing all changes at once when needed.
pub const TerrainVertexBuffer = struct {
    id: u32,
    vertices: std.ArrayList(Vertex),
    texture: Texture,
    shader: Shader,
    
    pub const Vertex = packed struct {
        position: Position,
        tex_coord: TextureCoord,
        color: Color = Color.white,
        
        pub const Position = packed struct {
            x: f32, y: f32, z: f32
        };

        pub const Color = packed struct {
            r: f32 = 0,
            g: f32 = 0,
            b: f32 = 0,
            a: f32 = 1,
            
            pub const white = Color { .r = 1, .g = 1, .b = 1, .a = 1 };
            pub const black = Color { .r = 1, .g = 1, .b = 1, .a = 1 };
        };

        pub const TextureCoord = packed struct {
            u: f32, v: f32
        };
        
        pub fn init(x: f32, y: f32, z: f32, u: f32, v: f32, r: f32, g: f32, b: f32, a: f32) Vertex {
            return .{
                .position = .{ .x = x, .y = y, .z = z },
                .tex_coord = .{ .u = u, .v = v },
                .color = .{ .r = r, .g = g, .b = b, .a = a }
            };
        }
    };
    
    pub fn create(allocator: std.mem.Allocator) TerrainVertexBuffer {
        var buf: TerrainVertexBuffer = undefined;
        buf.vertices = std.ArrayList(Vertex).init(allocator);
        buf.shader = Shader.terrain;
        buf.texture = Texture.terrain;
        c.glGenBuffers(1, &buf.id);
        
        buf.bind();
        buf.layout();
        return buf;
    }
    
    pub fn destroy(self: *TerrainVertexBuffer) void {
        c.glDeleteBuffers(1, &self.id);
        self.vertices.deinit();
    }
    
    pub fn sort(self: *TerrainVertexBuffer, x: f32, y: f32, z: f32) void {
        const triangles: [*][3]Vertex = @ptrCast(self.vertices.items.ptr);
        const len = self.vertices.items.len / 3;
        const slice = triangles[0..len];
        
        const camera = @Vector(3, f32) { x, y, z };
        
        std.sort.heap([3]Vertex, slice, camera, triCompare);
    }
    
    fn triCompare(pos: @Vector(3, f32), lhs: [3]Vertex, rhs: [3]Vertex) bool {
        return triDistance(pos, lhs) > triDistance(pos, rhs);
    }
    
    fn triDistance(pos: @Vector(3, f32), tri: [3]Vertex) f32 {
        const v1 = @Vector(3, f32) {
            tri[0].position.x, tri[0].position.y, tri[0].position.z
        };
        const v2 = @Vector(3, f32) {
            tri[1].position.x, tri[1].position.y, tri[1].position.z
        };
        const v3 = @Vector(3, f32) {
            tri[2].position.x, tri[2].position.y, tri[2].position.z
        };
        
        const average = (v1 + v2 + v3) / @Vector(3, f32) { 3, 3, 3 };
        const diff = average - pos;
        return @sqrt(@reduce(.Add, diff * diff));
    }
    
    /// Update the buffer on the GPU side with the local CPU data.
    pub fn sync(self: *const TerrainVertexBuffer) void {
        self.bind();
        c.glBufferData(
            c.GL_ARRAY_BUFFER,
            @intCast(self.vertices.items.len * @sizeOf(Vertex)),
            self.vertices.items.ptr,
            c.GL_DYNAMIC_DRAW
        );
    }
    
    pub fn bind(self: *const TerrainVertexBuffer) void {
        c.glBindBuffer(c.GL_ARRAY_BUFFER, self.id);
        self.texture.bind();
        self.shader.bind();
    }
    
    pub fn draw(self: *const TerrainVertexBuffer, matrix: *const Matrix4x4) void {
        self.bind();
        
        const sampler = self.shader.getUniform("texture_id");
        const transform = self.shader.getUniform("transform");
        c.glUniform1i(sampler, 0);
        
        c.glUniformMatrix4fv(transform, 1, c.GL_TRUE, @ptrCast(&matrix.data));
        
        c.glDrawArrays(c.GL_TRIANGLES, 0, @intCast(self.vertices.items.len));
    }
    
    fn layout(self: *const TerrainVertexBuffer) void {
        _ = self;
        c.glVertexAttribPointer(
            0,
            3,
            c.GL_FLOAT,
            c.GL_FALSE,
            @sizeOf(Vertex),
            @ptrFromInt(@offsetOf(Vertex, "position"))
        );
        c.glEnableVertexAttribArray(0);
        
        c.glVertexAttribPointer(
            1,
            2,
            c.GL_FLOAT,
            c.GL_FALSE,
            @sizeOf(Vertex),
            @ptrFromInt(@offsetOf(Vertex, "tex_coord"))
        );
        c.glEnableVertexAttribArray(1);
        
        c.glVertexAttribPointer(
            2,
            4,
            c.GL_FLOAT,
            c.GL_FALSE,
            @sizeOf(Vertex),
            @ptrFromInt(@offsetOf(Vertex, "color"))
        );
        c.glEnableVertexAttribArray(2);
    }
};
