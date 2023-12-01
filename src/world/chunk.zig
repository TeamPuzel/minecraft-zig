
const TerrainVertexBuffer = @import("../gl/buffer.zig").TerrainVertexBuffer;
const Block = @import("block.zig").Block;

pub const chunk_side = 16;
pub const chunk_height = 256;

pub const Chunk = packed struct {
    /// NOTE: Consider making this a method instead, could be easier to maintain.
    is_loaded: bool = true,
    /// A large chunk of memory storing blocks.
    blocks: [chunk_side][chunk_height][chunk_side]Block,
    
    /// Quite often, especially when rendering, chunks need to be able to
    /// efficiently refer to neighboring chunks. This is important because
    /// chunks are stored in a hash map. It is important not to invalidate
    /// these pointers. They are `null` if the chunk is not generated yet,
    /// however they remain valid for unloaded chunks - to check if a generated
    /// chunk is loaded for rendering purposes use `is_loaded` instead, as
    /// it can be used to cull faces more efficiently at chunk boundaries.
    neighbors: packed struct {
        north: ?*Chunk,
        south: ?*Chunk,
        east:  ?*Chunk,
        west:  ?*Chunk
    },
    
    pub fn update(self: *Chunk) void {
        _ = self;
    }
    
    pub fn mesh(self: *const Chunk, buffer: *TerrainVertexBuffer) void {
        
    }
};