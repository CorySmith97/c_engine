const std = @import("std");
const SpriteRenderable = @import("renderer.zig").SpriteRenderable;
const util = @import("../util.zig");
const math = util.math;

const Self = @This();
pos: math.Vec2i = .{},
sprite_renderable: SpriteRenderable,
spawner: bool = false,
traversable: bool = false,
