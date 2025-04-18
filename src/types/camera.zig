const std = @import("std");

const util = @import("../util.zig");
const math = util.math;
const mat4 = math.Mat4;
const vec3 = math.Vec3;

pub const Camera = struct {
    pos: vec3,
    front: vec3,
    up: vec3,
    target: vec3,
    vel: vec3,
};
