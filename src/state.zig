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

const sokol = @import("sokol");
const sdtx = sokol.debugtext;

const Console = @import("editor/console.zig");
const RenderSystem = @import("render_system.zig");
const RenderPass = RenderSystem.RenderPass;

const AudioSystem = @import("audio_system.zig");

const LogSystem = @import("log_system.zig").LogSystem;

const shd = @import("shaders/basic.glsl.zig");
const types = @import("types.zig");
const Menu = types.Menus;
const Scene = types.Scene;
const Entity = types.Entity;
const RenderTypes = types.RendererTypes;
const SpriteRenderable = RenderTypes.SpriteRenderable;
const math = @import("util/math.zig");
const Camera = types.Camera;

const Algorithms = @import("algorithms.zig");
const PathField = Algorithms.PathField;

//
// Location in grid space, and the fields of available move locations
//
const Paths: std.AutoHashMap(u32, PathField) = undefined;

pub const pass_count: u32 = 4;

pub const GameState = enum {
    main_menu,
    pause_menu,
    world_map,
    chapter_map,
};

pub const GameCursorTag = enum {
    default,
    selected_entity,
    selecting_action,
    selecting_target,
    hovering_entity,
    hovering_tile,
};

pub const TurnTag = enum {
    player,
    enemy,
    neutral,
};

//
// @todo Audio subsystem needs to be in here
//
const Self = @This();
allocator: std.mem.Allocator,
renderer: RenderSystem,
passes: []RenderPass,
console: Console,
loaded_scene: ?Scene,
game_cursor: math.Vec2,
game_cursor_mode: GameCursorTag,
selected_cell: ?usize,
selected_tile: ?usize,
selected_tile_click: bool = false,
selected_entity: ?usize,
selected_entity_click: bool = false,
selected_entity_path: PathField,
potential_targets: std.ArrayList(usize),
selected_target: ?usize = null,
displayed_menu: Menu.DisplayedMenu = .none,
view: math.Mat4,
selected_action: Menu.ActionMenu = .Attack,
//proj                  : math.Mat4,
camera: Camera = .{},
logger: LogSystem,
errors: u32 = 0,
error_timer: u32 = 0,

pub fn init(self: *Self, allocator: std.mem.Allocator) !void {
    var console: Console = undefined;
    try console.init(allocator);

    var logger: LogSystem = undefined;
    try logger.init(allocator);

    try logger.appendToCombatLog("HELLO, FROM THE COMABT LOG");

    const view = math.Mat4.translate(.{ .x = -self.camera.pos.x, .y = -self.camera.pos.y, .z = 0 });
    self.* = .{
        .allocator = allocator,
        .renderer = undefined,
        .passes = try allocator.alloc(RenderPass, pass_count),
        .console = console,
        .game_cursor = .{},
        .game_cursor_mode = .default,
        .loaded_scene = null,
        // @cleanup I dont think these should be in here? These are more editor specific. outside of the cell
        .selected_entity = null,
        .selected_tile = null,
        .selected_cell = null,
        .view = view,
        .logger = logger,
        .selected_entity_path = undefined,
        .potential_targets = std.ArrayList(usize).init(allocator),
    };

    try self.renderer.init(allocator);
}

//
// When a pass is reloaded, we have to clear its batch, otherwise we
// have overdraw.
//
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

//
// @todo move this to the renderer?
//
pub fn render(self: *Self, vs_params: shd.VsParams) void {
    assert(self.loaded_scene != null);
    for (self.renderer.render_passes.items) |*pass| {
        if (pass.id != .map_ui_1) {
            if (pass.enabled) {
                pass.render(vs_params);
            }
        }
    }
    //std.log.info("render ui: {}", .{self.renderer.render_passes.items[@intFromEnum(RenderTypes.RenderPassIds.UI_1)].batch.items.len});
    self.renderer.render_passes.items[@intFromEnum(RenderTypes.RenderPassIds.map_ui_1)].render(vs_params);
}

//
// This collision function is for mouse to world. Its used in the editor
//
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

//
// @copypasta Editor state has this duplicated
//
pub fn updateSpriteRenderable(
    self: *Self,
    sprite_ren: *const SpriteRenderable,
    s: usize,
) !void {
    if (self.renderer.render_passes.items[@intFromEnum(RenderTypes.RenderPassIds.map_entity_1)].batch.items.len > s) {
        try self.renderer.render_passes.items[@intFromEnum(RenderTypes.RenderPassIds.map_entity_1)].updateSpriteRenderables(s, sprite_ren.*);
    }
}

pub fn drawTextLayer(self: *Self) !void {
    _ = self;
}

pub fn drawMenu(
    self: *Self,
) !void {
    sdtx.font(2);
    sdtx.origin(60, 2);
    sdtx.home();
    switch (self.displayed_menu) {
        .action => {
            inline for (std.meta.fields(Menu.ActionMenu)) |i| {
                if (i.value == @intFromEnum(self.selected_action)) {
                    sdtx.color3f(1, 1, 1);
                } else {
                    sdtx.color3f(0, 1, 1);
                }
                sdtx.print("{s}\n", .{i.name});
            }
        },
        .item => {
            sdtx.color3f(1, 1, 1);
            sdtx.print("Here are sample items:\n", .{});
            sdtx.print("Cheese\n", .{});
            sdtx.print("Heal Pot\n", .{});
            sdtx.print("Tomahawk\n", .{});
        },
        else => {},
    }
}
