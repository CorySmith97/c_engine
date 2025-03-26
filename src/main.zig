const std = @import("std");
const ig = @import("cimgui");
const sokol = @import("sokol");
const app = sokol.app;
const sg = sokol.gfx;
const slog = sokol.log;
const glue = sokol.glue;
const imgui = sokol.imgui;
const shd = @import("shaders/basic.glsl.zig");
const math = @import("math.zig");
const Camera = @import("camera.zig").Camera;
const mat4 = math.Mat4;
const RenderPass = @import("renderer.zig").RenderPass;
const Entity = @import("entity.zig");

pub const Input = struct {
    up: bool = false,
    down: bool = false,
    left: bool = false,
    right: bool = false,
    forward: bool = false,
    backwards: bool = false,
};

var camera: Camera = undefined;
var view: math.Mat4 = undefined;
var pass: RenderPass = undefined;
var tile_pass: RenderPass = undefined;
var passaction: sg.PassAction = .{};
var image: sg.Image = .{};
var input: Input = .{};
var r: f32 = 0;
var proj: math.Mat4 = undefined;
var zoom_factor: f32 = 1;

pub fn api_init() !void {
    proj = mat4.ortho(-app.widthf() / 2, app.widthf() / 2, -app.heightf() / 2, app.heightf() / 2, -1, 1);
    view = math.Mat4.identity();
    const entity: Entity = .{};
    std.log.info("{any}", .{entity});

    sg.setup(.{
        .environment = glue.environment(),
        .logger = .{ .func = slog.func },
    });

    imgui.setup(.{
        .logger = .{ .func = slog.func },
    });

    try pass.init(
        "assets/spritesheet-1.png",
        .{ 16, 16 },
        .{ 256, 256 },
        std.heap.page_allocator,
    );
    try tile_pass.init(
        "assets/tiles.png",
        .{ 16, 16 },
        .{ 256, 256 },
        std.heap.page_allocator,
    );
    passaction.colors[0] = .{
        .load_action = .CLEAR,
        .clear_value = .{ .r = 0, .g = 0, .b = 0, .a = 0 },
    };
    camera = .{
        .up = .{ .x = 0, .y = 1, .z = 0 },
        .front = .{ .x = 0, .y = 0, .z = -1 },
        .target = .{ .x = 0, .y = 0, .z = 0 },
        .pos = .{ .x = 0, .y = 0, .z = 1 },
        .vel = .{ .x = 0, .y = 0, .z = 0 },
    };
}

pub fn api_frame() !void {
    if (input.forward) {
        camera.pos.z += 0.1;
    }
    if (input.backwards) {
        camera.pos.z -= 0.1;
    }
    //view = math.Mat4.lookat(camera.pos, camera.pos.add(camera.front), camera.up);
    const alloc = std.heap.page_allocator;
    const text = std.fmt.allocPrint(alloc,
        \\R: {}
        \\sprite count: {}
    , .{ r, pass.cur_num_of_sprite }) catch unreachable;
    defer alloc.free(text);
    imgui.newFrame(.{
        .width = app.width(),
        .height = app.height(),
        .delta_time = app.frameDuration(),
        .dpi_scale = app.dpiScale(),
    });

    //=== UI CODE STARTS HERE
    ig.igSetNextWindowPos(.{ .x = 10, .y = 10 }, ig.ImGuiCond_Once);
    ig.igSetNextWindowSize(.{ .x = 400, .y = 100 }, ig.ImGuiCond_Once);
    _ = ig.igBegin("Hello Dear ImGui!", 0, ig.ImGuiWindowFlags_None);
    ig.igText(text.ptr);
    if (ig.igButton("reset view")) {
        view = math.Mat4.identity();
        proj = mat4.ortho(-app.widthf() / 2, app.widthf() / 2, -app.heightf() / 2, app.heightf() / 2, -1, 1);
    }
    ig.igEnd();
    //=== UI CODE ENDS HERE
    r += 1;
    pass.updateBuffers();
    tile_pass.updateBuffers();
    const vs_params = computeVsParams(1.0, r);

    // call simgui.render() inside a sokol-sg pass
    sg.beginPass(.{ .action = passaction, .swapchain = glue.swapchain() });
    pass.render(vs_params);
    tile_pass.render(vs_params);
    imgui.render();
    sg.endPass();
    sg.commit();
}

