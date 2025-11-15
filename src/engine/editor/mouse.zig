const std = @import("std");
const builtin = @import("builtin");

const ig = @import("cimgui");
const sokol = @import("sokol");
const app = sokol.app;
const sg = sokol.gfx;
const slog = sokol.log;
const glue = sokol.glue;
const imgui = sokol.imgui;
const sdtx = sokol.debugtext;

const RenderSystem = @import("../render_system.zig");

const Console = @import("console.zig");
const TypeEditors = @import("entity_editor.zig");
const Quad = @import("../render_system/DrawCall.zig");
const Serde = @import("../util/serde.zig");
const State = @import("../engine_state.zig");
const types = @import("../types.zig");
const RenderPassIds = types.RendererTypes.RenderPassIds;
const Scene = types.Scene;
const EntityNs = types.EntityNs;
const Entity = EntityNs.Entity;
const GroupTile = types.GroupTile;
const Tile = types.Tile;
const GlobalConstants = types.GlobalConstants;
const SpriteRenderable = types.RendererTypes.SpriteRenderable;
const AABB = types.AABB;
const util = @import("../util.zig");
const math = util.math;
const mat4 = math.Mat4;
var zoom_factor = @import("../editor.zig").zoom_factor;
var es = @import("../editor.zig").es;
var mouse_middle_down = @import("../editor.zig").mouse_middle_down;
var scene_window_pos = @import("../editor.zig").scene_window_pos;
var mouse_world_space = @import("../editor.zig").mouse_world_space;

//
// All the possible states that the cursor can be.
//
// @todo add brush mode
//
pub const CursorTag = enum {
    inactive,
    editing_tile,
    moving_entity,
    editing_entity,
    moving_scene,
    box_select,
};


