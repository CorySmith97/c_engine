const std = @import("std");

export fn helloFromGame() void {
    std.log.info("Hello from the game\n", .{});
}
