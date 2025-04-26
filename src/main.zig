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
const State = @import("state.zig");
const Serde = @import("serde.zig");
const AudioDriver = @import("audio.zig");
const Console = @import("editor/console.zig");

pub const std_options: std.Options = .{
    // Set the log level to info
    .log_level = .info,

    // Define logFn to override the std implementation
    .logFn = customLogFn,
};

pub fn customLogFn(
    comptime level: std.log.Level,
    comptime scope: @Type(.enum_literal),
    comptime format: []const u8,
    args: anytype,
) void {
    const prefix = "[" ++ comptime level.asText() ++ "] " ++ "(" ++ @tagName(scope) ++ "):\t";

    // Print the message to stderr, silently ignoring any errors
    std.debug.lockStdErr();
    defer std.debug.unlockStdErr();
    const stderr = std.io.getStdErr().writer();
    nosuspend stderr.print(prefix ++ format ++ "\n", args) catch return;
}

var global_state: State = undefined;
var passaction: sg.PassAction = .{};
var proj: math.Mat4 = undefined;
var view: math.Mat4 = undefined;
const zoom_factor = 0.25;
var depth_image: sg.Image = .{};
var ad: AudioDriver = undefined;
var console: Console = undefined;

pub fn gameinit() !void {
    var env = glue.environment();
    env.defaults.color_format = .RGBA8;
    env.defaults.depth_format = .DEPTH_STENCIL;
    sg.setup(.{
        .environment = env,
        .logger = .{ .func = slog.func },
    });

    std.log.info("{s}", .{@tagName(sg.queryDesc().environment.defaults.color_format)});

    imgui.setup(.{
        .logger = .{ .func = slog.func },
    });

    //try ad.init();

    try global_state.init(std.heap.page_allocator);
    try console.init(global_state.allocator);
    var scene: Scene = .{};
    try Serde.loadSceneFromBinary(&scene, "t2.txt", global_state.allocator);
    global_state.loaded_scene = scene;
    try global_state.loaded_scene.?.loadScene(&global_state.renderer);
    std.log.info("{}", .{global_state.loaded_scene.?.tiles.len});
    passaction.colors[0] = .{
        .load_action = .CLEAR,
        .clear_value = .{ .r = 0, .g = 0, .b = 0, .a = 0 },
    };
    proj = mat4.ortho(
        -app.widthf() / 2 * zoom_factor + 50,
        app.widthf() / 2 * zoom_factor + 50,
        -app.heightf() / 2 * zoom_factor - 50,
        app.heightf() / 2 * zoom_factor - 50,
        -1,
        1,
    );
    view = math.Mat4.identity();
}

pub fn gameframe() !void {
    imgui.newFrame(.{
        .width = app.width(),
        .height = app.height(),
        .delta_time = app.frameDuration(),
        .dpi_scale = app.dpiScale(),
    });
    const viewport = ig.igGetMainViewport();
    viewport.*.Flags |= ig.ImGuiViewportFlags_NoRendererClear;

    ig.igSetNextWindowPos(viewport.*.WorkPos, ig.ImGuiCond_Always);
    ig.igSetNextWindowSize(viewport.*.WorkSize, ig.ImGuiCond_Always);
    ig.igSetNextWindowViewport(viewport.*.ID);

    if (console.open) {
        ig.igSetNextWindowPos(.{ .x = 10, .y = 10 }, ig.ImGuiCond_Once);
        ig.igSetNextWindowSize(.{ .x = 400, .y = 100 }, ig.ImGuiCond_Once);
        try console.console(global_state.allocator, &global_state);
    }

    var swapchain = glue.swapchain();
    swapchain.color_format = .RGBA8;
    global_state.updateBuffers();
    sg.beginPass(.{ .action = passaction, .swapchain = swapchain });
    global_state.render(util.computeVsParams(proj, view));
    imgui.render();
    sg.endPass();
    sg.commit();
}
pub fn gamecleanup() !void {}
pub fn gameevent(ev: [*c]const app.Event) !void {
    if (ev.*.type == .KEY_UP or ev.*.type == .KEY_DOWN) {
        switch (ev.*.key_code) {
            .A => console.open = true,
            .B => console.open = false,
            .ESCAPE => app.quit(),
            else => {},
        }
    }
}
export fn init() void {
    gameinit() catch unreachable;
}

export fn frame() void {
    gameframe() catch unreachable;
}

export fn cleanup() void {
    ad.deinit();
    gamecleanup() catch unreachable;
}
export fn event(ev: [*c]const app.Event) void {
    gameevent(ev) catch unreachable;
}

pub fn main() !void {
    var desc: app.Desc = undefined;

    desc = .{
        .init_cb = init,
        .frame_cb = frame,
        .event_cb = event,
        .cleanup_cb = cleanup,
        .width = 1200,
        .height = 800,
        .window_title = "HELLO",
    };

    app.run(desc);
}
