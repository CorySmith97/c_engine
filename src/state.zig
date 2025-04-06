const std = @import("std");
const RenderPass = @import("renderer.zig").RenderPass;
const Scene = @import("scene.zig");
const shd = @import("shaders/basic.glsl.zig");
const math = @import("math.zig");
const Entity = @import("entity.zig");

const Self = @This();
allocator: std.mem.Allocator,
passes: []RenderPass,
loaded_scene: ?Scene,
selected_entity: ?usize,

pub fn init(self: *Self) !void {
    const allocator = std.heap.page_allocator;
    self.* = .{
        .allocator = allocator,
        .passes = try allocator.alloc(RenderPass, 3),
        .loaded_scene = null,
        .selected_entity = null,
    };

    try self.passes[0].init(
        "assets/spritesheet-1.png",
        .{ 32, 32 },
        .{ 256, 256 },
        allocator,
    );
    try self.passes[1].init(
        "assets/tiles.png",
        .{ 16, 16 },
        .{ 256, 256 },
        allocator,
    );
    try self.passes[2].init(
        "assets/fg-tiles.png",
        .{ 16, 16 },
        .{ 256, 256 },
        allocator,
    );
}

pub fn updateBuffers(self: *Self, r: f32) void {
    for (self.passes) |*p| {
        p.updateBuffers(r);
    }
}

pub fn render(self: *Self, vs_params: shd.VsParams) void {
    for (self.passes) |*p| {
        p.render(vs_params);
    }
}

pub fn collision(self: *Self, world_space: math.Vec4) void {
    for (0.., self.passes[1].batch.items) |i, b| {
        if (b.pos.x < world_space.x and b.pos.x + 16 > world_space.x) {
            if (b.pos.y < world_space.y and b.pos.y + 16 > world_space.y) {
                self.selected_entity = i;
            }
        }
    }
}
