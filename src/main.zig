/// ===========================================================================
///
/// Author: Cory Smith
///
/// Date: 2025-04-22
///
/// Description:
///
///     Global state. This is where all of the subsystems are managed from.
///
///     Core Systems:
///     - Rendering
///     - Audio
///     - Input
/// ===========================================================================


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

const shd = @import("shaders/basic.glsl.zig");
const util = @import("util.zig");
const math = util.math;
const mat4 = math.Mat4;

const RenderPass = @import("render_system.zig").RenderPass;

const types = @import("types.zig");
const Scene = types.Scene;
const EntityNs = types.EntityNs;
const Entity = EntityNs.Entity;
const RenderPassIds = types.RendererTypes.RenderPassIds;

const State = @import("state.zig");
const Serde = @import("util/serde.zig");
const AudioDriver = @import("audio_system.zig");
const Console = @import("editor/console.zig");
const Input = @import("input.zig");

pub const std_options: std.Options = .{
    .log_level = .info,
    .logFn = customLogFn,
};

pub fn customLogFn(
    comptime level: std.log.Level,
    comptime scope: @Type(.enum_literal),
    comptime format: []const u8,
    args: anytype,
) void {
    if (builtin.os.tag == .macos) {
        const color: []const u8 =  switch (level) {
            .info =>  types.mac_Color_Blue,
            .debug =>  types.mac_Color_Green,
            .err =>  types.mac_Color_Red,
            .warn =>  types.mac_Color_Orange,
        };
        const prefix =  color ++ "[" ++ @tagName(scope) ++ "]\x1b[0m:\t";

        // print the message to stderr, silently ignoring any errors
        std.debug.lockStdErr();
        defer std.debug.unlockStdErr();
        const stderr = std.io.getStdErr().writer();
        nosuspend stderr.print(prefix ++ format ++ "\n", args) catch return;
    } else {
        const prefix = "[" ++ comptime level.asText() ++ "] " ++ "[" ++ @tagName(scope) ++ "]\x1b[0m:\t";

        // Print the message to stderr, silently ignoring any errors
        std.debug.lockStdErr();
        defer std.debug.unlockStdErr();
        const stderr = std.io.getStdErr().writer();
        nosuspend stderr.print(prefix ++ format ++ "\n", args) catch return;
    }
}

var global_state: State = undefined;
var passaction: sg.PassAction = .{};
var proj: math.Mat4 = undefined;
var view: math.Mat4 = undefined;
const zoom_factor = 0.25;
var depth_image: sg.Image = .{};
//var ad: AudioDriver = undefined;

pub fn gameinit() !void {
    std.log.err("This is a sample error", .{});
    std.log.debug("This is a sample debug", .{});
    std.log.warn("This is a sample warn", .{});

    //
    // Custom environment items for uniform color formats across systems.
    //
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
    var scene: Scene = .{};
    Serde.loadSceneFromJson(&scene, "test1", global_state.allocator) catch |e| {
        global_state.errors += 1;
        std.log.warn("{s}", .{@errorName(e)});
    };


    global_state.loaded_scene = scene;
    try global_state.loaded_scene.?.loadScene(&global_state.renderer);


    passaction.colors[0] = .{
        .load_action = .CLEAR,
        .clear_value = .{ .r = 0, .g = 0, .b = 0, .a = 0 },
    };
    proj = mat4.ortho(
        -app.widthf() / 2 * global_state.camera.zoom,
        app.widthf() / 2 * global_state.camera.zoom,
        -app.heightf() / 2 * global_state.camera.zoom,
        app.heightf() / 2 * global_state.camera.zoom,
        -1,
        1,
    );
}

