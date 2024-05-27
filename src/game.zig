const std = @import("std");
const engine = @import("core/engine.zig");

const BlockVertex = @import("root").BlockVertex;
const TGAConstPtr = engine.image.TGAConstPtr;
const Matrix4x4 = engine.math.Matrix4x4;
const Array = std.ArrayList;

pub const render_distance = 6;

// Idea to implement entities - obj-c style retain/release
/// NOTE: An instance of `World` requires a stable identity.
pub const World = struct {
    /// A hash map of all the chunks in the world.
    chunks: ChunkStorage,
    /// A cache for chunks within render distance, sorted by distance
    /// from the camera entity.
    visible_chunks: ChunkCache,
    /// Currently the player, but this will eventually be a pointer to any
    /// entity. It's the entity which the camera is attached to.
    player: Player,
    sorted_at: Position = .{ .x = 0, .y = 0, .z = 0 },
    timer: std.time.Timer,
    delta: f32 = 0,
    frame: usize = 0,
    
    pub const ChunkStorage = std.AutoHashMap(ChunkPosition, *Chunk);
    pub const ChunkCache = Array(*Chunk);
    
    pub fn init() !*World {
        var self = try std.heap.c_allocator.create(World);
        self.* = World {
            .chunks = ChunkStorage.init(std.heap.c_allocator),
            .visible_chunks = ChunkCache.init(std.heap.c_allocator),
            .player = .{},
            .timer = undefined
        };
        
        self.timer = try std.time.Timer.start();
        
        return self;
    }
    
    pub fn deinit(self: *World) void {
        var iter = self.chunks.iterator();
        while (iter.next()) |i| std.heap.c_allocator.destroy(i.value_ptr.*);
        
        self.visible_chunks.deinit();
        self.chunks.deinit();
        std.heap.c_allocator.destroy(self);
    }
    
    pub fn update(self: *World) !void {
        self.frame += 1;
        
        const ns: f64 = @floatFromInt(self.timer.read());
        const ms: f64 = ns * 0.000001;
        self.delta = @floatCast(ms);
        std.log.info("ms: {d:.6}\n", .{ ms });
        
        self.player.super.update(&self.player, self);
        
        // Remove far away chunks from cache
        var remove_list = Array(ChunkPosition).init(std.heap.c_allocator);
        defer remove_list.deinit();
        for (self.visible_chunks.items) |chunk|
            if (self.player.super.position.distanceTo(.{
                .x = @floatFromInt(chunk.x * chunk_side),
                .y = self.player.super.position.y,
                .z = @floatFromInt(chunk.z * chunk_side)
            }) > chunk_side * render_distance * 1.6) // Multiply to account for diagonal and extend past fog.
                try remove_list.append(.{ .x = chunk.x, .z = chunk.z });
        
        for (remove_list.items) |pos| {
            const index = blk: {
                for (self.visible_chunks.items, 0..) |chunk, i| if (chunk.x == pos.x and chunk.z == pos.z) break :blk i;
                unreachable;
            };
            const x = self.visible_chunks.items[index].x;
            const z = self.visible_chunks.items[index].z;
            
            self.visible_chunks.items[index].mesh.?.deinit();
            self.visible_chunks.items[index].mesh = null;
            if (!self.visible_chunks.items[index].was_modified) {
                std.heap.c_allocator.destroy(self.chunks.get(.{ .x = x, .z = z }).?);
                _ = self.chunks.remove(.{ .x = x, .z = z });
            }
            _ = self.visible_chunks.swapRemove(index);
        }
        
        // Load (maybe generate) new chunks (extremely naive)
        // TODO(!): Create a list of missing chunks, sort and generate closest first
        if (self.frame % 10 == 0) { // Only generate every once in a while, that way it isn't noticeably slow.
            var ix: i32 = -render_distance; gen_loop: while (ix <= render_distance) : (ix += 1) {
                var iz: i32 = -render_distance; up: while (iz <= render_distance) : (iz += 1) {
                    const ofx = ix + @as(i32, @intFromFloat(@divFloor(self.player.super.position.x, chunk_side)));
                    const ofz = iz + @as(i32, @intFromFloat(@divFloor(self.player.super.position.z, chunk_side)));
                    
                    for (self.visible_chunks.items) |chunk| if (chunk.x == ofx and chunk.z == ofz) continue :up;
                    
                    // Get or generate
                    const result = try self.chunks.getOrPut(.{ .x = ofx, .z = ofz });
                    if (!result.found_existing) {
                        result.value_ptr.* = try std.heap.c_allocator.create(Chunk);
                        result.value_ptr.*.* = Chunk.init(self, ofx, ofz);
                    }
                    try self.visible_chunks.append(result.value_ptr.*);
                    if (result.value_ptr.*.mesh == null) result.value_ptr.*.mesh = Array(BlockVertex).init(std.heap.c_allocator);
                    try result.value_ptr.*.remesh();
                    
                    @prefetch(result.value_ptr.*, std.builtin.PrefetchOptions {
                        .cache = .data, .locality = 3, .rw = .read
                    });
                    @prefetch(result.value_ptr.*.mesh.?.items.ptr, std.builtin.PrefetchOptions {
                        .cache = .data, .locality = 3, .rw = .write
                    });
                    
                    // Remesh neighbors
                    const north = self.chunks.get(.{ .x = ofx, .z = ofz + 1 });
                    if (north != null and north.?.mesh != null) try north.?.remesh();
                    const south = self.chunks.get(.{ .x = ofx, .z = ofz - 1 });
                    if (south != null and south.?.mesh != null) try south.?.remesh();
                    const east = self.chunks.get(.{ .x = ofx + 1, .z = ofz });
                    if (east != null and east.?.mesh != null) try east.?.remesh();
                    const west = self.chunks.get(.{ .x = ofx - 1, .z = ofz });
                    if (west != null and west.?.mesh != null) try west.?.remesh();
                    
                    break :gen_loop; // Do not generate more than one per frame, too slow
                }
            }
        }
        
        // Sort visible chunks
        std.sort.heap(*const Chunk, self.visible_chunks.items, self.player.super.position, chunkDistanceCompare);
        
        // Sort inside nearby chunks
        if (self.player.super.position.distanceTo(self.sorted_at) > 1) {
            // for (self.visible_chunks.items) |chunk| chunk.sort();
            self.sorted_at = self.player.super.position;
        }
        
        _ = self.timer.lap();
    }
    
    fn chunkDistanceCompare(pos: Position, lhs: *const Chunk, rhs: *const Chunk) bool {
        return pos.distanceTo(.{ .x = @floatFromInt(lhs.x), .y = 0, .z = @floatFromInt(lhs.z) }) >
               pos.distanceTo(.{ .x = @floatFromInt(rhs.x), .y = 0, .z = @floatFromInt(rhs.z) });
    }
    
    pub fn getPrimaryMatrix(self: *const World) Matrix4x4 {
        const width: f32 = @floatFromInt(engine.getWidth());
        const height: f32 = @floatFromInt(engine.getHeight());
        
        return Matrix4x4.translation(
            -self.player.super.position.x,
            -self.player.super.position.y,
            -self.player.super.position.z
        )
        .mul(&Matrix4x4.rotation(.Yaw, self.player.super.orientation.yaw))
        .mul(&Matrix4x4.rotation(.Pitch, self.player.super.orientation.pitch))
        .mul(&Matrix4x4.projection(width, height, 80, 0.1, 1000));
    }
    
    pub fn getUnifiedMesh(self: *const World) !Array(BlockVertex) {
        var buf = Array(BlockVertex).init(std.heap.c_allocator);
        
        var total_count: usize = 0;
        for (self.visible_chunks.items) |chunk| total_count += chunk.*.mesh.?.items.len;
        try buf.ensureTotalCapacity(total_count);
        
        for (self.visible_chunks.items) |chunk| try buf.appendSlice(chunk.*.mesh.?.items);
        
        return buf;
    }
    
    pub fn isOpaqueAt(self: *const World, x: i32, y: i32, z: i32) bool {
        const cx = @divFloor(x, chunk_side);
        const cz = @divFloor(z, chunk_side);
        
        const lx = @mod((@mod(x, chunk_side) + chunk_side), chunk_side);
        const ly = y;
        const lz = @mod((@mod(z, chunk_side) + chunk_side), chunk_side);
        
        const chunk = self.chunks.get(.{ .x = cx, .z = cz }) orelse return true;
        // const chunk.isGenerated else { return true }
        const block = chunk.maybeGetBlockAt(lx, ly, lz) orelse return true;
        return block.atlas_offsets != null and !block.is_transparent;
    }
    
    pub fn lightLevelAt(self: *const World, x: i32, y: i32, z: i32) u8 {
        const cx = @divFloor(x, chunk_side);
        const cz = @divFloor(z, chunk_side);
        
        const lx = @mod((@mod(x, chunk_side) + chunk_side), chunk_side);
        const ly = y;
        const lz = @mod((@mod(z, chunk_side) + chunk_side), chunk_side);
        
        const chunk = self.chunks.get(.{ .x = cx, .z = cz }) orelse return 15;
        return chunk.maybeGetLightLevelAt(lx, ly, lz) orelse return 15;
    }
};

