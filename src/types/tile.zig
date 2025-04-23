const std = @import("std");
const SpriteRenderable = @import("renderer.zig").SpriteRenderable;
const util = @import("../util.zig");
const math = util.math;

// @important  4 byte alignement 44 bytes
const Self = @This();
pos: math.Vec2i = .{}, // 8 bytes
sprite_renderable: SpriteRenderable = .{
    .pos = .{ .x = 0, .y = 0, .z = 0 },
    .sprite_id = 0,
    .color = .{ .x = 0, .y = 0, .z = 0, .w = 0 },
}, // 32 bytes
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

//pub fn jsonParse(allocator: std.mem.Allocator, source: anytype, options: std.json.ParseOptions) !Self {
//    // @todo finish parsing
//    _ = options;
//
//    var self: Self = .{};
//    if (try source.next() != .object_begin) {
//        return error.UnexpectedToken;
//    }
//
//    switch (try source.nextAlloc(allocator, .alloc_if_needed)) {
//        .string, .allocated_string => |token| {
//            std.log.info("token: {s}", .{token});
//            if (!std.mem.eql(u8, token, "pos")) {
//                return error.UnexpectedToken;
//            }
//        },
//        else => return error.UnexpectedToken,
//    }
//
//    // POS parsing
//    if (try source.next() != .object_begin) {
//        return error.UnexpectedToken;
//    }
//    switch (try source.nextAlloc(allocator, .alloc_if_needed)) {
//        .string, .allocated_string => |token| {
//            if (!std.mem.eql(u8, token, "x")) {
//                return error.UnexpectedToken;
//            }
//        },
//        else => return error.UnexpectedToken,
//    }
//    switch (try source.nextAlloc(allocator, .alloc_if_needed)) {
//        .number, .allocated_number => |token| {
//            self.pos.x = token;
//        },
//        else => return error.UnexpectedToken,
//    }
//    switch (try source.nextAlloc(allocator, .alloc_if_needed)) {
//        .string, .allocated_string => |token| {
//            if (!std.mem.eql(u8, token, "y")) {
//                return error.UnexpectedToken;
//            }
//        },
//        else => return error.UnexpectedToken,
//    }
//    switch (try source.nextAlloc(allocator, .alloc_if_needed)) {
//        .number, .allocated_number => |token| {
//            self.pos.y = token;
//        },
//        else => return error.UnexpectedToken,
//    }
//    if (try source.next() != .object_end) {
//        return error.UnexpectedToken;
//    }
//
//    if (try source.next() != .object_end) {
//        return error.UnexpectedToken;
//    }
//
//    return .{};
//}
