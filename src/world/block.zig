
const TerrainVertexBuffer = @import("../gl/buffer.zig").TerrainVertexBuffer;
const Vertex = TerrainVertexBuffer.Vertex;

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
    
    pub const Tag = enum (u16) {
        Air,
        Stone,
        Dirt
    };
    
    pub const Properties = packed struct {
        
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
        front:  bool = true,
        back:   bool = true,
        left:   bool = true,
        right:  bool = true,
        top:    bool = true,
        bottom: bool = true
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
        
        const sx = half_side + x;
        const sy = half_side + y;
        const sz = half_side + z;
        const c = tex_uvc;
        
        // Front
        if (faces.front) {
            try buffer.vertices.appendSlice(&.{
                Vertex.init( sx,  sy, -sz,   c * off.front.x + c, c * off.front.y,       1, 1, 1, 1), // TR
                Vertex.init(-sx,  sy, -sz,   c * off.front.x,     c * off.front.y,       1, 1, 1, 1), // TL
                Vertex.init(-sx, -sy, -sz,   c * off.front.x,     c * off.front.y + c,   1, 1, 1, 1), // BL
                Vertex.init( sx,  sy, -sz,   c * off.front.x + c, c * off.front.y,       1, 1, 1, 1), // TR
                Vertex.init(-sx, -sy, -sz,   c * off.front.x,     c * off.front.y + c,   1, 1, 1, 1), // BL
                Vertex.init( sx, -sy, -sz,   c * off.front.x + c, c * off.front.y + c,   1, 1, 1, 1)  // BR
            });
        }
        // Back
        if (faces.back) {
            try buffer.vertices.appendSlice(&.{
                Vertex.init(-sx,  sy,  sz,   c * off.front.x + c, c * off.front.y,       1, 1, 1, 1), // TR
                Vertex.init( sx,  sy,  sz,   c * off.front.x,     c * off.front.y,       1, 1, 1, 1), // TL
                Vertex.init( sx, -sy,  sz,   c * off.front.x,     c * off.front.y + c,   1, 1, 1, 1), // BL
                Vertex.init(-sx,  sy,  sz,   c * off.front.x + c, c * off.front.y,       1, 1, 1, 1), // TR
                Vertex.init( sx, -sy,  sz,   c * off.front.x,     c * off.front.y + c,   1, 1, 1, 1), // BL
                Vertex.init(-sx, -sy,  sz,   c * off.front.x + c, c * off.front.y + c,   1, 1, 1, 1)  // BR
            });
        }
        // Left
        if (faces.left) {
            try buffer.vertices.appendSlice(&.{
                Vertex.init(-sx,  sy, -sz,   c * off.front.x + c, c * off.front.y,       1, 1, 1, 1), // TR
                Vertex.init(-sx,  sy,  sz,   c * off.front.x,     c * off.front.y,       1, 1, 1, 1), // TL
                Vertex.init(-sx, -sy,  sz,   c * off.front.x,     c * off.front.y + c,   1, 1, 1, 1), // BL
                Vertex.init(-sx,  sy, -sz,   c * off.front.x + c, c * off.front.y,       1, 1, 1, 1), // TR
                Vertex.init(-sx, -sy,  sz,   c * off.front.x,     c * off.front.y + c,   1, 1, 1, 1), // BL
                Vertex.init(-sx, -sy, -sz,   c * off.front.x + c, c * off.front.y + c,   1, 1, 1, 1)  // BR
            });
        }
        // Right
        if (faces.right) {
            try buffer.vertices.appendSlice(&.{
                Vertex.init( sx,  sy,  sz,   c * off.front.x + c, c * off.front.y,       1, 1, 1, 1), // TR
                Vertex.init( sx,  sy, -sz,   c * off.front.x,     c * off.front.y,       1, 1, 1, 1), // TL
                Vertex.init( sx, -sy, -sz,   c * off.front.x,     c * off.front.y + c,   1, 1, 1, 1), // BL
                Vertex.init( sx,  sy,  sz,   c * off.front.x + c, c * off.front.y,       1, 1, 1, 1), // TR
                Vertex.init( sx, -sy, -sz,   c * off.front.x,     c * off.front.y + c,   1, 1, 1, 1), // BL
                Vertex.init( sx, -sy,  sz,   c * off.front.x + c, c * off.front.y + c,   1, 1, 1, 1)  // BR
            });
        }
        // Top
        if (faces.top) {
            try buffer.vertices.appendSlice(&.{
                Vertex.init( sx,  sy,  sz,   c * off.front.x + c, c * off.front.y,       1, 1, 1, 1), // TR
                Vertex.init(-sx,  sy,  sz,   c * off.front.x,     c * off.front.y,       1, 1, 1, 1), // TL
                Vertex.init(-sx,  sy, -sz,   c * off.front.x,     c * off.front.y + c,   1, 1, 1, 1), // BL
                Vertex.init( sx,  sy,  sz,   c * off.front.x + c, c * off.front.y,       1, 1, 1, 1), // TR
                Vertex.init(-sx,  sy, -sz,   c * off.front.x,     c * off.front.y + c,   1, 1, 1, 1), // BL
                Vertex.init( sx,  sy, -sz,   c * off.front.x + c, c * off.front.y + c,   1, 1, 1, 1)  // BR
            });
        }
        // Bottom
        if (faces.bottom) {
            try buffer.vertices.appendSlice(&.{
                Vertex.init( sx, -sy, -sz,   c * off.front.x + c, c * off.front.y,       1, 1, 1, 1), // TR
                Vertex.init( sx, -sy,  sz,   c * off.front.x,     c * off.front.y,       1, 1, 1, 1), // TL
                Vertex.init(-sx, -sy,  sz,   c * off.front.x,     c * off.front.y + c,   1, 1, 1, 1), // BL
                Vertex.init( sx, -sy, -sz,   c * off.front.x + c, c * off.front.y,       1, 1, 1, 1), // TR
                Vertex.init(-sx, -sy,  sz,   c * off.front.x,     c * off.front.y + c,   1, 1, 1, 1), // BL
                Vertex.init(-sx, -sy, -sz,   c * off.front.x + c, c * off.front.y + c,   1, 1, 1, 1)  // BR
            });
        }
    }
    
    // MARK: - Instances -------------------------------------------------------
    
    /// This special block represents the absence of a block.
    pub const air = Block {
        .tag = .Air
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
    
    /// A generic underground stone block.
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
};
