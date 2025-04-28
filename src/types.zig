/// ===========================================================================
///
/// Author: Cory Smith
///
/// Date: 2025-04-05
///
/// Description:
///     Uniform types that are used by both the engine and game
/// ===========================================================================
const std = @import("std");
pub const Entity = @import("types/entity.zig");
pub const Tile = @import("types/tile.zig");
pub const Scene = @import("types/scene.zig");
pub const RendererTypes = @import("types/renderer.zig");
const math = @import("util/math.zig");
pub const Editor = @import("types/editor.zig");

pub const GlobalConstants = struct {
    pub var grid_size: f32 = 16.0;
};


pub const AABB = struct {
    min: math.Vec2 = .{},
    max: math.Vec2 = .{},
};

pub const GroupTile = struct {
    id: usize,
    tile: Tile,
};
