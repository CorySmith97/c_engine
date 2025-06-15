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
const Camera3d = types.Camera3d;
const EntityNs = types.EntityNs;
const Entity = EntityNs.Entity;
const Model = types.RendererTypes.Model;
const RenderPassIds = types.RendererTypes.RenderPassIds;

const State = @import("state.zig");
const Serde = @import("util/serde.zig");
const AudioDriver = @import("audio_system.zig");
const Console = @import("editor/console.zig");
const Input = @import("input.zig");

const c = @cImport({
    @cInclude("gamepad/Gamepad.h");
    @cInclude("cgltf.h");
});

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
            .info =>  types.mac_Color_Blue,main
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

export fn on_attach(
    device: [*c]c.Gamepad_device,
    context: ?*anyopaque
) callconv(.C) void {
    _ = device;
    _ = context;
    std.log.info("Gamepad attached: ", .{  });
}

export fn on_button_down(
    device: [*c]c.Gamepad_device,
    buttonID: u32,
    timestamp: f64,
    context: ?*anyopaque
) callconv(.C) void {
    _ = device;
    _ = timestamp;
    const lils: *State = @ptrCast(@alignCast(context));
    std.log.info("lil state any{any}", .{lils.game_cursor});
    const s: *Scene = &(global_state.loaded_scene orelse return);
    // x playstation

    if (buttonID == 1) {
        switch (global_state.game_cursor_mode) {
            .default => {
                Input.selectEntity(s, &global_state) catch @panic("");
            },
            .selected_entity => {
                Input.placeEntity(s, &global_state) catch @panic("");
            },
            .selecting_target => {
                if (global_state.selected_target) |target| {
                    const selected = global_state.selected_entity orelse return;
                    var ent1 = s.entities.get(selected);
                    const ent2 = s.entities.get(target);

                    const res = EntityNs.combat(ent1.stats, ent1.weapon, ent2.stats, ent2.weapon) catch @panic("");
                    const results = std.fmt.allocPrint(global_state.allocator, "Ent1 did {} damage to Ent2", .{res}) catch @panic("");
                    defer global_state.allocator.free(results);


                    global_state.logger.appendToCombatLog(results) catch @panic("");
                    ent1.flags.turn_over = true;

                    global_state.updateSpriteRenderable(&ent1.sprite, selected) catch @panic("");
                    s.entities.set(selected, ent1);

                    global_state.game_cursor_mode = .default;

                    global_state.selected_entity = null;
                    global_state.selected_target = null;


                }
            },
            .selecting_action => {
                Input.selectingAction(s, &global_state) catch @panic("");
            },
            else => {},
        }

    }
    std.log.info("Button {d} down on ID ", .{ buttonID  });
}

export fn on_button_up(
    device: [*c]c.Gamepad_device,
    buttonID: u32,
    timestamp: f64,
    context: ?*anyopaque
) callconv(.C) void {
    _ = device;
    _ = timestamp;
    _ = context;
    std.log.info("Button {d} up", .{ buttonID });
}

export fn on_axis_move(
    device: [*c]c.Gamepad_device,
    axisID: u32,
    value: f32,
    lastValue: f32,
    timestamp: f64,
    context: ?*anyopaque
) callconv(.C) void {
    const step = 16.0;
    const w2        = app.widthf()  / 2 * global_state.camera.zoom;
    const h2        = app.heightf() / 2 * global_state.camera.zoom;
    const marginX   = w2 * 2 * global_state.camera.zoom;
    const marginY   = h2 * 2 * global_state.camera.zoom;

    const s = global_state.loaded_scene orelse return;
    // DPAD LEFT
    if (axisID == 7 and value == -1) {
        if (global_state.game_cursor_mode == .selecting_target) {
            for (global_state.potential_targets.items) |t| {
                for (s.entities.items(.sprite)) |sprite| {
                    const grid_space = util.vec3ToGridSpace(sprite.pos, 16, s.width);
                    if (grid_space == t) {
                        global_state.game_cursor.x -= 16;
                    }
                }
            }
            return;
        }
        if (global_state.game_cursor_mode == .selecting_action) return;
        if (global_state.game_cursor.x - 16 < global_state.camera.pos.x - marginX) {
            global_state.camera.pos.x -= 16;
        } else {
            global_state.game_cursor.x -= 16;
        }
    }

    // DPAD RIGHT
    if (axisID == 7 and value == 1) {
        if (global_state.game_cursor_mode == .selecting_action) return;
        if (global_state.game_cursor.x + step > global_state.camera.pos.x + marginX) {
            global_state.camera.pos.x += step;
        } else {
            global_state.game_cursor.x += 16;
        }
    }

    // DPAD UP
    if (axisID == 8 and value == -1) {
        if (global_state.game_cursor_mode == .selecting_action) {
            global_state.selected_action = @enumFromInt(
                if ((@intFromEnum(global_state.selected_action)) == 0) 3 else
                    @intFromEnum(global_state.selected_action) - 1
            );
            return;
        }

        if (global_state.game_cursor.y + step > global_state.camera.pos.y + marginY) {
            global_state.camera.pos.y += step;
        } else {
            global_state.game_cursor.y += 16;
        }

    }

    // DPAD DOWN
    if (axisID == 8 and value == 1) {
        if (global_state.game_cursor_mode == .selecting_target) {
            const gc = util.vec2ToGridSpace(global_state.game_cursor, 16, s.width);
            for (0.., s.entities.items(.sprite)) |i, sprite| {
                const target = util.vec3ToGridSpace(sprite.pos, 16, s.width);
                if (gc == target) {
                    global_state.selected_target = i;
                }
            }
        }
        if (global_state.game_cursor_mode == .selecting_action) {
            global_state.selected_action = @enumFromInt(
                if ((@intFromEnum(global_state.selected_action)) == 3) 0 else
                    @intFromEnum(global_state.selected_action) + 1
            );
            return;
        }
        if (global_state.game_cursor.y - step < global_state.camera.pos.y - marginY) {
            global_state.camera.pos.y -= step;
        } else {

            global_state.game_cursor.y -= 16;
        }
    }
    _ = device;
    _ = lastValue;
    _ = timestamp;
    _ = context;
    if (axisID != 6 and @abs(value) > 0.25) {
        std.log.info("Button {d} up, value: {d}", .{ axisID, value });
    }
}


