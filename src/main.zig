const std = @import("std");
pub const c = @import("core/c.zig");
pub const objc = @import("objc/objc.zig");
pub const assets = @import("assets/assets.zig");
pub const game = @import("game.zig");
pub const math = @import("core/math.zig");
pub const noise = @import("core/noise.zig");
pub const image = @import("core/image.zig");

const TGAConstPtr = image.TGAConstPtr;
const World = game.World;

const terrain = TGAConstPtr { .raw = assets.terrain_tga };
const initial_width = 800;
const initial_height = 600;

var window: *c.SDL_Window = undefined;
var event: c.SDL_Event = undefined;
var keymap: [*c]const u8 = undefined;
var width: i32 = undefined;
var height: i32 = undefined;
var renderer: *c.SDL_Renderer = undefined;
var metal_swapchain: objc.AnyInstance = undefined;
var wgpu_instance: c.WGPUInstance = undefined;
var wgpu_surface: c.WGPUSurface = undefined;
var wgpu_adapter: c.WGPUAdapter = undefined;
var wgpu_device: c.WGPUDevice = undefined;
var wgpu_queue: c.WGPUQueue = undefined;
var wgpu_shaders: c.WGPUShaderModule = undefined;
var wgpu_pipeline_layout: c.WGPUPipelineLayout = undefined;
var wgpu_surface_capabilities = std.mem.zeroes(c.WGPUSurfaceCapabilities);
var wgpu_render_pipeline: c.WGPURenderPipeline = undefined;
var wgpu_config: c.WGPUSurfaceConfiguration = undefined;

pub fn getWidth() i32 { return width; }
pub fn getHeight() i32 { return height; }

pub fn main() !void {
    if (c.SDL_Init(c.SDL_INIT_VIDEO) != 0) return error.InitializingSDL;
    
    window = c.SDL_CreateWindow(
        "Minecraft",
        c.SDL_WINDOWPOS_CENTERED,
        c.SDL_WINDOWPOS_CENTERED,
        initial_width, initial_height,
        c.SDL_WINDOW_ALLOW_HIGHDPI |
        c.SDL_WINDOW_METAL |
        c.SDL_WINDOW_RESIZABLE
    ) orelse return error.CreatingWindow;
    defer c.SDL_DestroyWindow(window);
    _ = c.SDL_SetWindowMinimumSize(window, initial_width, initial_height);
    
    renderer = c.SDL_CreateRenderer(window, -1, c.SDL_RENDERER_PRESENTVSYNC) orelse return error.CreatingRenderer;
    defer c.SDL_DestroyRenderer(renderer);
    
    c.SDL_GetWindowSizeInPixels(window, &width, &height);
    
    metal_swapchain = .{ .id = @alignCast(@ptrCast(c.SDL_RenderGetMetalLayer(renderer) orelse return error.GettingMetalSwapchain)) };
    
    keymap = c.SDL_GetKeyboardState(null);
    
    // WebGPU
    wgpu_instance = c.wgpuCreateInstance(null) orelse return error.CreatingWGPUInstance;
    defer c.wgpuInstanceRelease(wgpu_instance);
    wgpu_surface = c.wgpuInstanceCreateSurface(wgpu_instance, &.{
        .nextInChain = @ptrCast(&c.WGPUSurfaceDescriptorFromMetalLayer {
            .chain = .{ .sType = c.WGPUSType_SurfaceDescriptorFromMetalLayer },
            .layer = metal_swapchain.id
        })
    }) orelse return error.CreatingWGPUSurface;
    defer c.wgpuSurfaceRelease(wgpu_surface);
    
    c.wgpuInstanceRequestAdapter(wgpu_instance, &.{ .compatibleSurface = wgpu_surface }, &handleRequestAdapter, null);
    if (wgpu_adapter == null) return error.ReceivingWGPUAdapter;
    defer c.wgpuAdapterRelease(wgpu_adapter);
    
    c.wgpuAdapterRequestDevice(wgpu_adapter, null, &handleRequestDevice, null);
    if (wgpu_device == null) return error.ReceivingWGPUDevice;
    defer c.wgpuDeviceRelease(wgpu_device);
    
    wgpu_queue = c.wgpuDeviceGetQueue(wgpu_device) orelse return error.GettingWGPUQueue;
    defer c.wgpuQueueRelease(wgpu_queue);
    wgpu_shaders = c.wgpuDeviceCreateShaderModule(wgpu_device, &.{
        .label = "Shaders",
        .nextInChain = @ptrCast(&c.WGPUShaderModuleWGSLDescriptor {
            .chain = .{ .sType = c.WGPUSType_ShaderModuleWGSLDescriptor },
            .code = assets.shaders_wgsl
        })
    }) orelse return error.CreatingWGPUShaderModule;
    defer c.wgpuShaderModuleRelease(wgpu_shaders);
    
    wgpu_pipeline_layout = c.wgpuDeviceCreatePipelineLayout(wgpu_device, &.{
        .label = "PipelineLayout"
    }) orelse return error.CreatingWGPUPipelineLayout;
    defer c.wgpuPipelineLayoutRelease(wgpu_pipeline_layout);
    
    c.wgpuSurfaceGetCapabilities(wgpu_surface, wgpu_adapter, &wgpu_surface_capabilities);
    
    wgpu_render_pipeline = c.wgpuDeviceCreateRenderPipeline(wgpu_device, &.{
        .label = "RenderPipeline",
        .layout = wgpu_pipeline_layout,
        .vertex = .{ .module = wgpu_shaders, .entryPoint = "vs_main" },
        .fragment = &c.WGPUFragmentState {
            .module = wgpu_shaders,
            .entryPoint = "fs_main",
            .targetCount = 1,
            .targets = &c.WGPUColorTargetState {
                .format = wgpu_surface_capabilities.formats[0],
                .writeMask = c.WGPUColorWriteMask_All
            }
        },
        .primitive = .{ .topology = c.WGPUPrimitiveTopology_TriangleList },
        .multisample = .{ .count = 1, .mask = 0xffffffff }
    }) orelse return error.CreatingWGPURenderPipeline;
    defer c.wgpuRenderPipelineRelease(wgpu_render_pipeline);
    
    wgpu_config = c.WGPUSurfaceConfiguration {
        .device = wgpu_device,
        .usage = c.WGPUTextureUsage_RenderAttachment,
        .format = wgpu_surface_capabilities.formats[0],
        .presentMode = c.WGPUPresentMode_Fifo,
        .alphaMode = wgpu_surface_capabilities.alphaModes[0],
        .width = @intCast(getWidth()),
        .height = @intCast(getHeight()),
    };
    
    c.wgpuSurfaceConfigure(wgpu_surface, &wgpu_config);
    
    // Game
    var world = try World.init();
    defer world.deinit();
    
    loop: while (true) {
        c.SDL_GetWindowSizeInPixels(window, &width, &height);
        while (c.SDL_PollEvent(&event) > 0) {
            switch (event.type) {
                c.SDL_QUIT => break :loop,
                else => break
            }
        }
        
        world.update();
        try render(world);
    }
}