/// The key for chunk storage.
pub const ChunkPosition = packed struct { x: i32, z: i32 };

pub const chunk_side = 16;
pub const chunk_height = 256;

pub const Chunk = struct {
    world: *World,
    x: i32,
    z: i32,
    /// HACK: Dropping unmodified chunks from memory completely.
    /// Ideally just store the difference, this is very, very inefficient.
    was_modified: bool = false,
    blocks: [chunk_side][chunk_height][chunk_side]*const Block,
    light: [chunk_side][chunk_height][chunk_side]u8, // TODO(!): Test what this does as u4
    mesh: ?Array(BlockVertex),
    
    pub fn init(world: *World, x: i32, z: i32) Chunk {
        var buf = Chunk {
            .world = world,
            .x = x,
            .z = z,
            .blocks = @bitCast([_] *const Block { &Block.air } ** (chunk_side * chunk_height * chunk_side)),
            .light = @bitCast([_] u8 { 0 } ** (chunk_side * chunk_height * chunk_side)),
            .mesh = Array(BlockVertex).init(std.heap.c_allocator)
        };
        
        // Height pass
        for (0..chunk_side) |ix| {
            for (0..chunk_side) |iz| {
                const fix: f32 = @floatFromInt(ix);
                const fiz: f32 = @floatFromInt(iz);
                const fx: f32 = @floatFromInt(x);
                const fz: f32 = @floatFromInt(z);
                
                const pos_x = fix + chunk_side * fx;
                const pos_z = fiz + chunk_side * fz;
                
                const octave1 = engine.noise.perlin(pos_x * 0.01, pos_z * 0.01);
                const octave2 = engine.noise.perlin(pos_x * 0.05, pos_z * 0.05) / 2;
                const octave3 = engine.noise.perlin(pos_x * 0.1, pos_z * 0.1) / 4;
                
                const height = (octave1 + octave2 + octave3) / 3;
                
                for (0..chunk_height) |iy| {
                    const fiy: f32 = @floatFromInt(iy);
                    if (fiy < 160 * (height * 0.5 + 0.5)) buf.blocks[ix][iy][iz] = &Block.stone;
                    if (fiy >= 160 * (height * 0.5 + 0.5) and fiy < 76) buf.blocks[ix][iy][iz] = &Block.water;
                }
            }
        }
        
        // Dirt and grass pass
        for (0..chunk_side) |ix| {
            for (0..chunk_side) |iz| {
                const max_thickness = 3; // TODO(!): This has to be random but determined by seed
                var current_thickness: u32 = 0;
                var iyi: isize = chunk_height - 1; while (iyi >= 0) : (iyi -= 1) { const iy: usize = @intCast(iyi);
                    if (buf.blocks[ix][iy][iz] == &Block.stone) {
                        buf.blocks[ix][iy][iz] = if (current_thickness == 0) &Block.grass else &Block.dirt;
                        current_thickness += 1;
                    }
                    if (current_thickness == max_thickness) break;
                }
            }
        }
        
        buf.recomputeLight();
        return buf;
    }
    
    pub fn deinit(self: *const Chunk) void {
        if (self.mesh != null) self.mesh.?.deinit();
    }
    
    pub fn recomputeLight(self: *Chunk) void {
        // Ambient
        for (0..chunk_side) |ix| {
            for (0..chunk_side) |iz| {
                var iyi: isize = chunk_height - 1; while (iyi >= 0) : (iyi -= 1) { const iy: usize = @intCast(iyi);
                    if (self.blocks[ix][iy][iz] == &Block.air) {
                        self.light[ix][iy][iz] = 15;
                    } else {
                        break;
                    }
                }
            }
        }
    }
    
    /// Safe way to access block data, returns `null` on OOB access.
    pub fn maybeGetBlockAt(self: *const Chunk, x: i32, y: i32, z: i32) ?*const Block {
        if (x < 0 or y < 0 or z < 0 or x >= chunk_side or y >= chunk_height or z >= chunk_side) return null;
        const ux: usize = @intCast(x);
        const uy: usize = @intCast(y);
        const uz: usize = @intCast(z);
        return self.blocks[ux][uy][uz];
    }
    
    /// Safe way to access light data, returns `null` on OOB access.
    pub fn maybeGetLightLevelAt(self: *const Chunk, x: i32, y: i32, z: i32) ?u8 {
        if (x < 0 or y < 0 or z < 0 or x >= chunk_side or y >= chunk_height or z >= chunk_side) return null;
        const ux: usize = @intCast(x);
        const uy: usize = @intCast(y);
        const uz: usize = @intCast(z);
        return self.light[ux][uy][uz];
    }
    
    pub fn sort(self: *Chunk) void {
        // if (self.world.player.super.position.distanceTo(
        //     .{ .x = @floatFromInt(self.x), .y = self.world.player.super.position.y, .z = @floatFromInt(self.z) }
        // ) > chunk_side * 4) return;
    
        const pos = self.world.player.super.position;
        
        const triangles: [*][3]BlockVertex = @ptrCast(self.mesh.items.ptr);
        const len = self.mesh.items.len / 3;
        const slice = triangles[0..len];
        
        const camera = @Vector(3, f32) { pos.x, pos.y, pos.z };
        
        std.sort.heap([3]BlockVertex, slice, camera, triCompare);
    }
    
    fn triCompare(pos: @Vector(3, f32), lhs: [3]BlockVertex, rhs: [3]BlockVertex) bool {
        return triDistance(pos, lhs) > triDistance(pos, rhs);
    }
    
    fn triDistance(pos: @Vector(3, f32), tri: [3]BlockVertex) f32 {
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
    
    pub fn remesh(self: *Chunk) !void {
        self.mesh.?.clearRetainingCapacity();
        
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
                    
                    try block.mesh(self, self.facesFor(sx, sy, sz), fx + ofx, fy, fz + ofz, &self.mesh.?);
                }
            }
        }
    }
    
    inline fn facesFor(self: *const Chunk, x: i32, y: i32, z: i32) Block.Faces {
        const gx = x + self.x * chunk_side;
        const gy = y;
        const gz = z + self.z * chunk_side;
        
        return .{
            .north = !self.world.isOpaqueAt(gx,     gy,     gz + 1),
            .south = !self.world.isOpaqueAt(gx,     gy,     gz - 1),
            .east  = !self.world.isOpaqueAt(gx + 1, gy,     gz    ),
            .west  = !self.world.isOpaqueAt(gx - 1, gy,     gz    ),
            .up    = !self.world.isOpaqueAt(gx,     gy + 1, gz    ),
            .down  = !self.world.isOpaqueAt(gx,     gy - 1, gz    )
        };
    }
};

