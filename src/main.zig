
const std = @import("std");
const c = @import("c.zig");

const terrain = @embedFile("assets/terrain.png");

const noise = @import("noise.zig");
const perlin = @import("stb_perlin.zig");
const Application = @import("application.zig").Application;
const Color = @import("image.zig").Color;

var gpa = std.heap.GeneralPurposeAllocator(.{}) {};
var alloc = gpa.allocator();

pub fn main() !void {
    var app = try Application.init("Minecraft", 800, 600);
    defer app.deinit();
    
    var world = World.init();
    
    // Textures
    var atlas = app.pngToRGBA(terrain);
    defer atlas.deinit();
    
    atlas.becomeTexture();
    
    while (!app.shouldQuit()) {
        world.update();
        world.draw(&app);
        app.swapBuffers();
    }
}

const World = struct {
    tick: u64 = 0,
    player: Player = .{},
    entities: std.ArrayList(?*anyopaque),
    chunks: Chunks,
    
    const Chunks = std.AutoHashMap(packed struct { x: i64, z: i64 }, Chunk);
    
    fn init() World {
        var world = World {
            .entities = std.ArrayList(?*anyopaque).init(alloc),
            .chunks = Chunks.init(alloc)
        };
        world.player.super.position = @Vector(3, f64) { 0, 84, 0 };
        return world;
    }
    
    fn deinit(self: *World) void {
        self.chunks.deinit();
        self.entities.deinit();
    }
    
    fn update(self: *World) void {
        self.player.update();
        self.generateChunks();
        self.tick += 1;
    }
    
    fn generateChunks(self: *World) void {
        var xi: i64 = -5;
        while (xi <= 5) {
            var zi: i64 = -5;
            while (zi <= 5) {
                if (!self.chunks.contains(.{ .x = xi, .z = zi }))
                    self.chunks.putNoClobber(
                        .{ .x = xi, .z = zi },
                        Chunk.generate(xi, zi)
                    ) catch {};
                zi += 1;
            }
            xi += 1;
        }
    }
    
    fn draw(self: *const World, app: *Application) void {
        const display = app.getActualSize();
        c.glViewport(0, 0, display.width, display.height);
        c.glClearColor(0.6, 0.7, 0.8, 1);
        
        // Draw
        c.glClear(c.GL_COLOR_BUFFER_BIT | c.GL_DEPTH_BUFFER_BIT);
        c.glMatrixMode(c.GL_PROJECTION);
        c.glPushMatrix();
        
        const width_f64: f64 = @floatFromInt(display.width);
        const height_f64: f64 = @floatFromInt(display.height);
        const aspect = width_f64 / height_f64;
        
        // NOTE: Matrices take effect backwards
        c.glFrustum(-aspect / 2, aspect / 2, -0.5, 0.5, 0.4, 200);
        
        c.glRotated(self.player.super.orientation.pitch, 1, 0, 0);
        c.glRotated(self.player.super.orientation.yaw, 0, 1, 0);
        
        c.glTranslated(
            self.player.super.position[0],
            -self.player.super.position[1],
            self.player.super.position[2]
        );
        
        c.glBegin(c.GL_QUADS);
        var chunk_iter = self.chunks.iterator();
        while (chunk_iter.next()) |chunk| {
            chunk.value_ptr.draw(chunk.key_ptr.x, chunk.key_ptr.z);
        }
        c.glEnd();
        
        c.glPopMatrix();
    }
};

