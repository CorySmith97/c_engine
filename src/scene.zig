const std = @import("std");
const Entity = @import("entity.zig");
const Tile = @import("tile.zig");
const Renderer = @import("renderer.zig");

const Self = @This();
id: u32,
entities: std.MultiArrayList(Entity),
bg_tiles: std.MultiArrayList(Tile),
fg_tiles: std.MultiArrayList(Tile),

pub fn loadTestScene(
    self: *Self,
    allocator: std.mem.Allocator,
) !void {
    const width = 100;
    const height = 100;

    self.bg_tiles.resize(allocator, width * height);
    self.fg_tiles.resize(allocator, width * height);
}

pub fn loadScene(self: *Self, renderer: Renderer) !void {
    for (self.entities.len) |i| {
        const entity = self.entities.get(i);
        const renderable = entity.toSpriteRenderable();
        try renderer.render_passes.items[0].appendSpriteToBatch(renderable);
    }
}

pub fn saveScene(self: *Self) !void {
    _ = self;
}

pub fn renderScene(self: *Self) void {
    _ = self;
}
