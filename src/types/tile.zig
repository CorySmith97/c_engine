const std = @import("std");
const SpriteRenderable = @import("renderer.zig").SpriteRenderable;
const util = @import("../util.zig");
const math = util.math;

// @important  4 byte alignement 44 bytes
const Self = @This();
pos: math.Vec2i = .{}, // 8 bytes
sprite_renderable: SpriteRenderable, // 32 bytes
spawner: bool = false,
traversable: bool = false,

pub fn jsonStringify(self: *const Self, jws: anytype) !void {
    try jws.beginObject();
    try jws.objectField("pos");
    try jws.beginObject();
    try jws.objectField("x");
    try jws.print("{}", .{self.pos.x});
    try jws.objectField("y");
    try jws.print("{}", .{self.pos.y});
    try jws.endObject();

    try jws.objectField("sprite_renderable");
    try self.sprite_renderable.jsonStringify(jws);

    try jws.objectField("spawner");
    try jws.write(self.spawner);

    try jws.objectField("traversable");
    try jws.write(self.traversable);

    try jws.endObject();
}

pub fn jsonParse(allocator: std.mem.Allocator, source: anytype, options: std.json.ParseOptions) !Self {
    // @todo finish parsing
    _ = allocator;
    _ = source;
    _ = options;
}
