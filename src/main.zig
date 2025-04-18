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
const RenderPass = @import("renderer.zig").RenderPass;
const types = @import("types.zig");
const Scene = types.Scene;
const Entity = types.Entity;
const Editor = @import("editor.zig");

pub fn gameinit() !void {
    sg.setup(.{
        .environment = glue.environment(),
        .logger = .{ .func = slog.func },
    });

    imgui.setup(.{
        .logger = .{ .func = slog.func },
        .ini_filename = "imgui.ini",
    });
}

pub fn gameframe() !void {
    sg.commit();
}
pub fn gamecleanup() !void {}
pub fn gameevent(ev: [*c]const app.Event) !void {
    _ = imgui.handleEvent(ev.*);
}
export fn init() void {
    gameinit() catch unreachable;
}

export fn frame() void {
    gameframe() catch unreachable;
}

export fn cleanup() void {
    gamecleanup() catch unreachable;
}
export fn event(ev: [*c]const app.Event) void {
    gameevent(ev) catch unreachable;
}

export fn einit() void {
    Editor.init() catch unreachable;
}

export fn eframe() void {
    Editor.frame() catch unreachable;
}

export fn ecleanup() void {
    Editor.cleanup() catch unreachable;
}
export fn eevent(ev: [*c]const app.Event) void {
    Editor.event(ev) catch unreachable;
}

pub fn main() !void {
    const allocator = std.heap.page_allocator;
    var args_iter = try std.process.argsWithAllocator(allocator);
    var desc: app.Desc = undefined;

    // We allow for different compilation flags to denote
    // if we are in editor mode vs game mode. The editor
    // mode renders the game seperately to give us a nicer
    // application to edit files and such.
    while (args_iter.next()) |arg| {
        if (std.mem.eql(u8, arg, "editor")) {
            desc = .{
                .init_cb = einit,
                .frame_cb = eframe,
                .event_cb = eevent,
                .cleanup_cb = ecleanup,
                .width = 1200,
                .height = 800,
                .window_title = "HELLO",
            };
        } else {
            desc = .{
                .init_cb = init,
                .frame_cb = frame,
                .event_cb = event,
                .cleanup_cb = cleanup,
                .width = 1200,
                .height = 800,
                .window_title = "HELLO",
            };
        }
    }

    app.run(desc);
}
