
const engine = @import("engine/engine.zig");
const World = @import("game.zig").World;

pub fn main() !void {
    var window = try engine.Window.init("Minecraft");
    defer window.deinit();
    
    window.lockCursor(true);
    
    var world = try World.init();
    defer world.deinit();
    
    while (window.update()) {
        window.clear();
        world.update();
        world.draw();
        window.swapBuffers();
    }
}