//
// Data structure to manage mouse information over
// many different files.
//
pub const MouseState = struct {
    cursor: CursorTag = .inactive,
    mouse_position_ig: ig.ImVec2_t = .{},
    mouse_position_v2: math.Vec2 = .{},
    mouse_position_clamped_v2: math.Vec2 = .{},
    hover_over_scene: bool = false,
    moving_entity: bool = false,
    mouse_clicked_left: bool = false,
    click_and_hold_timer: u32 = 0,
    select_box: AABB = .{},
    select_box_start_grabed: bool = false,

    //
    // Convert float mouse coords to snapped grid coords
    //
    pub fn mouseToGridv2(
        self: *MouseState,
    ) math.Vec2 {
        return .{
            .x = @intFromFloat(self.mouse_position_v2.x / 16.0),
            .y = @intFromFloat(self.mouse_position_v2.y / 16.0),
        };
    }

    //
    // This is the function that handles mouse input for the sokol events
    //
    pub fn mouseEvents(
        self: *MouseState,
        ev: [*c]const app.Event,
    ) !void {
        const eve = ev.*;

        if (eve.type == .MOUSE_SCROLL) {
            if (zoom_factor - 0.02 < 0.1) {
                zoom_factor = 0.1;
            }

            if (eve.scroll_y > 0.1 and zoom_factor < 5) {
                zoom_factor += 0.02;
            }

            if (eve.scroll_y < 0.1 and zoom_factor > 0.1) {
                zoom_factor -= 0.02;
            }

            es.proj = mat4.ortho(
                -app.widthf() / 2 * zoom_factor,
                app.widthf() / 2 * zoom_factor,
                -app.heightf() / 2 * zoom_factor,
                app.heightf() / 2 * zoom_factor,
                -1,
                1,
            );
        }

        if (ev.*.type == .MOUSE_MOVE) {}

        if (ev.*.type == .MOUSE_MOVE) {
            const mouse_rel_x = self.mouse_position_ig.x - scene_window_pos.x;
            const mouse_rel_y = self.mouse_position_ig.y - scene_window_pos.y;

            const texture_x = mouse_rel_x / 700.0;
            const texture_y = mouse_rel_y / 440.0;

            //
            // Adjust for texture coordinates for different
            // graphics apis
            //
            var ndc_x: f32 = 0;
            var ndc_y: f32 = 0;
            if (builtin.os.tag == .linux) {
                ndc_x = 1.0 - texture_x * 2.0;
                ndc_y = texture_y * 2.0 - 1.0;
            } else {
                ndc_x = texture_x * 2.0 - 1.0;
                ndc_y = 1.0 - texture_y * 2.0;
            }

            const view_proj = math.Mat4.mul(es.proj, es.view);
            const inv = math.Mat4.inverse(view_proj);
            mouse_world_space = math.Mat4.mulByVec4(inv, .{ .x = ndc_x, .y = ndc_y, .z = 0, .w = 1 });
        }
        if (ev.*.type == .MOUSE_MOVE and mouse_middle_down) {
            es.mouse_state.cursor = .moving_scene;
            if (builtin.os.tag == .linux) {
                es.view = math.Mat4.mul(es.view, math.Mat4.translate(.{
                    .x = zoom_factor * ev.*.mouse_dx,
                    .y = zoom_factor * ev.*.mouse_dy,
                    .z = 0,
                }));
            } else {
                es.view = math.Mat4.mul(es.view, math.Mat4.translate(.{
                    .x = zoom_factor * ev.*.mouse_dx,
                    .y = zoom_factor * -ev.*.mouse_dy,
                    .z = 0,
                }));
            }
        }

        if (ev.*.type == .MOUSE_DOWN or ev.*.type == .MOUSE_UP) {
            const mouse_pressed = ev.*.type == .MOUSE_DOWN;
            switch (ev.*.mouse_button) {
                .MIDDLE => {
                    mouse_middle_down = mouse_pressed;
                    if (!mouse_pressed) {
                        es.mouse_state.cursor = .inactive;
                    }
                },
                .LEFT => {
                    try self.leftMouseClick(mouse_pressed);
                },
                .RIGHT => {
                    if (es.state.selected_tile_click) {
                        es.state.selected_entity = null;
                        es.state.selected_tile_click = false;
                        es.state.selected_tile = null;
                        es.mouse_state.select_box = .{};
                    }

                    //
                    // Clear the group on click so as to not continue to break stuff.
                    //
                    es.al_tile_group_selected.clearAndFree();
                },

                else => {},
            }
        }
    }

    fn leftMouseClick(self: *MouseState, mouse_pressed: bool) !void {
        es.mouse_state.click_and_hold_timer = 0;
        es.mouse_state.mouse_clicked_left = mouse_pressed;

        if (!mouse_pressed) {
            if (es.mouse_state.cursor == .box_select and es.mouse_state.hover_over_scene) {
                es.mouse_state.select_box.max = es.mouse_state.mouse_position_v2;
                es.mouse_state.select_box_start_grabed = false;

                if (es.state.loaded_scene) |s| {
                    switch (es.selected_layer) {
                        .map_tiles_1 => {
                            try self.leftMouseClickTile1(&s);
                        },
                        .map_entity_1 => {
                            for (0..s.entities.len) |i| {
                                const ent = s.entities.get(i);
                                if (util.aabbIG(
                                    .{ .x = mouse_world_space.x, .y = mouse_world_space.y },
                                    .{ .x = ent.sprite.pos.x, .y = ent.sprite.pos.y },
                                    .{ .x = GlobalConstants.grid_size, .y = GlobalConstants.grid_size },
                                )) {
                                    es.state.selected_entity = i;
                                }
                            }
                        },
                        else => {},
                    }
                }
            }
            es.mouse_state.cursor = .inactive;
        }
        switch (es.mouse_state.cursor) {
            .inactive => {
                if (self.hover_over_scene) {
                    switch (es.selected_layer) {
                        .map_entity_1 => {
                            if (es.state.loaded_scene) |s| {
                                for (0.., s.entities.items(.aabb)) |i, aabb| {
                                    if (util.aabbRec(es.mouse_state.mouse_position_v2, aabb)) {
                                        es.state.selected_entity = i;
                                    }
                                }
                            }
                        },
                        else => {},
                    }
                    if (es.state.selected_tile) |_| {
                        es.state.selected_tile_click = true;
                    }
                }
            },
            .editing_tile => {},
            .moving_entity => {},
            .editing_entity => {},
            .moving_scene => {},
            .box_select => {
                if (self.hover_over_scene) {
                    es.al_tile_group_selected.clearAndFree();
                    if (es.state.loaded_scene) |s| {
                        switch (es.selected_layer) {
                            .map_tiles_1 => {
                                try self.boxselectTile1(&s);
                            },
                            else => {},
                        }
                    }
                }
            },
        }

        // End switch
    }

    fn leftMouseClickTile1(
        self: *MouseState,
        s: *const Scene,
    ) !void {
        _ = self;
        for (0..s.tiles.len) |i| {
            const t = s.tiles.get(i);

            const tile_aabb: AABB = .{
                .min = .{
                    .x = t.sprite_renderable.pos.x,
                    .y = t.sprite_renderable.pos.y,
                },
                .max = .{
                    .x = t.sprite_renderable.pos.x + 16,
                    .y = t.sprite_renderable.pos.y + 16,
                },
            };

            const normalized_select_box: AABB = .{
                .min = .{
                    .x = @min(es.mouse_state.select_box.min.x, es.mouse_state.select_box.max.x),
                    .y = @min(es.mouse_state.select_box.min.y, es.mouse_state.select_box.max.y),
                },
                .max = .{
                    .x = @max(es.mouse_state.select_box.min.x, es.mouse_state.select_box.max.x),
                    .y = @max(es.mouse_state.select_box.min.y, es.mouse_state.select_box.max.y),
                },
            };

            if (util.aabbColl(tile_aabb, normalized_select_box)) {
                try es.al_tile_group_selected.append(.{ .id = i, .tile = t });
            }
        }
    }

    fn boxselectTile1(
        self: *MouseState,
        s: *const Scene,
    ) !void {
        _ = self;
        for (0..s.tiles.len) |i| {
            const t = s.tiles.get(i);

            const tile_aabb: AABB = .{
                .min = .{
                    .x = t.sprite_renderable.pos.x,
                    .y = t.sprite_renderable.pos.y,
                },
                .max = .{
                    .x = t.sprite_renderable.pos.x + 16,
                    .y = t.sprite_renderable.pos.y + 16,
                },
            };

            if (util.aabbColl(tile_aabb, es.mouse_state.select_box)) {
                try es.al_tile_group_selected.append(.{ .id = i, .tile = t });
            }
        }
    }
};
