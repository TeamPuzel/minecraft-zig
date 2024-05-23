
const std = @import("std");
const engine = @import("engine/engine.zig");
const assets = @import("assets/assets.zig");

const Matrix4x4 = engine.math.Matrix4x4;

const render_distance = 16;

// Idea to implement entities - obj-c style retain/release
pub const World = struct {
    // A hash map of all the chunks in the world.
    chunks: ChunkStorage,
    /// A cache for chunks within render distance, sorted by distance
    /// from the camera entity.
    visible_chunks: ChunkCache,
    /// Currently the player, but this will eventually be a pointer to any
    /// entity. It's the entity which the camera is attached to.
    player: Player,
    
    // TODO: The other properties are to be revised, multi-threading is required.
    mesh: TerrainDrawObject,
    timer: std.time.Timer,
    delta: f32 = 0,
    
    pub const ChunkStorage = std.AutoArrayHashMap(ChunkPosition, *Chunk);
    pub const ChunkCache = std.ArrayList(*Chunk);
    
    pub fn init() !World {
        var self = World {
            .chunks = ChunkStorage.init(std.heap.c_allocator),
            .visible_chunks = ChunkCache.init(std.heap.c_allocator),
            .mesh = TerrainDrawObject.create(
                std.heap.c_allocator,
                try engine.graphics.Shader.create(assets.terrain_vs, assets.terrain_fs),
                try engine.graphics.Texture.create(assets.terrain)
            ),
            .player = .{},
            .timer = undefined
        };
        
        var ix: i32 = -render_distance; while (ix <= render_distance) : (ix += 1) {
            var iz: i32 = -render_distance; while (iz <= render_distance) : (iz += 1) {
                // Generate chunk
                try self.chunks.put(.{ .x = ix, .z = iz }, try std.heap.c_allocator.create(Chunk));
                const chunk = self.chunks.get(.{ .x = ix, .z = iz }).?;
                chunk.* = Chunk.generate(ix, iz);
                
                if (self.chunks.get(.{ .x = ix + 1, .z = iz })) |n| {
                    n.neighbors.west = chunk;
                    chunk.neighbors.east = n;
                }
                if (self.chunks.get(.{ .x = ix - 1, .z = iz })) |n| {
                    n.neighbors.east = chunk;
                    chunk.neighbors.west = n;
                }
                if (self.chunks.get(.{ .x = ix, .z = iz + 1 })) |n| {
                    n.neighbors.south = chunk;
                    chunk.neighbors.north = n;
                }
                if (self.chunks.get(.{ .x = ix, .z = iz - 1 })) |n| {
                    n.neighbors.north = chunk;
                    chunk.neighbors.south = n;
                }
            }
        }
        
        try self.remesh();
        
        self.timer = try std.time.Timer.start();
        
        return self;
    }
    
    pub fn deinit(self: *World) void {
        var iter = self.chunks.iterator();
        while (iter.next()) |i| std.heap.c_allocator.destroy(i.value_ptr.*);
        
        self.visible_chunks.deinit();
        self.chunks.deinit();
        self.mesh.destroy();
    }
    
    pub fn update(self: *World) void {
        const ns: f64 = @floatFromInt(self.timer.read());
        const ms: f64 = ns * 0.000001;
        self.delta = @floatCast(ms);
        std.log.info("ms: {d:.6}\n", .{ ms });
        
        self.player.super.update(&self.player, self);
        
        _ = self.timer.lap();
    }
    
    fn remesh(self: *World) !void {
        var iter = self.chunks.iterator();
        while (iter.next()) |chunk| {
            try chunk.value_ptr.*.mesh(&self.mesh);
        }
        
        // TODO: Optimize, currently unusable
        // self.mesh.sort(
        //     self.player.super.position.x,
        //     self.player.super.position.y,
        //     self.player.super.position.z
        // );
        
        self.mesh.sync();
    }
    
    pub fn draw(self: *const World) void {
        const width: f32 = @floatFromInt(engine.Window.shared.width);
        const height: f32 = @floatFromInt(engine.Window.shared.height);
        
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
    neighbors: extern struct {
        north: ?*Chunk = null,
        south: ?*Chunk = null,
        east:  ?*Chunk = null,
        west:  ?*Chunk = null
    },
    
    pub fn generate(x: i32, z: i32) Chunk {
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
            for (0..chunk_side) |iz| {
                const fix: f32 = @floatFromInt(ix);
                const fiz: f32 = @floatFromInt(iz);
                const fx: f32 = @floatFromInt(x);
                const fz: f32 = @floatFromInt(z);
                
                const octave1 = engine.noise.perlin((fix + 16 * fx) * 0.02, (fiz + 16 * fz) * 0.02);
                const octave2 = engine.noise.perlin((fix + 16 * fx) * 0.03, (fiz + 16 * fz) * 0.03);
                const octave3 = engine.noise.perlin((fix + 16 * fx) * 0.1, (fiz + 16 * fz) * 0.1);
                const height = octave1 / 3 + ((octave2 + octave3) / 20);
                
                for (0..chunk_height) |iy| {
                    const fiy: f32 = @floatFromInt(iy);
                    if (fiy < 160 * (height * 0.5 + 0.5))
                        buf.blocks[ix][iy][iz] = &Block.grass;
                    if (fiy >= 160 * (height * 0.5 + 0.5) and fiy < 76)
                        buf.blocks[ix][iy][iz] = &Block.water;
                }
            }
        }
        
        return buf;
    }
    
    pub fn mesh(self: *const Chunk, buffer: *TerrainDrawObject) !void {
        const ofx: f32 = @floatFromInt(self.x * chunk_side);
        const ofz: f32 = @floatFromInt(self.z * chunk_side);
        
        for (self.blocks, 0..) |horiz, ix| {
            for (horiz, 0..) |vert, iy| {
                for (vert, 0..) |block, iz| {
                    
                    const fx: f32 = @floatFromInt(ix);
                    const fy: f32 = @floatFromInt(iy);
                    const fz: f32 = @floatFromInt(iz);
                    
                    const sx: i32 = @intCast(ix);
                    const sy: i32 = @intCast(iy);
                    const sz: i32 = @intCast(iz);
                    
                    try block.mesh(
                        .{
                            .north = !self.isOpaqueAt(sx, sy, sz + 1),
                            .south = !self.isOpaqueAt(sx, sy, sz - 1),
                            .east  = !self.isOpaqueAt(sx + 1, sy, sz),
                            .west  = !self.isOpaqueAt(sx - 1, sy, sz),
                            .up    = !self.isOpaqueAt(sx, sy + 1, sz),
                            .down  = !self.isOpaqueAt(sx, sy - 1, sz)
                        },
                        fx + ofx, fy, fz + ofz, buffer
                    );
                }
            }
        }
    }
    
    fn isOpaqueAt(self: *const Chunk, x: i32, y: i32, z: i32) bool {
        const ux: usize = @intCast(@abs(x));
        const uy: usize = @intCast(@abs(y));
        const uz: usize = @intCast(@abs(z));
        
        return if (y < 0 or y >= chunk_height) false
        else if (x < 0) {
            const west = self.neighbors.west orelse return true;
            return !west.blocks[chunk_side - 1][uy][uz].is_transparent;
        } else if (x >= chunk_side) {
            const east = self.neighbors.east orelse return true;
            return !east.blocks[0][uy][uz].is_transparent;
        } else if (z < 0) {
            const south = self.neighbors.south orelse return true;
            return !south.blocks[ux][uy][chunk_side - 1].is_transparent;
        } else if (z >= chunk_side) {
            const north = self.neighbors.north orelse return true;
            return !north.blocks[ux][uy][0].is_transparent;
        } else { 
            return !self.blocks[ux][uy][uz].is_transparent;
        };
    }
};

