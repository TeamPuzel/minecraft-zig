
const engine = @import("engine/engine.zig");
const World = @import("game.zig").World;

pub fn main() !void {
    try engine.init("Minecraft");
    defer engine.deinit();
    
    engine.lockCursor(true);
    
    var world = try World.init();
    defer world.deinit();
    
    engine.graphics.setClearColor(.{ .r = 0.52, .g = 0.67, .b = 0.97 });
    
    while (engine.update()) {
        engine.clear();
        
        world.update();
        world.draw();
        
        engine.swapBuffers();
    }
}
