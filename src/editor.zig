/// === EDITOR ===
/// This is the entire editor in a single file basically.
/// It may be split apart later, but for now its completely
/// fine.
const std = @import("std");
const ig = @import("cimgui");
const sokol = @import("sokol");
const app = sokol.app;
const sg = sokol.gfx;
const slog = sokol.log;
const glue = sokol.glue;
const imgui = sokol.imgui;
const Camera = @import("camera.zig");
const math = @import("math.zig");
const mat4 = math.Mat4;
const State = @import("state.zig");
const Scene = @import("scene.zig");
const util = @import("util.zig");
const Lua = @import("scripting/lua.zig");

const predefined_colors = [_]ig.ImVec4_t{
    .{ .x = 1.0, .y = 0.0, .z = 0.0, .w = 1.0 }, // red
    .{ .x = 0.0, .y = 1.0, .z = 0.0, .w = 1.0 }, // green
    .{ .x = 0.0, .y = 0.0, .z = 1.0, .w = 1.0 }, // blue
    .{ .x = 1.0, .y = 1.0, .z = 0.0, .w = 1.0 }, // yellow
    .{ .x = 1.0, .y = 1.0, .z = 1.0, .w = 1.0 }, // white
    .{ .x = 0.0, .y = 0.0, .z = 0.0, .w = 1.0 }, // black
};

pub const Input = struct {
    up: bool = false,
    down: bool = false,
    left: bool = false,
    right: bool = false,
    forward: bool = false,
    backwards: bool = false,
};

pub const EditorState = struct {};

var mouse_middle_down: bool = false;
var camera: Camera = undefined;
var view: math.Mat4 = undefined;
var passaction: sg.PassAction = .{};
var offscreen: sg.PassAction = .{};
var image: sg.Image = .{};
var input: Input = .{};
var r: f32 = 0;
var proj: math.Mat4 = undefined;
var zoom_factor: f32 = 0.25;
var settings_docked: bool = false;
var editor_scene_image: sg.Image = .{};
var editor_scene_image_depth: sg.Image = .{};
var attachment: sg.Attachments = .{};
var layout_initialized: bool = false;
var mouse_world_space: math.Vec4 = .{};
var scene_window_pos = ig.ImVec2_t{};
var scene_window_size = ig.ImVec2_t{};
var is_mouse_in_scene: bool = false;
var scene: Scene = undefined;
var state: State = undefined;
const allocator = std.heap.page_allocator;
var buf: [8192]u8 = undefined;

