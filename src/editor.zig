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
const Tile = types.Tile;
const Serde = @import("serde.zig");
const Quad = @import("renderer/RenderQuad.zig");
const TypeEditors = @import("editor/entity_editor.zig");
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

pub const Cursor = enum {
    moving_entity,
    editing_tile,
    editing_entity,
};

pub const MouseState = struct {
    mouse_position_ig: ig.ImVec2_t = .{},
    mouse_position_v2: math.Vec2 = .{},
    hover_over_scene: bool = false,
    moving_entity: bool = false,

    pub fn mouseEvents(self: *MouseState, ev: [*c]const app.Event) void {
        const eve = ev.*;
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
    }
    if (ev.*.type == .MOUSE_MOVE) {
        const mouse_rel_x = self.mouse_position_ig.x - scene_window_pos.x;
        const mouse_rel_y = self.mouse_position_ig.y - scene_window_pos.y;

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
                if (self.hover_over_scene) {
                    switch (es.selected_layer) {
                        .ENTITY_1 => {
                            if (es.state.loaded_scene) |s| {
                                for (0.., s.entities.items(.aabb)) |i, aabb| {
                                    if (util.aabbRec(es.mouse_state.mouse_position_v2, aabb))  {
                                        es.state.selected_entity = i;
                                    }
                                }
                            }
                            if (es.state.selected_entity) |_| {
                                es.state.selected_entity_click = true;
                            }
                        },
                        else =>{},
                    }
                    if (es.state.selected_tile) |_| {
                        es.state.selected_tile_click = true;
                    }
                }
            },
            .RIGHT => {
                if (es.state.selected_tile_click) {
                    es.state.selected_tile_click = false;
                    es.state.selected_tile = null;
                }
            },

            else => {},
        }
    }

    }
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

var history_buf: std.ArrayList([]const u8) = undefined;

pub const EditorState = struct {
    gpa: std.heap.GeneralPurposeAllocator(.{}),
    allocator: std.mem.Allocator = undefined,
    view: math.Mat4 = undefined,
    proj: math.Mat4 = undefined,
    mouse_state: MouseState = .{},
    editor_scene_image: sg.Image = .{},
    editor_scene_image_depth: sg.Image = .{},
    attachment: sg.Attachments = .{},
    editor_config: EditorConfig = .{},
    zoom_factor: f32 = 0.25,
    selected_layer: RenderPassIds = .TILES_1,
    state: State = undefined,
    console: Console = undefined,

    pub fn init(self: *EditorState) !void {
        const gpa = std.heap.GeneralPurposeAllocator(.{}){};
        const allocator = std.heap.page_allocator;
        var s: State = undefined;
        try s.init(allocator);
        var c: Console = undefined;
        try c.init(allocator);
        self.* = .{
            .gpa = gpa,
            .allocator = allocator,
            .view = math.Mat4.identity(),
            .proj = mat4.ortho(
                -app.widthf() / 2 * zoom_factor + 50,
                app.widthf() / 2 * zoom_factor + 50,
                -app.heightf() / 2 * zoom_factor - 50,
                app.heightf() / 2 * zoom_factor - 50,
                -1,
                1,
            ),
            .state = s,
            .selected_layer = .TILES_1,
            .console = c,
        };
    }
};

var es: EditorState = undefined;
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
var attachment: sg.Attachments = .{};
var layout_initialized: bool = false;
var mouse_world_space: math.Vec4 = .{};
var scene_window_pos = ig.ImVec2_t{};
var scene_window_size = ig.ImVec2_t{};
var is_mouse_in_scene: bool = false;
var scene: Scene = undefined;
var buf: [8192]u8 = undefined;
var mouse_state: MouseState = .{};
var scene_list_buffer: std.ArrayList([]const u8) = undefined;
var new_temp_scene: Scene = .{};
var new_scene_open: bool = false;
var load_scene_open: bool = false;
var editor_config: EditorConfig = .{};
var console_buf: [8192]u8 = undefined;

const test_string = "HELLO FROM HERE";

const test_json =
    \\{
    \\    "pos": {
    \\        "x": 0,
    \\        "y": 0
    \\    },
    \\    "sprite_renderable": {
    \\        "pos": {
    \\            "x": 0e0,
    \\            "y": 1e2,
    \\            "z": 0e0
    \\        },
    \\        "sprite_id": 4.6e1,
    \\        "color": {
    \\            "x": 1e0,
    \\            "y": 1e0,
    \\            "z": 1e0,
    \\            "w": 1e0
    \\        }
    \\    },
    \\    "spawner": false,
    \\    "traversable": false
    \\}
