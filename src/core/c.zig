const std = @import("std");
const builtin = @import("builtin");

pub usingnamespace @cImport({
    @cInclude("SDL2/SDL.h");
    @cInclude("SDL2/SDL_image.h");
    @cInclude("wgpu.h");
});