/// A collection of properties describing a block.
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
    
    pub fn mesh(self: *const Block, chunk: *const Chunk, faces: Faces, x: f32, y: f32, z: f32, vertices: *Array(BlockVertex)) !void {
        const off = self.atlas_offsets orelse return; // Abort if not drawable
        
        const s = half_side;
        const c = tex_uvc;
        
        const a: f32 = if (self.tag == .water) 1.0 else 1.0; // HACK :)
        
        const ix: i32 = @intFromFloat(@floor(x));
        const iy: i32 = @intFromFloat(@floor(y));
        const iz: i32 = @intFromFloat(@floor(z));
        
        // Back
        if (faces.north) {
            const light_level: f32 = @floatFromInt(chunk.world.lightLevelAt(ix, iy, iz + 1));
            const light_c = light_level / 15;
            const r: f32 = light_c;
            const g: f32 = light_c;
            const b: f32 = light_c;
            
            try vertices.appendSlice(&.{
                BlockVertex.init(-s + x,  s + y,  s + z,   c * off.back.x + c, c * off.back.y,       r, g, b, a), // TR
                BlockVertex.init( s + x,  s + y,  s + z,   c * off.back.x,     c * off.back.y,       r, g, b, a), // TL
                BlockVertex.init( s + x, -s + y,  s + z,   c * off.back.x,     c * off.back.y + c,   r, g, b, a), // BL
                BlockVertex.init(-s + x,  s + y,  s + z,   c * off.back.x + c, c * off.back.y,       r, g, b, a), // TR
                BlockVertex.init( s + x, -s + y,  s + z,   c * off.back.x,     c * off.back.y + c,   r, g, b, a), // BL
                BlockVertex.init(-s + x, -s + y,  s + z,   c * off.back.x + c, c * off.back.y + c,   r, g, b, a)  // BR
            });
        }
        // Front
        if (faces.south) {
            const light_level: f32 = @floatFromInt(chunk.world.lightLevelAt(ix, iy, iz - 1));
            const light_c = light_level / 15;
            const r: f32 = light_c;
            const g: f32 = light_c;
            const b: f32 = light_c;
            
            try vertices.appendSlice(&.{
                BlockVertex.init( s + x,  s + y, -s + z,   c * off.front.x + c, c * off.front.y,       r, g, b, a), // TR
                BlockVertex.init(-s + x,  s + y, -s + z,   c * off.front.x,     c * off.front.y,       r, g, b, a), // TL
                BlockVertex.init(-s + x, -s + y, -s + z,   c * off.front.x,     c * off.front.y + c,   r, g, b, a), // BL
                BlockVertex.init( s + x,  s + y, -s + z,   c * off.front.x + c, c * off.front.y,       r, g, b, a), // TR
                BlockVertex.init(-s + x, -s + y, -s + z,   c * off.front.x,     c * off.front.y + c,   r, g, b, a), // BL
                BlockVertex.init( s + x, -s + y, -s + z,   c * off.front.x + c, c * off.front.y + c,   r, g, b, a)  // BR
            });
        }
        // Right
        if (faces.east) {
            const light_level: f32 = @floatFromInt(chunk.world.lightLevelAt(ix + 1, iy, iz));
            const light_c = light_level / 15;
            const r: f32 = light_c;
            const g: f32 = light_c;
            const b: f32 = light_c;
            
            try vertices.appendSlice(&.{
                BlockVertex.init( s + x,  s + y,  s + z,   c * off.right.x + c, c * off.right.y,       r, g, b, a), // TR
                BlockVertex.init( s + x,  s + y, -s + z,   c * off.right.x,     c * off.right.y,       r, g, b, a), // TL
                BlockVertex.init( s + x, -s + y, -s + z,   c * off.right.x,     c * off.right.y + c,   r, g, b, a), // BL
                BlockVertex.init( s + x,  s + y,  s + z,   c * off.right.x + c, c * off.right.y,       r, g, b, a), // TR
                BlockVertex.init( s + x, -s + y, -s + z,   c * off.right.x,     c * off.right.y + c,   r, g, b, a), // BL
                BlockVertex.init( s + x, -s + y,  s + z,   c * off.right.x + c, c * off.right.y + c,   r, g, b, a)  // BR
            });
        }
        // Left
        if (faces.west) {
            const light_level: f32 = @floatFromInt(chunk.world.lightLevelAt(ix - 1, iy, iz));
            const light_c = light_level / 15;
            const r: f32 = light_c;
            const g: f32 = light_c;
            const b: f32 = light_c;
            
            try vertices.appendSlice(&.{
                BlockVertex.init(-s + x,  s + y, -s + z,   c * off.left.x + c, c * off.left.y,       r, g, b, a), // TR
                BlockVertex.init(-s + x,  s + y,  s + z,   c * off.left.x,     c * off.left.y,       r, g, b, a), // TL
                BlockVertex.init(-s + x, -s + y,  s + z,   c * off.left.x,     c * off.left.y + c,   r, g, b, a), // BL
                BlockVertex.init(-s + x,  s + y, -s + z,   c * off.left.x + c, c * off.left.y,       r, g, b, a), // TR
                BlockVertex.init(-s + x, -s + y,  s + z,   c * off.left.x,     c * off.left.y + c,   r, g, b, a), // BL
                BlockVertex.init(-s + x, -s + y, -s + z,   c * off.left.x + c, c * off.left.y + c,   r, g, b, a)  // BR
            });
        }
        // Top
        if (faces.up) {
            const light_level: f32 = @floatFromInt(chunk.world.lightLevelAt(ix, iy + 1, iz));
            const light_c = light_level / 15;
            const r: f32 = light_c;
            const g: f32 = light_c;
            const b: f32 = light_c;
            
            try vertices.appendSlice(&.{
                BlockVertex.init( s + x,  s + y,  s + z,   c * off.top.x + c, c * off.top.y,       r, g, b, a), // TR
                BlockVertex.init(-s + x,  s + y,  s + z,   c * off.top.x,     c * off.top.y,       r, g, b, a), // TL
                BlockVertex.init(-s + x,  s + y, -s + z,   c * off.top.x,     c * off.top.y + c,   r, g, b, a), // BL
                BlockVertex.init( s + x,  s + y,  s + z,   c * off.top.x + c, c * off.top.y,       r, g, b, a), // TR
                BlockVertex.init(-s + x,  s + y, -s + z,   c * off.top.x,     c * off.top.y + c,   r, g, b, a), // BL
                BlockVertex.init( s + x,  s + y, -s + z,   c * off.top.x + c, c * off.top.y + c,   r, g, b, a)  // BR
            });
        }
        // Bottom
        if (faces.down) {
            const light_level: f32 = @floatFromInt(chunk.world.lightLevelAt(ix, iy - 1, iz));
            const light_c = light_level / 15;
            const r: f32 = light_c;
            const g: f32 = light_c;
            const b: f32 = light_c;
            
            try vertices.appendSlice(&.{
                BlockVertex.init( s + x, -s + y, -s + z,   c * off.bottom.x + c, c * off.bottom.y,       r, g, b, a), // TR
                BlockVertex.init(-s + x, -s + y, -s + z,   c * off.bottom.x,     c * off.bottom.y,       r, g, b, a), // TL
                BlockVertex.init(-s + x, -s + y,  s + z,   c * off.bottom.x,     c * off.bottom.y + c,   r, g, b, a), // BL
                BlockVertex.init( s + x, -s + y, -s + z,   c * off.bottom.x + c, c * off.bottom.y,       r, g, b, a), // TR
                BlockVertex.init(-s + x, -s + y,  s + z,   c * off.bottom.x,     c * off.bottom.y + c,   r, g, b, a), // BL
                BlockVertex.init( s + x, -s + y,  s + z,   c * off.bottom.x + c, c * off.bottom.y + c,   r, g, b, a)  // BR
            });
        }
    }
    
    // MARK: - Instances -----------------------------------------------------------------------------------------------
    
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
        .is_transparent = false,
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

