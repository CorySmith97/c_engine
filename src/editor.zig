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
const State = @import("state.zig");
const util = @import("util.zig");
const math = util.math;
const mat4 = math.Mat4;
const Lua = @import("scripting/lua.zig");
const types = @import("types.zig");
const RenderPassIds = types.RendererTypes.RenderPassIds;
const Scene = types.Scene;
const Entity = types.Entity;
const Serde = @import("serde.zig");

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

pub const MouseState = struct {
    hover_over_scene: bool = false,
};

const SerdeMode = enum {
    JSON,
    BINARY,
};

pub const EditorConfig = struct {
    mode: SerdeMode = .BINARY,

    pub fn loadConfig(
        self: *EditorConfig,
        allo: std.mem.Allocator,
    ) !void {
        var cwd = std.fs.cwd();

        var config_file = try cwd.openFile("editor.json", .{});
        defer config_file.close();

        const config_buf = try config_file.readToEndAlloc(allo, 1000);

        const temp = try std.json.parseFromSliceLeaky(EditorConfig, allo, config_buf, .{});
        self.mode = temp.mode;
    }
};

var mouse_middle_down: bool = false;
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
var mouse_state: MouseState = .{};
var selected_layer: State.RenderPassIds = .TILES_1;
var scene_list_buffer: std.ArrayList([]const u8) = undefined;
var new_temp_scene: Scene = .{};
var new_scene_open: bool = false;
var load_scene_open: bool = false;
var editor_config: EditorConfig = .{};

const test_string = "HELLO FROM HERE";

pub fn init() !void {
    try editor_config.loadConfig(allocator);
    //try Lua.luaTest();

    scene_list_buffer = std.ArrayList([]const u8).init(allocator);

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
        .width = 700,
        .height = 440,
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
    //try scene.loadTestScene(allocator, &state);
    if (editor_config.mode == .BINARY) {
        try Serde.loadSceneFromBinary(&scene, "t2.txt", std.heap.page_allocator);
        try Serde.writeSceneToJson(&scene, "t2.json", std.heap.page_allocator);
        state.loaded_scene = scene;
    } else if (editor_config.mode == .JSON) {
        try Serde.loadSceneFromJson(&scene, "t2.json", std.heap.page_allocator);
    }
    try state.loaded_scene.?.loadScene(&state.renderer);

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

    try main_menu();

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
    ig.igImage(imgui.imtextureid(editor_scene_image), ig.ImVec2{ .x = 700, .y = 440 });
    ig.igEnd();

    // Editor for Entity
    _ = ig.igBegin("Entity Editor", 0, ig.ImGuiWindowFlags_None);
    if (state.selected_entity) |s| {
        if (state.selected_entity_click) {
            var tile = state.loaded_scene.?.tiles.get(s);
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
            _ = ig.igInputFloat("Sprite ID: ", &tile.sprite_renderable.sprite_id);

            _ = ig.igCheckbox("Spawner", &tile.spawner);
            _ = ig.igCheckbox("Traversable", &tile.traversable);
            state.loaded_scene.?.tiles.set(s, tile);

            if (state.renderer.render_passes.items[@intFromEnum(selected_layer)].batch.items.len > s) {
                try state.renderer.render_passes.items[@intFromEnum(selected_layer)].updateSpriteRenderables(s, tile.sprite_renderable);
            }
        }
    }
    ig.igEnd();

    // Drawer for data. This is unused for now, but something will go here.
    // Idea tab for animations, or Possible script viewer.
    _ = ig.igBegin("Drawer", 0, ig.ImGuiWindowFlags_None);
    ig.igEnd();

    //for (0..test_string.len) |i| {
    //    const f: f32 = @floatFromInt(i);
    //    try state.renderer.render_passes.items[@intFromEnum(RenderPassIds.UI_1)].appendSpriteToBatch(.{
    //        .pos = .{ .x = f * 16 - 32, .y = 26, .z = 0 },
    //        .sprite_id = @floatFromInt(test_string[i]),
    //        .color = .{ .x = 0.1, .y = 1, .z = 0.5, .w = 1 },
    //    });
    //}

    var clamped_mouse_pos: math.Vec3 = undefined;
    if (mouse_state.hover_over_scene) {
        const grid_size = 16.0;
        const grid_offset_x = 0.0; // Adjust as needed
        const grid_offset_y = -12.0; // Adjust as needed
        clamped_mouse_pos = math.Vec3{
            .x = @floor((mouse_world_space.x - grid_offset_x) / grid_size) * grid_size + grid_offset_x,
            .y = @floor((mouse_world_space.y - grid_offset_y) / grid_size) * grid_size + grid_offset_y,
            .z = 0,
        };

        try state.renderer.render_passes.items[@intFromEnum(RenderPassIds.UI_1)].appendSpriteToBatch(.{ .pos = clamped_mouse_pos, .sprite_id = 1, .color = .{ .x = 0, .y = 0, .z = 0, .w = 0 } });
    }

    try left_window();

    // Prepare render data for instanced rendering
    const vs_params = util.computeVsParams(proj, view);
    state.updateBuffers();

    // === Render scene to image
    sg.beginPass(.{ .action = offscreen, .attachments = attachment });
    if (state.loaded_scene) |_| {
        state.render(vs_params);
    }
    if (!state.selected_entity_click) {
        state.collision(mouse_world_space);
    }
    sg.endPass();

    // === Render IMGUI windows
    sg.beginPass(.{ .action = passaction, .swapchain = glue.swapchain() });
    imgui.render();
    sg.endPass();
    sg.commit();
    state.renderer.render_passes.items[@intFromEnum(RenderPassIds.UI_1)].batch.clearRetainingCapacity();
    state.renderer.render_passes.items[@intFromEnum(RenderPassIds.UI_1)].cur_num_of_sprite = 0;
}

