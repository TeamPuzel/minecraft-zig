
pub const TGAConstPtr = packed struct {
    raw: [*]const u8,
    
    pub fn getWidth(self: TGAConstPtr) u16 { @setRuntimeSafety(false);
        const w: *const u16 = @alignCast(@ptrCast(self.raw + 12)); return w.*;
    }
    
    pub fn getHeight(self: TGAConstPtr) u16 { @setRuntimeSafety(false);
        const h: *const u16 = @alignCast(@ptrCast(self.raw + 14)); return h.*;
    }
    
    pub fn asPixelSlice(self: TGAConstPtr) []const BGRA { @setRuntimeSafety(false);
        const pixels: [*]const BGRA = @alignCast(@ptrCast(self.raw + 18));
        return pixels[0..(@as(usize, self.getWidth()) * @as(usize, self.getHeight()))];
    }
    
    pub fn getPixelAt(self: TGAConstPtr, x: usize, y: usize) BGRA {
        return self.asPixelSlice()[x + y * self.getWidth()];
    }
};

pub const BGRA = extern struct { b: u8, g: u8, r: u8, a: u8 };
