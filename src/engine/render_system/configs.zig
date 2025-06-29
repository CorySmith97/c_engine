/// ===========================================================================
///
/// Author: Cory Smith
///
/// Date: 2025-04-22
///
/// Description:
/// ===========================================================================

const util = @import("../util.zig");
const math = util.math;
const types = @import("../types.zig");
const Scene = types.Scene;
const Entity = types.Entity;
const RendererTypes = types.RendererTypes;
const SpriteRenderable = RendererTypes.SpriteRenderable;

pub const RenderPassConfig = struct {
    id: RendererTypes.RenderPassIds,
    path: []const u8,
    atlas_size: [2]f32,
    sprite_size: [2]f32,
};

// @incorrect_rendering Likely due to spritesheet dimensions being
// incorrect
pub var Defaults = &[_]RenderPassConfig{
    .{
        .id = .map_tiles_1,
        .path = "src/game/assets/tiles_1.png",
        .sprite_size = .{ 16, 16 },
        .atlas_size = .{ 256, 256 },
    },
    .{
        .id = .map_tiles_2,
        .path = "src/game/assets/tiles_2.png",
        .sprite_size = .{ 16, 16 },
        .atlas_size = .{ 256, 256 },
    },
    .{
        .id = .map_entity_1,
        .path = "src/game/assets/entity_1.png",
        .sprite_size = .{ 16, 16 },
        .atlas_size = .{ 256, 256 },
    },
    .{
        .id = .map_ui_1,
        .path = "src/game/assets/ui_1.png",
        .sprite_size = .{ 16, 16 },
        .atlas_size = .{ 256, 256 },
    },
};
