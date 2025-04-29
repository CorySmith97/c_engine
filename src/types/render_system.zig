/// ===========================================================================
///
/// Author: Cory Smith
///
/// Date: 2025-04-22
///
/// Description:
/// ===========================================================================


const math = @import("../util.zig").math;

pub const SpriteRenderable = extern struct {
    pos       : math.Vec3 = .{},
    sprite_id : f32 = 0,
    color     : math.Vec4 = .{},
};

pub const pass_count: u32 = 4;

//
// @todo Rename these for prefixes. IE
// m_ for map sprite
// c_ for combat sprite
//
// Also move to lower case
//
pub const RenderPassIds = enum(usize) {
    TILES_1,
    TILES_2,
    ENTITY_1,
    UI_1,
};
