/// ===========================================================================
///
/// Author: Cory Smith
///
/// Date: 2025-04-01
///
/// Description:
/// ===========================================================================
const std = @import("std");
const RenderPass = @import("renderer.zig").RenderPass;
const types = @import("types.zig");
const Scene = types.Scene;
const Entity = types.Entity;
const shd = @import("shaders/basic.glsl.zig");
const math = @import("util/math.zig");
const Renderer = @import("renderer.zig");
const assert = std.debug.assert;
const Console = @import("editor/console.zig");

pub const pass_count: u32 = 4;

/// === GLOBAL STATE ===
const Self = @This();
allocator: std.mem.Allocator,
renderer: Renderer,
passes: []RenderPass,
console: *Console,
loaded_scene: ?Scene,
selected_cell: ?usize,
selected_tile: ?usize,
selected_tile_click: bool = false,
selected_entity: ?usize,
selected_entity_click: bool = false,

pub fn init(self: *Self, allocator: std.mem.Allocator) !void {
    var console: Console = undefined;
    try console.init(allocator);
    self.* = .{
        .allocator = allocator,
        .renderer = undefined,
        .passes = try allocator.alloc(RenderPass, pass_count),
        .console = &console,
        .loaded_scene = null,
        .selected_entity = null,
        .selected_tile = null,
        .selected_cell =   null,
    };

    try self.renderer.init(allocator);
}

pub fn resetRenderPasses(self: *Self) !void {
    for (self.passes) |pass| {
        pass.batch.clearAndFree();
        pass.cur_num_of_sprite = 0;
    }
}

pub fn updateBuffers(self: *Self) void {
    for (self.renderer.render_passes.items) |*pass| {
        if (pass.batch.items.len > 0) {
            pass.updateBuffers();
        }
    }
}


pub fn render(self: *Self, vs_params: shd.VsParams) void {
    assert(self.loaded_scene != null);
    for (self.renderer.render_passes.items) |*pass| {
        pass.render(vs_params);
    }
}

pub fn collision(self: *Self, world_space: math.Vec4) void {
    for (0.., self.renderer.render_passes.items[0].batch.items) |i, b| {
        if (b.pos.x < world_space.x and b.pos.x + 16 > world_space.x) {
            if (b.pos.y < world_space.y and b.pos.y + 16 > world_space.y) {
                self.selected_cell = i;
                self.selected_tile = i;
            }
        }
    }
}
