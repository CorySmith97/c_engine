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

// THIS IS A CUSTOM LOG INTERFACE
// It makes logs look better for the default logging interface
// found in std.log
pub const std_options: std.Options = .{
    .log_level = .info,
    .logFn = customLogFn,
};

pub fn customLogFn(
    comptime level: std.log.Level,
    comptime scope: @Type(.enum_literal),
    comptime format: []const u8,
    args: anytype,
) void {
    const prefix = "[" ++ comptime level.asText() ++ "] " ++ "(" ++ @tagName(scope) ++ "):\t";

    // Print the message to stderr, silently ignoring any errors
    std.debug.lockStdErr();
    defer std.debug.unlockStdErr();
    const stderr = std.io.getStdErr().writer();
    nosuspend stderr.print(prefix ++ format ++ "\n", args) catch return;
}



pub const AABB = struct {
    min: math.Vec2 = .{},
    max: math.Vec2 = .{},
};

pub const GroupTile = struct {
    id: usize,
    tile: Tile,
};
