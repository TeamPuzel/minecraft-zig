
const std = @import("std");
const Chunk = @import("chunk.zig").Chunk;

pub const World = packed struct {
    chunk_cache: ChunkCache,
    chunks: std.AutoHashMap(ChunkPosition, Chunk),
    time: u64 = 0,
    season: Season = .Spring,
    name: []const u8,
    
    pub const Season = enum {
        Spring, Summer, Autumn, Winter
    };
    
    pub fn generate(name: []const u8) World {
        
    }
    
    pub fn update(self: *World) void {
        
    }
    
    pub fn draw(self: *const World) void {
        
    }
    
    fn rebuildCache(self: *World) void {
        _ = self;
        unreachable;
    }
    
    /// Load the world from the world folder.
    pub fn load(name: []const u8) LoadError!World {
        _ = name;
        unreachable;
    }
    
    /// Save the world to the world folder.
    pub fn save(self: *const World) SaveError!void {
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
pub const ChunkPosition = packed struct { x: i64, z: i64 };

/// Stores pointers to all "loaded" chunks,
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