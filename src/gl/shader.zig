//! This module handles shader compilation.
//! 
//! TODO(TeamPuzel):
//! - (?) PBR

const terrain_v = @embedFile("shaders/terrain.vs");
const terrain_f = @embedFile("shaders/terrain.fs");

const c = @import("../platform/c.zig");
const std = @import("std");

pub var terrain: Shader = undefined;

/// Creates all shaders.
/// Must run after opengl is initialized.
pub fn init() !void {
    terrain = try Shader.create(terrain_v, terrain_f);
}

/// Destroys all shaders.
pub fn deinit() void {
    terrain.destroy();
}

const Kind = enum (u8) { Vertex, Fragment };

pub const Shader = packed struct {
    id: u32,
    
    fn create(v_src: [:0]const u8, f_src: [:0]const u8) !Shader {
        const program = c.glCreateProgram();
        const v = try compile(.Vertex, v_src);
        const f = try compile(.Fragment, f_src);
        c.glAttachShader(program, v);
        c.glAttachShader(program, f);
        c.glLinkProgram(program);
        c.glValidateProgram(program);
        
        c.glDeleteShader(v);
        c.glDeleteShader(f);
        return .{ .id = program };
    }
    
    fn destroy(self: *Shader) void {
        c.glDeleteProgram(self.id);
    }
    
    pub fn bind(self: *const Shader) void {
        c.glUseProgram(self.id);
    }
    
    pub fn getUniform(self: *const Shader, name: [:0]const u8) i32 {
        self.bind();
        return c.glGetUniformLocation(self.id, name.ptr);
    }
};

inline fn compile(kind: Kind, src: [:0]const u8) !u32 {
    const id = c.glCreateShader(
        if (kind == .Vertex) c.GL_VERTEX_SHADER else c.GL_FRAGMENT_SHADER
    );
    c.glShaderSource(id, 1, @ptrCast(&src), null);
    c.glCompileShader(id);
    
    var result: i32 = undefined;
    c.glGetShaderiv(id, c.GL_COMPILE_STATUS, &result);
    if (result == 0) {
        var len: i32 = undefined;
        c.glGetShaderiv(id, c.GL_INFO_LOG_LENGTH, &len);
        var msg = std.mem.zeroes([1024:0]u8);
        c.glGetShaderInfoLog(id, len, &len, &msg);
        std.log.err(
            \\Could not compile {s} shader:
            \\{s}
            , .{
                if (kind == .Vertex) "vertex" else "fragment",
                msg
            }
        );
        return error.CompilingShader;
    }
    return id;
}
