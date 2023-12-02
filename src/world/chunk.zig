
const std = @import("std");
const noise = @import("../utilities/noise.zig");

const TerrainVertexBuffer = @import("../gl/buffer.zig").TerrainVertexBuffer;
const Block = @import("block.zig").Block;

pub const chunk_side = 16;
pub const chunk_height = 256;

pub const Chunk = struct {
    /// A large chunk of memory storing block pointers.
    blocks: [chunk_side][chunk_height][chunk_side]*const Block,
    
    /// If not `null` the chunk is loaded
    mesh: ?TerrainVertexBuffer,
    
    /// Quite often, especially when rendering, chunks need to be able to
    /// efficiently refer to neighboring chunks. This is important because
    /// chunks are stored in a hash map. It is important not to invalidate
    /// these pointers. They are `null` if the chunk is not generated yet,
    /// however they remain valid for unloaded chunks - to check if a generated
    /// chunk is loaded for rendering purposes check `mesh` instead, as
    /// it can be used to cull faces more efficiently at chunk boundaries.
    neighbors: packed struct {
        north: ?*Chunk = null,
        south: ?*Chunk = null,
        east:  ?*Chunk = null,
        west:  ?*Chunk = null
    },
    
    pub fn generate(x: i32, z: i32) !Chunk {
        var buf = Chunk {
            .mesh = TerrainVertexBuffer.create(std.heap.c_allocator),
            .blocks = @bitCast(
                [_] *const Block { &Block.air } ** 
                    (chunk_side * chunk_height * chunk_side)
            ),
            .neighbors = .{}
        };
        
        _ = x; _ = z;
        
        for (0..chunk_side) |ix| {
            for (0..chunk_height) |iy| {
                for (0..chunk_side) |iz| {
                    if (iy < 128) buf.blocks[ix][iy][iz] = &Block.stone;
                }
            }
        }
        
        try buf.remesh();
        
        return buf;
    }
    
    pub fn destroy(self: *Chunk) void {
        if (self.mesh) |_| self.mesh.?.destroy();
    }
    
    pub fn load(self: *Chunk) void {
        std.debug.assert(self.mesh == null);
        
    }
    
    pub fn unload(self: *Chunk) void {
        std.debug.assert(self.mesh != null);
        
    }
    
    fn remesh(self: *Chunk) !void {
        self.mesh.?.vertices.clearRetainingCapacity();
        
        for (self.blocks, 0..) |horiz, ix| {
            for (horiz, 0..) |vert, iy| {
                for (vert, 0..) |block, iz| {
                    
                    const fx: f32 = @floatFromInt(ix);
                    const fy: f32 = @floatFromInt(iy);
                    const fz: f32 = @floatFromInt(iz);
                    
                    try block.mesh(.{}, fx, fy, fz, &self.mesh.?);
                }
            }
        }
        
        self.mesh.?.sync();
    }
};