pub fn init() !void {
    try Lua.luaTest();

    // Default Projection matrix
    proj = mat4.ortho(
        -app.widthf() / 2 * zoom_factor + 50,
        app.widthf() / 2 * zoom_factor + 50,
        -app.heightf() / 2 * zoom_factor - 50,
        app.heightf() / 2 * zoom_factor - 50,
        -1,
        1,
    );
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

    // While in the editor, we render the game to a texture. that
    // texture is then rendered within an Imgui window.
    var img_desc: sg.ImageDesc = .{
        .render_target = true,
        .width = 600,
        .height = 400,
        .pixel_format = .RGBA8,
        .sample_count = 1,
    };

    // Image for scene needs both Image, and depth image
    editor_scene_image = sg.makeImage(img_desc);

    var attachment_desc: sg.AttachmentsDesc = .{};
    attachment_desc.colors[0].image = editor_scene_image;
    img_desc.pixel_format = .DEPTH;

    editor_scene_image_depth = sg.makeImage(img_desc);
    attachment_desc.depth_stencil.image = editor_scene_image_depth;

    attachment = sg.makeAttachments(attachment_desc);

    // Ready State data
    try state.init();
    try scene.loadTestScene(std.heap.page_allocator, &state.passes[0]);

    // Default pass actions
    passaction.colors[0] = .{
        .load_action = .CLEAR,
        .clear_value = .{ .r = 0, .g = 0, .b = 0, .a = 0 },
    };
    offscreen.colors[0] = .{
        .load_action = .CLEAR,
        .clear_value = .{ .r = 0, .g = 0, .b = 0, .a = 0 },
    };
}
pub fn frame() !void {
    //view = math.Mat4.lookat(camera.pos, camera.pos.add(camera.front), camera.up);
    //
    //
    // Imgui Frame setup
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

    // Create a dockspace to enable window docking
    _ = ig.igBegin("DockSpace", null, window_flags);
    const dockspace_id = ig.igGetIDStr("MyDockSpace".ptr, null);
    _ = ig.igDockSpace(dockspace_id);
    ig.igSetNextWindowDockID(dockspace_id, ig.ImGuiCond_Once);
    ig.igEnd();

    // Game scene renderer. Game rendered to a texture
    ig.igSetNextWindowDockID(dockspace_id, ig.ImGuiCond_Once);
    _ = ig.igBegin("Scene", 0, ig.ImGuiWindowFlags_None);
    scene_window_pos = ig.igGetWindowPos();
    scene_window_size = ig.igGetContentRegionAvail();
    ig.igImage(imgui.imtextureid(editor_scene_image), ig.ImVec2{ .x = 600, .y = 400 });
    ig.igEnd();

    // Editor for Entity
    _ = ig.igBegin("Entity Editor", 0, ig.ImGuiWindowFlags_None);
    if (ig.igInputText("New level", &buf, buf.len, ig.ImGuiWindowFlags_None)) {
        std.log.info("{s}, len: {}", .{ buf[0.. :0], buf.len });
    }
    if (state.selected_entity) |s| {
        if (state.selected_entity_click) {
            var tile = scene.tiles.get(s);
            const selected = try std.fmt.allocPrint(
                state.allocator,
                "ENTID: {d}\nSprite id: {d}\nPos: {}, {}, {}",
                .{
                    s,
                    tile.sprite_renderable.sprite_id,
                    tile.sprite_renderable.pos.x,
                    tile.sprite_renderable.pos.y,
                    tile.sprite_renderable.pos.z,
                },
            );
            defer state.allocator.free(selected);
            ig.igText(selected.ptr);

            var color_array = tile.sprite_renderable.color.toArray();
            _ = ig.igColorPicker4("Color", &color_array, ig.ImGuiColorEditFlags_None, null);
            _ = ig.igText("Preset Colors:");
            ig.igNewLine();
            for (predefined_colors, 0..) |preset, i| {
                ig.igSameLine();
                const str = try std.fmt.allocPrintZ(allocator, "##c{}", .{i});
                defer allocator.free(str);
                if (ig.igColorButton(
                    str.ptr,
                    preset,
                    ig.ImGuiColorEditFlags_None,
                )) {
                    color_array = [4]f32{ preset.x, preset.y, preset.z, preset.w };
                }
            }
            tile.sprite_renderable.color = math.Vec4.fromArray(color_array);

            _ = ig.igCheckbox("Spawner", &tile.spawner);
            _ = ig.igCheckbox("Traversable", &tile.traversable);
            scene.tiles.set(s, tile);

            try state.passes[0].updateSpriteRenderables(s, tile.sprite_renderable);
        }
    }
    ig.igEnd();

    // Drawer for data. This is unused for now, but something will go here.
    // Idea tab for animations, or Possible script viewer.
    _ = ig.igBegin("Drawer", 0, ig.ImGuiWindowFlags_None);
    ig.igEnd();

    // General Scene Settings
    _ = ig.igBegin("Settings", 0, ig.ImGuiWindowFlags_None);
    const mtext = try std.fmt.allocPrint(state.allocator, "Mouse World Pos: {d:.3}, {d:.3}", .{ mouse_world_space.x, mouse_world_space.y });
    defer state.allocator.free(mtext);
    ig.igText(mtext.ptr);
    const text = try std.fmt.allocPrint(state.allocator, "frame furation: {d:.3}", .{app.frameDuration()});
    defer state.allocator.free(text);
    ig.igText(text.ptr);

    const view_text = try std.fmt.allocPrint(
        state.allocator,
        "VIEW:\n{} {} {} {}\n{} {} {} {}\n{} {} {} {}\n{} {} {} {}",
        .{
            view.m[0][0],
            view.m[0][1],
            view.m[0][2],
            view.m[0][3],
            view.m[1][0],
            view.m[1][1],
            view.m[1][2],
            view.m[1][3],
            view.m[2][0],
            view.m[2][1],
            view.m[2][2],
            view.m[2][3],
            view.m[3][0],
            view.m[3][1],
            view.m[3][2],
            view.m[3][3],
        },
    );
    defer state.allocator.free(view_text);
    ig.igText(view_text.ptr);
    if (ig.igButton("reload scene")) {
        try scene.reloadScene(std.heap.page_allocator);
        try scene.loadTestScene(std.heap.page_allocator, &state.passes[0]);
    }
    if (ig.igButton("reset view")) {
        view = math.Mat4.identity();
        proj = mat4.ortho(-app.widthf() / 2, app.widthf() / 2, -app.heightf() / 2, app.heightf() / 2, -1, 1);
    }
    ig.igEnd();

    // Prepare render data for instanced rendering
    const vs_params = util.computeVsParams(proj, view);
    state.updateBuffers();

    // === Render scene to image
    sg.beginPass(.{ .action = offscreen, .attachments = attachment });
    state.render(vs_params);
    if (!state.selected_entity_click) {
        state.collision(mouse_world_space);
    }
    sg.endPass();

    // === Render IMGUI windows
    sg.beginPass(.{ .action = passaction, .swapchain = glue.swapchain() });
    imgui.render();
    sg.endPass();
    sg.commit();
}

pub fn cleanup() !void {
    ig.igSaveIniSettingsToDisk("imgui.ini");
    imgui.shutdown();
}

pub fn event(ev: [*c]const app.Event) !void {
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
        view = math.Mat4.mul(view, math.Mat4.translate(.{
            .x = zoom_factor * ev.*.mouse_dx,
            .y = zoom_factor * -ev.*.mouse_dy,
            .z = 0,
        }));
    }
    if (ev.*.type == .MOUSE_DOWN or ev.*.type == .MOUSE_UP) {
        const mouse_pressed = ev.*.type == .MOUSE_DOWN;
        switch (ev.*.mouse_button) {
            .MIDDLE => mouse_middle_down = mouse_pressed,
            .LEFT => {
                if (state.selected_entity) |_| {
                    state.selected_entity_click = true;
                }
            },
            .RIGHT => {
                if (state.selected_entity_click) {
                    state.selected_entity_click = false;
                    state.selected_entity = null;
                }
            },

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
