
const Block = @import("block.zig").Block;

pub const chunk_size = 16;
pub const chunk_height = 256;

pub const Chunk = packed struct {
    blocks: [chunk_size][chunk_height][chunk_size]Block,
    
    pub const Neighbors = packed struct {
        
    };
    
    pub fn update(self: *Chunk) void {
        
    }
    
    pub fn mesh(self: *const Chunk ???) void {
        // TODO
    }
};