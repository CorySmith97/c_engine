/// ===========================================================================
///
/// Author: Cory Smith
///
/// Date: 2025-04-27
///
/// Description:
/// ===========================================================================

const std = @import("std");
const log = std.log.scoped(.input);

const ig = @import("cimgui");
const sokol = @import("sokol");
const app = sokol.app;
const sg = sokol.gfx;
const slog = sokol.log;
const glue = sokol.glue;
const imgui = sokol.imgui;

const shd = @import("shaders/basic.glsl.zig");
const util = @import("util.zig");
const math = util.math;
const mat4 = math.Mat4;

const State = @import("engine_state.zig");
const RenderPassIds = @import("types.zig").RendererTypes.RenderPassIds;

const types = @import("types.zig");
const Scene = types.Scene;
const RendererTypes = types.RendererTypes;
const SpriteRenderable = RendererTypes.SpriteRenderable;
const EntityNs = types.EntityNs;

const dijkstra = @import("algorithms/dijkstras.zig");
const PathField = dijkstra.PathField;

const HotReload = @import("hot_reload.zig");

//
// @todo:cs I need to make simple combat loop.
// Place info about combat in logs for the meantime.
// Goal: 05/05/2025 eod.
//

const dirs = [_]math.Vec3{
    .{ .x = 0, .y = -16, .z = 0},
    .{ .x = 0, .y = 16, .z = 0},
    .{ .x = 16, .y = 0, .z = 0},
    .{ .x = -16, .y = 0, .z = 0},
};

pub fn gameevent(ev: [*c]const app.Event, state: *State) !void {
    _ = imgui.handleEvent(ev.*);
    state.view = math.Mat4.translate(.{
        .x = -state.camera.pos.x,
        .y = -state.camera.pos.y,
        .z = 0,
    });


    //
    // how much your cursor moves per press
    //
    const step      = 16;
    const w2        = app.widthf()  / 2 * state.camera.zoom;
    const h2        = app.heightf() / 2 * state.camera.zoom;
    const marginX   = w2 * 2 * state.camera.zoom;
    const marginY   = h2 * 2 * state.camera.zoom;

    if (ev.*.type == .KEY_DOWN) {
        const key_pressed = ev.*.type == .KEY_DOWN;
        //
        // Universal keybinding
        //
        switch (ev.*.key_code) {
            .F1     => state.console.open = key_pressed,
            .F2     => state.console.open = false,
            .F3     => {
                try HotReload.unloadDll();
                try HotReload.recompileDll();
                try HotReload.loadDll();
            },
            else => {},
        }
        var s: *Scene = &(state.loaded_scene orelse return);
        switch (ev.*.key_code) {
            .LEFT  => {
                if (state.game_cursor_mode == .selecting_target) {
                    for (state.potential_targets.items) |t| {
                        for (s.entities.items(.sprite)) |sprite| {
                            const grid_space = util.vec3ToGridSpace(sprite.pos, 16, s.width);
                            if (grid_space == t) {
                                state.game_cursor.x -= 16;
                            }
                        }
                    }
                    return;
                }
                if (state.game_cursor_mode == .selecting_action) return;
                if (state.game_cursor.x - step < state.camera.pos.x - marginX) {
                    state.camera.pos.x -= step;
                } else {
                    state.game_cursor.x -= 16;
                }
            },
            .RIGHT => {
                if (state.game_cursor_mode == .selecting_action) return;
                if (state.game_cursor.x + step > state.camera.pos.x + marginX) {
                    state.camera.pos.x += step;
                } else {
                    state.game_cursor.x += 16;
                }
            },
            .UP    => {
                if (state.game_cursor_mode == .selecting_action) {
                    state.selected_action = @enumFromInt(
                        if ((@intFromEnum(state.selected_action)) == 0) 3 else
                            @intFromEnum(state.selected_action) - 1
                    );
                    return;
                }

                if (state.game_cursor.y + step > state.camera.pos.y + marginY) {
                    state.camera.pos.y += step;
                } else {
                    state.game_cursor.y += 16;
                }
            },
            .DOWN  => {
                if (state.game_cursor_mode == .selecting_target) {
                    const gc = util.vec2ToGridSpace(state.game_cursor, 16, s.width);
                    for (0.., s.entities.items(.sprite)) |i, sprite| {
                        const target = util.vec3ToGridSpace(sprite.pos, 16, s.width);
                        if (gc == target) {
                            state.selected_target = i;
                        }
                    }
                }
                if (state.game_cursor_mode == .selecting_action) {
                    state.selected_action = @enumFromInt(
                        if ((@intFromEnum(state.selected_action)) == 3) 0 else
                            @intFromEnum(state.selected_action) + 1
                    );
                    return;
                }
                if (state.game_cursor.y - step < state.camera.pos.y - marginY) {
                    state.camera.pos.y -= step;
                } else {

                    state.game_cursor.y -= 16;
                }
            },
            .S => {
                switch (state.game_cursor_mode) {
                    .selecting_target => {
                        state.renderer.resetPass(.map_tiles_2);
                        state.game_cursor_mode = .selecting_action;
                    },
                    .selected_entity => {
                        state.game_cursor_mode = .default;
                    },
                    .selecting_action => {
                        state.game_cursor_mode = .selected_entity;
                    },
                    else => {},
                }
            },
            .A => {
                switch (state.game_cursor_mode) {
                    .default => {
                        try selectEntity(s, state);
                    },
                    .selected_entity => {
                        try placeEntity(s, state);
                    },
                    .selecting_target => {
                        if (state.selected_target) |target| {
                            const selected = state.selected_entity orelse return;
                            var ent1 = s.entities.get(selected);
                            const ent2 = s.entities.get(target);

                            const res = try EntityNs.combat(ent1.stats, ent1.weapon, ent2.stats, ent2.weapon);
                            const results = try std.fmt.allocPrint(state.allocator, "Ent1 did {} damage to Ent2", .{res});
                            defer state.allocator.free(results);


                            try state.logger.appendToCombatLog(results);
                            ent1.flags.turn_over = true;

                            try state.updateSpriteRenderable(&ent1.sprite, selected);
                            s.entities.set(selected, ent1);

                            state.game_cursor_mode = .default;

                            state.selected_entity = null;
                            state.selected_target = null;


                        }
                    },
                    .selecting_action => {
                        try selectingAction(s, state);
                    },
                    else => {},
                }

            },


            .B => {
            },
            .ESCAPE => app.quit(),
            else => {},
        }
    }

}

