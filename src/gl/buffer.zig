//! This module contains various types of buffers and their vertices.

const std = @import("std");
const c = @import("../platform/c.zig");

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

pub const BlockVertex = packed struct {
    position: Position,
    tex_coord: TextureCoord,
    color: Color = Color.white
};

pub const BlockVertexBuffer = struct {
    id: u32,
    vertices: std.ArrayList(BlockVertex),
    
    pub fn create(allocator: std.mem.Allocator) BlockVertexBuffer {
        var buf: BlockVertexBuffer = undefined;
        buf.vertices = std.ArrayList(BlockVertex).init(allocator);
        c.glGenBuffers(1, &buf.id);
        
        buf.bind();
        buf.layout();
        return buf;
    }
    
    pub fn destroy(self: *BlockVertexBuffer) void {
        c.glDeleteBuffers(1, &self.id);
        self.vertices.deinit();
    }
    
    pub fn sync(self: *const BlockVertexBuffer) void {
        self.bind();
        c.glBufferData(
            c.GL_ARRAY_BUFFER,
            @intCast(self.vertices.items.len * @sizeOf(BlockVertex)),
            self.vertices.items.ptr,
            c.GL_DYNAMIC_DRAW
        );
    }
    
    pub fn bind(self: *const BlockVertexBuffer) void {
        c.glBindBuffer(c.GL_ARRAY_BUFFER, self.id);
    }
    
    pub fn draw(self: *const BlockVertexBuffer) void {
        c.glDrawArrays(c.GL_TRIANGLES, 0, @intCast(self.vertices.items.len));
    }
    
    // pub fn wireframe(self: *const BlockVertexBuffer) void {
    //     c.glDrawArrays(c.GL_LINES, 0, @intCast(self.vertices.items.len));
    // }
    
    fn layout(self: *const BlockVertexBuffer) void {
        _ = self;
        c.glVertexAttribPointer(
            0,
            3,
            c.GL_FLOAT,
            c.GL_FALSE,
            @sizeOf(BlockVertex),
            @ptrFromInt(@offsetOf(BlockVertex, "position"))
        );
        c.glEnableVertexAttribArray(0);
        
        c.glVertexAttribPointer(
            1,
            2,
            c.GL_FLOAT,
            c.GL_FALSE,
            @sizeOf(BlockVertex),
            @ptrFromInt(@offsetOf(BlockVertex, "tex_coord"))
        );
        c.glEnableVertexAttribArray(1);
        
        c.glVertexAttribPointer(
            2,
            4,
            c.GL_FLOAT,
            c.GL_FALSE,
            @sizeOf(BlockVertex),
            @ptrFromInt(@offsetOf(BlockVertex, "color"))
        );
        c.glEnableVertexAttribArray(2);
    }
};
