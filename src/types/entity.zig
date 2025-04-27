/// ===========================================================================
///
/// Author: Cory Smith
///
/// Date: 2025-04-05
///
/// Description:
/// ===========================================================================


const std = @import("std");
const Renderer = @import("renderer.zig");
const SpriteRenderable = Renderer.SpriteRenderable;
const RenderPassIds = Renderer.RenderPassIds;
const util = @import("../util.zig");
const math = util.math;
const types = @import("../types.zig");
const AABB = types.AABB;

pub const EntityTag = enum {
    default,
};

const default_aabb: AABB = .{
    .min = math.Vec2.zero(),
    .max = math.Vec2{ .x = 16, .y = 16 },
};



// @important @incorrect_rendering We have to manually change serde formatting as we go.
const Self = @This();
id             : u32 = 10,
spritesheet_id : RenderPassIds = .ENTITY_1,
z_index        : f32 = 0,
entity_type    : EntityTag = .default,
pos            : math.Vec2 = .{},
size           : math.Vec2 = .{},
sprite_id      : f32 = 0,
aabb           : AABB = default_aabb,
lua_script     : []const u8 = "",
// FLAGS
selected       : bool = false,


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
