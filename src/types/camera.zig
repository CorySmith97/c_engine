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

const CameraProjection = enum {
    perspective,
    orthographic,
};

pub const Camera = struct {
    pos  : vec2 = .{},
    zoom : f32 = 0.5,
};

pub const Camera3d = struct {
    position: vec3 = .{.x = 1, .y = 0, .z = 1},
    target: vec3 = .{},
    up: vec3 = .{.x = 0, .y = 1, .z = 0},
    fov: f32 = 90,

    pub fn lookAt(
        c: Camera3d
    ) mat4 {
        var f: vec3 = vec3.sub(c.target , c.position);

        const f_length = vec3.len(f);
        if (f_length > 0 ) {
            f = vec3.scale(f, 1/f_length);
        }

        var s = vec3.cross(f, c.up);

        const s_length = vec3.len(s);
        if (s_length > 0 ) {
            s = vec3.scale(s, 1/s_length);
        }

        const u = vec3.cross(s, f);

        return mat4{
            .m = .{
                .{s.x, u.x, -f.x, 0},
                .{s.y, u.y, -f.y, 0},
                .{s.z, u.z, -f.z, 0},
                .{-(vec3.dot(s, c.position)), -(vec3.dot(u, c.position)), vec3.dot(f, c.position), 1.0},
            },
        };
    }
};
