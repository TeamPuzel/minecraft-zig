
const std = @import("std");
const c = @import("c.zig");

const terrain = @embedFile("assets/terrain.png");

var width: c_int = 600;
var height: c_int = 600;
var is_hidpi: bool = false;

pub fn main() !void {
    _ = c.SDL_Init(c.SDL_INIT_VIDEO);
    defer c.SDL_Quit();
    
    _ = c.IMG_Init(c.IMG_INIT_PNG);
    defer c.IMG_Quit();
    
    _ = c.SDL_GL_LoadLibrary(null);
    
    // Textures
    const rw = c.SDL_RWFromConstMem(terrain.ptr, terrain.len);
    const temp_surface = c.IMG_Load_RW(rw, 0);
    const surface = c.SDL_ConvertSurfaceFormat(temp_surface, c.SDL_PIXELFORMAT_RGBA32, 0);
    
    _ = c.SDL_RWclose(rw);
    
    // Window
    const window = c.SDL_CreateWindow(
        "Not Minecraft",
        c.SDL_WINDOWPOS_UNDEFINED,
        c.SDL_WINDOWPOS_UNDEFINED,
        width, height,
        c.SDL_WINDOW_ALLOW_HIGHDPI |
        c.SDL_WINDOW_OPENGL |
        c.SDL_WINDOW_ALWAYS_ON_TOP |
        c.SDL_WINDOW_RESIZABLE
    ) orelse return error.CreatingWindow;
    defer c.SDL_DestroyWindow(window);
    
    _ = c.SDL_SetRelativeMouseMode(1);
    
    // OpenGL
    _ = c.SDL_GL_SetAttribute(c.SDL_GL_CONTEXT_MAJOR_VERSION, 1);
    _ = c.SDL_GL_SetAttribute(c.SDL_GL_CONTEXT_MINOR_VERSION, 1);
    _ = c.SDL_GL_SetAttribute(
        c.SDL_GL_CONTEXT_PROFILE_MASK, c.SDL_GL_CONTEXT_PROFILE_COMPATIBILITY
    );
    _ = c.SDL_GL_SetAttribute(c.SDL_GL_DOUBLEBUFFER, 1);
    
    _ = c.SDL_GL_SetSwapInterval(1);
    
    const context = c.SDL_GL_CreateContext(window);
    defer c.SDL_GL_DeleteContext(context);
    
    var event: c.SDL_Event = undefined;
    
    c.glClearColor(0.0, 0.0, 0.0, 1.0);
    c.glEnable(c.GL_DEPTH_TEST);
    c.glEnable(c.GL_TEXTURE_2D);
    
    var tex: c_uint = undefined;
    c.glGenTextures(1, &tex);
    c.glBindTexture(c.GL_TEXTURE_2D, tex);
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
    
    c.glTexParameterf(c.GL_TEXTURE_2D, c.GL_TEXTURE_MIN_FILTER, c.GL_NEAREST);
    c.glTexParameterf(c.GL_TEXTURE_2D, c.GL_TEXTURE_MAG_FILTER, c.GL_NEAREST);
    c.glTexParameterf(c.GL_TEXTURE_2D, c.GL_TEXTURE_WRAP_S, c.GL_REPEAT);
    c.glTexParameterf(c.GL_TEXTURE_2D, c.GL_TEXTURE_WRAP_T, c.GL_REPEAT);
    
    c.glColor3f(1, 1, 1);
    
    loop:
    while (true) {
        // Events
        while (c.SDL_PollEvent(&event) > 0) {
            switch (event.type) {
                c.SDL_QUIT => break :loop,
                else => break
            }
        }
        
        // Mouse look
        var mx: c_int = undefined;
        var my: c_int = undefined;
        _ = c.SDL_GetRelativeMouseState(&mx, &my);
        const mxf: f64 = @floatFromInt(mx);
        const myf: f64 = @floatFromInt(my);
        facing_h += mxf / 10;
        facing_v += myf / 10;
        // facing_h = @mod(facing_h, 360);
        // facing_v = @mod(facing_v, 360);
        
        facing_v = std.math.clamp(facing_v, -90, 90);
        
        processInput();
        
        c.SDL_GL_GetDrawableSize(window, &width, &height);
        c.glViewport(0, 0, width, height);
        
        // Draw
        c.glClear(c.GL_COLOR_BUFFER_BIT | c.GL_DEPTH_BUFFER_BIT);
        
        c.glMatrixMode(c.GL_PROJECTION);
        c.glPushMatrix();
        
        const width_f64: f64 = @floatFromInt(width);
        const height_f64: f64 = @floatFromInt(height);
        const aspect = width_f64 / height_f64;
        
        // NOTE: Matrices take effect backwards
        c.glFrustum(-aspect / 2, aspect / 2, -0.5, 0.5, 0.4, 50);
        
        c.glRotated(facing_v, 1, 0, 0);
        c.glRotated(facing_h, 0, 1, 0);
        
        c.glTranslated(pos_x, pos_y, pos_z);
        // c.glRotatef(t / 150, 1, 0, 0);
        // c.glRotatef(t / 75, 0, 1, 0);
        
        Block.grass.draw(0, 0);
        
        c.glPopMatrix();
        
        c.SDL_GL_SwapWindow(window);
        t += 1;
    }
}

