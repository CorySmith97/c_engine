/// ===========================================================================
///
/// Author: Cory Smith
///
/// Date: 2025-04-22
///
/// Description:
/// ===========================================================================


const math = @import("../util.zig").math;
const std = @import("std");
const log = std.log.scoped(.RenderSystem);

//
// Flag for if render should shimmer
//
pub const SpriteRenderable = extern struct {
    pos       : math.Vec3 = .{},
    sprite_id : f32 = 0,
    color     : math.Vec4 = .{},
};

pub const pass_count: u32 = 4;

//
// map_ for map sprite
// combat_ for combat sprite
//
pub const RenderPassIds = enum(usize) {
    map_tiles_1,
    map_tiles_2,
    map_entity_1,
    //battle_entity_1,
    map_ui_1,
};