// MARK: - Entities ----------------------------------------------------------------------------------------------------

pub const gravity = 0.2;

pub const Position = extern struct {
    x: f32 = 0, y: f32 = 0, z: f32 = 0,
    
    pub inline fn distanceTo(self: Position, other: Position) f32 {
        const pow = std.math.pow;
        return @sqrt(
            pow(f32, self.x - other.x, 2) +
            pow(f32, self.y - other.y, 2) +
            pow(f32, self.z - other.z, 2)
        );
    }
    
    pub inline fn moveInDirectionAtSpeed(self: *Position, direction: Orientation, speed: f32) void {
        const heading = @Vector(3, f32) {
            @sin(std.math.degreesToRadians(direction.yaw)) * speed, 0,
            @cos(std.math.degreesToRadians(direction.yaw)) * speed
        };
        const svec: @Vector(3, f32) = @bitCast(self.*);
        self.* = @bitCast(heading + svec);
    }
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
        self.super.orientation.pitch = std.math.clamp(self.super.orientation.pitch, -90, 90);
            
        if (engine.input.key(.w)) self.super.position.moveInDirectionAtSpeed(self.super.orientation, 0.01 * world.delta);
        if (engine.input.key(.a)) self.super.position.moveInDirectionAtSpeed(
            .{ .pitch = self.super.orientation.pitch, .yaw = self.super.orientation.yaw + 270, .roll = self.super.orientation.roll },
            0.01 * world.delta
        );
        if (engine.input.key(.s)) self.super.position.moveInDirectionAtSpeed(
            .{ .pitch = self.super.orientation.pitch, .yaw = self.super.orientation.yaw + 180, .roll = self.super.orientation.roll },
            0.01 * world.delta
        );
        if (engine.input.key(.d)) self.super.position.moveInDirectionAtSpeed(
            .{ .pitch = self.super.orientation.pitch, .yaw = self.super.orientation.yaw + 90, .roll = self.super.orientation.roll },
            0.01 * world.delta
        );
        if (engine.input.key(.space)) self.super.position.y      += 0.01 * world.delta;
        if (engine.input.key(.left_shift)) self.super.position.y -= 0.01 * world.delta;
        
        // Basic, camera unaligned movement
        // if (engine.input.key(.w)) self.super.position.z          += 0.01 * world.delta;
        // if (engine.input.key(.a)) self.super.position.x          -= 0.01 * world.delta;
        // if (engine.input.key(.s)) self.super.position.z          -= 0.01 * world.delta;
        // if (engine.input.key(.d)) self.super.position.x          += 0.01 * world.delta;
    }
};
