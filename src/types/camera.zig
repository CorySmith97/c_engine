/// ===========================================================================
///
/// Author: Cory Smith
///
/// Date: 2025-04-26
///
/// Description:
/// ===========================================================================


const std = @import("std");

const util = @import("../util.zig");
const math = util.math;
const mat4 = math.Mat4;
const vec3 = math.Vec3;
const vec2 = math.Vec2;

pub const Camera = struct {
    pos  : vec2 = .{},
    zoom : f32 = 0.26,
};
