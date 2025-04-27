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
        .id = .TILES_1,
        .path = "assets/tiles_1.png",
        .sprite_size = .{ 16, 16 },
        .atlas_size = .{ 256, 256 },
    },
    .{
        .id = .TILES_2,
        .path = "assets/tiles_2.png",
        .sprite_size = .{ 16, 16 },
        .atlas_size = .{ 256, 256 },
    },
    .{
        .id = .ENTITY_1,
        .path = "assets/entity_1.png",
        .sprite_size = .{ 16, 16 },
        .atlas_size = .{ 256, 256 },
    },
    .{
        .id = .UI_1,
        .path = "assets/ui_1.png",
        .sprite_size = .{ 16, 16 },
        .atlas_size = .{ 256, 256 },
    },
};
