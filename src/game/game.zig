const std = @import("std");

export fn init() void {
}
export fn tick() void {
}
export fn draw() void {
}
export fn reload() void {
    std.log.info("Hello from the game\n", .{});
}
