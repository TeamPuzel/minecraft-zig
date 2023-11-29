
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
    atlas_offsets: ?AtlasOffsets = null,
    
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
    
    pub const Tag = enum {
        Air,
        Stone
    };
    
    pub const AtlasOffsets = struct {
        front:  @Vector(2, i32),
        back:   @Vector(2, i32),
        left:   @Vector(2, i32),
        right:  @Vector(2, i32),
        top:    @Vector(2, i32),
        bottom: @Vector(2, i32)
    };
    
    /// A mask used to communicate which faces need to be meshed.
    pub const Faces = packed struct {
        left: bool,
        right: bool,
        top: bool,
        bottom: bool,
        front: bool,
        back: bool
    }; 
    
    pub fn mesh(self: *const Block, vertices: []BlockVertex) void {
        
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
        .atlas_offsets = .{
            .front  = [_]i32 { 1, 0 },
            .back   = [_]i32 { 1, 0 },
            .left   = [_]i32 { 1, 0 },
            .right  = [_]i32 { 1, 0 },
            .top    = [_]i32 { 1, 0 },
            .bottom = [_]i32 { 1, 0 }
        }
    };
};