const Chunk = struct {
    blocks: [16][128][16]Block = @bitCast([_]Block { .Air } ** (16 * 128 * 16)),
    
    fn generate(x: i64, z: i64) Chunk {
        var buf = Chunk {};
        
        for (0..16) |ix| {
            for (0..16) |iz| {
                const fix: f32 = @floatFromInt(ix);
                const fiz: f32 = @floatFromInt(iz);
                const fx: f32 = @floatFromInt(x);
                const fz: f32 = @floatFromInt(z);
                
                const octave1 = noise.perlin((fix + 16 * fx) * 0.02, (fiz + 16 * fz) * 0.02);
                const octave2 = noise.perlin((fix + 16 * fx) * 0.03, (fiz + 16 * fz) * 0.03);
                const octave3 = noise.perlin((fix + 16 * fx) * 0.1, (fiz + 16 * fz) * 0.1);
                const height = octave1 / 3 + ((octave2 + octave3) / 20);
                
                for (0..128) |iy| {
                    const fiy: f32 = @floatFromInt(iy);
                    if (fiy < 160 * (height * 0.5 + 0.5)) buf.blocks[ix][iy][iz] = .Stone;
                }
            }
        }
        return buf;
    }
    
    fn draw(self: *const Chunk, x: i64, z: i64) void {
        for (0..16) |ix| {
            for (0..16) |iz| {
                for (0..128) |iy| {
                    const ixc: i64 = @intCast(ix);
                    const iyc: i64 = @intCast(iy);
                    const izc: i64 = @intCast(iz);
                    
                    const left   = @Vector(3, i64) { ixc - 1, iyc, izc };
                    const right  = @Vector(3, i64) { ixc + 1, iyc, izc };
                    const top    = @Vector(3, i64) { ixc, iyc + 1, izc };
                    const bottom = @Vector(3, i64) { ixc, iyc - 1, izc };
                    const front  = @Vector(3, i64) { ixc, iyc, izc - 1 };
                    const back   = @Vector(3, i64) { ixc, iyc, izc + 1 };
                    
                    const faces = Block.Faces {
                        .left = self.isEmptyAt(left),
                        .right = self.isEmptyAt(right),
                        .top = self.isEmptyAt(top),
                        .bottom = self.isEmptyAt(bottom),
                        .front = self.isEmptyAt(front),
                        .back = self.isEmptyAt(back)
                    };
                    
                    self.blocks[ix][iy][iz]
                        .draw(faces, ixc + 16 * x, iyc, izc + 16 * z);
                }
            }
        }
    }
    
    fn blockAt(self: *const Chunk, position: @Vector(3, i64)) Block {
        const ux: usize = @intCast(position[0]);
        const uy: usize = @intCast(position[1]);
        const uz: usize = @intCast(position[2]);
        
        return self.blocks[ux][uy][uz];
    }
    
    fn isEmptyAt(self: *const Chunk, position: @Vector(3, i64)) bool {
        if (
            position[0] < 0 or position[0] >= 16 or
            position[1] < 0 or position[1] >= 128 or
            position[2] < 0 or position[2] >= 16
        ) {
            return true;
        } else if (self.blockAt(position) == .Air) {
            return true;
        } else {
            return false;
        }
    }
};

