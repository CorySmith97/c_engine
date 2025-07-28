const std = @import("std");
const Renderer = @import("render.zig");

pub fn main() !void {
    var app = Renderer{};
    try app.run();
}
