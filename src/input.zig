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


pub fn gameevent(ev: [*c]const app.Event, state: *State) !void {
    if (ev.*.type == .KEY_UP or ev.*.type == .KEY_DOWN) {
        switch (ev.*.key_code) {
            .A => console.open = true,
            .B => console.open = false,
            .ESCAPE => app.quit(),
            else => {},
        }
    }
}