pub fn cleanup() !void {
    ig.igSaveIniSettingsToDisk("imgui.ini");
    imgui.shutdown();
}

pub fn event(ev: [*c]const app.Event) !void {
    const eve = ev.*;

    // forward input events to sokol-imgui
    _ = imgui.handleEvent(ev.*);
    const ig_mouse = ig.igGetMousePos();

    if (util.aabb(ig_mouse, scene_window_pos, scene_window_size)) {
        mouse_state.hover_over_scene = true;
    } else {
        mouse_state.hover_over_scene = false;
    }

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
            -app.widthf() / 2 * zoom_factor + 50,
            app.widthf() / 2 * zoom_factor + 50,
            -app.heightf() / 2 * zoom_factor - 50,
            app.heightf() / 2 * zoom_factor - 50,
            -1,
            1,
        );
    }
    if (ev.*.type == .MOUSE_MOVE) {
        const mouse_rel_x = ig_mouse.x - scene_window_pos.x;
        const mouse_rel_y = ig_mouse.y - scene_window_pos.y;

        const texture_x = mouse_rel_x / 700.0;
        const texture_y = mouse_rel_y / 440.0;

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
                if (mouse_state.hover_over_scene) {
                    if (state.selected_entity) |_| {
                        state.selected_entity_click = true;
                    }
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

fn main_menu() !void {
    if (ig.igBeginMainMenuBar()) {}
    if (ig.igButton("Open Dropdown")) {
        ig.igOpenPopup("dropdown", 0);
    }

    if (ig.igBeginPopup("dropdown", 0)) {
        if (ig.igButton("New Scenes")) {
            new_temp_scene = .{};
            new_scene_open = true;
            ig.igCloseCurrentPopup();
        }
        if (ig.igButton("Save Scenes")) {
            if (state.loaded_scene) |*s| {
                try Serde.writeSceneToBinary(s, s.scene_name);
            }
            ig.igCloseCurrentPopup();
        }
        if (ig.igButton("Load Scene")) {
            var level_dir = try std.fs.cwd().openDir("levels", .{});
            var level_walker = try level_dir.walk(allocator);
            while (try level_walker.next()) |entry| {
                try scene_list_buffer.append(try allocator.dupe(u8, entry.basename));
            }
            level_walker.deinit();
            load_scene_open = true;
        }
        ig.igEndPopup();
    }
    if (load_scene_open) {
        ig.igSetNextWindowBgAlpha(1.0);
        ig.igSetNextWindowSize(.{ .x = 300, .y = 200 }, ig.ImGuiCond_None);
        if (ig.igBegin("Load Scene", &load_scene_open, ig.ImGuiWindowFlags_NoSavedSettings | ig.ImGuiWindowFlags_NoDocking)) {
            if (scene_list_buffer.items.len > 0) {
                for (scene_list_buffer.items) |s| {
                    if (ig.igButton(s.ptr)) {
                        // @todo load a scene, and set the scene to the state loaded scene
                        if (state.loaded_scene) |*loaded_scene| {
                            loaded_scene.deloadScene(allocator, &state);
                        }
                        var temp_scene: Scene = .{};
                        try Serde.loadSceneFromBinary(&temp_scene, s, allocator);
                        state.loaded_scene = temp_scene;
                        try state.loaded_scene.?.loadScene(&state.renderer);

                        load_scene_open = false;
                        scene_list_buffer.clearAndFree();
                        break;
                    }
                }
            }
        }
        ig.igEnd();
    }

    if (new_scene_open) {
        ig.igSetNextWindowBgAlpha(1.0);
        ig.igSetNextWindowSize(.{ .x = 300, .y = 200 }, ig.ImGuiCond_None);
        if (ig.igBegin("New Scene", &new_scene_open, ig.ImGuiWindowFlags_NoSavedSettings | ig.ImGuiWindowFlags_NoDocking)) {
            if (ig.igInputText("Name", &buf, buf.len, ig.ImGuiWindowFlags_None)) {
                const temp_name: []const u8 = std.mem.span(@as([*c]u8, @ptrCast(buf[0..].ptr)));
                new_temp_scene.scene_name = temp_name;
            }
            _ = ig.igInputFloat("Width", &new_temp_scene.width);
            _ = ig.igInputFloat("Height", &new_temp_scene.height);
            if (ig.igButton("New Scene")) {
                state.loaded_scene.?.deloadScene(allocator, &state);
                try new_temp_scene.tiles.setCapacity(allocator, @as(usize, @intFromFloat(new_temp_scene.width * new_temp_scene.height)));
                for (0..new_temp_scene.tiles.capacity) |i| {
                    const f: f32 = @floatFromInt(i);
                    new_temp_scene.tiles.insertAssumeCapacity(i, .{
                        .sprite_renderable = .{
                            .pos = .{
                                .x = @mod(f, new_temp_scene.width) * 16,
                                .y = @floor(f / new_temp_scene.height) * 16,
                                .z = 0,
                            },
                            .sprite_id = 0,
                            .color = .{
                                .x = 1.0,
                                .y = 1.0,
                                .z = 1.0,
                                .w = 1.0,
                            },
                        },
                    });
                }
                state.loaded_scene = new_temp_scene;
                try state.loaded_scene.?.loadScene(&state.renderer);
                try Serde.writeSceneToBinary(&state.loaded_scene.?, state.loaded_scene.?.scene_name);
                state.selected_entity = null;
            }
        }
        ig.igEnd();
    }

    ig.igEndMainMenuBar();
}

fn left_window() !void {
    // General Scene Settings
    _ = ig.igBegin("Settings", 0, ig.ImGuiWindowFlags_None);
    ig.igBeginGroup();
    ig.igTextColored(predefined_colors[1], "Stats");
    const text = try std.fmt.allocPrint(state.allocator, "frame duration: {d:.3}", .{app.frameDuration()});
    defer state.allocator.free(text);
    ig.igText(text.ptr);
    const render_pass_count = try std.fmt.allocPrint(state.allocator, "RenderPass Count: {d}", .{state.passes.len});
    defer state.allocator.free(render_pass_count);
    ig.igText(render_pass_count.ptr);

    ig.igNewLine();
    ig.igSameLine();
    ig.igText("Selected Layer");
    ig.igText(@tagName(selected_layer));
    for (std.meta.tags(State.RenderPassIds)) |id| {
        if (ig.igButton(@tagName(id).ptr)) {
            selected_layer = id;
        }
    }
    ig.igEndGroup();
    ig.igEnd();
}