fn handleRequestAdapter(status: c.WGPURequestAdapterStatus, adapter: c.WGPUAdapter, _: [*c]const u8, _: ?*anyopaque) callconv(.C) void {
    if (status == c.WGPURequestAdapterStatus_Success) wgpu_adapter = adapter;
}

fn handleRequestDevice(status: c.WGPURequestDeviceStatus, device: c.WGPUDevice, _: [*c]const u8, _: ?*anyopaque) callconv(.C) void {
    if (status == c.WGPURequestDeviceStatus_Success) wgpu_device = device;
}

fn lockCursor(value: bool) void {
    if (value) _ = c.SDL_SetRelativeMouseMode(1)
    else _ = c.SDL_SetRelativeMouseMode(0);
}

pub const BlockVertex = packed struct {
    position: BlockVertex.Position,
    tex_coord: TextureCoord,
    color: Color = Color.white,
    
    pub const Position = packed struct { x: f32, y: f32, z: f32 };
    pub const TextureCoord = packed struct { u: f32, v: f32 };
    
    pub inline fn init(x: f32, y: f32, z: f32, u: f32, v: f32, r: f32, g: f32, b: f32, a: f32) BlockVertex {
        return .{
            .position = .{ .x = x, .y = y, .z = z },
            .tex_coord = .{ .u = u, .v = v },
            .color = .{ .r = r, .g = g, .b = b, .a = a }
        };
    }
};

