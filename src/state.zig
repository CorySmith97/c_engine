const std = @import("std");
const RenderPass = @import("renderer.zig").RenderPass;
const Scene = @import("scene.zig");
const shd = @import("shaders/basic.glsl.zig");
const math = @import("math.zig");
const Entity = @import("entity.zig");

pub const RenderPassIds = struct {
    var pass_count: u32 = 4;
    var TILES_1: usize = 0;
    var TILES_2: usize = 1;
    var ENTITES_1: usize = 2;
    var UI_1: usize = 3;
};

/// === GLOBAL STATE ===
const Self = @This();
allocator: std.mem.Allocator,
passes: []RenderPass,
loaded_scene: ?Scene,
selected_entity: ?usize,
selected_entity_click: bool = false,

pub fn init(self: *Self) !void {
    const allocator = std.heap.page_allocator;
    self.* = .{
        .allocator = allocator,
        .passes = try allocator.alloc(RenderPass, RenderPassIds.pass_count),
        .loaded_scene = null,
        .selected_entity = null,
    };

    try self.passes[RenderPassIds.ENTITES_1].init(
        "assets/entity_1.png",
        .{ 32, 32 },
        .{ 256, 256 },
        allocator,
    );
    try self.passes[RenderPassIds.TILES_1].init(
        "assets/tiles_1.png",
        .{ 16, 16 },
        .{ 256, 256 },
        allocator,
    );
    try self.passes[RenderPassIds.TILES_2].init(
        "assets/tiles_2.png",
        .{ 16, 16 },
        .{ 256, 256 },
        allocator,
    );
    try self.passes[RenderPassIds.UI_1].init(
        "assets/ui_1.png",
        .{ 16, 16 },
        .{ 256, 256 },
        allocator,
    );
}

pub fn resetRenderPasses(self: *Self) !void {
    for (self.passes) |pass| {
        pass.batch.clearAndFree();
        pass.cur_num_of_sprite = 0;
    }
}

pub fn updateBuffers(self: *Self) void {
    for (self.passes) |*p| {
        if (p.batch.items.len > 0) {
            p.updateBuffers();
        }
    }
}

pub fn render(self: *Self, vs_params: shd.VsParams) void {
    for (self.passes) |*p| {
        p.render(vs_params);
    }
}

pub fn collision(self: *Self, world_space: math.Vec4) void {
    for (0.., self.passes[0].batch.items) |i, b| {
        if (b.pos.x < world_space.x and b.pos.x + 16 > world_space.x) {
            if (b.pos.y < world_space.y and b.pos.y + 16 > world_space.y) {
                self.selected_entity = i;
            }
        }
    }
}
