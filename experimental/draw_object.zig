
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
            const mirror = @typeInfo(Self);
            
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
                        c.glEnableVertexAttribArray(0);
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