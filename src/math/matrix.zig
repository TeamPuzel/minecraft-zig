
const std = @import("std");

pub const Matrix4x4 = extern struct {
    data: [4][4]f32 = @bitCast([_]f32 { 0 } ** (4 * 4)),
    
    /// Performs a SIMD multiplication of two matrices.
    pub inline fn mul(
        noalias self:  *const Matrix4x4,
        noalias other: *const Matrix4x4
    ) Matrix4x4 {
        @setFloatMode(.Optimized);
        
        const l1: @Vector(4, f32) = self.data[0];
        const l2: @Vector(4, f32) = self.data[1];
        const l3: @Vector(4, f32) = self.data[2];
        const l4: @Vector(4, f32) = self.data[3];
        
        const r1: @Vector(4, f32) = .{ other.data[0][0], other.data[1][0], other.data[2][0], other.data[3][0] };
        const r2: @Vector(4, f32) = .{ other.data[0][1], other.data[1][1], other.data[2][1], other.data[3][1] };
        const r3: @Vector(4, f32) = .{ other.data[0][2], other.data[1][2], other.data[2][2], other.data[3][2] };
        const r4: @Vector(4, f32) = .{ other.data[0][3], other.data[1][3], other.data[2][3], other.data[3][3] };
        
        return .{ .data = .{
            .{ @reduce(.Add, l1 * r1), @reduce(.Add, l1 * r2), @reduce(.Add, l1 * r3), @reduce(.Add, l1 * r4) },
            .{ @reduce(.Add, l2 * r1), @reduce(.Add, l2 * r2), @reduce(.Add, l2 * r3), @reduce(.Add, l2 * r4) },
            .{ @reduce(.Add, l3 * r1), @reduce(.Add, l3 * r2), @reduce(.Add, l3 * r3), @reduce(.Add, l3 * r4) },
            .{ @reduce(.Add, l4 * r1), @reduce(.Add, l4 * r2), @reduce(.Add, l4 * r3), @reduce(.Add, l4 * r4) }
        }};
    }
    
    pub inline fn eq(
        noalias self:  *const Matrix4x4,
        noalias other: *const Matrix4x4
    ) bool {
        @setFloatMode(.Optimized);
        const m1: @Vector(16, f32) = @bitCast(self.*);
        const m2: @Vector(16, f32) = @bitCast(other.*);
        return @reduce(.And, m1 == m2);
    }
    
    pub const RotationAxis = enum { Yaw, Pitch, Roll };
    
    pub fn rotation(comptime axis: RotationAxis, angle: f32) Matrix4x4 {
        const a = std.math.degreesToRadians(f32, angle);
        return switch (axis) {
            .Pitch => .{ .data = .{
                .{ 1, 0, 0, 0 },
                .{ 0, @cos(a), -@sin(a), 0 },
                .{ 0, @sin(a), @cos(a), 0 },
                .{ 0, 0, 0, 1 }
            }},
            .Yaw => .{ .data = .{
                .{ @cos(a), 0, @sin(a), 0 },
                .{ 0, 1, 0, 0 },
                .{ -@sin(a), 0, @cos(a), 0 },
                .{ 0, 0, 0, 1 }
            }},
            .Roll => .{ .data = .{
                .{ @cos(a), -@sin(a), 0, 0 },
                .{ @sin(a), @cos(a), 0, 0 },
                .{ 0, 0, 1, 0 },
                .{ 0, 0, 0, 1 }
            }},
        };
    }
    
    pub fn translation(x: f32, y: f32, z: f32) Matrix4x4 {
        return .{ .data = .{
            .{ 1, 0, 0, 0 },
            .{ 0, 1, 0, 0 },
            .{ 0, 0, 1, 0 },
            .{ x, y, z, 1 }
        }};
    }
    
    pub fn scaling(x: f32, y: f32, z: f32) Matrix4x4 {
        return .{ .data = .{
            .{ x, 0, 0, 0 },
            .{ 0, y, 0, 0 },
            .{ 0, 0, z, 0 },
            .{ 0, 0, 0, 1 }
        }};
    }
    
    pub fn projection(w: f32, h: f32, fov: f32, near: f32, far: f32) Matrix4x4 {
        const aspect = h / w;
        const q = far / (far - near);
        const f = 1 / @tan(std.math.degreesToRadians(f32, fov) / 2);
        return .{ .data = .{
            .{ aspect * f, 0, 0, 0 },
            .{ 0, f, 0, 0 },
            .{ 0, 0, q, 1 },
            .{ 0, 0, -near * q, 0 }
        }};
    }
    
    pub fn frustum(l: f32, r: f32, top: f32, bottom: f32, near: f32, far: f32) Matrix4x4 {
        const a = (r + l) / (r - l);
        const b = (top + bottom) / (top - bottom);
        const c = -((far + near) / (far - near));
        const d = -(2 * far * near / (far - near));
        return .{ .data = .{
            .{ 2 * near / (r - l), 0, a, 0 },
            .{ 0, 2 * near / (top - bottom), b, 0 },
            .{ 0, 0, c, d },
            .{ 0, 0, -1, 0 }
        }};
    }
    
    pub fn identity() Matrix4x4 {
        return .{ .data = .{
            .{ 1, 0, 0, 0 },
            .{ 0, 1, 0, 0 },
            .{ 0, 0, 1, 0 },
            .{ 0, 0, 0, 1 }
        }};
    }
};

test "matrix multiplication" {
    const mat1 = Matrix4x4 { .data = .{
        .{ 5, 7, 9, 10 },
        .{ 2, 3, 3, 8 },
        .{ 8, 10, 2, 3 },
        .{ 3, 3, 4, 8 }
    }};
    
    const mat2 = Matrix4x4 { .data = .{
        .{ 3, 10, 12, 18 },
        .{ 12, 1, 4, 9 },
        .{ 9, 10, 12, 2 },
        .{ 3, 12, 4, 10 }
    }};
    
    try std.testing.expect(
        mat1.mul(&mat2).eq(&Matrix4x4 { .data = .{
            .{ 210, 267, 236, 271 },
            .{ 93, 149, 104, 149 },
            .{ 171, 146, 172, 268 },
            .{ 105, 169, 128, 169 }
        }})
    );
}