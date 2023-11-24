
const builtin = @import("builtin");

pub usingnamespace @cImport({
    // if (builtin.os.tag == .windows) {
        @cInclude("SDL.h");
        @cInclude("SDL_image.h");
        @cInclude("gl/gl.h");
    // } else if (builtin.os.tag == .macos) {
    //     @cInclude("SDL2/SDL.h");
    //     @cInclude("SDL2/SDL_image.h");
    //     @cInclude("OpenGL/gl.h");
    // }
});
