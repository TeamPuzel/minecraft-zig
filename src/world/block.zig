
const TerrainVertexBuffer = @import("../gl/buffer.zig").TerrainVertexBuffer;
const Vertex = TerrainVertexBuffer.Vertex;
const Chunk = @import("world.zig").Chunk;

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
        Air,
        Stone,
        Dirt,
        Grass,
        Water,
        Sand
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
    
    pub fn mesh(self: *const Block, faces: Faces, x: f32, y: f32, z: f32, buffer: *TerrainVertexBuffer) !void {
        const off = self.atlas_offsets orelse return; // Abort if not drawable
        
        const s = half_side;
        const c = tex_uvc;
        const o: f32 = if (self.tag == .Water) 0.4 else 1.0;
        
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
        .tag = .Air,
        .is_transparent = true
    };
    
    /// A generic underground stone block.
    pub const stone = Block {
        .tag = .Stone,
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
        .tag = .Dirt,
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
        .tag = .Grass,
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
        .tag = .Dirt,
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
        .tag = .Water,
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