pub fn selectingAction(
    s: *Scene,
    state: *State,
) !void {
    switch (state.selected_action) {
        .Attack => {
            const ent = s.entities.get(state.selected_entity.?);
            for (dirs) |d| {

                const sr: SpriteRenderable = .{
                    .pos = math.Vec3.add(ent.sprite.pos, d),
                    .sprite_id = 100,
                    .color     = .{ .x = 1, .y = 0, .z = 0, .w = 0.4 },
                };
                if (sr.pos.x < 0 or sr.pos.y < 0) {
                    continue;
                }
                try state
                    .renderer
                    .addSpriteToBatch(.map_tiles_2, sr);

                const target = util.vec3ToGridSpace(sr.pos, 16, s.width);
                log.info("{any}", .{target});
                try state.potential_targets.append(target);
            }
            state.game_cursor_mode = .selecting_target;
        },
        .Items => {
            state.displayed_menu =  .item;
        },
        .Wait => {
            state.renderer.resetPass(.map_tiles_2);
            state.selected_entity = null;
            state.game_cursor_mode = .default;
            state.selected_action = .Attack;
        },
        else => {},
    }
}

pub fn placeEntity(
    s: *Scene,
    state: *State,
) !void {
    //
    // if we dont have a selected entity simply break out early;
    //
    const e = state.selected_entity orelse return;

    log.info("Placing entity", .{});
    var ent = s.entities.get(e);
    for (0.., s.entities.items(.sprite))|i, sprite| {
        if (i == e) {
            continue;
        }

        if (sprite.pos.x == state.game_cursor.x and sprite.pos.y == state.game_cursor.y) {
            return;
        }
    }

    ent.sprite.pos = .{.x = state.game_cursor.x, .y = state.game_cursor.y } ;

    const gc_to_index: usize = @intFromFloat((state.game_cursor.y / 16.0 * s.width) + state.game_cursor.x / 16.0);
    if (state.selected_entity_path.shortest[gc_to_index] <= ent.stats.move_speed) {
        try state.logger.appendToCombatLog("Combat has happened or something");
        s.entities.set(e, ent);
        //state.selected_entity = null;
        state.allocator.free(state.selected_entity_path.prev);
        state.allocator.free(state.selected_entity_path.shortest);
        state.selected_entity_path = undefined;
        state.renderer.resetPass(.map_tiles_2);
    }
    state.game_cursor_mode = .selecting_action;
    state.displayed_menu = .action;
}

pub fn selectEntity(
    s: *Scene,
    state: *State,
) !void {
    for (0.., s.entities.items(.sprite), s.entities.items(.world_index), s.entities.items(.stats))
        |i, sprite, idx, stats| {

        if (sprite.pos.x == state.game_cursor.x and sprite.pos.y == state.game_cursor.y) {
            state.selected_entity = i;
            const pf = try dijkstra.findAllPaths(idx, s.*, 5, s.tiles);

            const tileSize = 16.0;
            const maxCost = stats.move_speed;

            for (pf.shortest, 0..) |dist, f| {
                const v: f32 = @floatFromInt(f);

                if (dist <= maxCost) {
                    const ix = @mod(v, s.width);
                    const iy = @floor(v / s.width);
                    const x  = @as(f32, ix) * tileSize;
                    const y  = @as(f32, iy) * tileSize;
                    const sr: SpriteRenderable = .{
                        .pos       = .{ .x = x, .y = y, .z = 0 },
                        .sprite_id = 100,
                        .color     = .{ .x = 0, .y = 1, .z = 0, .w = 0.4 },
                    };
                    try state
                        .renderer
                        .addSpriteToBatch(.map_tiles_2, sr);
                }
            }
            state.selected_entity_path = pf;
            state.game_cursor_mode = .selected_entity;
        }
    }
}
