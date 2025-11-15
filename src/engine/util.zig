/// ===========================================================================
///
/// Author: Cory Smith
///
/// Date: 2025-04-01
///
/// Description:
///     Utility Library
/// ===========================================================================
const std = @import("std");
const builtin = @import("builtin");
const types = @import("types.zig");
pub const math = @import("util/math.zig");
const mat4 = math.Mat4;
const shd = @import("shaders/basic.glsl.zig");
const ig = @import("cimgui");
const AABB = @import("types.zig").AABB;

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
    if (builtin.os.tag == .macos) {
        const color: []const u8 =  switch (level) {
            .info =>  types.mac_Color_Blue,
            .debug =>  types.mac_Color_Green,
            .err =>  types.mac_Color_Red,
            .warn =>  types.mac_Color_Orange,
        };
        const prefix =  color ++ "[" ++ @tagName(scope) ++ "]\x1b[0m:\t";

        // print the message to stderr, silently ignoring any errors
        std.debug.lockStdErr();
        defer std.debug.unlockStdErr();
        const stderr = std.io.getStdErr().writer();
        nosuspend stderr.print(prefix ++ format ++ "\n", args) catch return;
    } else {
        const prefix = "[" ++ comptime level.asText() ++ "] " ++ "[" ++ @tagName(scope) ++ "]\x1b[0m:\t";

        // Print the message to stderr, silently ignoring any errors
        std.debug.lockStdErr();
        defer std.debug.unlockStdErr();
        const stderr = std.io.getStdErr().writer();
        nosuspend stderr.print(prefix ++ format ++ "\n", args) catch return;
    }
}


pub fn computeVsParams(proj: mat4, view: mat4) shd.VsParams {
    const model = mat4.identity();
    //const rxm = mat4.rotate(rx, .{ .x = 1.0, .y = 0.0, .z = 0.0 });
    //const rym = mat4.rotate(ry, .{ .x = 0.0, .y = 1.0, .z = 0.0 });
    //const model = mat4.mul(rxm, rym);
    //const aspect = app.widthf() / app.heightf();
    //const proj = mat4.persp(60, aspect, 0.01, 100);
    return shd.VsParams{ .mvp = mat4.mul(mat4.mul(proj, view), model) };
}

pub fn vec3ToGridSpace(
    v: math.Vec3,
    grid_size: f32,
    width: f32,
) usize {
    const scaled = math.Vec3.scale(v, 1/grid_size);
    return @intFromFloat((scaled.y * width) + scaled.x);
}

pub fn vec2ToGridSpace(
    v: math.Vec2,
    grid_size: f32,
    width: f32,
) usize {
    const scaled = math.Vec2.scale(v, 1/grid_size);
    return @intFromFloat((scaled.y * width) + scaled.x);
}

pub fn aabbColl(a: AABB, b: AABB) bool {
    return (a.min.x <= b.max.x and a.max.x >= b.min.x and a.min.y <= b.max.y and a.max.y >= b.min.y);
}

pub fn aabbRec(point: math.Vec2, aabb: AABB) bool {
    const is_point_inside = point.x >= aabb.min.x and point.x <= aabb.min.x + aabb.max.x and
        point.y >= aabb.min.y and point.y <= aabb.min.y + aabb.max.y;
    return is_point_inside;
}

pub fn aabbIG(point: ig.ImVec2_t, pos: ig.ImVec2_t, size: ig.ImVec2_t) bool {
    const is_point_inside = point.x >= pos.x and point.x <= pos.x + size.x and
        point.y >= pos.y and point.y <= pos.y + size.y;
    return is_point_inside;
}

pub const Interpolations = struct {
    pub fn lerpVec2i(vec1: math.Vec2i, vec2: math.Vec2i) f32 {
        _ = vec1;
        _ = vec2;
    }
};

test "aabb" {
    const a: AABB = .{
        .min = .{
            .x = 0,
            .y = 0,
        },
        .max = .{
            .x = 10,
            .y = 10,
        },
    };
    const b: AABB = .{
        .min = .{
            .x = 5,
            .y = 5,
        },
        .max = .{
            .x = 15,
            .y = 15,
        },
    };
    const c: AABB = .{
        .min = .{
            .x = 12,
            .y = 15,
        },
        .max = .{
            .x = 25,
            .y = 25,
        },
    };

    try std.testing.expect(aabbColl(a, b));
    try std.testing.expect(!aabbColl(a, c));
}
