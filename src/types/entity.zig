/// ===========================================================================
///
/// Author: Cory Smith
///
/// Date: 2025-04-05
///
/// Description:
///     Everything that is not a tile in the game world is an entity.
///     This is a generic class right now, there will be optimizations
///     built into it later. But it will be exclusively stored in a
///     multiarraylist, meaning we only have to filter over the fields that
///     we want to use for a specific entity. IE if there is a destructable
///     wall, then there is no need to access weapon data for examples.
/// ===========================================================================


const std = @import("std");
const log = std.log.scoped(.entity);
const Renderer = @import("render_system.zig");
const SpriteRenderable = Renderer.SpriteRenderable;
const RenderPassIds = Renderer.RenderPassIds;
const util = @import("../util.zig");
const math = util.math;
const types = @import("../types.zig");
const AABB = types.AABB;
const Weapon = @import("weapon.zig");

pub const EntityTag = enum {
    default,
};

const default_aabb: AABB = .{
    .min = math.Vec2.zero(),
    .max = math.Vec2{ .x = 16, .y = 16 },
};

const Stats = struct {
    level      : u16 = 1,
    health     : u16 = 10,
    strength   : u16 = 10,
    magic      : u16 = 10,
    dexterity  : u16 = 10,
    wisdom     : u16 = 10,
    charisma   : u16 = 10,
    speed      : u16 = 10,
    defense    : u16 = 10,
    resistence : u16 = 10,
    move_speed : u16 = 5,
};

const Animation = struct {
    frame_count : u32 = 0,
    indicies    : []f32 = &.{},
    cur_frame   : u32 = 0,
    speed       : u32 = 0,
};

const Flags = packed struct {
    selected       : bool = false,
    player_team    : bool = false,
};



//
// @todo I want to just add sprite renderable instead of the pieces.
// SpriteRenderable is already 4 byte aligned and all the data is always needed
// together. position can be stored twice.
//
// @todo we should update these sprite renderables every frame regardless
//
// @incorrect_rendering We have to manually change serde formatting as we go.
const Self                     = @This();
id             : u32           = 10,
spritesheet_id : RenderPassIds = .ENTITY_1,
z_index        : f32           = 0,
entity_type    : EntityTag     = .default,
sprite         : SpriteRenderable = .{},
aabb           : AABB          = default_aabb,
lua_script     : []const u8    = "",
flags          : Flags         = .{},
weapon         : Weapon        = .{},
stats          : Stats         = .{},
animation      : Animation    = .{},


//
// This grabs a preset entity from the global hashmap.
// The static_stats flag is meant to give randomness to
// massively reused entities.
//
pub fn init(
    self: *Self,
    e_type: []const u8,
    static_stats: bool,
) void {
    _ = self;
    _ = e_type;
    _ = static_stats;
}

//
// Frame based update
//
pub fn update(
    self: *Self,
) void {
    _ = self;
}

pub fn combat(
    e1_stats: Stats,
    e1_weapon: Weapon,
    e2_stats: Stats,
    e2_weapon: Weapon,
) !void {
    _ = e1_stats ;
    _ = e1_weapon ;
    _ = e2_stats  ;
    _ = e2_weapon ;
}

pub fn render(
    self: *Self,
) !void {
    _ = self;
}

pub fn updateAnimation(
    animation: *Animation,
) f32 {
    animation.*.frame_count += 1;

    if (animation.*.frame_count >= animation.speed) {
        animation.*.frame_count = 0;
        animation.*.cur_frame = (animation.*.cur_frame + 1) % @as(u32,@intCast(animation.indicies.len));
    }

    return animation.indicies[@intCast(animation.cur_frame)];

}


//
// Global Entity list with all the default types for enemies/reusable entities.
//
pub const EntityList = std.StaticStringMap(Self).initComptime(.{
    .{"default", Self{}},
    .{"sage", Self{
        .animation = .{
            .frame_count = 0,
            .indicies  = @constCast(&[_]f32{0,1,2}),
            .cur_frame = 0,
            .speed = 42,
        }
    }},
    .{"thief", Self{
        .animation = .{
            .frame_count = 0,
            .indicies  = @constCast(&[_]f32{16,17,18}),
            .cur_frame = 0,
            .speed = 42,
        }
    }},
});