var t: f32 = 0;
var facing_v: f64 = 0;
var facing_h: f64 = 0;
var pos_x: f64 = 0;
var pos_y: f64 = 0;
var pos_z: f64 = -1.5;

fn vecFromAngle(deg: f64) packed struct { x: f64, y: f64 } {
    const x: f32 = 0;
    const y: f32 = 1;
    const rad = std.math.degreesToRadians(f64, deg);
    const sin = std.math.sin(rad);
    const cos = std.math.cos(rad);
    return .{
        .x = x * cos - y * sin,
        .y = x * sin + y * cos
    };
}

fn processInput() void {
    const keymap = c.SDL_GetKeyboardState(null);
    
    const heading = vecFromAngle(facing_h);
    
    if (keymap[c.SDL_SCANCODE_W] == 1) {
        pos_x += heading.x / 7000;
        pos_z += heading.y / 7000;
    }
}

const Color = packed struct {
    r: f32, g: f32, b: f32, a: f32,
    
    fn bind(self: *const Color) void {
        c.glColor4f(self.r, self.g, self.b, self.a);
    }
    
    const white = Color { .r = 1, .g = 1, .b = 1, .a = 1 }; 
};

const Block = struct {
    texture: struct {
        const Pos = packed struct { x: u32, y: u32, color: Color = Color.white };
        front: Pos,
        back: Pos,
        left: Pos,
        right: Pos,
        top: Pos,
        bottom: Pos
    },
    
    const size: f32 = 0.5;
    const atlas_scale = 0.0625;
    
    fn draw(self: *const Block, x: i64, y: i64) void {
        _ = self; _ = x; _ = y;
        
        // Back
        c.glBegin(c.GL_QUADS);
        c.glTexCoord2f(0.1875, 0.0625);
        c.glVertex3f(size,-size, size);
        c.glTexCoord2f(0.1875, 0);
        c.glVertex3f(size, size, size);
        c.glTexCoord2f(0.25, 0);
        c.glVertex3f(-size, size, size);
        c.glTexCoord2f(0.25, 0.0625);
        c.glVertex3f(-size, -size, size);
        c.glEnd();
        
        // Right
        c.glBegin(c.GL_QUADS);
        c.glTexCoord2f(0.1875, 0.0625);
        c.glVertex3f(size, -size, -size);
        c.glTexCoord2f(0.1875, 0);
        c.glVertex3f(size, size, -size);
        c.glTexCoord2f(0.25, 0);
        c.glVertex3f(size, size, size);
        c.glTexCoord2f(0.25, 0.0625);
        c.glVertex3f(size, -size, size);
        c.glEnd();
        
        // Left
        c.glBegin(c.GL_QUADS);
        c.glTexCoord2f(0.1875, 0.0625);
        c.glVertex3f(-size, -size, size);
        c.glTexCoord2f(0.1875, 0);
        c.glVertex3f(-size, size, size);
        c.glTexCoord2f(0.25, 0);
        c.glVertex3f(-size, size, -size);
        c.glTexCoord2f(0.25, 0.0625);
        c.glVertex3f(-size, -size, -size);
        c.glEnd();
        
        // Top
        c.glColor3f(0.6, 1, 0.4);
        c.glBegin(c.GL_QUADS);
        c.glTexCoord2f(0, 0);
        c.glVertex3f(size, size, size);
        c.glTexCoord2f(0.0625, 0);
        c.glVertex3f(size, size, -size);
        c.glTexCoord2f(0.0625, 0.0625);
        c.glVertex3f(-size, size, -size);
        c.glTexCoord2f(0, 0.0625);
        c.glVertex3f(-size, size, size);
        c.glEnd();
        c.glColor3f(1, 1, 1);
        
        // Bottom
        c.glBegin(c.GL_QUADS);
        c.glTexCoord2f(0.0625 * 2, 0.0625);
        c.glVertex3f(size, -size, -size);
        c.glTexCoord2f(0.0625 * 2, 0);
        c.glVertex3f(size, -size, size);
        c.glTexCoord2f(0.0625 * 3, 0);
        c.glVertex3f(-size, -size, size);
        c.glTexCoord2f(0.0625 * 3, 0.0625);
        c.glVertex3f(-size, -size, -size);
        c.glEnd();
        
        // Front
        c.glBegin(c.GL_QUADS);
        c.glTexCoord2f(0.1875, 0.0625);
        c.glVertex3f(-size, -size, -size);
        c.glTexCoord2f(0.1875, 0);
        c.glVertex3f(-size, size, -size);
        c.glTexCoord2f(0.25, 0);
        c.glVertex3f(size, size, -size);
        c.glTexCoord2f(0.25, 0.0625);
        c.glVertex3f(size, -size, -size); 
        c.glEnd();
    }
    
    const grass = Block {
        .texture = .{
            .front = .{ .x = 3, .y = 0 },
            .back = .{ .x = 3, .y = 0 },
            .left = .{ .x = 3, .y = 0 },
            .right = .{ .x = 3, .y = 0 },
            .top = .{ .x = 0, .y = 0 },
            .bottom = .{ .x = 2, .y = 0 }
        }
    };
};