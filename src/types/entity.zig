/// This is my generic entity class. All entities will belong to This
/// class at the end of the day. Entities will be store via MultiArrayList
const std = @import("std");
const Renderer = @import("renderer.zig");
const SpriteRenderable = Renderer.SpriteRenderable;
const RenderPassIds = Renderer.RenderPassIds;
const util = @import("../util.zig");
const math = util.math;

pub const EntityTag = enum {
    default,
};

pub const AABB = struct {
    min: math.Vec2,
    max: math.Vec2,
};

// @important @incorrect_rendering We have to manually change serde formatting as we go.
const Self = @This();
id: u32 = 10,
spritesheet_id: RenderPassIds = .ENTITY_1,
z_index: f32 = 0,
entity_type: EntityTag = .default,
pos: math.Vec2 = .{},
size: math.Vec2 = .{},
sprite_id: f32 = 0,
aabb: AABB = .{
    .min = math.Vec2.zero(),
    .max = math.Vec2{ .x = 16, .y = 16 },
},
lua_script: []const u8 = "",
// FLAGS
selected: bool = false,

pub fn jsonStringify(self: *const Self, jws: anytype) !void {
    try jws.beginObject();
    try jws.objectField("id");
    try jws.print("{}", .{self.id});
    try jws.objectField("spritesheet_id");
    try jws.print("{s}", .{@tagName(self.spritesheet_id)});
    try jws.objectField("z_index");
    try jws.print("{}", .{self.z_index});
    try jws.objectField("entity_type");
    try jws.print("{s}", .{@tagName(self.entity_type)});
    try jws.objectField("pos");
    try jws.beginObject();
    try jws.objectField("x");
    try jws.print("{}", .{self.pos.x});
    try jws.objectField("y");
    try jws.print("{}", .{self.pos.y});
    try jws.endObject();
    try jws.objectField("size");
    try jws.beginObject();
    try jws.objectField("x");
    try jws.print("{}", .{self.size.x});
    try jws.objectField("y");
    try jws.print("{}", .{self.size.y});
    try jws.endObject();
    try jws.objectField("sprite_id");
    try jws.print("{}", .{self.sprite_id});

    // Start aabb
    try jws.objectField("aabb");
    try jws.beginObject();
    try jws.objectField("min");
    try jws.beginObject();
    try jws.objectField("x");
    try jws.print("{}", .{self.aabb.min.x});
    try jws.objectField("y");
    try jws.print("{}", .{self.aabb.min.y});
    try jws.endObject();
    try jws.objectField("max");
    try jws.beginObject();
    try jws.objectField("x");
    try jws.print("{}", .{self.aabb.max.x});
    try jws.objectField("y");
    try jws.print("{}", .{self.aabb.max.y});
    try jws.endObject();
    try jws.endObject();
    // end aabb
    //
    try jws.objectField("lua_script");
    try jws.print("{s}", .{self.lua_script});

    try jws.objectField("selected");
    try jws.print("{}", .{self.selected});

    try jws.endObject();
}

//pub fn jsonParse(allocator: std.mem.Allocator, source: anytype, options: std.json.ParseOptions) !Self {
//    _ = allocator;
//    _ = source;
//    _ = options;
//    // @todo finish parsing
//}

pub fn init(
    self: *Self,
    e_type: EntityTag,
) void {
    _ = self;
    _ = e_type;
}

pub fn toSpriteRenderable(self: *const Self) SpriteRenderable {
    return .{
        .pos = .{
            .x = self.pos.x,
            .y = self.pos.y,
            .z = self.z_index,
        },
        .sprite_id = self.sprite_id,
        .color = .{ .x = 0.0, .y = 0.0, .z = 0.0, .w = 1.0 },
    };
}
