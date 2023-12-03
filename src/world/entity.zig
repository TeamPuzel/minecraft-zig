
const std = @import("std");
const c = @import("../platform/c.zig");
const World = @import("world.zig").World;

pub const Position = extern struct {
    x: f32 = 0, y: f32 = 0, z: f32 = 0
};

pub const Orientation = extern struct {
    pitch: f32 = 0, yaw: f32 = 0, roll: f32 = 0
};

pub const Entity = extern struct {
    position: Position = .{},
    orientation: Orientation = .{},
    update: *const fn(self: *anyopaque, world: *World) callconv(.C) void = @ptrCast(&update),
    
    fn update(_: *Entity, _: *World) callconv(.C) void {}
};

pub const Player = extern struct {
    super: Entity = .{
        .position = .{ .y = 130 },
        .update = @ptrCast(&update)
    },
    
    fn update(self: *Player, world: *World) callconv(.C) void {
        // Basic mouse look
        var mx: i32 = undefined;
        var my: i32 = undefined;
        _ = c.SDL_GetRelativeMouseState(&mx, &my);
        const mxf: f32 = @floatFromInt(mx);
        const myf: f32 = @floatFromInt(my);
        // NOTE: This might become an issue. Not sure if I'm supposed to reverse
        // the input or rotation matrices (if raycasting goes the opposite way this is why)
        self.super.orientation.yaw += mxf / 10;
        self.super.orientation.pitch += myf / 10;
        self.super.orientation.pitch = 
            std.math.clamp(self.super.orientation.pitch, -90, 90);
            
        // Basic movement
        const keymap = c.SDL_GetKeyboardState(null);
        if (keymap[c.SDL_SCANCODE_W] == 1) self.super.position.z      += 0.001;
        if (keymap[c.SDL_SCANCODE_A] == 1) self.super.position.x      -= 0.001;
        if (keymap[c.SDL_SCANCODE_S] == 1) self.super.position.z      -= 0.001;
        if (keymap[c.SDL_SCANCODE_D] == 1) self.super.position.x      += 0.001;
        if (keymap[c.SDL_SCANCODE_SPACE] == 1) self.super.position.y  += 0.001;
        if (keymap[c.SDL_SCANCODE_LSHIFT] == 1) self.super.position.y -= 0.001;
            
        _ = world;
    }
};