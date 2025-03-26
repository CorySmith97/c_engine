/// This is my generic entity class. All entities will belong to This
/// class at the end of the day. Entities will be store via MultiArrayList
const std = @import("std");
const SpriteRenderable = @import("renderer.zig").SpriteRenderable;
const math = @import("math.zig");

pub const EntityType = enum {
    default,
};

const AABB = struct {
    min: math.Vec2,
    max: math.Vec2,
};

const Self = @This();
id: u32 = 0,
z_index: f32 = 0,
entity_type: EntityType = .default,
pos: math.Vec2 = math.Vec2.zero(),
sprite_id: f32 = 0,
aabb: AABB = .{
    .min = math.Vec2.zero(),
    .max = math.Vec2.zero(),
},
// FLAGS
selected: bool = false,

pub fn init(
    self: *Self,
    e_type: EntityType,
) void {
    _ = self;
    _ = e_type;
}

pub fn toSpriteRenderable(self: *Self) SpriteRenderable {
    return .{
        .pos = .{
            .x = self.pos.x,
            .y = self.pos.y,
            .z = self.z_index,
        },
        .sprite_id = self.sprite_id,
    };
}
