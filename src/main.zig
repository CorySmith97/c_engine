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
const State = @import("state.zig");

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
var passaction: sg.PassAction = .{};
var offscreen: sg.PassAction = .{};
var image: sg.Image = .{};
var input: Input = .{};
var r: f32 = 0;
var proj: math.Mat4 = undefined;
var zoom_factor: f32 = 0.1;
var state: State = undefined;
var settings_docked: bool = false;
var editor_scene_image: sg.Image = .{};
var editor_scene_image_depth: sg.Image = .{};
var attachment: sg.Attachments = .{};
var layout_initialized: bool = false;
var mouse_world_space: math.Vec4 = .{};
var scene_window_pos = ig.ImVec2_t{};
var scene_window_size = ig.ImVec2_t{};
var is_mouse_in_scene: bool = false;

pub fn api_init() !void {
    proj = mat4.ortho(-app.widthf() / 2, app.widthf() / 2, -app.heightf() / 2, app.heightf() / 2, -1, 1);
    view = math.Mat4.identity();

    sg.setup(.{
        .environment = glue.environment(),
        .logger = .{ .func = slog.func },
    });

    imgui.setup(.{
        .logger = .{ .func = slog.func },
        .ini_filename = "imgui.ini",
    });

    const io = ig.igGetIO();
    io.*.ConfigFlags |= ig.ImGuiConfigFlags_DockingEnable;
    io.*.ConfigFlags |= ig.ImGuiConfigFlags_ViewportsEnable;
    ig.igLoadIniSettingsFromDisk(io.*.IniFilename);

    var img_desc: sg.ImageDesc = .{
        .render_target = true,
        .width = 600,
        .height = 400,
        .pixel_format = .RGBA8,
        .sample_count = 1,
    };
    editor_scene_image = sg.makeImage(img_desc);
    var attachment_desc: sg.AttachmentsDesc = .{};
    attachment_desc.colors[0].image = editor_scene_image;
    img_desc.pixel_format = .DEPTH;
    editor_scene_image_depth = sg.makeImage(img_desc);
    attachment_desc.depth_stencil.image = editor_scene_image_depth;
    attachment = sg.makeAttachments(attachment_desc);
    try state.init();

    passaction.colors[0] = .{
        .load_action = .CLEAR,
        .clear_value = .{ .r = 0, .g = 0, .b = 0, .a = 0 },
    };
    offscreen.colors[0] = .{
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
    imgui.newFrame(.{
        .width = app.width(),
        .height = app.height(),
        .delta_time = app.frameDuration(),
        .dpi_scale = app.dpiScale(),
    });
    const viewport = ig.igGetMainViewport();
    viewport.*.Flags |= ig.ImGuiViewportFlags_NoRendererClear;
    const style = ig.igGetStyle();
    style.*.Colors[ig.ImGuiCol_WindowBg] = ig.ImVec4_t{ .x = 0, .y = 0, .z = 0, .w = 0 };

    const window_flags = ig.ImGuiWindowFlags_MenuBar |
        ig.ImGuiWindowFlags_NoDocking |
        ig.ImGuiWindowFlags_NoTitleBar |
        ig.ImGuiWindowFlags_NoCollapse |
        ig.ImGuiWindowFlags_NoResize |
        ig.ImGuiWindowFlags_NoMove |
        ig.ImGuiWindowFlags_NoBringToFrontOnFocus |
        ig.ImGuiWindowFlags_NoNavFocus |
        ig.ImGuiWindowFlags_NoBackground |
        ig.ImGuiWindowFlags_NoInputs;

    ig.igSetNextWindowPos(viewport.*.WorkPos, ig.ImGuiCond_Always);
    ig.igSetNextWindowSize(viewport.*.WorkSize, ig.ImGuiCond_Always);
    ig.igSetNextWindowViewport(viewport.*.ID);

    _ = ig.igBegin("DockSpace", null, window_flags);

    // Submit the DockSpace
    const dockspace_id = ig.igGetIDStr("MyDockSpace".ptr, null);
    _ = ig.igDockSpace(dockspace_id);

    ig.igSetNextWindowDockID(dockspace_id, ig.ImGuiCond_Once);

    // Your existing UI code can go here or be separate windows that will dock

    ig.igEnd();
    ig.igSetNextWindowDockID(dockspace_id, ig.ImGuiCond_Once);
    _ = ig.igBegin("Scene", 0, ig.ImGuiWindowFlags_None);
    scene_window_pos = ig.igGetWindowPos();
    scene_window_size = ig.igGetContentRegionAvail();
    ig.igImage(imgui.imtextureid(editor_scene_image), ig.ImVec2{ .x = 600, .y = 400 });
    ig.igEnd();
    _ = ig.igBegin("Entity Editor", 0, ig.ImGuiWindowFlags_None);
    if (state.selected_entity) |s| {
        const selected = try std.fmt.allocPrint(state.allocator, "ENTID: {d}", .{s});
        defer state.allocator.free(selected);
        ig.igText(selected.ptr);
    }
    ig.igEnd();
    _ = ig.igBegin("Drawer", 0, ig.ImGuiWindowFlags_None);
    ig.igEnd();
    _ = ig.igBegin("Settings", 0, ig.ImGuiWindowFlags_None);
    const mtext = try std.fmt.allocPrint(state.allocator, "Mouse World Pos: {d:.3}, {d:.3}", .{ mouse_world_space.x, mouse_world_space.y });
    defer state.allocator.free(mtext);
    const text = try std.fmt.allocPrint(state.allocator, "frame furation: {d:.3}", .{app.frameDuration()});
    defer state.allocator.free(text);
    ig.igText(mtext.ptr);
    ig.igText(text.ptr);
    if (ig.igButton("increment")) {
        r += 1;
    }
    if (ig.igButton("reset view")) {
        view = math.Mat4.identity();
        proj = mat4.ortho(-app.widthf() / 2, app.widthf() / 2, -app.heightf() / 2, app.heightf() / 2, -1, 1);
    }
    ig.igEnd();

    //=== UI CODE ENDS HERE
    const vs_params = computeVsParams(1.0, r);
    state.updateBuffers(r);

    // call simgui.render() inside a sokol-sg pass
    sg.beginPass(.{ .action = offscreen, .attachments = attachment });
    state.render(vs_params);
    state.collision(mouse_world_space);
    sg.endPass();
    sg.beginPass(.{ .action = passaction, .swapchain = glue.swapchain() });
    imgui.render();
    sg.endPass();
    sg.commit();
}

pub fn api_cleanup() !void {
    ig.igSaveIniSettingsToDisk("imgui.ini");
    imgui.shutdown();
}

pub fn api_event(ev: [*c]const app.Event) !void {
    const eve = ev.*;
    // forward input events to sokol-imgui
    _ = imgui.handleEvent(ev.*);
    if (eve.type == .MOUSE_SCROLL) {
        if (zoom_factor - 0.05 < 0) {
            zoom_factor = 0.0;
        }
        if (eve.scroll_y > 0 and zoom_factor < 5) {
            zoom_factor += 0.05;
        }
        if (eve.scroll_y < 0 and zoom_factor > 0) {
            zoom_factor -= 0.05;
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
        const ig_mouse = ig.igGetMousePos();

        const mouse_rel_x = ig_mouse.x - scene_window_pos.x;
        const mouse_rel_y = ig_mouse.y - scene_window_pos.y;

        const texture_x = mouse_rel_x / 600.0;
        const texture_y = mouse_rel_y / 400.0;

        const ndc_x = texture_x * 2.0 - 1.0;
        const ndc_y = 1.0 - texture_y * 2.0; // Flip Y for OpenGL-style coordinates

        const view_proj = math.Mat4.mul(proj, view);
        const inv = math.Mat4.inverse(view_proj);
        mouse_world_space = math.Mat4.mulByVec4(inv, .{ .x = ndc_x, .y = ndc_y, .z = 0, .w = 1 });
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
            .LEFT => {
                view = math.Mat4.mul(view, math.Mat4.translate(.{ .x = zoom_factor * -10, .y = zoom_factor * 0, .z = 0 }));
            },
            .RIGHT => {
                view = math.Mat4.mul(view, math.Mat4.translate(.{ .x = zoom_factor * 10, .y = zoom_factor * 0, .z = 0 }));
            },
            .UP => {
                view = math.Mat4.mul(view, math.Mat4.translate(.{ .x = zoom_factor * 0, .y = zoom_factor * 10, .z = 0 }));
            },
            .DOWN => {
                view = math.Mat4.mul(view, math.Mat4.translate(.{ .x = zoom_factor * 0, .y = zoom_factor * -10, .z = 0 }));
            },
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
    const allocator = std.heap.page_allocator;
    var args_iter = try std.process.argsWithAllocator(allocator);
    var desc: app.Desc = undefined;

    while (args_iter.next()) |arg| {
        if (std.mem.eql(u8, arg, "editor")) {
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
