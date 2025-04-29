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
    pos: math.Vec3,
    sprite_id: f32,
    color: math.Vec4,
};

pub const pass_count: u32 = 4;

pub const RenderPassIds = enum {
    TILES_1,
    TILES_2,
    ENTITY_1,
    UI_1,
};
