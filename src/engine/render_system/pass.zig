pub const RenderQueue: array(RenderPass) = .{};

pub const RenderPass = union {
    single: Pass,
    instanced2D: Instanced2DPass,
};

const Pass = struct {
    handle: u32,
    bindings: sg.bindings,
    pipeline: sg.pipeline,
};

const Instanced2DPass = struct {
    handle: u32,
    draw_count: u32,
    bindings: sg.bindings,
    pipeline: sg.pipeline,
};

const std = @import("std");
const array = std.ArrayListUnmanaged;
const sokol = @import("sokol");
const sg = sokol.gfx;

const globals = @import("../globals.zig");
const allocator = globals.gpa.allocator();