//
// @cleanup just move this to another file.
//
pub fn customSwapchain(
) sg.Swapchain {
    //
    // Again custom swap chain to have uniform color formats across systems.
    //
    var swapchain = glue.swapchain();
    swapchain.color_format = .RGBA8;
    return swapchain;
}


var global_state: State = undefined;
var passaction: sg.PassAction = .{};
var proj: math.Mat4 = undefined;
var view: math.Mat4 = undefined;
const camera = Camera3d{};
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

    c.Gamepad_init();
    c.Gamepad_deviceAttachFunc(on_attach, null);
    c.Gamepad_buttonDownFunc(on_button_down, &global_state);
    c.Gamepad_buttonUpFunc(on_button_up, null);
    c.Gamepad_axisMoveFunc(on_axis_move, null);
    c.Gamepad_detectDevices();

    var m: Model = .{};

    // LOL this is going on hold
    // its complicated af
    m.init("assets/models/RobotModel.gltf");

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
    //proj = camera.lookAt();
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

    //
    // GAME UPDATE
    //

    c.Gamepad_processEvents();

    global_state.error_timer += 1;
    if (global_state.error_timer >= 180) {
        global_state.error_timer = 0;
        global_state.errors = 0;

    }
    global_state.selected_cell = null;
    if (global_state.loaded_scene) |s| {
        for ( s.entities.items(.sprite), s.entities.items(.animation), s.entities.items(.flags)) |*sprite, *animation, flags| {
            if (!flags.turn_over) {
                sprite.sprite_id = EntityNs.updateAnimation(animation);
            }
        }
    }
    if (global_state.loaded_scene) |s| {
        for (0.., s.entities.items(.sprite), s.entities.items(.world_index)) |i, *sprite, *w|{
            w.* = @as(u32, @intFromFloat((sprite.pos.x / 16.0) + ( sprite.pos.y / 16.0 ) * s.width ));
            if (sprite.pos.x == global_state.game_cursor.x and sprite.pos.y == global_state.game_cursor.y) {
                global_state.selected_cell = i;
            }
            try global_state.updateSpriteRenderable(sprite, i);
        }
    }

    //
    // RENDERING FRAME
    //

    imgui.newFrame(.{
        .width = app.width(),
        .height = app.height(),
        .delta_time = app.frameDuration(),
        .dpi_scale = app.dpiScale(),
    });

    if (global_state.console.open) {
        ig.igSetNextWindowPos(.{ .x = 10, .y = 10 }, ig.ImGuiCond_Once);
        ig.igSetNextWindowSize(.{ .x = 400, .y = 100 }, ig.ImGuiCond_Once);
        try global_state.console.console(global_state.allocator, &global_state);
    }

    if (global_state.game_cursor_mode == .selecting_action) {
        try global_state.drawMenu();
    }

    try global_state.renderer.addSpriteToBatch(.map_ui_1,
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


    const swapchain = customSwapchain();
    global_state.updateBuffers();


    sg.beginPass(.{ .action = passaction, .swapchain = swapchain });
    if (global_state.loaded_scene) |_| {
        global_state.render(util.computeVsParams(proj, global_state.view));
    }


    const canvas_w = app.widthf() * 0.5;
    const canvas_h = app.heightf() * 0.5;

    sdtx.font(2);
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
    global_state.renderer.resetPass(.map_ui_1);
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
