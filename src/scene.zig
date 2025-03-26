const std = @import("std");
const Entity = @import("entity.zig");
const Tile = @import("tile.zig");

const Self = @This();
id: u32,
entities: std.ArrayList(Entity),
tiles: std.ArrayList(Tile),

pub fn renderScene(self: *Self) void {
    _ = self;
}