/// A collection of properties describing a block.
/// 
/// TODO(TeamPuzel):
/// - (!!) Benchmark usage through pointers vs inline.
/// - (?)  Light absorption coefficient, e.g. for water, which should get
///        progressively darker as depth increases.
pub const Block = struct {
    /// Identifies the exact type at runtime.
    tag: Tag,
    
    /// Describes which faces use which texture.
    /// Not present for invisible blocks.
    atlas_offsets: ?AtlasOffsets = null,
    
    is_transparent: bool = false,
    
    pub const Tag = enum (u16) {
        air,
        stone,
        dirt,
        grass,
        water,
        sand
    };
    
    pub const AtlasOffsets = packed struct {
        back:   Offset,
        front:  Offset,
        left:   Offset,
        right:  Offset,
        top:    Offset,
        bottom: Offset,
        
        pub const Offset = packed struct {
            x: f32, y: f32
        };
    };
    
    /// A mask used to communicate which faces need to be meshed.
    pub const Faces = packed struct {
        north: bool,
        south: bool,
        east:  bool,
        west:  bool,
        up:    bool,
        down:  bool
    };
    
    /// The length of a block side.
    pub const side_len = 1.0;
    /// Half a block side length for use in vertices.
    pub const half_side = side_len / 2.0;
    
    /// The resolution of a single terrain atlas tile.
    pub const tex_block_size = 16.0;
    /// The resolution of the terrain atlas.
    pub const tex_side_len = 256.0;
    /// A coefficient for converting block coordinates to uv coordinates.
    pub const tex_uvc = tex_block_size / tex_side_len;
    
    pub fn mesh(self: *const Block, faces: Faces, x: f32, y: f32, z: f32, buffer: *TerrainDrawObject) !void {
        const off = self.atlas_offsets orelse return; // Abort if not drawable
        
        const s = half_side;
        const c = tex_uvc;
        const o: f32 = if (self.tag == .water) 0.4 else 1.0;
        
        // Back
        if (faces.north) {
            try buffer.vertices.appendSlice(&.{
                Vertex.init(-s + x,  s + y,  s + z,   c * off.back.x + c, c * off.back.y,       1, 1, 1, o), // TR
                Vertex.init( s + x,  s + y,  s + z,   c * off.back.x,     c * off.back.y,       1, 1, 1, o), // TL
                Vertex.init( s + x, -s + y,  s + z,   c * off.back.x,     c * off.back.y + c,   1, 1, 1, o), // BL
                Vertex.init(-s + x,  s + y,  s + z,   c * off.back.x + c, c * off.back.y,       1, 1, 1, o), // TR
                Vertex.init( s + x, -s + y,  s + z,   c * off.back.x,     c * off.back.y + c,   1, 1, 1, o), // BL
                Vertex.init(-s + x, -s + y,  s + z,   c * off.back.x + c, c * off.back.y + c,   1, 1, 1, o)  // BR
            });
        }
        // Front
        if (faces.south) {
            try buffer.vertices.appendSlice(&.{
                Vertex.init( s + x,  s + y, -s + z,   c * off.front.x + c, c * off.front.y,       1, 1, 1, o), // TR
                Vertex.init(-s + x,  s + y, -s + z,   c * off.front.x,     c * off.front.y,       1, 1, 1, o), // TL
                Vertex.init(-s + x, -s + y, -s + z,   c * off.front.x,     c * off.front.y + c,   1, 1, 1, o), // BL
                Vertex.init( s + x,  s + y, -s + z,   c * off.front.x + c, c * off.front.y,       1, 1, 1, o), // TR
                Vertex.init(-s + x, -s + y, -s + z,   c * off.front.x,     c * off.front.y + c,   1, 1, 1, o), // BL
                Vertex.init( s + x, -s + y, -s + z,   c * off.front.x + c, c * off.front.y + c,   1, 1, 1, o)  // BR
            });
        }
        // Right
        if (faces.east) {
            try buffer.vertices.appendSlice(&.{
                Vertex.init( s + x,  s + y,  s + z,   c * off.right.x + c, c * off.right.y,       1, 1, 1, o), // TR
                Vertex.init( s + x,  s + y, -s + z,   c * off.right.x,     c * off.right.y,       1, 1, 1, o), // TL
                Vertex.init( s + x, -s + y, -s + z,   c * off.right.x,     c * off.right.y + c,   1, 1, 1, o), // BL
                Vertex.init( s + x,  s + y,  s + z,   c * off.right.x + c, c * off.right.y,       1, 1, 1, o), // TR
                Vertex.init( s + x, -s + y, -s + z,   c * off.right.x,     c * off.right.y + c,   1, 1, 1, o), // BL
                Vertex.init( s + x, -s + y,  s + z,   c * off.right.x + c, c * off.right.y + c,   1, 1, 1, o)  // BR
            });
        }
        // Left
        if (faces.west) {
            try buffer.vertices.appendSlice(&.{
                Vertex.init(-s + x,  s + y, -s + z,   c * off.left.x + c, c * off.left.y,       1, 1, 1, o), // TR
                Vertex.init(-s + x,  s + y,  s + z,   c * off.left.x,     c * off.left.y,       1, 1, 1, o), // TL
                Vertex.init(-s + x, -s + y,  s + z,   c * off.left.x,     c * off.left.y + c,   1, 1, 1, o), // BL
                Vertex.init(-s + x,  s + y, -s + z,   c * off.left.x + c, c * off.left.y,       1, 1, 1, o), // TR
                Vertex.init(-s + x, -s + y,  s + z,   c * off.left.x,     c * off.left.y + c,   1, 1, 1, o), // BL
                Vertex.init(-s + x, -s + y, -s + z,   c * off.left.x + c, c * off.left.y + c,   1, 1, 1, o)  // BR
            });
        }
        // Top
        if (faces.up) {
            try buffer.vertices.appendSlice(&.{
                Vertex.init( s + x,  s + y,  s + z,   c * off.top.x + c, c * off.top.y,       1, 1, 1, o), // TR
                Vertex.init(-s + x,  s + y,  s + z,   c * off.top.x,     c * off.top.y,       1, 1, 1, o), // TL
                Vertex.init(-s + x,  s + y, -s + z,   c * off.top.x,     c * off.top.y + c,   1, 1, 1, o), // BL
                Vertex.init( s + x,  s + y,  s + z,   c * off.top.x + c, c * off.top.y,       1, 1, 1, o), // TR
                Vertex.init(-s + x,  s + y, -s + z,   c * off.top.x,     c * off.top.y + c,   1, 1, 1, o), // BL
                Vertex.init( s + x,  s + y, -s + z,   c * off.top.x + c, c * off.top.y + c,   1, 1, 1, o)  // BR
            });
        }
        // Bottom
        if (faces.down) {
            try buffer.vertices.appendSlice(&.{
                Vertex.init( s + x, -s + y, -s + z,   c * off.bottom.x + c, c * off.bottom.y,       1, 1, 1, o), // TR
                Vertex.init(-s + x, -s + y, -s + z,   c * off.bottom.x,     c * off.bottom.y,       1, 1, 1, o), // TL
                Vertex.init(-s + x, -s + y,  s + z,   c * off.bottom.x,     c * off.bottom.y + c,   1, 1, 1, o), // BL
                Vertex.init( s + x, -s + y, -s + z,   c * off.bottom.x + c, c * off.bottom.y,       1, 1, 1, o), // TR
                Vertex.init(-s + x, -s + y,  s + z,   c * off.bottom.x,     c * off.bottom.y + c,   1, 1, 1, o), // BL
                Vertex.init( s + x, -s + y,  s + z,   c * off.bottom.x + c, c * off.bottom.y + c,   1, 1, 1, o)  // BR
            });
        }
    }
    
    // MARK: - Instances -------------------------------------------------------
    
    /// This special block represents the absence of a block.
    pub const air = Block {
        .tag = .air,
        .is_transparent = true
    };
    
    /// A generic underground stone block.
    pub const stone = Block {
        .tag = .stone,
        .atlas_offsets = .{
            .front  = .{ .x = 1, .y = 0 },
            .back   = .{ .x = 1, .y = 0 },
            .left   = .{ .x = 1, .y = 0 },
            .right  = .{ .x = 1, .y = 0 },
            .top    = .{ .x = 1, .y = 0 },
            .bottom = .{ .x = 1, .y = 0 }
        }
    };
    
    pub const dirt = Block {
        .tag = .dirt,
        .atlas_offsets = .{
            .front  = .{ .x = 2, .y = 0 },
            .back   = .{ .x = 2, .y = 0 },
            .left   = .{ .x = 2, .y = 0 },
            .right  = .{ .x = 2, .y = 0 },
            .top    = .{ .x = 2, .y = 0 },
            .bottom = .{ .x = 2, .y = 0 }
        }
    };
    
    pub const grass = Block {
        .tag = .grass,
        .atlas_offsets = .{
            .front  = .{ .x = 3, .y = 0 },
            .back   = .{ .x = 3, .y = 0 },
            .left   = .{ .x = 3, .y = 0 },
            .right  = .{ .x = 3, .y = 0 },
            .top    = .{ .x = 0, .y = 0 },
            .bottom = .{ .x = 2, .y = 0 }
        }
    };
    
    pub const sand = Block {
        .tag = .dirt,
        .atlas_offsets = .{
            .front  = .{ .x = 2, .y = 1 },
            .back   = .{ .x = 2, .y = 1 },
            .left   = .{ .x = 2, .y = 1 },
            .right  = .{ .x = 2, .y = 1 },
            .top    = .{ .x = 2, .y = 1 },
            .bottom = .{ .x = 2, .y = 1 }
        }
    };
    
    pub const water = Block {
        .tag = .water,
        .is_transparent = true,
        .atlas_offsets = .{
            .front  = .{ .x = 13, .y = 12 },
            .back   = .{ .x = 13, .y = 12 },
            .left   = .{ .x = 13, .y = 12 },
            .right  = .{ .x = 13, .y = 12 },
            .top    = .{ .x = 13, .y = 12 },
            .bottom = .{ .x = 13, .y = 12 }
        }
    };
};

