
const c = @import("../platform/c.zig");
const std = @import("std");
const assets = @import("../assets/assets.zig");

pub const Texture = packed struct {
    id: u32,
    
    pub var terrain: Texture = undefined;
    
    /// Creates all textures.
    pub fn init() !void {
        terrain = try Texture.create(assets.terrain);
    }

    /// Destroys all textures.
    pub fn deinit() void {
        terrain.destroy();
    }
    
    fn create(data: []const u8) !Texture {
        // Load image
        const rw = c.SDL_RWFromConstMem(data.ptr, @intCast(data.len));
        defer _ = c.SDL_RWclose(rw);
        
        const temp_surface = c.IMG_Load_RW(rw, 0);
        defer c.SDL_FreeSurface(temp_surface);
        
        const surface = c.SDL_ConvertSurfaceFormat(
            temp_surface, c.SDL_PIXELFORMAT_RGBA32, 0
        );
        defer c.SDL_FreeSurface(surface);
        
        // Create texture
        var tex: Texture = undefined;
        c.glGenTextures(1, &tex.id);
        
        tex.bind();
        
        c.glTexImage2D(
            c.GL_TEXTURE_2D,
            0,
            c.GL_RGBA,
            surface.*.w,
            surface.*.h,
            0,
            c.GL_RGBA,
            c.GL_UNSIGNED_BYTE,
            surface.*.pixels
        );
        
        c.glTexParameteri(c.GL_TEXTURE_2D, c.GL_TEXTURE_MIN_FILTER, c.GL_NEAREST);
        c.glTexParameteri(c.GL_TEXTURE_2D, c.GL_TEXTURE_MAG_FILTER, c.GL_NEAREST);
        c.glTexParameteri(c.GL_TEXTURE_2D, c.GL_TEXTURE_WRAP_S, c.GL_REPEAT);
        c.glTexParameteri(c.GL_TEXTURE_2D, c.GL_TEXTURE_WRAP_T, c.GL_REPEAT);
        
        return tex;
    }
    
    pub fn destroy(self: *Texture) void {
        c.glDeleteTextures(1, &self.id);
    }
    
    pub fn bind(self: *const Texture) void {
        c.glBindTexture(c.GL_TEXTURE_2D, self.id);
    }
};