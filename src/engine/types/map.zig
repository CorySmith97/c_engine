const std = @import("std");
const sokol = @import("sokol");
const sg = sokol.gfx;
const util = @import("../util.zig");
const math = util.math;

pub const Polygon = struct {
    points: []math.Vec2,
};

const Map = @This();
highlight_mode: bool,
background: sg.Image,