// MARK: - Entities ------------------------------------------------------------

pub const Position = extern struct {
    x: f32 = 0, y: f32 = 0, z: f32 = 0
};

pub const Orientation = extern struct {
    pitch: f32 = 0, yaw: f32 = 0, roll: f32 = 0
};

pub const Entity = extern struct {
    position: Position = .{},
    orientation: Orientation = .{},
    update: *const fn(self: *anyopaque, world: *World) callconv(.C) void = @ptrCast(&update),
    
    fn update(_: *Entity, _: *World) callconv(.C) void {}
};

pub const Player = extern struct {
    super: Entity = .{
        .position = .{ .y = 80 },
        .update = @ptrCast(&update)
    },
    
    fn update(self: *Player, world: *World) callconv(.C) void {
        // Mouse look
        const mouse = engine.input.relativeMouse();
        self.super.orientation.yaw += mouse.x / 10;
        self.super.orientation.pitch += mouse.y / 10;
        self.super.orientation.pitch = 
            std.math.clamp(self.super.orientation.pitch, -90, 90);
            
        // Basic, camera unaligned movement
        if (engine.input.key(.w)) self.super.position.z          += 0.01 * world.delta;
        if (engine.input.key(.a)) self.super.position.x          -= 0.01 * world.delta;
        if (engine.input.key(.s)) self.super.position.z          -= 0.01 * world.delta;
        if (engine.input.key(.d)) self.super.position.x          += 0.01 * world.delta;
        if (engine.input.key(.space)) self.super.position.y      += 0.01 * world.delta;
        if (engine.input.key(.left_shift)) self.super.position.y -= 0.01 * world.delta;
    }
};

const TerrainDrawObject = engine.graphics.DrawObject(Vertex);

const Vertex = packed struct {
    position: Vertex.Position,
    tex_coord: TextureCoord,
    color: engine.Color = engine.Color.white,
    
    pub const Position = packed struct {
        x: f32, y: f32, z: f32
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
