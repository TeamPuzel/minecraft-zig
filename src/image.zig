
const c = @import("c.zig");

pub const Color = packed struct {
    r: f32 = 0,
    g: f32 = 0,
    b: f32 = 0,
    a: f32 = 1,
    
    pub fn bind(self: *const Color) void {
        c.glColor4f(self.r, self.g, self.b, self.a);
    }
    
    pub const white = Color { .r = 1, .g = 1, .b = 1, .a = 1 };
    pub const black = Color { .r = 1, .g = 1, .b = 1, .a = 1 };
};

pub const Image = struct {
    pixels: [*c]Color,
    width: i32,
    height: i32,
    
    _surface: [*c]c.SDL_Surface,
    _texture_id: ?u32 = null,
    
    pub fn deinit(self: *Image) void {
        c.SDL_FreeSurface(self._surface);
        if (self._texture_id != null) {
            c.glDeleteTextures(1, &self._texture_id.?);
        }
    }
    
    pub fn becomeTexture(self: *Image) void {
        var id: u32 = undefined;
        c.glGenTextures(1, &id);
        self._texture_id = id;
        
        self.bind();
        c.glTexImage2D(
            c.GL_TEXTURE_2D,
            0,
            c.GL_RGBA,
            self.width,
            self.height,
            0,
            c.GL_RGBA,
            c.GL_UNSIGNED_BYTE,
            self.pixels
        );
        
        c.glTexParameterf(c.GL_TEXTURE_2D, c.GL_TEXTURE_MIN_FILTER, c.GL_NEAREST);
        c.glTexParameterf(c.GL_TEXTURE_2D, c.GL_TEXTURE_MAG_FILTER, c.GL_NEAREST);
        c.glTexParameterf(c.GL_TEXTURE_2D, c.GL_TEXTURE_WRAP_S, c.GL_REPEAT);
        c.glTexParameterf(c.GL_TEXTURE_2D, c.GL_TEXTURE_WRAP_T, c.GL_REPEAT);
    }
    
    pub fn bind(self: *Image) void {
        c.glBindTexture(c.GL_TEXTURE_2D, self._texture_id.?);
    }
};