const math = @import("../math.zig");

pub const SpriteRenderable = extern struct {
    pos: math.Vec3,
    sprite_id: f32,
    color: math.Vec4,
};
