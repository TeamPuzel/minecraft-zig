
const std = @import("std");

pub const Matrix4x4 = extern struct {
    data: [4][4]f32,
    
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