
const TerrainVertexBuffer = @import("../gl/buffer.zig").TerrainVertexBuffer;
const Vertex = TerrainVertexBuffer.Vertex;

/// A collection of properties describing a block.
/// 
/// TODO(TeamPuzel):
/// - (!!) Benchmark usage through pointers vs inline.
/// - (?)  Light absorption coefficient, e.g. for water, which should get
///        progressively darker as depth increases.
pub const Block = packed struct {
    /// Identifies the exact type at runtime.
    tag: Tag,
    
    /// Describes which faces use which texture.
    /// Not present for invisible blocks.
    atlas_offsets: ?*const AtlasOffsets = null,
    
    /// Describes how much light is present at this location, has no effect
    /// on non-translucent blocks.
    light: u8 = 0,
    humidity: u8 = 0,
    temperature: u8 = 0,
    
    /// Determines if the block should collide with entities.
    is_solid: bool = true,
    
    /// Determines if adjacent blocks should render their faces.
    /// Transparent blocks are grouped together, rendered differently and
    /// also prevent adjacent blocks from culling connected faces.
    is_transparent: bool = false,
    
    /// Determines if light can pass through this block.
    /// If not set, block transparency is used instead.
    is_translucent: ?bool = null,
    
    pub const Tag = enum (u16) {
        Air,
        Stone
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
        front: bool,
        back: bool,
        left: bool,
        right: bool,
        top: bool,
        bottom: bool
    };
    
    /// The length of a block side.
    pub const side_len: comptime_float = 1;
    /// Half a block side length for use in vertices.
    pub const half_side = side_len / 2;
    
    /// The resolution of a single terrain atlas tile.
    pub const tex_block_size = 16;
    /// The resolution of the terrain atlas.
    pub const tex_side_len = 256;
    /// A coefficient for converting block coordinates to uv coordinates.
    pub const tex_uvc = tex_block_size / tex_side_len;
    
    pub fn mesh(self: *const Block, faces: Faces, buffer: *TerrainVertexBuffer) !void {
        const off = self.atlas_offsets orelse return; // Abort if not drawable
        
        const s = half_side; // Use shorter names for better readability
        const c = tex_uvc;
        const b = tex_block_size;
        
        // Front
        if (faces.front) {
            try buffer.vertices.appendSlice(&.{
                Vertex.init( s,  s, -s,   c * off.front.x + b, c * off.front.y,       1, 1, 1, 1), // TR
                Vertex.init(-s,  s, -s,   c * off.front.x,     c * off.front.y,       1, 1, 1, 1), // TL
                Vertex.init(-s, -s, -s,   c * off.front.x,     c * off.front.y + b,   1, 1, 1, 1), // BL
                Vertex.init( s,  s, -s,   c * off.front.x + b, c * off.front.y,       1, 1, 1, 1), // TR
                Vertex.init(-s, -s, -s,   c * off.front.x,     c * off.front.y + b,   1, 1, 1, 1), // BL
                Vertex.init( s, -s, -s,   c * off.front.x + b, c * off.front.y + b,   1, 1, 1, 1)  // BR
            });
        }
        // Back
        if (faces.back) {
            try buffer.vertices.appendSlice(&.{
                Vertex.init(-s,  s,  s,   c * off.front.x + b, c * off.front.y,       1, 1, 1, 1), // TR
                Vertex.init( s,  s,  s,   c * off.front.x,     c * off.front.y,       1, 1, 1, 1), // TL
                Vertex.init( s, -s,  s,   c * off.front.x,     c * off.front.y + b,   1, 1, 1, 1), // BL
                Vertex.init(-s,  s,  s,   c * off.front.x + b, c * off.front.y,       1, 1, 1, 1), // TR
                Vertex.init( s, -s,  s,   c * off.front.x,     c * off.front.y + b,   1, 1, 1, 1), // BL
                Vertex.init(-s, -s,  s,   c * off.front.x + b, c * off.front.y + b,   1, 1, 1, 1)  // BR
            });
        }
        // Left
        if (faces.left) {
            try buffer.vertices.appendSlice(&.{
                Vertex.init(-s,  s, -s,   c * off.front.x + b, c * off.front.y,       1, 1, 1, 1), // TR
                Vertex.init(-s,  s,  s,   c * off.front.x,     c * off.front.y,       1, 1, 1, 1), // TL
                Vertex.init(-s, -s,  s,   c * off.front.x,     c * off.front.y + b,   1, 1, 1, 1), // BL
                Vertex.init(-s,  s, -s,   c * off.front.x + b, c * off.front.y,       1, 1, 1, 1), // TR
                Vertex.init(-s, -s,  s,   c * off.front.x,     c * off.front.y + b,   1, 1, 1, 1), // BL
                Vertex.init(-s, -s, -s,   c * off.front.x + b, c * off.front.y + b,   1, 1, 1, 1)  // BR
            });
        }
        // Right
        if (faces.right) {
            try buffer.vertices.appendSlice(&.{
                Vertex.init( s,  s,  s,   c * off.front.x + b, c * off.front.y,       1, 1, 1, 1), // TR
                Vertex.init( s,  s, -s,   c * off.front.x,     c * off.front.y,       1, 1, 1, 1), // TL
                Vertex.init( s, -s, -s,   c * off.front.x,     c * off.front.y + b,   1, 1, 1, 1), // BL
                Vertex.init( s,  s,  s,   c * off.front.x + b, c * off.front.y,       1, 1, 1, 1), // TR
                Vertex.init( s, -s, -s,   c * off.front.x,     c * off.front.y + b,   1, 1, 1, 1), // BL
                Vertex.init( s, -s,  s,   c * off.front.x + b, c * off.front.y + b,   1, 1, 1, 1)  // BR
            });
        }
        // Top
        if (faces.top) {
            try buffer.vertices.appendSlice(&.{
                Vertex.init( s,  s,  s,   c * off.front.x + b, c * off.front.y,       1, 1, 1, 1), // TR
                Vertex.init(-s,  s,  s,   c * off.front.x,     c * off.front.y,       1, 1, 1, 1), // TL
                Vertex.init(-s,  s, -s,   c * off.front.x,     c * off.front.y + b,   1, 1, 1, 1), // BL
                Vertex.init( s,  s,  s,   c * off.front.x + b, c * off.front.y,       1, 1, 1, 1), // TR
                Vertex.init(-s,  s, -s,   c * off.front.x,     c * off.front.y + b,   1, 1, 1, 1), // BL
                Vertex.init( s,  s, -s,   c * off.front.x + b, c * off.front.y + b,   1, 1, 1, 1)  // BR
            });
        }
        // Bottom
        if (faces.bottom) {
            try buffer.vertices.appendSlice(&.{
                Vertex.init( s, -s, -s,   c * off.front.x + b, c * off.front.y,       1, 1, 1, 1), // TR
                Vertex.init( s, -s,  s,   c * off.front.x,     c * off.front.y,       1, 1, 1, 1), // TL
                Vertex.init(-s, -s,  s,   c * off.front.x,     c * off.front.y + b,   1, 1, 1, 1), // BL
                Vertex.init( s, -s, -s,   c * off.front.x + b, c * off.front.y,       1, 1, 1, 1), // TR
                Vertex.init(-s, -s,  s,   c * off.front.x,     c * off.front.y + b,   1, 1, 1, 1), // BL
                Vertex.init(-s, -s, -s,   c * off.front.x + b, c * off.front.y + b,   1, 1, 1, 1)  // BR
            });
        }
    }
    
    // MARK: - Instances -------------------------------------------------------
    
    /// This special block represents the absence of a block.
    pub const Air = Block {
        .tag = .Air,
        .is_solid = false
    };
    
    /// A generic underground stone block.
    pub const Stone = Block {
        .tag = .Stone,
        .atlas_offsets = &.{
            .front  = .{ .x = 1, .y = 0 },
            .back   = .{ .x = 1, .y = 0 },
            .left   = .{ .x = 1, .y = 0 },
            .right  = .{ .x = 1, .y = 0 },
            .top    = .{ .x = 1, .y = 0 },
            .bottom = .{ .x = 1, .y = 0 }
        }
    };
};
