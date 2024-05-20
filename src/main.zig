
const engine = @import("engine/engine.zig");
const World = @import("game.zig").World;

pub fn main() !void {
    const window = try engine.Window.init("Minecraft");
    defer window.deinit();
    
    window.lockCursor(true);
    
    var world = try World.init();
    defer world.deinit();
    
    engine.graphics.setClearColor(.{ .r = 0.52, .g = 0.67, .b = 0.97 });
    
    while (window.update()) {
        window.clear();
        world.update();
        world.draw();
        window.swapBuffers();
    }
}