pub fn gameframe() !void {
    global_state.error_timer += 1;
    if (global_state.error_timer >= 180) {
        global_state.error_timer = 0;
        global_state.errors = 0;

    }
    global_state.selected_cell = null;
    if (global_state.loaded_scene) |s| {
        for (0.., s.entities.items(.sprite), s.entities.items(.world_index)) |i, *sprite, *w|{
            w.* = @as(u32, @intFromFloat((sprite.pos.x / 16.0) + ( sprite.pos.y / 16.0 ) * s.width ));
            if (sprite.pos.x == global_state.game_cursor.x and sprite.pos.y == global_state.game_cursor.y) {
                global_state.selected_cell = i;
            }
            try global_state.updateSpriteRenderable(sprite, i);
        }
    }
    if (global_state.loaded_scene) |s| {
        for ( s.entities.items(.sprite), s.entities.items(.animation)) |*sprite, *animation| {
            sprite.sprite_id = EntityNs.updateAnimation(animation);
        }
    }

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

    //_ = ig.igBegin("View", null, ig.ImGuiWindowFlags_None);
    //ig.igText(\\View:
    //              \\%.1f %.1f %.1f %.1f
    //              \\%.1f %.1f %.1f %.1f
    //              \\%.1f %.1f %.1f %.1f
    //              \\%.1f %.1f %.1f %.1f
    //              \\
    //              ,global_state.view.m[0][0]
    //              ,global_state.view.m[0][1]
    //              ,global_state.view.m[0][2]
    //              ,global_state.view.m[0][3]
    //              ,global_state.view.m[1][0]
    //              ,global_state.view.m[1][1]
    //              ,global_state.view.m[1][2]
    //              ,global_state.view.m[1][3]
    //              ,global_state.view.m[2][0]
    //              ,global_state.view.m[2][1]
    //              ,global_state.view.m[2][2]
    //              ,global_state.view.m[2][3]
    //              ,global_state.view.m[3][0]
    //              ,global_state.view.m[3][1]
    //              ,global_state.view.m[3][2]
    //              ,global_state.view.m[3][3]
    //          );

    //ig.igText("Cursor: %.1f %.1f", global_state.game_cursor.x, global_state.game_cursor.y);
    //ig.igEnd();

    if (global_state.console.open) {
        ig.igSetNextWindowPos(.{ .x = 10, .y = 10 }, ig.ImGuiCond_Once);
        ig.igSetNextWindowSize(.{ .x = 400, .y = 100 }, ig.ImGuiCond_Once);
        try global_state.console.console(global_state.allocator, &global_state);
    }

    try global_state.renderer.render_passes.items[@intFromEnum(RenderPassIds.map_ui_1)].appendSpriteToBatch(
        .{
            .pos = .{
                .x = (global_state.game_cursor.x),
                .y = (global_state.game_cursor.y),
                .z = 0,
            },
            .sprite_id = 1,
            .color = .{ .x = 0, .y = 0, .z = 0, .w = 0 },
        },
    );


    //
    // Again custom swap chain to have uniform color formats across systems.
    //
    var swapchain = glue.swapchain();
    swapchain.color_format = .RGBA8;
    global_state.updateBuffers();


    sg.beginPass(.{ .action = passaction, .swapchain = swapchain });
    if (global_state.loaded_scene) |_| {
        global_state.render(util.computeVsParams(proj, global_state.view));
    }


    const canvas_w = app.widthf() * 0.5;
    const canvas_h = app.heightf() * 0.5;

    sdtx.canvas(canvas_w, canvas_h);
    sdtx.color3f(1, 1, 1);
    sdtx.origin(0, 1);
    sdtx.home();
    sdtx.print("{}, {}\n", .{canvas_w, canvas_h});
    sdtx.origin(0, 2);
    sdtx.home();
    sdtx.print("game cursor: {d:.1} {d:.1}\n", .{global_state.game_cursor.x, global_state.game_cursor.y});
    sdtx.print("selected Cell {?}\n", .{global_state.selected_cell});
    sdtx.print("selected Entity {?}", .{global_state.selected_entity});
    if (global_state.loaded_scene) |s| {
        if (global_state.selected_entity) |sprite| {
            const ent = s.entities.get(sprite);
            sdtx.origin(0, 5);
            sdtx.home();

            const ent_info = try std.fmt.allocPrintZ(
                global_state.allocator,
                \\Pos: {d:.1} {d:.1}
                \\Index: {}
                    , .{ent.sprite.pos.x, ent.sprite.pos.y, ent.world_index});

            defer global_state.allocator.free(ent_info);
            sdtx.puts(ent_info);
            //RenderSystem.printFont(0, "Hello", 255, 255, 255);

        }

        sdtx.origin(0, 40);
        sdtx.home();
        for (global_state.logger.combat_logs.items) |log| {
            sdtx.print("{s}\n", .{log});
        }
        sdtx.origin(canvas_w - 10, canvas_h - 20);
        sdtx.home();
        sdtx.color3f(1, 0, 0);
        sdtx.puts("Error Added");
    }
    sdtx.draw();
    imgui.render();
    sg.endPass();
    sg.commit();
    global_state.renderer.render_passes.items[@intFromEnum(RenderPassIds.map_ui_1)].batch.clearRetainingCapacity();
    global_state.renderer.render_passes.items[@intFromEnum(RenderPassIds.map_ui_1)].cur_num_of_sprite = 0;
}
pub fn gamecleanup() !void {}
export fn init() void {
    gameinit() catch unreachable;
}

export fn frame() void {
    gameframe() catch unreachable;
}

export fn cleanup() void {
    //ad.deinit();
    gamecleanup() catch unreachable;
}
export fn event(ev: [*c]const app.Event) void {
    Input.gameevent(ev, &global_state) catch unreachable;
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
