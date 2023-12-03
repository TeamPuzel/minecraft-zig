
const std = @import("std");
const c = @import("../platform/c.zig");
const noise = @import("../math/noise.zig");
const window = @import("../platform/window.zig");

const Matrix4x4 = @import("../math/matrix.zig").Matrix4x4;
const Player = @import("entity.zig").Player;
const TerrainVertexBuffer = @import("../gl/buffer.zig").TerrainVertexBuffer;
const Block = @import("block.zig").Block;

pub const World = struct {
    chunks: ChunkStorage,
    player: Player,
    mesh: TerrainVertexBuffer,
    
    pub const ChunkStorage = std.AutoArrayHashMap(ChunkPosition, Chunk);
    
    pub fn generate() !World {
        var buf = World {
            .chunks = ChunkStorage.init(std.heap.c_allocator),
            .mesh = TerrainVertexBuffer.create(std.heap.c_allocator),
            .player = .{}
        };
        
        var ix: i32 = -2;
        while (ix <= 2) : (ix += 1) {
            var iz: i32 = -2;
            while (iz <= 2) : (iz += 1) {
                try buf.chunks.put(.{ .x = ix, .z = iz }, try Chunk.generate(ix, iz));
            }
        }
        
        try buf.remesh();
        
        return buf;
    }
    
    pub fn deinit(self: *World) void {
        self.chunks.deinit();
        self.mesh.destroy();
    }
    
    pub fn update(self: *World) void {
        self.player.super.update(&self.player, self);
    }
    
    fn remesh(self: *World) !void {
        var iter = self.chunks.iterator();
        while (iter.next()) |chunk| {
            try chunk.value_ptr.mesh(&self.mesh);
        }
        self.mesh.sync();
    }
    
    pub fn draw(self: *const World) void {
        const width: f32 = @floatFromInt(window.actual_width);
        const height: f32 = @floatFromInt(window.actual_height);
        
        const mat = Matrix4x4.translation(
                -self.player.super.position.x,
                -self.player.super.position.y,
                -self.player.super.position.z
            )
            .mul(&Matrix4x4.rotation(.Yaw, self.player.super.orientation.yaw))
            .mul(&Matrix4x4.rotation(.Pitch, self.player.super.orientation.pitch))
            .mul(&Matrix4x4.projection(width, height, 80, 0.1, 1000));
        
        self.mesh.draw(&mat);
    }
};

/// The key for chunk storage.
pub const ChunkPosition = packed struct { x: i32, z: i32 };

/// Stores pointers to all loaded chunks,
/// that is, chunks within render distance.
pub const ChunkCache = packed struct {
    /// A pointer to where the 2d pointer array is allocated.
    /// Dynamic because render distance isn't constant.
    data: [*]*Chunk,
    render_distance: u32,
    
    fn init(render_distance: u32) ChunkCache {
        _ = render_distance;
    }
};

pub const chunk_side = 16;
pub const chunk_height = 256;

pub const Chunk = struct {
    x: i32,
    z: i32,
    /// A large chunk of memory storing block pointers.
    blocks: [chunk_side][chunk_height][chunk_side]*const Block,
    
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
            .x = x,
            .z = z,
            .blocks = @bitCast(
                [_] *const Block { &Block.air } ** 
                    (chunk_side * chunk_height * chunk_side)
            ),
            .neighbors = .{}
        };
        
        for (0..chunk_side) |ix| {
            for (0..chunk_height) |iy| {
                for (0..chunk_side) |iz| {
                    if (iy < 128) buf.blocks[ix][iy][iz] = &Block.stone;
                }
            }
        }
        
        return buf;
    }
    
    pub fn mesh(self: *Chunk, buffer: *TerrainVertexBuffer) !void {
        const ofx: f32 = @floatFromInt(self.x * chunk_side);
        const ofz: f32 = @floatFromInt(self.z * chunk_side);
        
        for (self.blocks, 0..) |horiz, ix| {
            for (horiz, 0..) |vert, iy| {
                for (vert, 0..) |block, iz| {
                    
                    const fx: f32 = @floatFromInt(ix);
                    const fy: f32 = @floatFromInt(iy);
                    const fz: f32 = @floatFromInt(iz);
                    
                    try block.mesh(.{}, fx + ofx, fy, fz + ofz, buffer);
                }
            }
        }
    }
};