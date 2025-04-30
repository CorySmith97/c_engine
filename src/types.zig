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
pub const RendererTypes = @import("types/render_system.zig");
const math = @import("util/math.zig");
pub const Editor = @import("types/editor.zig");
pub const Camera = @import("types/camera.zig").Camera;

pub const mac_Color_Blue   = "\x1b[34m";
pub const mac_Color_Green  = "\x1b[32m";
pub const mac_Color_Red    = "\x1b[31m";
pub const mac_Color_Orange = "\x1b[35m";

pub const GlobalConstants = struct {
    pub var grid_size: f32 = 16.0;
};


pub const AABB = struct {
    min: math.Vec2 = .{},
    max: math.Vec2 = .{},
};

pub const GroupTile = struct {
    id   : usize,
    tile : Tile,
};

pub const Rect = struct {
    x      : f32,
    y      : f32,
    width  : f32,
    height : f32,

    pub fn rectFromAABB(aabb: AABB) Rect {
        return .{
            .x = aabb.min.x,
            .y = aabb.min.y,
            .width = aabb.max.x - aabb.min.x,
            .height = aabb.max.y - aabb.min.y,
        };
    }

    //
    // Assumption that point 2 is further.
    // IE start drag from left to right
    //
    pub fn rectFromPoints(
        p1: math.Vec2,
        p2: math.Vec2,
    ) Rect {
        return .{
            .x = p1.x,
            .y = p1.y,
            .width = p2.x - p1.x,
            .height = p2.y - p1.y,
        };
    }
};
