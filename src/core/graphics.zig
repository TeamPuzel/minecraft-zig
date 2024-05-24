const c = @import("c.zig");
const std = @import("std");
const image = @import("image.zig");

const TGAConstPtr = image.TGAConstPtr;
const Color = @import("engine.zig").Color;
const Matrix4x4 = @import("math.zig").Matrix4x4;

pub fn setClearColor(color: Color) void {
    c.glClearColor(color.r, color.g, color.b, color.a);
}

pub const Shader = packed struct {
    id: u32,
    
    pub fn create(v_src: [:0]const u8, f_src: [:0]const u8) !Shader {
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
    
    pub fn destroy(self: *Shader) void {
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

const ShaderSourceKind = enum { Vertex, Fragment };

inline fn compile(kind: ShaderSourceKind, src: [:0]const u8) !u32 {
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

pub const Texture = packed struct {
    id: u32,
    
    pub fn createFrom(img: TGAConstPtr) !Texture {
        var tex: Texture = undefined;
        c.glGenTextures(1, &tex.id);
        
        tex.bind();
        
        c.glTexImage2D(
            c.GL_TEXTURE_2D,
            0,
            c.GL_RGBA,
            img.getWidth(),
            img.getHeight(),
            0,
            c.GL_BGRA,
            c.GL_UNSIGNED_BYTE,
            @ptrCast(img.asPixelSlice().ptr)
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

/// A specialized representation of a shared CPU / GPU object.
/// Currently vertices can only be simple structures containing nothing
/// but structures of floats. They *must* be `packed`.
pub fn VertexBuffer(comptime V: type) type {
    return struct { const Self = @This();
        id: u32,
        vertices: std.ArrayList(V),
        
        pub fn create(alloc: std.mem.Allocator) Self {
            var self = Self {
                .vertices = std.ArrayList(V).init(alloc),
                .id = undefined
            };
            
            c.glGenBuffers(1, &self.id);
        
            self.bind();
            return self;
        }
        
        pub fn destroy(self: *Self) void {
            c.glDeleteBuffers(1, &self.id);
            self.vertices.deinit();
        }
        
        pub fn sync(self: *const Self) void {
            self.bind();
            c.glBufferData(
                c.GL_ARRAY_BUFFER,
                @intCast(self.vertices.items.len * @sizeOf(V)),
                self.vertices.items.ptr,
                c.GL_DYNAMIC_DRAW
            );
        }
        
        pub fn draw(self: *const Self) void {
            self.bind();
            c.glDrawArrays(c.GL_TRIANGLES, 0, @intCast(self.vertices.items.len));
        }
        
        fn bind(self: *const Self) void {
            c.glBindBuffer(c.GL_ARRAY_BUFFER, self.id);
            self.layout();
        }
        
        fn layout(self: *const Self) void {
            _ = self;
            const mirror = @typeInfo(V);
            
            switch (mirror) {
                .Struct => |v| {
                    if (v.layout != .@"packed")
                        @compileError("Only packed structs can be vertices");
                    
                    inline for (v.fields, 0..) |field, i| {
                        const info = @typeInfo(field.type);
                        
                        c.glVertexAttribPointer(
                            i,
                            info.Struct.fields.len,
                            c.GL_FLOAT,
                            c.GL_FALSE,
                            @sizeOf(V),
                            @ptrFromInt(@offsetOf(V, field.name))
                        );
                        c.glEnableVertexAttribArray(i);
                    }
                    
                },
                else => @compileError("Only structs can be passed to OpenGL")
            }
            
        }
    };
}
