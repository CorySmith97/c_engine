const AppConfig = @import("config.zig");
const ig = @import("cimgui");
const sokol = @import("sokol");
const app = sokol.app;
const sg = sokol.gfx;
const slog = sokol.log;
const glue = sokol.glue;
const imgui = sokol.imgui;
const sdtx = sokol.debugtext;

const Input = @import("input.zig");
//const MouseState = Input.MouseState;
const KeyboardState = Input.KeyboardState;

pub const App = struct {
    var config = AppConfig{};

    pub fn init() callconv(.c) void {
        var env = glue.environment();
        env.defaults.color_format = .RGBA8;
        env.defaults.depth_format = .DEPTH_STENCIL;

        sg.setup(.{
            .environment = env,
            .logger = .{ .func = slog.func },
        });

        imgui.setup(.{
            .logger = .{ .func = slog.func },
        });

        //config.user_init();
    }

    pub fn frame() callconv(.c)  void {
        //config.user_frame();
        //sg.commit();
    }

    pub fn input(ev: [*c]const app.Event) callconv(.c)  void {
        _ = imgui.handleEvent(ev.*);
        switch (ev.*.type) {
            .KEY_DOWN => {
                KeyboardState.keys_pressed[@intCast(@intFromEnum(ev.*.key_code))] = true;
            },
            .KEY_UP => {
                KeyboardState.keys_pressed[@intCast(@intFromEnum(ev.*.key_code))] = false;
            },
            else => {},
        }

        //config.user_input();
    }

    pub fn deinit() callconv(.c) void {
        //config.user_deinit();
    }
};

