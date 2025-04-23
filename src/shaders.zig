pub const Basic = @import("shaders/basic.glsl.zig");

pub const Tags = enum { basic };

pub const Shaders = union(Tags) {
    basic: Basic,
};
