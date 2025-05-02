/// ===========================================================================
///
/// Author: Cory Smith
///
/// Date: 2025-04-27
///
/// Description:
/// ===========================================================================

const std = @import("std");
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
const State = @import("state.zig");
const log = std.log.scoped(.input);
const RenderPassIds = @import("types.zig").RendererTypes.RenderPassIds;
const types = @import("types.zig");
const RendererTypes = types.RendererTypes;
const SpriteRenderable = RendererTypes.SpriteRenderable;

const dikstra = @import("algorithms/dijkstras.zig");


pub fn gameevent(ev: [*c]const app.Event, state: *State) !void {
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
        if (state.loaded_scene) |*s| {
            switch (ev.*.key_code) {
                .L     => state.console.open = key_pressed,
                .LEFT  => {
                    if (state.game_cursor.x - step < state.camera.pos.x - marginX) {
                        state.camera.pos.x -= step;
                    } else {
                        state.game_cursor.x -= 16;
                    }
                },
                .RIGHT => {
                    if (state.game_cursor.x + step > state.camera.pos.x + marginX) {
                        state.camera.pos.x += step;
                    } else {
                        state.game_cursor.x += 16;
                    }
                },
                .UP    => {
                    if (state.game_cursor.y + step > state.camera.pos.y + marginY) {
                        state.camera.pos.y += step;
                    } else {
                        state.game_cursor.y += 16;
                    }
                },
                .DOWN  => {
                    if (state.game_cursor.y - step < state.camera.pos.y - marginY) {
                        state.camera.pos.y -= step;
                    } else {

                        state.game_cursor.y -= 16;
                    }
                },
                .A => {
                    for (0.., s.entities.items(.sprite), s.entities.items(.world_index), s.entities.items(.stats))
                        |i, sprite, idx, stats|
                        {
                            if (sprite.pos.x == state.game_cursor.x
                                    and sprite.pos.y == state.game_cursor.y)
                                {
                                    state.selected_entity = i;
                                    const pf = try dikstra.findAllPaths(idx, s.*, 5, s.tiles);

                                    const tileSize = 16.0;
                                    const maxCost = @as(f32, @floatFromInt(stats.move_speed));

                                    for (pf.shortest, 0..) |dist, f| {
                                        const v: f32 = @floatFromInt(f);

                                        if (dist <= maxCost) {
                                            const ix = @mod(v, s.width);
                                            const iy = @floor(v / s.width);
                                            const x  = @as(f32, ix) * tileSize;
                                            const y  = @as(f32, iy) * tileSize;
                                            const sr: SpriteRenderable = .{
                                                .pos       = .{ .x = x, .y = y, .z = 0 },
                                                .sprite_id = 0,
                                                .color     = .{ .x = 0, .y = 0, .z = 0, .w = 1 },
                                            };
                                            try state
                                                .renderer
                                                .render_passes
                                                .items[@intFromEnum(RendererTypes.RenderPassIds.TILES_2)]
                                                .appendSpriteToBatch(sr);
                                        }
                                    }

                                    state.selected_entity_path = pf;
                            }
                    }
                },


                .B => {
                    if (state.selected_entity) |e| {
                        log.info("Placing entity", .{});
                        var ent = s.entities.get(e);
                        var collide: bool = false;
                        for (0.., s.entities.items(.sprite))|i, sprite| {
                            if (i == e) {
                                continue;
                            }

                            if (sprite.pos.x == ent.sprite.pos.x and sprite.pos.y == ent.sprite.pos.y) {
                                std.log.info("We hitting?", .{});
                                collide = true;
                            }
                        }
                        if (!collide) {
                            ent.sprite.pos = .{.x = state.game_cursor.x, .y = state.game_cursor.y } ;
                        } else {
                            ent.sprite.pos = .{.x = state.game_cursor.x - 16, .y = state.game_cursor.y } ;
                        }

                        s.entities.set(e, ent);
                        state.selected_entity = null;
                        state.allocator.free(state.selected_entity_path.prev);
                        state.allocator.free(state.selected_entity_path.shortest);
                        state.selected_entity_path = undefined;
                        state.renderer.render_passes.items[@intFromEnum(RendererTypes.RenderPassIds.TILES_2)].batch.clearRetainingCapacity();
                        state.renderer.render_passes.items[@intFromEnum(RendererTypes.RenderPassIds.TILES_2)].cur_num_of_sprite = 0;
                    }
                },
                .ESCAPE => app.quit(),
                else => {},
            }
        }
    }


}
