
const std = @import("std");
const builtin = @import("builtin");

pub usingnamespace @cImport({
    if (builtin.os.tag == .windows) {
        @cInclude("SDL.h");
        @cInclude("SDL_image.h");
    } else if (builtin.os.tag == .macos) {
        @cInclude("SDL2/SDL.h");
        @cInclude("SDL2/SDL_image.h");
    }
    @cInclude("glad/glad.h");
});

// Required subset of SDL for runtime linking on linux
pub usingnamespace if (builtin.os.tag == .linux) struct {
    const dlopen = std.c.dlopen;
    const dlsym = std.c.dlsym;
    const RTLD_NOW = std.c.RTLD.NOW;
    
    pub const SDL_Event = extern union {
        type: u32,
        padding: [56]u8
    };
    
    pub const SDL_INIT_TIMER = @as(c_uint, 0x00000001);
    pub const SDL_INIT_AUDIO = @as(c_uint, 0x00000010);
    pub const SDL_INIT_VIDEO = @as(c_uint, 0x00000020);
    pub const SDL_INIT_JOYSTICK = @as(c_uint, 0x00000200);
    pub const SDL_INIT_HAPTIC = @as(c_uint, 0x00001000);
    pub const SDL_INIT_GAMECONTROLLER = @as(c_uint, 0x00002000);
    pub const SDL_INIT_EVENTS = @as(c_uint, 0x00004000);
    pub const SDL_INIT_SENSOR = @as(c_uint, 0x00008000);
    
    pub const IMG_INIT_JPG: c_int = 1;
    pub const IMG_INIT_PNG: c_int = 2;
    pub const IMG_INIT_TIF: c_int = 4;
    pub const IMG_INIT_WEBP: c_int = 8;
    pub const IMG_INIT_JXL: c_int = 16;
    pub const IMG_INIT_AVIF: c_int = 32;
    
    pub const SDL_WINDOWPOS_CENTERED = SDL_WINDOWPOS_CENTERED_DISPLAY(@as(c_int, 0));
    pub inline fn SDL_WINDOWPOS_CENTERED_DISPLAY(X: anytype) @TypeOf(SDL_WINDOWPOS_CENTERED_MASK | X) {
        _ = &X;
        return SDL_WINDOWPOS_CENTERED_MASK | X;
    }
    pub const SDL_WINDOWPOS_CENTERED_MASK = std.zig.c_translation.promoteIntLiteral(c_uint, 0x2FFF0000, .hex);
    
    pub const SDL_WINDOW_FULLSCREEN: c_int = 1;
    pub const SDL_WINDOW_OPENGL: c_int = 2;
    pub const SDL_WINDOW_SHOWN: c_int = 4;
    pub const SDL_WINDOW_HIDDEN: c_int = 8;
    pub const SDL_WINDOW_BORDERLESS: c_int = 16;
    pub const SDL_WINDOW_RESIZABLE: c_int = 32;
    pub const SDL_WINDOW_MINIMIZED: c_int = 64;
    pub const SDL_WINDOW_MAXIMIZED: c_int = 128;
    pub const SDL_WINDOW_MOUSE_GRABBED: c_int = 256;
    pub const SDL_WINDOW_INPUT_FOCUS: c_int = 512;
    pub const SDL_WINDOW_MOUSE_FOCUS: c_int = 1024;
    pub const SDL_WINDOW_FULLSCREEN_DESKTOP: c_int = 4097;
    pub const SDL_WINDOW_FOREIGN: c_int = 2048;
    pub const SDL_WINDOW_ALLOW_HIGHDPI: c_int = 8192;
    pub const SDL_WINDOW_MOUSE_CAPTURE: c_int = 16384;
    pub const SDL_WINDOW_ALWAYS_ON_TOP: c_int = 32768;
    pub const SDL_WINDOW_SKIP_TASKBAR: c_int = 65536;
    pub const SDL_WINDOW_UTILITY: c_int = 131072;
    pub const SDL_WINDOW_TOOLTIP: c_int = 262144;
    pub const SDL_WINDOW_POPUP_MENU: c_int = 524288;
    pub const SDL_WINDOW_KEYBOARD_GRABBED: c_int = 1048576;
    pub const SDL_WINDOW_VULKAN: c_int = 268435456;
    pub const SDL_WINDOW_METAL: c_int = 536870912;
    pub const SDL_WINDOW_INPUT_GRABBED: c_int = 256;
    
    pub const SDL_QUIT = 256;
    
    pub const SDL_bool = c_uint;
    
    pub const SDL_GLContext = ?*anyopaque;
    pub const SDL_Window = opaque {};
    
    pub const SDL_GLattr = c_uint;
    pub const SDL_GL_CONTEXT_MAJOR_VERSION = 17;
    pub const SDL_GL_CONTEXT_MINOR_VERSION = 18;
    pub const SDL_GL_CONTEXT_PROFILE_MASK = 21;
    pub const SDL_GL_DOUBLEBUFFER = 5;
    pub const SDL_GL_DEPTH_SIZE = 6;
    
    pub const SDL_GL_CONTEXT_PROFILE_CORE = 1;
    
    pub const SDL_PIXELFORMAT_RGBA32: c_int = 376840196;
    
    pub usingnamespace scancodes;
    
    pub var SDL_Init:                  *const allowzero fn(flags: u32) callconv(.C) c_int = @ptrFromInt(0);
    pub var SDL_GL_LoadLibrary:        *const allowzero fn(path: [*c]const u8) callconv(.C) c_int = @ptrFromInt(0);
    pub var SDL_CreateWindow:          *const allowzero fn(title: [*c]const u8, x: c_int, y: c_int, w: c_int, h: c_int, flags: u32) callconv(.C) ?*SDL_Window = @ptrFromInt(0);
    pub var SDL_SetWindowMinimumSize:  *const allowzero fn(window: ?*SDL_Window, min_w: c_int, min_h: c_int) callconv(.C) void = @ptrFromInt(0);
    pub var SDL_GL_SetAttribute:       *const allowzero fn(attr: SDL_GLattr, value: c_int) callconv(.C) c_int = @ptrFromInt(0);
    pub var SDL_GL_SetSwapInterval:    *const allowzero fn(interval: c_int) callconv(.C) c_int = @ptrFromInt(0);
    pub var SDL_GL_CreateContext:      *const allowzero fn(window: ?*SDL_Window) callconv(.C) SDL_GLContext = @ptrFromInt(0);
    pub var SDL_GL_GetProcAddress:     *const allowzero fn(proc: [*c]const u8) callconv(.C) ?*anyopaque = @ptrFromInt(0);
    pub var SDL_GL_GetDrawableSize:    *const allowzero fn(window: ?*SDL_Window, w: [*c]c_int, h: [*c]c_int) callconv(.C) void = @ptrFromInt(0);
    pub var SDL_Quit:                  *const allowzero fn() callconv(.C) void = @ptrFromInt(0);
    pub var SDL_DestroyWindow:         *const allowzero fn(window: ?*SDL_Window) callconv(.C) void = @ptrFromInt(0);
    pub var SDL_GL_DeleteContext:      *const allowzero fn(context: SDL_GLContext) callconv(.C) void = @ptrFromInt(0);
    pub var SDL_SetRelativeMouseMode:  *const allowzero fn(enabled: SDL_bool) callconv(.C) c_int = @ptrFromInt(0);
    pub var SDL_GL_SwapWindow:         *const allowzero fn(window: ?*SDL_Window) callconv(.C) void = @ptrFromInt(0);
    pub var SDL_GetKeyboardState:      *const allowzero fn(numkeys: [*c]c_int) callconv(.C) [*c]const u8 = @ptrFromInt(0);
    pub var SDL_GetRelativeMouseState: *const allowzero fn(x: [*c]c_int, y: [*c]c_int) callconv(.C) u32 = @ptrFromInt(0);
    pub var SDL_PollEvent:             *const allowzero fn(event: [*c]SDL_Event) callconv(.C) c_int = @ptrFromInt(0);
    
    // Stuff below can be dropped if I load assets in a manageable format like TGA.
    pub const SDL_Surface = extern struct {
        flags: u32 = @import("std").mem.zeroes(u32),
        format: [*c]c_int = @import("std").mem.zeroes([*c]c_int),
        w: c_int = @import("std").mem.zeroes(c_int),
        h: c_int = @import("std").mem.zeroes(c_int),
        pitch: c_int = @import("std").mem.zeroes(c_int),
        pixels: ?*anyopaque = @import("std").mem.zeroes(?*anyopaque),
        userdata: ?*anyopaque = @import("std").mem.zeroes(?*anyopaque),
        locked: c_int = @import("std").mem.zeroes(c_int),
        list_blitmap: ?*anyopaque = @import("std").mem.zeroes(?*anyopaque),
        clip_rect: SDL_Rect = @import("std").mem.zeroes(SDL_Rect),
        map: ?*anyopaque = @import("std").mem.zeroes(?*anyopaque),
        refcount: c_int = @import("std").mem.zeroes(c_int),
    };
    pub const SDL_Rect = extern struct {
        x: c_int = @import("std").mem.zeroes(c_int),
        y: c_int = @import("std").mem.zeroes(c_int),
        w: c_int = @import("std").mem.zeroes(c_int),
        h: c_int = @import("std").mem.zeroes(c_int),
    };
    pub const SDL_RWops = extern struct {}; // UNSAFE
     
    pub var SDL_ConvertSurfaceFormat: *const allowzero fn(src: [*c]SDL_Surface, pixel_format: u32, flags: u32) callconv(.C) [*c]SDL_Surface = @ptrFromInt(0);
    pub var SDL_FreeSurface:          *const allowzero fn(surface: [*c]SDL_Surface) callconv(.C) void = @ptrFromInt(0);
    pub var SDL_RWFromConstMem:       *const allowzero fn(mem: ?*const anyopaque, size: c_int) callconv(.C) [*c]SDL_RWops = @ptrFromInt(0);
    pub var SDL_RWclose:              *const allowzero fn(context: [*c]SDL_RWops) callconv(.C) c_int = @ptrFromInt(0);
    
    pub var IMG_Init:                 *const allowzero fn(flags: c_int) callconv(.C) c_int = @ptrFromInt(0);
    pub var IMG_Quit:                 *const allowzero fn() callconv(.C) void = @ptrFromInt(0);
    pub var IMG_Load_RW:              *const allowzero fn(src: [*c]SDL_RWops, freesrc: c_int) callconv(.C) [*c]SDL_Surface = @ptrFromInt(0);
    
    pub fn loadLibraries() !void {
        const sdl = dlopen("libSDL2-2.0.so", RTLD_NOW) orelse return error.loadingLibrarySDL2;
        
        SDL_Init                  = @ptrCast(dlsym(sdl, "SDL_Init") orelse return error.function);
        SDL_GL_LoadLibrary        = @ptrCast(dlsym(sdl, "SDL_GL_LoadLibrary") orelse return error.function);
        SDL_CreateWindow          = @ptrCast(dlsym(sdl, "SDL_CreateWindow") orelse return error.function);
        SDL_SetWindowMinimumSize  = @ptrCast(dlsym(sdl, "SDL_SetWindowMinimumSize") orelse return error.function);
        SDL_GL_SetAttribute       = @ptrCast(dlsym(sdl, "SDL_GL_SetAttribute") orelse return error.function);
        SDL_GL_SetSwapInterval    = @ptrCast(dlsym(sdl, "SDL_GL_SetSwapInterval") orelse return error.function);
        SDL_GL_CreateContext      = @ptrCast(dlsym(sdl, "SDL_GL_CreateContext") orelse return error.function);
        SDL_GL_GetProcAddress     = @ptrCast(dlsym(sdl, "SDL_GL_GetProcAddress") orelse return error.function);
        SDL_GL_GetDrawableSize    = @ptrCast(dlsym(sdl, "SDL_GL_GetDrawableSize") orelse return error.function);
        SDL_Quit                  = @ptrCast(dlsym(sdl, "SDL_Quit") orelse return error.function);
        SDL_DestroyWindow         = @ptrCast(dlsym(sdl, "SDL_DestroyWindow") orelse return error.function);
        SDL_GL_DeleteContext      = @ptrCast(dlsym(sdl, "SDL_GL_DeleteContext") orelse return error.function);
        SDL_SetRelativeMouseMode  = @ptrCast(dlsym(sdl, "SDL_SetRelativeMouseMode") orelse return error.function);
        SDL_GL_SwapWindow         = @ptrCast(dlsym(sdl, "SDL_GL_SwapWindow") orelse return error.function);
        SDL_GetKeyboardState      = @ptrCast(dlsym(sdl, "SDL_GetKeyboardState") orelse return error.function);
        SDL_GetRelativeMouseState = @ptrCast(dlsym(sdl, "SDL_GetRelativeMouseState") orelse return error.function);
        SDL_PollEvent             = @ptrCast(dlsym(sdl, "SDL_PollEvent") orelse return error.function);
        
        SDL_ConvertSurfaceFormat  = @ptrCast(dlsym(sdl, "SDL_ConvertSurfaceFormat") orelse return error.function); 
        SDL_FreeSurface           = @ptrCast(dlsym(sdl, "SDL_FreeSurface") orelse return error.function);
        SDL_RWFromConstMem        = @ptrCast(dlsym(sdl, "SDL_RWFromConstMem") orelse return error.function);
        SDL_RWclose               = @ptrCast(dlsym(sdl, "SDL_RWclose") orelse return error.function);
        
        const img = dlopen("libSDL2_image-2.0.so.0", RTLD_NOW) orelse return error.loadingLibrarySDL2Image;
        
        IMG_Init                  = @ptrCast(dlsym(img, "IMG_Init") orelse return error.function);
        IMG_Quit                  = @ptrCast(dlsym(img, "IMG_Quit") orelse return error.function);
        IMG_Load_RW               = @ptrCast(dlsym(img, "IMG_Load_RW") orelse return error.function);
    }
    
    // pub const LoadError = error { library, function, variable };
} else struct {};

