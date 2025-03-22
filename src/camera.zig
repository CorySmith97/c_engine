const std = @import("std");

const mat4 = @import("math.zig").Mat4;
const vec3 = @import("math.zig").Vec3;

pub const Camera = struct {
    pos: vec3,
    front: vec3,
    up: vec3,
    target: vec3,
    vel: vec3,
};