;

pub fn editorInit() !void {

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
    try es.init();
    //const testtile = try std.json.parseFromSliceLeaky(Tile, allocator, test_json, .{});
    //std.log.info("{any}", .{testtile});
    try editor_config.loadConfig(es.allocator);
    //try Lua.luaTest();

    scene_list_buffer = std.ArrayList([]const u8).init(es.allocator);
    history_buf = std.ArrayList([]const u8).init(es.allocator);

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
    es.editor_scene_image = sg.makeImage(img_desc);

    var attachment_desc: sg.AttachmentsDesc = .{};
    attachment_desc.colors[0].image = es.editor_scene_image;
    img_desc.pixel_format = .DEPTH_STENCIL;

    es.editor_scene_image_depth = sg.makeImage(img_desc);
    attachment_desc.depth_stencil.image = es.editor_scene_image_depth;

    attachment = sg.makeAttachments(attachment_desc);

    //try scene.loadTestScene(allocator, &state);
    if (editor_config.mode == .BINARY) {
        try scene.loadTestScene(es.allocator, &es.state);
        //try Serde.loadSceneFromBinary(&scene, "t2.txt", std.heap.page_allocator);
        try Serde.writeSceneToJson(&scene, "t2.json", std.heap.page_allocator);
        es.state.loaded_scene = scene;
    } else if (editor_config.mode == .JSON) {
        try Serde.loadSceneFromJson(&scene, "t2.json", std.heap.page_allocator);
        es.state.loaded_scene = scene;
    }
    try es.state.loaded_scene.?.loadScene(&es.state.renderer);

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
pub fn editorFrame() !void {
    es.mouse_state.mouse_position_ig = ig.igGetMousePos();

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
    ig.igImage(imgui.imtextureid(es.editor_scene_image), ig.ImVec2{ .x = 700, .y = 440 });
    ig.igEnd();

    // Editor for Entity
    _ = ig.igBegin("Entity Editor", 0, ig.ImGuiWindowFlags_None);
    if (es.selected_layer == .TILES_1 or es.selected_layer == .TILES_2) {
        try TypeEditors.drawTileEditor(&es);
    } else {
        try TypeEditors.drawEntityEditor(&es);
    }
    ig.igEnd();

    // Drawer for data. This is unused for now, but something will go here.
    // Idea tab for animations, or Possible script viewer.
    // @todo Move this to the console editor file.
    try es.console.console(es.allocator);

    //for (0..test_string.len) |i| {
    //    const f: f32 = @floatFromInt(i);
    //    try state.renderer.render_passes.items[@intFromEnum(RenderPassIds.UI_1)].appendSpriteToBatch(.{
    //        .pos = .{ .x = f * 16 - 32, .y = 26, .z = 0 },
    //        .sprite_id = @floatFromInt(test_string[i]),
    //        .color = .{ .x = 0.1, .y = 1, .z = 0.5, .w = 1 },
    //    });
    //}

    var clamped_mouse_pos: math.Vec3 = undefined;
    if (es.mouse_state.hover_over_scene) {
        const grid_size = 16.0;
        const grid_offset_x = 0.0;
        const grid_offset_y = 0.0;
        clamped_mouse_pos = math.Vec3{
            .x = @floor((mouse_world_space.x - grid_offset_x) / grid_size) * grid_size + grid_offset_x,
            .y = @floor((mouse_world_space.y - grid_offset_y) / grid_size) * grid_size + grid_offset_y,
            .z = 0,
        };

        es.mouse_state.mouse_position_v2.x = clamped_mouse_pos.x;
        es.mouse_state.mouse_position_v2.y = clamped_mouse_pos.y;

        try es.state.renderer.render_passes.items[@intFromEnum(RenderPassIds.UI_1)].appendSpriteToBatch(.{ .pos = clamped_mouse_pos, .sprite_id = 1, .color = .{ .x = 0, .y = 0, .z = 0, .w = 0 }, },);
    }

    try left_window();

    // Prepare render data for instanced rendering
    const vs_params = util.computeVsParams(proj, view);
    es.state.updateBuffers();

    // === Render scene to image
    sg.beginPass(.{ .action = offscreen, .attachments = attachment });
    if (es.state.loaded_scene) |_| {
        es.state.render(vs_params);
    }
    if (!es.state.selected_tile_click) {
        es.state.collision(mouse_world_space);
    }
    sg.endPass();

    //Quad.drawQuad2dSpace(.{ .x = 10, .y = 10 }, .{ .x = 1, .y = 0, .z = 0 }, .{ .mvp = vs_params.mvp });

    // === Render IMGUI windows
    sg.beginPass(.{ .action = passaction, .swapchain = glue.swapchain() });
    imgui.render();
    sg.endPass();
    sg.commit();
    es.state.renderer.render_passes.items[@intFromEnum(RenderPassIds.UI_1)].batch.clearRetainingCapacity();
    es.state.renderer.render_passes.items[@intFromEnum(RenderPassIds.UI_1)].cur_num_of_sprite = 0;
}

pub fn editorCleanup() !void {
    //ig.igSaveIniSettingsToDisk("imgui.ini");
    imgui.shutdown();
}

pub fn editorEvent(ev: [*c]const app.Event) !void {
    es.mouse_state.mouseEvents(ev);
    // forward input events to sokol-imgui
    _ = imgui.handleEvent(ev.*);
    const ig_mouse = ig.igGetMousePos();

    if (util.aabbIG(ig_mouse, scene_window_pos, scene_window_size)) {
        es.mouse_state.hover_over_scene = true;
    } else {
        es.mouse_state.hover_over_scene = false;
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
            if (es.state.loaded_scene) |*s| {
                try Serde.writeSceneToBinary(s, s.scene_name);
            }
            ig.igCloseCurrentPopup();
        }
        if (ig.igButton("Load Scene")) {
            var level_dir = try std.fs.cwd().openDir("levels", .{});
            var level_walker = try level_dir.walk(es.allocator);
            while (try level_walker.next()) |entry| {
                try scene_list_buffer.append(try es.allocator.dupe(u8, entry.basename));
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
                        if (es.state.loaded_scene) |*loaded_scene| {
                            loaded_scene.deloadScene(es.allocator, &es.state);
                        }
                        var temp_scene: Scene = .{};
                        try Serde.loadSceneFromBinary(&temp_scene, s, es.allocator);
                        es.state.loaded_scene = temp_scene;
                        try es.state.loaded_scene.?.loadScene(&es.state.renderer);

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
                es.state.loaded_scene.?.deloadScene(es.allocator, &es.state);
                try new_temp_scene.tiles.setCapacity(es.allocator, @as(usize, @intFromFloat(new_temp_scene.width * new_temp_scene.height)));
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
                es.state.loaded_scene = new_temp_scene;
                try es.state.loaded_scene.?.loadScene(&es.state.renderer);
                try Serde.writeSceneToBinary(&es.state.loaded_scene.?, es.state.loaded_scene.?.scene_name);
                es.state.selected_tile = null;
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
    const text = try std.fmt.allocPrint(es.allocator, "frame duration: {d:.3}", .{app.frameDuration()});
    defer es.allocator.free(text);
    ig.igText(text.ptr);
    const render_pass_count = try std.fmt.allocPrint(es.allocator, "RenderPass Count: {d}", .{es.state.passes.len});
    defer es.allocator.free(render_pass_count);
    ig.igText(render_pass_count.ptr);

    ig.igNewLine();
    ig.igSameLine();
    ig.igText("Selected Layer");
    ig.igText(@tagName(es.selected_layer));
    for (std.meta.tags(RenderPassIds)) |id| {
        if (ig.igButton(@tagName(id).ptr)) {
            es.selected_layer = id;
        }
    }
    ig.igEndGroup();
    ig.igEnd();
}

export fn init() void {
    editorInit() catch unreachable;
}

export fn frame() void {
    editorFrame() catch unreachable;
}

export fn cleanup() void {
    editorCleanup() catch unreachable;
}
export fn event(ev: [*c]const app.Event) void {
    editorEvent(ev) catch unreachable;
}

pub fn main() !void {
    app.run(.{
        .init_cb = init,
        .frame_cb = frame,
        .event_cb = event,
        .cleanup_cb = cleanup,
        .width = 1200,
        .height = 800,
        .window_title = "HELLO",
    });
}
