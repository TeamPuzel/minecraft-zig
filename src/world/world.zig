
const std = @import("std");
const c = @import("../platform/c.zig");
const noise = @import("../math/noise.zig");
const window = @import("../platform/window.zig");
const shader = @import("../gl/shader.zig");
const texture = @import("../gl/texture.zig");

const Matrix4x4 = @import("../math/matrix.zig").Matrix4x4;
const Player = @import("entity.zig").Player;
const TerrainVertexBuffer = @import("../gl/buffer.zig").TerrainVertexBuffer;
const Block = @import("block.zig").Block;

pub const World = struct {
    chunks: ChunkStorage,
    player: Player,
    
    pub const ChunkStorage = std.AutoArrayHashMap(ChunkPosition, Chunk);
    
    pub fn generate() !World {
        var buf = World {
            .chunks = ChunkStorage.init(std.heap.c_allocator),
            .player = .{}
        };
        
        var ix: i32 = -2;
        while (ix <= 2) : (ix += 1) {
            var iz: i32 = -2;
            while (iz <= 2) : (iz += 1) {
                try buf.chunks.put(.{ .x = ix, .z = iz }, try Chunk.generate(ix, iz));
            }
        }
        
        return buf;
    }
    
    pub fn update(self: *World) void {
        self.player.super.update(&self.player, self);
    }
    
    pub fn draw(self: *const World) void {
        shader.terrain.bind();
        texture.terrain.bind();
        const sampler = shader.terrain.getUniform("texture_id");
        const transform = shader.terrain.getUniform("transform");
        c.glUniform1i(sampler, 0);
        
        const width: f32 = @floatFromInt(window.actual_width);
        const height: f32 = @floatFromInt(window.actual_height);
        
        const mat = Matrix4x4.translation(
                -self.player.super.position.x,
                -self.player.super.position.y,
                -self.player.super.position.z
            )
            .mul(&Matrix4x4.rotation(.Yaw, self.player.super.orientation.yaw))
            .mul(&Matrix4x4.rotation(.Pitch, self.player.super.orientation.pitch))
            // .mul(&Matrix4x4.frustum(-aspect / 2, aspect / 2, -0.5, 0.5, 0.4, 1000));
            .mul(&Matrix4x4.projection(width, height, 80, 0.1, 1000));
        
        c.glUniformMatrix4fv(transform, 1, c.GL_TRUE, @ptrCast(&mat.data));
        
        var iter = self.chunks.iterator();
        while (iter.next()) |chunk| {
            if (chunk.value_ptr.mesh) |mesh| {
                mesh.draw();
            }
        }
        
    }
    
    // MARK: - Serialization ---------------------------------------------------
    
    /// Load the world from the world folder.
    pub fn loadFromFile(name: []const u8) LoadError!World {
        _ = name;
        unreachable;
    }
    
    /// Save the world to the world folder.
    pub fn saveToFile(self: *const World) SaveError!void {
        _ = self;
        unreachable;
    }
    
    pub const LoadError = error {
        Corrupted,
        Inaccessible
    };
    
    pub const SaveError = error {
        Inaccessible
    };
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
            .x = x,
            .z = z,
            .mesh = TerrainVertexBuffer.create(std.heap.c_allocator),
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
        
        const ofx: f32 = @floatFromInt(self.x * chunk_side);
        const ofz: f32 = @floatFromInt(self.z * chunk_side);
        
        for (self.blocks, 0..) |horiz, ix| {
            for (horiz, 0..) |vert, iy| {
                for (vert, 0..) |block, iz| {
                    
                    const fx: f32 = @floatFromInt(ix);
                    const fy: f32 = @floatFromInt(iy);
                    const fz: f32 = @floatFromInt(iz);
                    
                    try block.mesh(.{}, fx + ofx, fy, fz + ofz, &self.mesh.?);
                }
            }
        }
        
        self.mesh.?.sync();
    }
};