const scancodes = struct {
    pub const SDL_SCANCODE_UNKNOWN: c_int = 0;
    pub const SDL_SCANCODE_A: c_int = 4;
    pub const SDL_SCANCODE_B: c_int = 5;
    pub const SDL_SCANCODE_C: c_int = 6;
    pub const SDL_SCANCODE_D: c_int = 7;
    pub const SDL_SCANCODE_E: c_int = 8;
    pub const SDL_SCANCODE_F: c_int = 9;
    pub const SDL_SCANCODE_G: c_int = 10;
    pub const SDL_SCANCODE_H: c_int = 11;
    pub const SDL_SCANCODE_I: c_int = 12;
    pub const SDL_SCANCODE_J: c_int = 13;
    pub const SDL_SCANCODE_K: c_int = 14;
    pub const SDL_SCANCODE_L: c_int = 15;
    pub const SDL_SCANCODE_M: c_int = 16;
    pub const SDL_SCANCODE_N: c_int = 17;
    pub const SDL_SCANCODE_O: c_int = 18;
    pub const SDL_SCANCODE_P: c_int = 19;
    pub const SDL_SCANCODE_Q: c_int = 20;
    pub const SDL_SCANCODE_R: c_int = 21;
    pub const SDL_SCANCODE_S: c_int = 22;
    pub const SDL_SCANCODE_T: c_int = 23;
    pub const SDL_SCANCODE_U: c_int = 24;
    pub const SDL_SCANCODE_V: c_int = 25;
    pub const SDL_SCANCODE_W: c_int = 26;
    pub const SDL_SCANCODE_X: c_int = 27;
    pub const SDL_SCANCODE_Y: c_int = 28;
    pub const SDL_SCANCODE_Z: c_int = 29;
    pub const SDL_SCANCODE_1: c_int = 30;
    pub const SDL_SCANCODE_2: c_int = 31;
    pub const SDL_SCANCODE_3: c_int = 32;
    pub const SDL_SCANCODE_4: c_int = 33;
    pub const SDL_SCANCODE_5: c_int = 34;
    pub const SDL_SCANCODE_6: c_int = 35;
    pub const SDL_SCANCODE_7: c_int = 36;
    pub const SDL_SCANCODE_8: c_int = 37;
    pub const SDL_SCANCODE_9: c_int = 38;
    pub const SDL_SCANCODE_0: c_int = 39;
    pub const SDL_SCANCODE_RETURN: c_int = 40;
    pub const SDL_SCANCODE_ESCAPE: c_int = 41;
    pub const SDL_SCANCODE_BACKSPACE: c_int = 42;
    pub const SDL_SCANCODE_TAB: c_int = 43;
    pub const SDL_SCANCODE_SPACE: c_int = 44;
    pub const SDL_SCANCODE_MINUS: c_int = 45;
    pub const SDL_SCANCODE_EQUALS: c_int = 46;
    pub const SDL_SCANCODE_LEFTBRACKET: c_int = 47;
    pub const SDL_SCANCODE_RIGHTBRACKET: c_int = 48;
    pub const SDL_SCANCODE_BACKSLASH: c_int = 49;
    pub const SDL_SCANCODE_NONUSHASH: c_int = 50;
    pub const SDL_SCANCODE_SEMICOLON: c_int = 51;
    pub const SDL_SCANCODE_APOSTROPHE: c_int = 52;
    pub const SDL_SCANCODE_GRAVE: c_int = 53;
    pub const SDL_SCANCODE_COMMA: c_int = 54;
    pub const SDL_SCANCODE_PERIOD: c_int = 55;
    pub const SDL_SCANCODE_SLASH: c_int = 56;
    pub const SDL_SCANCODE_CAPSLOCK: c_int = 57;
    pub const SDL_SCANCODE_F1: c_int = 58;
    pub const SDL_SCANCODE_F2: c_int = 59;
    pub const SDL_SCANCODE_F3: c_int = 60;
    pub const SDL_SCANCODE_F4: c_int = 61;
    pub const SDL_SCANCODE_F5: c_int = 62;
    pub const SDL_SCANCODE_F6: c_int = 63;
    pub const SDL_SCANCODE_F7: c_int = 64;
    pub const SDL_SCANCODE_F8: c_int = 65;
    pub const SDL_SCANCODE_F9: c_int = 66;
    pub const SDL_SCANCODE_F10: c_int = 67;
    pub const SDL_SCANCODE_F11: c_int = 68;
    pub const SDL_SCANCODE_F12: c_int = 69;
    pub const SDL_SCANCODE_PRINTSCREEN: c_int = 70;
    pub const SDL_SCANCODE_SCROLLLOCK: c_int = 71;
    pub const SDL_SCANCODE_PAUSE: c_int = 72;
    pub const SDL_SCANCODE_INSERT: c_int = 73;
    pub const SDL_SCANCODE_HOME: c_int = 74;
    pub const SDL_SCANCODE_PAGEUP: c_int = 75;
    pub const SDL_SCANCODE_DELETE: c_int = 76;
    pub const SDL_SCANCODE_END: c_int = 77;
    pub const SDL_SCANCODE_PAGEDOWN: c_int = 78;
    pub const SDL_SCANCODE_RIGHT: c_int = 79;
    pub const SDL_SCANCODE_LEFT: c_int = 80;
    pub const SDL_SCANCODE_DOWN: c_int = 81;
    pub const SDL_SCANCODE_UP: c_int = 82;
    pub const SDL_SCANCODE_NUMLOCKCLEAR: c_int = 83;
    pub const SDL_SCANCODE_KP_DIVIDE: c_int = 84;
    pub const SDL_SCANCODE_KP_MULTIPLY: c_int = 85;
    pub const SDL_SCANCODE_KP_MINUS: c_int = 86;
    pub const SDL_SCANCODE_KP_PLUS: c_int = 87;
    pub const SDL_SCANCODE_KP_ENTER: c_int = 88;
    pub const SDL_SCANCODE_KP_1: c_int = 89;
    pub const SDL_SCANCODE_KP_2: c_int = 90;
    pub const SDL_SCANCODE_KP_3: c_int = 91;
    pub const SDL_SCANCODE_KP_4: c_int = 92;
    pub const SDL_SCANCODE_KP_5: c_int = 93;
    pub const SDL_SCANCODE_KP_6: c_int = 94;
    pub const SDL_SCANCODE_KP_7: c_int = 95;
    pub const SDL_SCANCODE_KP_8: c_int = 96;
    pub const SDL_SCANCODE_KP_9: c_int = 97;
    pub const SDL_SCANCODE_KP_0: c_int = 98;
    pub const SDL_SCANCODE_KP_PERIOD: c_int = 99;
    pub const SDL_SCANCODE_NONUSBACKSLASH: c_int = 100;
    pub const SDL_SCANCODE_APPLICATION: c_int = 101;
    pub const SDL_SCANCODE_POWER: c_int = 102;
    pub const SDL_SCANCODE_KP_EQUALS: c_int = 103;
    pub const SDL_SCANCODE_F13: c_int = 104;
    pub const SDL_SCANCODE_F14: c_int = 105;
    pub const SDL_SCANCODE_F15: c_int = 106;
    pub const SDL_SCANCODE_F16: c_int = 107;
    pub const SDL_SCANCODE_F17: c_int = 108;
    pub const SDL_SCANCODE_F18: c_int = 109;
    pub const SDL_SCANCODE_F19: c_int = 110;
    pub const SDL_SCANCODE_F20: c_int = 111;
    pub const SDL_SCANCODE_F21: c_int = 112;
    pub const SDL_SCANCODE_F22: c_int = 113;
    pub const SDL_SCANCODE_F23: c_int = 114;
    pub const SDL_SCANCODE_F24: c_int = 115;
    pub const SDL_SCANCODE_EXECUTE: c_int = 116;
    pub const SDL_SCANCODE_HELP: c_int = 117;
    pub const SDL_SCANCODE_MENU: c_int = 118;
    pub const SDL_SCANCODE_SELECT: c_int = 119;
    pub const SDL_SCANCODE_STOP: c_int = 120;
    pub const SDL_SCANCODE_AGAIN: c_int = 121;
    pub const SDL_SCANCODE_UNDO: c_int = 122;
    pub const SDL_SCANCODE_CUT: c_int = 123;
    pub const SDL_SCANCODE_COPY: c_int = 124;
    pub const SDL_SCANCODE_PASTE: c_int = 125;
    pub const SDL_SCANCODE_FIND: c_int = 126;
    pub const SDL_SCANCODE_MUTE: c_int = 127;
    pub const SDL_SCANCODE_VOLUMEUP: c_int = 128;
    pub const SDL_SCANCODE_VOLUMEDOWN: c_int = 129;
    pub const SDL_SCANCODE_KP_COMMA: c_int = 133;
    pub const SDL_SCANCODE_KP_EQUALSAS400: c_int = 134;
    pub const SDL_SCANCODE_INTERNATIONAL1: c_int = 135;
    pub const SDL_SCANCODE_INTERNATIONAL2: c_int = 136;
    pub const SDL_SCANCODE_INTERNATIONAL3: c_int = 137;
    pub const SDL_SCANCODE_INTERNATIONAL4: c_int = 138;
    pub const SDL_SCANCODE_INTERNATIONAL5: c_int = 139;
    pub const SDL_SCANCODE_INTERNATIONAL6: c_int = 140;
    pub const SDL_SCANCODE_INTERNATIONAL7: c_int = 141;
    pub const SDL_SCANCODE_INTERNATIONAL8: c_int = 142;
    pub const SDL_SCANCODE_INTERNATIONAL9: c_int = 143;
    pub const SDL_SCANCODE_LANG1: c_int = 144;
    pub const SDL_SCANCODE_LANG2: c_int = 145;
    pub const SDL_SCANCODE_LANG3: c_int = 146;
    pub const SDL_SCANCODE_LANG4: c_int = 147;
    pub const SDL_SCANCODE_LANG5: c_int = 148;
    pub const SDL_SCANCODE_LANG6: c_int = 149;
    pub const SDL_SCANCODE_LANG7: c_int = 150;
    pub const SDL_SCANCODE_LANG8: c_int = 151;
    pub const SDL_SCANCODE_LANG9: c_int = 152;
    pub const SDL_SCANCODE_ALTERASE: c_int = 153;
    pub const SDL_SCANCODE_SYSREQ: c_int = 154;
    pub const SDL_SCANCODE_CANCEL: c_int = 155;
    pub const SDL_SCANCODE_CLEAR: c_int = 156;
    pub const SDL_SCANCODE_PRIOR: c_int = 157;
    pub const SDL_SCANCODE_RETURN2: c_int = 158;
    pub const SDL_SCANCODE_SEPARATOR: c_int = 159;
    pub const SDL_SCANCODE_OUT: c_int = 160;
    pub const SDL_SCANCODE_OPER: c_int = 161;
    pub const SDL_SCANCODE_CLEARAGAIN: c_int = 162;
    pub const SDL_SCANCODE_CRSEL: c_int = 163;
    pub const SDL_SCANCODE_EXSEL: c_int = 164;
    pub const SDL_SCANCODE_KP_00: c_int = 176;
    pub const SDL_SCANCODE_KP_000: c_int = 177;
    pub const SDL_SCANCODE_THOUSANDSSEPARATOR: c_int = 178;
    pub const SDL_SCANCODE_DECIMALSEPARATOR: c_int = 179;
    pub const SDL_SCANCODE_CURRENCYUNIT: c_int = 180;
    pub const SDL_SCANCODE_CURRENCYSUBUNIT: c_int = 181;
    pub const SDL_SCANCODE_KP_LEFTPAREN: c_int = 182;
    pub const SDL_SCANCODE_KP_RIGHTPAREN: c_int = 183;
    pub const SDL_SCANCODE_KP_LEFTBRACE: c_int = 184;
    pub const SDL_SCANCODE_KP_RIGHTBRACE: c_int = 185;
    pub const SDL_SCANCODE_KP_TAB: c_int = 186;
    pub const SDL_SCANCODE_KP_BACKSPACE: c_int = 187;
    pub const SDL_SCANCODE_KP_A: c_int = 188;
    pub const SDL_SCANCODE_KP_B: c_int = 189;
    pub const SDL_SCANCODE_KP_C: c_int = 190;
    pub const SDL_SCANCODE_KP_D: c_int = 191;
    pub const SDL_SCANCODE_KP_E: c_int = 192;
    pub const SDL_SCANCODE_KP_F: c_int = 193;
    pub const SDL_SCANCODE_KP_XOR: c_int = 194;
    pub const SDL_SCANCODE_KP_POWER: c_int = 195;
    pub const SDL_SCANCODE_KP_PERCENT: c_int = 196;
    pub const SDL_SCANCODE_KP_LESS: c_int = 197;
    pub const SDL_SCANCODE_KP_GREATER: c_int = 198;
    pub const SDL_SCANCODE_KP_AMPERSAND: c_int = 199;
    pub const SDL_SCANCODE_KP_DBLAMPERSAND: c_int = 200;
    pub const SDL_SCANCODE_KP_VERTICALBAR: c_int = 201;
    pub const SDL_SCANCODE_KP_DBLVERTICALBAR: c_int = 202;
    pub const SDL_SCANCODE_KP_COLON: c_int = 203;
    pub const SDL_SCANCODE_KP_HASH: c_int = 204;
    pub const SDL_SCANCODE_KP_SPACE: c_int = 205;
    pub const SDL_SCANCODE_KP_AT: c_int = 206;
    pub const SDL_SCANCODE_KP_EXCLAM: c_int = 207;
    pub const SDL_SCANCODE_KP_MEMSTORE: c_int = 208;
    pub const SDL_SCANCODE_KP_MEMRECALL: c_int = 209;
    pub const SDL_SCANCODE_KP_MEMCLEAR: c_int = 210;
    pub const SDL_SCANCODE_KP_MEMADD: c_int = 211;
    pub const SDL_SCANCODE_KP_MEMSUBTRACT: c_int = 212;
    pub const SDL_SCANCODE_KP_MEMMULTIPLY: c_int = 213;
    pub const SDL_SCANCODE_KP_MEMDIVIDE: c_int = 214;
    pub const SDL_SCANCODE_KP_PLUSMINUS: c_int = 215;
    pub const SDL_SCANCODE_KP_CLEAR: c_int = 216;
    pub const SDL_SCANCODE_KP_CLEARENTRY: c_int = 217;
    pub const SDL_SCANCODE_KP_BINARY: c_int = 218;
    pub const SDL_SCANCODE_KP_OCTAL: c_int = 219;
    pub const SDL_SCANCODE_KP_DECIMAL: c_int = 220;
    pub const SDL_SCANCODE_KP_HEXADECIMAL: c_int = 221;
    pub const SDL_SCANCODE_LCTRL: c_int = 224;
    pub const SDL_SCANCODE_LSHIFT: c_int = 225;
    pub const SDL_SCANCODE_LALT: c_int = 226;
    pub const SDL_SCANCODE_LGUI: c_int = 227;
    pub const SDL_SCANCODE_RCTRL: c_int = 228;
    pub const SDL_SCANCODE_RSHIFT: c_int = 229;
    pub const SDL_SCANCODE_RALT: c_int = 230;
    pub const SDL_SCANCODE_RGUI: c_int = 231;
    pub const SDL_SCANCODE_MODE: c_int = 257;
    pub const SDL_SCANCODE_AUDIONEXT: c_int = 258;
    pub const SDL_SCANCODE_AUDIOPREV: c_int = 259;
    pub const SDL_SCANCODE_AUDIOSTOP: c_int = 260;
    pub const SDL_SCANCODE_AUDIOPLAY: c_int = 261;
    pub const SDL_SCANCODE_AUDIOMUTE: c_int = 262;
    pub const SDL_SCANCODE_MEDIASELECT: c_int = 263;
    pub const SDL_SCANCODE_WWW: c_int = 264;
    pub const SDL_SCANCODE_MAIL: c_int = 265;
    pub const SDL_SCANCODE_CALCULATOR: c_int = 266;
    pub const SDL_SCANCODE_COMPUTER: c_int = 267;
    pub const SDL_SCANCODE_AC_SEARCH: c_int = 268;
    pub const SDL_SCANCODE_AC_HOME: c_int = 269;
    pub const SDL_SCANCODE_AC_BACK: c_int = 270;
    pub const SDL_SCANCODE_AC_FORWARD: c_int = 271;
    pub const SDL_SCANCODE_AC_STOP: c_int = 272;
    pub const SDL_SCANCODE_AC_REFRESH: c_int = 273;
    pub const SDL_SCANCODE_AC_BOOKMARKS: c_int = 274;
    pub const SDL_SCANCODE_BRIGHTNESSDOWN: c_int = 275;
    pub const SDL_SCANCODE_BRIGHTNESSUP: c_int = 276;
    pub const SDL_SCANCODE_DISPLAYSWITCH: c_int = 277;
    pub const SDL_SCANCODE_KBDILLUMTOGGLE: c_int = 278;
    pub const SDL_SCANCODE_KBDILLUMDOWN: c_int = 279;
    pub const SDL_SCANCODE_KBDILLUMUP: c_int = 280;
    pub const SDL_SCANCODE_EJECT: c_int = 281;
    pub const SDL_SCANCODE_SLEEP: c_int = 282;
    pub const SDL_SCANCODE_APP1: c_int = 283;
    pub const SDL_SCANCODE_APP2: c_int = 284;
    pub const SDL_SCANCODE_AUDIOREWIND: c_int = 285;
    pub const SDL_SCANCODE_AUDIOFASTFORWARD: c_int = 286;
    pub const SDL_SCANCODE_SOFTLEFT: c_int = 287;
    pub const SDL_SCANCODE_SOFTRIGHT: c_int = 288;
    pub const SDL_SCANCODE_CALL: c_int = 289;
    pub const SDL_SCANCODE_ENDCALL: c_int = 290;
    pub const SDL_NUM_SCANCODES: c_int = 512;
};
