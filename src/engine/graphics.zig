
const c = @import("c.zig");
const std = @import("std");

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
    
    pub fn create(data: []const u8) !Texture {
        // Load image
        const rw = c.SDL_RWFromConstMem(data.ptr, @intCast(data.len));
        defer _ = c.SDL_RWclose(rw);
        
        const temp_surface = c.IMG_Load_RW(rw, 0);
        defer c.SDL_FreeSurface(temp_surface);
        
        const surface = c.SDL_ConvertSurfaceFormat(
            temp_surface, c.SDL_PIXELFORMAT_RGBA32, 0
        );
        defer c.SDL_FreeSurface(surface);
        
        // Create texture
        var tex: Texture = undefined;
        c.glGenTextures(1, &tex.id);
        
        tex.bind();
        
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
pub fn DrawObject(comptime V: type) type {
    return struct { const Self = @This();
        id: u32,
        vertices: std.ArrayList(V),
        texture: ?Texture,
        shader: Shader,
        
        pub fn create(alloc: std.mem.Allocator, shader: Shader, tex: ?Texture) Self {
            var self = Self {
                .vertices = std.ArrayList(V).init(alloc),
                .texture = tex,
                .shader = shader,
                .id = undefined
            };
            
            c.glGenBuffers(1, &self.id);
        
            self.bind();
            return self;
        }
        
        pub fn destroy(self: *Self) void {
            c.glDeleteBuffers(1, &self.id);
            self.vertices.deinit();
            
            self.shader.destroy(); // nocheckin
            if (self.texture) |_| self.texture.?.destroy(); // nocheckin
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
        
        /// TODO! Make this generic, it very much is not.
        pub fn draw(self: *const Self, matrix: *const Matrix4x4) void {
            self.bind();
            
            const sampler = self.shader.getUniform("texture_id");
            const transform = self.shader.getUniform("transform");
            c.glUniform1i(sampler, 0);
            
            c.glUniformMatrix4fv(transform, 1, c.GL_TRUE, @ptrCast(&matrix.data));
            
            c.glDrawArrays(c.GL_TRIANGLES, 0, @intCast(self.vertices.items.len));
        }
        
        fn bind(self: *const Self) void {
            c.glBindBuffer(c.GL_ARRAY_BUFFER, self.id);
            if (self.texture) |tex| tex.bind();
            self.shader.bind();
            self.layout();
        }
        
        fn layout(self: *const Self) void {
            _ = self;
            const mirror = @typeInfo(V);
            
            switch (mirror) {
                .Struct => |v| {
                    if (v.layout != .Packed)
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
        
        /// TODO! Make this generic.
        pub fn sort(self: *Self, x: f32, y: f32, z: f32) void {
            const triangles: [*][3]V = @ptrCast(self.vertices.items.ptr);
            const len = self.vertices.items.len / 3;
            const slice = triangles[0..len];
            
            const camera = @Vector(3, f32) { x, y, z };
            
            std.sort.heap([3]V, slice, camera, triCompare);
        }
        
        fn triCompare(pos: @Vector(3, f32), lhs: [3]V, rhs: [3]V) bool {
            return triDistance(pos, lhs) > triDistance(pos, rhs);
        }
        
        fn triDistance(pos: @Vector(3, f32), tri: [3]V) f32 {
            const v1 = @Vector(3, f32) {
                tri[0].position.x, tri[0].position.y, tri[0].position.z
            };
            const v2 = @Vector(3, f32) {
                tri[1].position.x, tri[1].position.y, tri[1].position.z
            };
            const v3 = @Vector(3, f32) {
                tri[2].position.x, tri[2].position.y, tri[2].position.z
            };
            
            const average = (v1 + v2 + v3) / @Vector(3, f32) { 3, 3, 3 };
            const diff = average - pos;
            return @sqrt(@reduce(.Add, diff * diff));
        }
    };
}