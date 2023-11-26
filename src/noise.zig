
/// Will return in range `-1...1`.
/// To make it in range `0...1`, multiply by `0.5` and add `0.5`.
pub fn perlin(x: f32, y: f32) f32 {
    const vec = @Vector(2, f32) { x, y };
    
    const ivec0: @Vector(2, i32) = @intFromFloat(@floor(vec));
    const ivec1 = ivec0 + @Vector(2, i32) { 1, 1 };
    
    const svec = vec - @floor(vec);
    
    const n0a = dotGridGradient(ivec0, vec);
    const n1a = dotGridGradient(@Vector(2, i32) { ivec1[0], ivec0[1] }, vec);
    const ix0 = interpolate(n0a, n1a, svec[0]);
    
    const n0b = dotGridGradient(@Vector(2, i32) { ivec0[0], ivec1[1] }, vec);
    const n1b = dotGridGradient(ivec1, vec);
    const ix1 = interpolate(n0b, n1b, svec[0]);
    
    return interpolate(ix0, ix1, svec[1]);
}

inline fn interpolate(a0: f32, a1: f32, w: f32) f32 {
    return (a1 - a0) * w + a0;
}

inline fn randomGradient(vec: @Vector(2, i32)) @Vector(2, f32) {
    const w: u32 = 8 * @sizeOf(u32);
    const s: u32 = w / 2;
    
    var a: u32 = @bitCast(vec[0]);
    var b: u32 = @bitCast(vec[1]);
    
    a *%= 3284157443; 
    b ^= a << s | a >> w-s;
    b *%= 1911520717;
    a ^= b << s | b >> w-s;
    a *%= 2048419325;
    
    const c: u32 = 0o0;
    const div: f32 = @floatFromInt(~(~c >> 1));
    
    const fa: f32 = @floatFromInt(a);
    
    const random = fa * (3.14159265 / div);
    return @Vector(2, f32) { @cos(random), @sin(random) };
}

inline fn dotGridGradient(iv: @Vector(2, i32), v: @Vector(2, f32)) f32 {
    const gradient = randomGradient(iv);
    
    const ixf: f32 = @floatFromInt(iv[0]);
    const iyf: f32 = @floatFromInt(iv[1]);
    const ivf = @Vector(2, f32) { ixf, iyf };
    
    const d = v - ivf;
    
    const m = d * gradient;
    return m[0] + m[1];
}

const permutation = [_]i32 { 
    151, 160, 137,  91,  90,  15, 131,  13, 201,  95,  96,  53, 194, 233,   7, 225,
    140,  36, 103,  30,  69, 142,   8,  99,  37, 240,  21,  10,  23, 190,   6, 148,
    247, 120, 234,  75,   0,  26, 197,  62,  94, 252, 219, 203, 117,  35,  11,  32,
     57, 177,  33,  88, 237, 149,  56,  87, 174,  20, 125, 136, 171, 168,  68, 175,
     74, 165,  71, 134, 139,  48,  27, 166,  77, 146, 158, 231,  83, 111, 229, 122,
     60, 211, 133, 230, 220, 105,  92,  41,  55,  46, 245,  40, 244, 102, 143,  54,
     65,  25,  63, 161,   1, 216,  80,  73, 209,  76, 132, 187, 208,  89,  18, 169,
    200, 196, 135, 130, 116, 188, 159,  86, 164, 100, 109, 198, 173, 186,   3,  64,
     52, 217, 226, 250, 124, 123,   5, 202,  38, 147, 118, 126, 255,  82,  85, 212,
    207, 206,  59, 227,  47,  16,  58,  17, 182, 189,  28,  42, 223, 183, 170, 213,
    119, 248, 152,   2,  44, 154, 163,  70, 221, 153, 101, 155, 167,  43, 172,   9,
    129,  22,  39, 253,  19,  98, 108, 110,  79, 113, 224, 232, 178, 185, 112, 104,
    218, 246,  97, 228, 251,  34, 242, 193, 238, 210, 144,  12, 191, 179, 162, 241,
     81,  51, 145, 235, 249,  14, 239, 107,  49, 192, 214,  31, 181, 199, 106, 157,
    184,  84, 204, 176, 115, 121,  50,  45, 127,   4, 150, 254, 138, 236, 205,  93,
    222, 114,  67,  29,  24,  72, 243, 141, 128, 195,  78,  66, 215,  61, 156, 180
};