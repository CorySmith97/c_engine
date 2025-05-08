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
const HashMap = std.StaticStringMap;
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
    health     : u16 = 1,
    cur_health : u16 = 1,
    strength   : u16 = 1,
    magic      : u16 = 1,
    dexterity  : u16 = 1,
    wisdom     : u16 = 1,
    charisma   : u16 = 1,
    speed      : u16 = 1,
    defense    : u16 = 1,
    resistence : u16 = 1,
    move_speed : u16 = 5,
};

const AnimationTag = enum {
    map,
    battle_idle,
    battle_attack,
    battle_crit,
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

const Team = enum {
    player,
    enemy,
    neutral,
};

//
// @incorrect_rendering We have to manually change serde formatting as we go.
//
// Need to store world location as a usize/u32.
//
pub const Entity = struct {
    id                 : u32           = 10,

    //
    // This is the index of the entity for the corresponding location in the tiles
    // array. Used for pathfinding as well as collisions. Havent decided which
    // I will keep at the moment. The differences come from the byte difference.
    // Zig does not guarentee the structure of a struct. IE if it can optimize for
    // alignment, itll change the shape in memory for better packing.
    //
    world_index        : u32           = 0, // 4 bytes
    grid_pos           : usize         = 0, // 4 bytes on 32 bit machines
    // 8 bytes on 64 bit machines


    //
    // Rendering Info
    //

    // default map sprite id
    spritesheet_id     : RenderPassIds = .map_entity_1,

    // battle sprite id
    //b_spritesheet_id   : RenderPassIds = .battle_entity_1,

    z_index            : f32           = 0,
    entity_type        : EntityTag     = .default,
    selected_animation : AnimationTag = .map,
    animation          : Animation     = .{},
    sprite             : SpriteRenderable = .{},

    // Axis Aligned Bounding Box. Collision info
    aabb               : AABB          = default_aabb,
    flags              : Flags         = .{},

    // Gameplay info
    weapon             : Weapon        = .{},
    stats              : Stats         = .{},
    team               : Team          = .player,
    // Removing scripting for the meantime. I dont want to deal with the headache.
    //lua_script     : []const u8    = "",
};

//
// Ideally we dont use methods that are attached to the struct
// as a v-table. We want to have functions that take aspects of an
// entity and process data on those smaller subsets. IE combat,
// which is passes that stats and weapons of two seperate
// entities in order to calculate the outcome of a fight.
//

//
// This grabs a preset entity from the global hashmap.
// The static_stats flag is meant to give randomness to
// massively reused entities.
//
pub fn init(
    self: *Entity,
    e_type: []const u8,
    static_stats: bool,
) void {
    _ = self;
    _ = e_type;
    _ = static_stats;
}


pub fn combat(
    e1_stats: Stats,
    e1_weapon: Weapon,
    e2_stats: Stats,
    e2_weapon: Weapon,
) !void {

    const e1_base_attack = switch (e1_weapon.subtype) {
        .magical      => {
            e1_stats.magic + e1_weapon.damage;
        },
        .physical_str => {},
        .physical_dex => {},
    };
    const e2_base_attack = switch (e2_weapon.subtype) {
        .magical      => {
            e2_stats.magic + e2_weapon.damage;
        },
        .physical_str => {},
        .physical_dex => {},
    };

    _ = e1_base_attack;
    _ = e2_base_attack;
}


//
// Update the animation completely independent of other entity info
//
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
// I'd like all of these sprites to be on one spritesheet. Itll be huge, and thats
// okay. GPUs can store the memory. Wont be more that a few mb.
//
pub const EntityList = std.StaticStringMap(Entity).initComptime(.{
    .{"default", Entity{}},
    .{"sage", Entity{
        .animation = .{
            .frame_count = 0,
            .indicies  = @constCast(&[_]f32{0,1,2}),
            .cur_frame = 0,
            .speed = 42,
        }
    }},
    .{"thief", Entity{
        .animation = .{
            .frame_count = 0,
            .indicies  = @constCast(&[_]f32{16,17,18}),
            .cur_frame = 0,
            .speed = 42,
        }
    }},
    .{"mage", Entity{
        .animation = .{
            .frame_count = 0,
            .indicies  = @constCast(&[_]f32{32,33,34}),
            .cur_frame = 0,
            .speed = 42,
        }
    }},
});
