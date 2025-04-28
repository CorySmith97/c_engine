/// ===========================================================================
///
/// Author: Cory Smith
///
/// Date: 2025-04-01
///
/// Description:
///     This is our global state management.
///     Ideally we dont add too much to this file. but it is used for
///     both the game and the editor.
/// ===========================================================================
const std = @import("std");
const assert = std.debug.assert;

const Console = @import("editor/console.zig");
const Renderer = @import("renderer.zig");
const RenderPass = @import("renderer.zig").RenderPass;
const shd = @import("shaders/basic.glsl.zig");
const types = @import("types.zig");
const Scene = types.Scene;
const Entity = types.Entity;
const RenderTypes = types.RendererTypes;
const math = @import("util/math.zig");

pub const pass_count: u32 = 4;


//
// @todo State needs a camera that is seperate from the editor camera
// that can be tracked to follow the player cursor.
//
const Self = @This();
allocator             : std.mem.Allocator,
renderer              : Renderer,
passes                : []RenderPass,
console               : Console,
loaded_scene          : ?Scene,
game_cursor           : math.Vec2,
selected_cell         : ?usize,
selected_tile         : ?usize,
selected_tile_click   : bool = false,
selected_entity       : ?usize,
selected_entity_click : bool = false,

pub fn init(self: *Self, allocator: std.mem.Allocator) !void {
    var console: Console = undefined;
    try console.init(allocator);
    self.* = .{
        .allocator = allocator,
        .renderer = undefined,
        .passes = try allocator.alloc(RenderPass, pass_count),
        .console = console,
        .game_cursor = .{},
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
        if (pass.id != .UI_1) {
            if (pass.enabled) {
                pass.render(vs_params);
            }
        }
    }
    //std.log.info("render ui: {}", .{self.renderer.render_passes.items[@intFromEnum(RenderTypes.RenderPassIds.UI_1)].batch.items.len});
    self.renderer.render_passes.items[@intFromEnum(RenderTypes.RenderPassIds.UI_1)].render(vs_params);
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
