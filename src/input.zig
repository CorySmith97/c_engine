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
                if (state.loaded_scene) |s| {
                    for (0.., s.entities.items(.sprite))|i, sprite| {
                        if (sprite.pos.x == state.game_cursor.x and sprite.pos.y == state.game_cursor.y) {
                            log.info("Grabbing entity", .{});
                            state.selected_entity = i;
                        }
                    }
                }
            },
            .B => {
              if (state.loaded_scene) |*s| {
                  if (state.selected_entity) |e| {
                      log.info("PLacing entity", .{});
                      var ent = s.entities.get(e);
                      ent.sprite.pos = .{.x = state.game_cursor.x, .y = state.game_cursor.y } ;

                      s.entities.set(e, ent);
                  }
                }
            },
            .ESCAPE => app.quit(),
            else => {},
        }
    }


}
