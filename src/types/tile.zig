/// ===========================================================================
///
/// Author: Cory Smith
///
/// Date: 2025-04-05
///
/// Description:
///     Tile class for the world. World is grid based made of these as
///     basic building blocks.
/// ===========================================================================

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