fn render(world: *const World) !void { _ = world;
    var surface_texture: c.WGPUSurfaceTexture = undefined;
    c.wgpuSurfaceGetCurrentTexture(wgpu_surface, &surface_texture);
    
    switch (surface_texture.status) {
        c.WGPUSurfaceGetCurrentTextureStatus_Success => {},
        c.WGPUSurfaceGetCurrentTextureStatus_Timeout,
        c.WGPUSurfaceGetCurrentTextureStatus_Outdated,
        c.WGPUSurfaceGetCurrentTextureStatus_Lost => {
            if (surface_texture.texture != null) c.wgpuTextureRelease(surface_texture.texture);
            wgpu_config.width = @intCast(getWidth());
            wgpu_config.height = @intCast(getHeight());
            c.wgpuSurfaceConfigure(wgpu_surface, &wgpu_config);
            return;
        },
        c.WGPUSurfaceGetCurrentTextureStatus_OutOfMemory => return error.SurfaceTextureOutOfMemory,
        c.WGPUSurfaceGetCurrentTextureStatus_DeviceLost => return error.SurfaceTextureDeviceLost,
        c.WGPUSurfaceGetCurrentTextureStatus_Force32 => return error.SurfaceTextureForce32,
        else => {}
    }
    if (surface_texture.texture == null) return error.SurfaceTextureIsNull;
    
    const frame = c.wgpuTextureCreateView(surface_texture.texture, null) orelse return error.CreatingTextureView;
    const command_encoder = c.wgpuDeviceCreateCommandEncoder(wgpu_device, &.{ .label = "CommandEncoder" })
        orelse return error.CreatingCommandEncoder;
    const render_pass_encoder = c.wgpuCommandEncoderBeginRenderPass(command_encoder, &.{
        .label = "RenderPassEncoder",
        .colorAttachmentCount = 1,
        .colorAttachments = &c.WGPURenderPassColorAttachment {
            .view = frame,
            .loadOp = c.WGPULoadOp_Clear,
            .storeOp = c.WGPUStoreOp_Store,
            .clearValue = .{ .r = 0.0, .g = 1.0, .b = 0.0, .a = 1.0 }
        }
    }) orelse return error.BeginningRenderPass;
    
    c.wgpuRenderPassEncoderSetPipeline(render_pass_encoder, wgpu_render_pipeline);
    c.wgpuRenderPassEncoderDraw(render_pass_encoder, 3, 1, 0, 0);
    c.wgpuRenderPassEncoderEnd(render_pass_encoder);
    
    const command_buffer = c.wgpuCommandEncoderFinish(command_encoder, &.{ .label = "CommandBuffer" })
        orelse return error.FinishingCommandEncoder;
    
    c.wgpuQueueSubmit(wgpu_queue, 1, &command_buffer);
    c.wgpuSurfacePresent(wgpu_surface);

    c.wgpuCommandBufferRelease(command_buffer);
    c.wgpuRenderPassEncoderRelease(render_pass_encoder);
    c.wgpuCommandEncoderRelease(command_encoder);
    c.wgpuTextureViewRelease(frame);
    c.wgpuTextureRelease(surface_texture.texture);
}

pub const Color = packed struct {
    r: f32 = 0, g: f32 = 0, b: f32 = 0, a: f32 = 1,
    
    pub const clear = Color { .r = 0, .g = 0, .b = 0, .a = 0 };
    pub const white = Color { .r = 1, .g = 1, .b = 1, .a = 1 };
    pub const black = Color { .r = 0, .g = 0, .b = 0, .a = 1 };
};

pub inline fn relativeMouse() packed struct { x: f32, y: f32 } {
    var x: i32 = undefined;
    var y: i32 = undefined;
    _ = c.SDL_GetRelativeMouseState(&x, &y);
    const fx: f32 = @floatFromInt(x);
    const fy: f32 = @floatFromInt(y);
    return .{ .x = fx, .y = fy };
}

pub inline fn key(comptime name: Key) bool {
    return switch (name) {
        .w => keymap[c.SDL_SCANCODE_W],
        .a => keymap[c.SDL_SCANCODE_A],
        .s => keymap[c.SDL_SCANCODE_S],
        .d => keymap[c.SDL_SCANCODE_D],
        
        .left_shift => keymap[c.SDL_SCANCODE_LSHIFT],
        .space => keymap[c.SDL_SCANCODE_SPACE],
        
        else => std.debug.panic("Unimplemented input: {any}", .{ name })
    } == 1;
}

pub const Key = enum {
    a, b, c, d, e, f,
    g, h, i, j, k, l,
    m, n, o, p, q, r,
    s, t, u, v, w, x,
    y, z,
    
    num_1, num_2,
    num_3, num_4,
    num_5, num_6,
    num_7, num_8,
    num_9, num_0,
    
    space,
    left_shift,
    right_shift,
    
    left_mouse,
    right_mouse
};