pub fn api_cleanup() !void {
    imgui.shutdown();
}

pub fn api_event(ev: [*c]const app.Event) !void {
    const eve = ev.*;
    // forward input events to sokol-imgui
    _ = imgui.handleEvent(ev.*);
    if (eve.type == .MOUSE_SCROLL) {
        if (eve.scroll_y > 0 and zoom_factor < 5) {
            zoom_factor += 0.15;
        }
        if (eve.scroll_y < 0 and zoom_factor > 0) {
            zoom_factor -= 0.15;
        }
        proj = mat4.ortho(
            -app.widthf() / 2 * zoom_factor,
            app.widthf() / 2 * zoom_factor,
            -app.heightf() / 2 * zoom_factor,
            app.heightf() / 2 * zoom_factor,
            -1,
            1,
        );
    }
    if (ev.*.type == .MOUSE_MOVE) {
        const ndc_x = (eve.mouse_x / app.widthf()) * 2.0 - 1.0;
        const ndc_y = 1.0 - (eve.mouse_y / app.heightf()) * 2.0;
        const view_proj = math.Mat4.mul(proj, view);
        const inv = math.Mat4.inverse(view_proj);
        const world_space = math.Mat4.mulByVec4(inv, .{ .x = ndc_x, .y = ndc_y, .z = 0, .w = 1 });
        _ = world_space;
    }
    if (ev.*.type == .MOUSE_MOVE and mouse_middle_down) {
        view = math.Mat4.mul(view, math.Mat4.translate(.{ .x = zoom_factor * ev.*.mouse_dx, .y = zoom_factor * -ev.*.mouse_dy, .z = 0 }));
    }
    if (ev.*.type == .MOUSE_DOWN or ev.*.type == .MOUSE_UP) {
        const mouse_pressed = ev.*.type == .MOUSE_DOWN;
        switch (ev.*.mouse_button) {
            .MIDDLE => mouse_middle_down = mouse_pressed,

            else => {},
        }
    }

    if (ev.*.type == .KEY_UP or ev.*.type == .KEY_DOWN) {
        const key_pressed = ev.*.type == .KEY_DOWN;
        switch (ev.*.key_code) {
            .W => input.forward = key_pressed,
            .S => input.backwards = key_pressed,
            .A => input.left = key_pressed,
            .D => input.right = key_pressed,
            .ESCAPE => app.quit(),
            else => {},
        }
    }
}
export fn init() void {
    api_init() catch unreachable;
}

export fn frame() void {
    api_frame() catch unreachable;
}

export fn cleanup() void {
    api_cleanup() catch unreachable;
}
var mouse_middle_down: bool = false;
export fn event(ev: [*c]const app.Event) void {
    api_event(ev) catch unreachable;
}

pub fn main() !void {
    app.run(.{
        .init_cb = init,
        .frame_cb = frame,
        .event_cb = event,
        .cleanup_cb = cleanup,
        .width = 800,
        .height = 600,
        .window_title = "HELLO",
    });
}

fn computeVsParams(rx: f32, ry: f32) shd.VsParams {
    _ = rx;
    _ = ry;
    const model = mat4.identity();
    //const rxm = mat4.rotate(rx, .{ .x = 1.0, .y = 0.0, .z = 0.0 });
    //const rym = mat4.rotate(ry, .{ .x = 0.0, .y = 1.0, .z = 0.0 });
    //const model = mat4.mul(rxm, rym);
    //const aspect = app.widthf() / app.heightf();
    //const proj = mat4.persp(60, aspect, 0.01, 100);
    return shd.VsParams{ .mvp = mat4.mul(mat4.mul(proj, view), model) };
}