const Block = enum {
    Air,
    Stone,
    
    const Faces = packed struct {
        left: bool,
        right: bool,
        top: bool,
        bottom: bool,
        front: bool,
        back: bool,
        
        _pad: u2 = 0,
        
        const all = Faces {
            .left = true,
            .right = true,
            .top = true,
            .bottom = true,
            .front = true,
            .back = true
        };
        
        const none = Faces {
            .left = false,
            .right = false,
            .top = false,
            .bottom = false,
            .front = false,
            .back = false
        };
    };
    
    const size: f32 = 1.0;
    const half_size: f32 = 0.5;
    
    const atlas_scale = 0.0625;
    
    fn draw(self: *const Block, faces: Faces, x: i64, y: i64, z: i64) void {
        if (self.* == .Air) return; // hack
        
        const xf: f32 = @floatFromInt(x);
        const yf: f32 = @floatFromInt(y);
        const zf: f32 = @floatFromInt(z);
        
        // Left
        if (faces.left) {
            c.glTexCoord2f(0.1875, 0.0625);
            c.glVertex3f(-half_size + xf * size, -half_size + yf * size, half_size + zf * size);
            c.glTexCoord2f(0.1875, 0);
            c.glVertex3f(-half_size + xf * size, half_size + yf * size, half_size + zf * size);
            c.glTexCoord2f(0.25, 0);
            c.glVertex3f(-half_size + xf * size, half_size + yf * size, -half_size + zf * size);
            c.glTexCoord2f(0.25, 0.0625);
            c.glVertex3f(-half_size + xf * size, -half_size + yf * size, -half_size + zf * size);
        }
        
        // Right
        if (faces.right) {
            c.glTexCoord2f(0.1875, 0.0625);
            c.glVertex3f(half_size + xf * size, -half_size + yf * size, -half_size + zf * size);
            c.glTexCoord2f(0.1875, 0);
            c.glVertex3f(half_size + xf * size, half_size + yf * size, -half_size + zf * size);
            c.glTexCoord2f(0.25, 0);
            c.glVertex3f(half_size + xf * size, half_size + yf * size, half_size + zf * size);
            c.glTexCoord2f(0.25, 0.0625);
            c.glVertex3f(half_size + xf * size, -half_size + yf * size, half_size + zf * size);
        }
        
        // Top
        if (faces.top) {
            c.glColor3f(0.6, 1, 0.4);
            c.glTexCoord2f(0, 0);
            c.glVertex3f(half_size + xf * size, half_size + yf * size, half_size + zf * size);
            c.glTexCoord2f(0.0625, 0);
            c.glVertex3f(half_size + xf * size, half_size + yf * size, -half_size + zf * size);
            c.glTexCoord2f(0.0625, 0.0625);
            c.glVertex3f(-half_size + xf * size, half_size + yf * size, -half_size + zf * size);
            c.glTexCoord2f(0, 0.0625);
            c.glVertex3f(-half_size + xf * size, half_size + yf * size, half_size + zf * size);
            c.glColor3f(1, 1, 1);
        }
        
        // Bottom
        if (faces.bottom) {
            c.glTexCoord2f(0.0625 * 2, 0.0625);
            c.glVertex3f(half_size + xf * size, -half_size + yf * size, -half_size + zf * size);
            c.glTexCoord2f(0.0625 * 2, 0);
            c.glVertex3f(half_size + xf * size, -half_size + yf * size, half_size + zf * size);
            c.glTexCoord2f(0.0625 * 3, 0);
            c.glVertex3f(-half_size + xf * size, -half_size + yf * size, half_size + zf * size);
            c.glTexCoord2f(0.0625 * 3, 0.0625);
            c.glVertex3f(-half_size + xf * size, -half_size + yf * size, -half_size + zf * size);
        }
        
        // Front
        if (faces.front) {
            c.glTexCoord2f(0.1875, 0.0625);
            c.glVertex3f(-half_size + xf * size, -half_size + yf * size, -half_size + zf * size);
            c.glTexCoord2f(0.1875, 0);
            c.glVertex3f(-half_size + xf * size, half_size + yf * size, -half_size + zf * size);
            c.glTexCoord2f(0.25, 0);
            c.glVertex3f(half_size + xf * size, half_size + yf * size, -half_size + zf * size);
            c.glTexCoord2f(0.25, 0.0625);
            c.glVertex3f(half_size + xf * size, -half_size + yf * size, -half_size + zf * size);
        }
        
        // Back
        if (faces.back) {
            c.glTexCoord2f(0.1875, 0.0625);
            c.glVertex3f(half_size + xf * size, -half_size + yf * size, half_size + zf * size);
            c.glTexCoord2f(0.1875, 0);
            c.glVertex3f(half_size + xf * size, half_size + yf * size, half_size + zf * size);
            c.glTexCoord2f(0.25, 0);
            c.glVertex3f(-half_size + xf * size, half_size + yf * size, half_size + zf * size);
            c.glTexCoord2f(0.25, 0.0625);
            c.glVertex3f(-half_size + xf * size, -half_size + yf * size, half_size + zf * size);
        }
    }
};

const Orientation = packed struct {
    yaw: f64 = 0, pitch: f64 = 0, roll: f64 = 0
};

const Entity = struct {
    position: @Vector(3, f64) = @Vector(3, f64) { 0, 0, 0 },
    orientation: Orientation = .{},
    bounding_box: ?struct {
        origin: @Vector(3, f64),
        size: @Vector(3, f64)
    } = null
};

const Player = struct {
    super: Entity = .{},
    
    fn update(self: *Player) void {
        var mx: c_int = undefined;
        var my: c_int = undefined;
        _ = c.SDL_GetRelativeMouseState(&mx, &my);
        const mxf: f64 = @floatFromInt(mx);
        const myf: f64 = @floatFromInt(my);
        self.super.orientation.yaw += mxf / 10;
        self.super.orientation.pitch += myf / 10;
        self.super.orientation.pitch = std.math.clamp(self.super.orientation.pitch, -90, 90);
        
        const keymap = c.SDL_GetKeyboardState(null);
        const heading = vecFromAngle(self.super.orientation.yaw);
        if (keymap[c.SDL_SCANCODE_W] == 1) {
            self.super.position[0] += heading.x / 100;
            self.super.position[2] += heading.y / 100;
        }
    }
};

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