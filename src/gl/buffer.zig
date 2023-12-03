//! This module contains various types of buffers and their vertices.

const std = @import("std");
const c = @import("../platform/c.zig");

/// A vertex buffer optimized for caching terrain on the gpu and only
/// synchronizing all changes at once when needed.
/// 
/// It could potentially be optimized further by only sending updated vertices,
/// however, that would probably be overkill.
pub const TerrainVertexBuffer = struct {
    id: u32,
    vertices: std.ArrayList(Vertex),
    
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
        c.glGenBuffers(1, &buf.id);
        
        buf.bind();
        buf.layout();
        return buf;
    }
    
    pub fn destroy(self: *TerrainVertexBuffer) void {
        c.glDeleteBuffers(1, &self.id);
        self.vertices.deinit();
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
    }
    
    pub fn draw(self: *const TerrainVertexBuffer) void {
        self.bind();
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
