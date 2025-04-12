const std = @import("std");
const SpriteRenderable = @import("renderer/SpriteRenderable.zig").SpriteRenderable;
const math = @import("math.zig");

const Self = @This();
sprite_renderable: SpriteRenderable,
spawner: bool = false,
traversable: bool = false,
