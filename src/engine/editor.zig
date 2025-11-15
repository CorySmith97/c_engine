/// ===========================================================================
///
/// Author: Cory Smith
///
/// Date: 2025-04-05
///
/// Description:
///     This is the entire editor in a single file basically.
///     It may be split apart later, but for now its completely
///     fine.
///
///     @todo:cs This is going to be rewritten to be small components. I want
///     the editor to live within the game. Allowing for easier dev mode. One
///     entry point overall into the system.
///
/// ===========================================================================

//
// EDITOR TYPES
//
pub const Input = struct {
    up: bool = false,
    down: bool = false,
    left: bool = false,
    right: bool = false,
    forward: bool = false,
    backwards: bool = false,
};


const SPRITE_TOP_EDGE = 4;
const SPRITE_BOTTOM_EDGE = 6;
const SPRITE_LEFT_EDGE = 5;
const SPRITE_RIGHT_EDGE = 4;
const SPRITE_TOP_LEFT_CORNER = 9;
const SPRITE_TOP_RIGHT_CORNER = 10;
const SPRITE_BOTTOM_LEFT_CORNER = 7;
const SPRITE_BOTTOM_RIGHT_CORNER = 8;
const SPRITE_CENTER = 11;


//
// This is the state management for the editor. This will likely
// be a changin structure as I figure out how to better abstract.
// However for the meantime having it be a monolith data structure
// I think is fine. It allows for easy iteration speeds.
//
pub const EditorState = struct {
    gpa: std.heap.GeneralPurposeAllocator(.{}),
    allocator: std.mem.Allocator = undefined,

    // Global state
    state: State = undefined,

    //
    // @cleanup move these into a camera class. That allows for swapping
    // from orthographic to perspective if we move to 3d.
    //
    // Editor state should have a camera, and game state should also
    // have its own camera.
    //
    view: math.Mat4 = undefined,
    proj: math.Mat4 = undefined,
    mouse_state: MouseState = .{},
    zoom_factor: f32 = 0.25,

    // Render Surface
    editor_scene_image: sg.Image = .{},
    editor_scene_image_depth: sg.Image = .{},
    attachment: sg.Attachments = .{},

    // Serde info
    editor_config: EditorConfig = .{},
    selected_layer: RenderPassIds = .map_tiles_1,
    frame_count: std.ArrayList(f32) = undefined,
    continuous_sprite_mode: bool = false,
    al_tile_group_selected: std.ArrayList(GroupTile) = undefined,
    al_lasso_tool_buffer: std.ArrayList(SpriteRenderable) = undefined,

    pub fn init(
        self: *EditorState,
    ) !void {
        const gpa = std.heap.GeneralPurposeAllocator(.{}){};
        const allocator = std.heap.page_allocator;

        var s: State = undefined;
        try s.init(allocator);

        try self.editor_config.loadConfig(allocator);

        occupied = std.AutoHashMap(math.Vec2i, bool).init(allocator);

        self.* = .{
            .gpa = gpa,
            .allocator = allocator,
            .view = math.Mat4.translate(.{ .x = -150, .y = -100, .z = 0 }),
            .proj = mat4.ortho(
                -app.widthf() / 2 * zoom_factor,
                app.widthf() / 2 * zoom_factor,
                -app.heightf() / 2 * zoom_factor,
                app.heightf() / 2 * zoom_factor,
                -1,
                1,
            ),
            .state = s,
            .selected_layer = .map_tiles_1,
            .frame_count = std.ArrayList(f32).init(allocator),
            .al_tile_group_selected = std.ArrayList(GroupTile).init(allocator),
            .al_lasso_tool_buffer = std.ArrayList(SpriteRenderable).init(allocator),
        };

        //
        // While in the editor, we render the game to a texture. that
        // texture is then rendered within an Imgui window.
        //
        var img_desc: sg.ImageDesc = .{
            .render_target = true,
            .width = 700,
            .height = 440,
            .pixel_format = .RGBA8,
            .sample_count = 1,
        };

        //
        // Image for scene needs both Image, and depth image
        //
        self.editor_scene_image = sg.makeImage(img_desc);

        var attachment_desc: sg.AttachmentsDesc = .{};

        attachment_desc.colors[0].image = es.editor_scene_image;
        img_desc.pixel_format = .DEPTH_STENCIL;

        self.editor_scene_image_depth = sg.makeImage(img_desc);
        attachment_desc.depth_stencil.image = es.editor_scene_image_depth;

        attachment = sg.makeAttachments(attachment_desc);

        //
        // Load the scene from disk Switch Depending on the mode we are in.
        //
        if (!std.mem.eql(u8, self.editor_config.starting_level, "")) {
            switch (self.editor_config.mode) {
                .BINARY => try Serde.loadSceneFromBinary(&scene, "t2.txt", std.heap.page_allocator),
                .JSON => try Serde.loadSceneFromJson(&scene, self.editor_config.starting_level, std.heap.page_allocator),
            }

            self.state.loaded_scene = scene;
            try self.state.loaded_scene.?.loadScene(&self.state.renderer);
        } else {
            self.state.loaded_scene = null;
        }
    }

    pub fn drawLassoFromAABB(
        self: *EditorState,
    ) !void {
        _ = self;
    }

    //
    // Draw the quad for multiselect with a lasso type sprite
    //
    pub fn drawMouseSelectBox(
        self: *EditorState,
    ) !void {
        switch (self.mouse_state.cursor) {
            .box_select => {

                //
                // This needs to be different as the select should be reactive
                // and the selected_tile_group is only grabbed once the mouse
                // is released
                //
                if (self.state.loaded_scene) |s| {
                    for (s.tiles.items(.sprite_renderable)) |sprite| {
                        const tile_aabb: AABB = .{
                            .min = .{
                                .x = sprite.pos.x,
                                .y = sprite.pos.y,
                            },
                            .max = .{
                                .x = sprite.pos.x + 16,
                                .y = sprite.pos.y + 16,
                            },
                        };

                        const normalized_select_box: AABB = .{
                            .min = .{
                                .x = @min(es.mouse_state.select_box.min.x, es.mouse_state.mouse_position_v2.x),
                                .y = @min(es.mouse_state.select_box.min.y, es.mouse_state.mouse_position_v2.y),
                            },
                            .max = .{
                                .x = @max(es.mouse_state.select_box.min.x, es.mouse_state.mouse_position_v2.x),
                                .y = @max(es.mouse_state.select_box.min.y, es.mouse_state.mouse_position_v2.y),
                            },
                        };

                        if (util.aabbColl(tile_aabb, normalized_select_box)) {
                            const lasso_sprite: SpriteRenderable = .{
                                .pos = sprite.pos,
                                .sprite_id = 2,
                                .color = .{ .x = 0, .y = 0, .z = 0, .w = 0 },
                            };
                            try occupied.put(.{ .x = @intFromFloat(lasso_sprite.pos.x), .y = @intFromFloat(lasso_sprite.pos.y) }, true);
                            try self.al_lasso_tool_buffer.append(lasso_sprite);
                        }
                    }
                }
            },
            else => {},
        }
    }

    pub fn deinit(
        self: *EditorState,
    ) void {
        self.frame_count.deinit();
        self.al_tile_group_selected.deinit();
        _ = self.gpa.deinit();
    }

    pub fn updateSpriteRenderable(
        self: *EditorState,
        sprite_ren: *const SpriteRenderable,
        s: usize,
    ) !void {
        //
        // Hopefully this is a nice wrapper to update sprites in the
        // layer we are currently working on
        //
        if (self.state.renderer.render_passes.items[@intFromEnum(self.selected_layer)].batch.items.len > s) {
            try self.state.renderer.render_passes.items[@intFromEnum(self.selected_layer)].updateSpriteRenderables(s, sprite_ren.*);
        }
    }

    pub fn resetUiBuffer(
        self: *EditorState,
    ) !void {

        //
        // The UI is rendered from scratch each from. We need to manually
        // change the buffers and recalc that every frame as it changes
        // often. This is called Immediate mode ui
        //
        self.state.renderer.render_passes.items[@intFromEnum(RenderPassIds.map_ui_1)].batch.clearRetainingCapacity();
        self.state.renderer.render_passes.items[@intFromEnum(RenderPassIds.map_ui_1)].cur_num_of_sprite = 0;
    }

    pub fn drawMouseUI(self: *EditorState) !void {
        if (self.mouse_state.hover_over_scene) {
            const grid_size = 16.0;
            self.mouse_state.mouse_position_clamped_v2 = .{
                .x = @floor((mouse_world_space.x) / grid_size) * grid_size,
                .y = @floor((mouse_world_space.y) / grid_size) * grid_size,
            };
            self.mouse_state.mouse_position_v2 = math.Vec2{
                .x = mouse_world_space.x,
                .y = mouse_world_space.y,
            };
            self.al_lasso_tool_buffer.clearAndFree();

            try self.drawMouseSelectBox();
            for (self.al_lasso_tool_buffer.items) |*item| {
                try self.state.renderer.render_passes.items[@intFromEnum(RenderPassIds.map_ui_1)].appendSpriteToBatch(item.*);
            }

            if (self.mouse_state.cursor != .box_select) {
                try self.state.renderer.render_passes.items[@intFromEnum(RenderPassIds.map_ui_1)].appendSpriteToBatch(
                    .{
                        .pos = .{
                            .x = @floor((mouse_world_space.x) / grid_size) * grid_size,
                            .y = @floor((mouse_world_space.y) / grid_size) * grid_size,
                            .z = 0,
                        },
                        .sprite_id = 1,
                        .color = .{ .x = 0, .y = 0, .z = 0, .w = 0 },
                    },
                );
            }
        }
    }
};

//
// STATIC VARIABLES FOR EDITOR
// These are varaibles that only live within this file.
// These are primarily for testing and for having a global
// editor state.
//
// @refactor many of these things can move to the editor state
//
pub var es: EditorState = undefined;
var mouse_middle_down: bool = false;
//
// mat[3][0] camera x pos
// mat[3][1] camera y pos
//
var view: math.Mat4 = undefined;
var passaction: sg.PassAction = .{};
var offscreen: sg.PassAction = .{};
var image: sg.Image = .{};
var input: Input = .{};
var r: f32 = 0;
var proj: math.Mat4 = undefined;
pub var zoom_factor: f32 = 0.25;
var settings_docked: bool = false;
var attachment: sg.Attachments = .{};
var layout_initialized: bool = false;
var mouse_world_space: math.Vec4 = .{};
pub var scene_window_pos = ig.ImVec2_t{};
pub var scene_window_size = ig.ImVec2_t{};
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
var occupied: std.AutoHashMap(math.Vec2i, bool) = undefined;

//
// ===========================================================================
// Main Initialization function for the Editor
// Passed to Sokol as the init function through a wrapper
//
pub fn editorInit() !void {

    //
    // Graphics initialization
    //
    sg.setup(.{
        .environment = glue.environment(),
        .logger = .{ .func = slog.func },
    });

    imgui.setup(.{
        .logger = .{ .func = slog.func },
        .ini_filename = "imgui.ini",
    });

    //
    // State Initialization
    //
    try es.init();

    //
    // Static Variable Initialization
    //
    scene_list_buffer = std.ArrayList([]const u8).init(es.allocator);

    const io = ig.igGetIO();
    io.*.ConfigFlags |= ig.ImGuiConfigFlags_DockingEnable;
    io.*.ConfigFlags |= ig.ImGuiConfigFlags_ViewportsEnable;
    ig.igLoadIniSettingsFromDisk(io.*.IniFilename);

    // Default pass actions
    passaction.colors[0] = .{
        .load_action = .CLEAR,
        .clear_value = .{ .r = 0.2, .g = 0.2, .b = 0.2, .a = 2 },
    };

    offscreen.colors[0] = .{
        .load_action = .CLEAR,
        .clear_value = .{ .r = 0.2, .g = 0.2, .b = 0.2, .a = 2 },
    };
}

//
// ===========================================================================
// Frame function for Sokol
// wrapped for error handling
//
pub fn editorFrame() !void {

    //
    // Update Logic
    //

    const store = es.selected_layer;
    es.selected_layer = .map_entity_1;
    //
    // @cleanup I hate the way this is currently working. Scene should hold this logic
    //
    if (es.state.loaded_scene) |s| {
        for (0.., s.entities.items(.sprite)) |i, *sprite| {
            try es.updateSpriteRenderable(sprite, i);
        }
    }

    //
    // When editing, we dont want to update animations. When it saves it causes
    // issues.
    //
    //if (es.state.loaded_scene) |s| {
    //    for (s.entities.items(.sprite), s.entities.items(.animation)) |*sprite, *animation| {
    //        sprite.sprite_id = EntityNs.updateAnimation(animation);
    //    }
    //}
    es.selected_layer = store;
    try es.frame_count.append(@floatCast(app.frameDuration()));
    es.mouse_state.mouse_position_ig = ig.igGetMousePos();
    if (es.mouse_state.mouse_clicked_left) {

        //
        // @cleanup This is a terrible way to determine if multiselect
        // should be used. Its tied to framerate, and also feels
        // incredibly jank
        //
        es.mouse_state.click_and_hold_timer += 1;
        if (es.mouse_state.click_and_hold_timer >= 10 and es.mouse_state.hover_over_scene) {
            es.mouse_state.cursor = .box_select;
            if (!es.mouse_state.select_box_start_grabed) {
                es.mouse_state.select_box.min = es.mouse_state.mouse_position_v2;
                es.mouse_state.select_box_start_grabed = true;
            }
        }
    }

    //
    // Render System
    //

    //
    // Imgui Frame setup
    //
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

    //
    // Create a dockspace to enable window docking
    //
    _ = ig.igBegin("DockSpace", null, window_flags);
    const dockspace_id = ig.igGetIDStr("MyDockSpace".ptr, null);
    _ = ig.igDockSpace(dockspace_id);
    ig.igSetNextWindowDockID(dockspace_id, ig.ImGuiCond_Once);
    ig.igEnd();

    //
    // Game scene renderer. Game rendered to a texture
    //
    ig.igSetNextWindowDockID(dockspace_id, ig.ImGuiCond_Once);
    _ = ig.igBegin("Scene", 0, ig.ImGuiWindowFlags_None);
    scene_window_pos = ig.igGetWindowPos();
    scene_window_size = ig.igGetContentRegionAvail();
    ig.igImage(imgui.imtextureid(es.editor_scene_image), ig.ImVec2{ .x = 700, .y = 440 });
    ig.igEnd();

    //
    // Editor for Entity
    //
    _ = ig.igBegin("Entity Editor", 0, ig.ImGuiWindowFlags_None);
    if (es.selected_layer == .map_tiles_1 or es.selected_layer == .map_tiles_2) {
        try TypeEditors.drawTileEditor(&es);
    } else {
        try TypeEditors.drawEntityEditor(&es);
    }
    ig.igEnd();

    //
    // Drawer for data. This is unused for now, but something will go here.
    // Idea tab for animations, or Possible script viewer.
    //
    try es.state.console.console(
        es.allocator,
        &es.state,
    );

    try es.drawMouseUI();
    try left_window();

    //
    // Prepare render data for instanced rendering
    //
    const vs_params = util.computeVsParams(es.proj, es.view);
    es.state.updateBuffers();

    //
    // Render scene to image
    //
    sg.beginPass(.{ .action = offscreen, .attachments = attachment });
    if (es.state.loaded_scene) |_| {
        es.state.render(vs_params);
    }
    if (!es.state.selected_tile_click) {
        es.state.collision(mouse_world_space);
    }

    //
    // This is a temporary Text system for the game. Its ascii only. Which
    // limits language to english primarily.
    //
    sdtx.canvas(app.widthf() * 0.5, app.heightf() * 0.5);
    sdtx.origin(0.0, 10.0);
    sdtx.home();

    sdtx.puts("Test string");
    //RenderSystem.printFont(0, "Hello", 255, 255, 255);

    sdtx.draw();
    sg.endPass();

    //
    // Render IMGUI windows
    //
    sg.beginPass(.{ .action = passaction, .swapchain = glue.swapchain() });
    imgui.render();
    sg.endPass();
    sg.commit();

    try es.resetUiBuffer();
}

pub fn editorCleanup() !void {
    es.deinit();
    //ig.igSaveIniSettingsToDisk("imgui.ini");
    imgui.shutdown();
}

pub fn editorEvent(ev: [*c]const app.Event) !void {
    try es.mouse_state.mouseEvents(ev);

    //
    // forward input events to sokol-imgui
    //
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
                es.view = math.Mat4.mul(es.view, math.Mat4.translate(.{ .x = zoom_factor * 10, .y = zoom_factor * 0, .z = 0 }));
            },
            .RIGHT => {
                es.view = math.Mat4.mul(es.view, math.Mat4.translate(.{ .x = zoom_factor * -10, .y = zoom_factor * 0, .z = 0 }));
            },
            .UP => {
                es.view = math.Mat4.mul(es.view, math.Mat4.translate(.{ .x = zoom_factor * 0, .y = zoom_factor * -10, .z = 0 }));
            },
            .DOWN => {
                es.view = math.Mat4.mul(es.view, math.Mat4.translate(.{ .x = zoom_factor * 0, .y = zoom_factor * 10, .z = 0 }));
            },
            .W => input.forward = key_pressed,
            .S => input.backwards = key_pressed,
            .A => input.left = key_pressed,
            .D => input.right = key_pressed,
            //.ESCAPE => app.quit(),
            else => {},
        }
    }
}

//
// ===========================================================================
// Main Menu. What is found at the top of the screen.
//
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
                //try Serde.writeSceneToBinary(s, s.scene_name);
                try Serde.writeSceneToJson(s, s.scene_name, es.allocator);
            }
            ig.igCloseCurrentPopup();
        }
        if (ig.igButton("Load Scene")) {
            var level_dir = try std.fs.cwd().openDir("src/game/levels", .{ .iterate = true });
            var level_walker = try level_dir.walk(es.allocator);
            while (try level_walker.next()) |entry| {
                try scene_list_buffer.append(try es.allocator.dupe(u8, entry.basename));
                if (es.editor_config.mode == .BINARY and std.mem.containsAtLeast(u8, entry.basename, 1, ".txt")) {
                    try scene_list_buffer.append(try es.allocator.dupe(u8, entry.basename));
                }
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
                        es.state.selected_cell = null;
                        es.state.selected_tile = null;
                        es.state.selected_entity = null;
                        // @todo load a scene, and set the scene to the state loaded scene
                        if (es.state.loaded_scene) |*loaded_scene| {
                            loaded_scene.deloadScene(es.allocator, &es.state);
                        }
                        var temp_scene: Scene = .{};
                        try Serde.loadSceneFromJson(&temp_scene, s, es.allocator);
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
                if (es.state.loaded_scene) |*s| {
                    s.deloadScene(es.allocator, &es.state);
                }
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

    if (es.frame_count.items.len > 60) {
        _ = es.frame_count.orderedRemove(0);
    }

    if (ig.igCollapsingHeader("Frame Data", ig.ImGuiTreeNodeFlags_DefaultOpen)) {
        ig.igText("Frame info");
        ig.igPlotLinesEx(
            " ",
            es.frame_count.items.ptr,
            @intCast(es.frame_count.items.len),
            0,
            " ",
            0.006,
            0.012,
            .{ .x = 200, .y = 80 },
            4,
        );
    }
    if (ig.igCollapsingHeader("Mouse Data", ig.ImGuiTreeNodeFlags_DefaultOpen)) {
        ig.igBeginGroup();
        ig.igText(
            "Mouse Cursor State:",
        );
        ig.igText(@tagName(es.mouse_state.cursor));
        ig.igText(
            \\MouseFlags:
            \\
            \\Mouse Over Scene: %d
            \\Mouse Clicked Left: %d
            \\Mouse Click Timer: %d
            \\Mouse Position: %.1f, %.1f
            \\Mouse Select min: %.1f, %.1f
            \\Mouse Select max: %.1f, %.1f
            \\
        ,
            es.mouse_state.hover_over_scene,
            es.mouse_state.mouse_clicked_left,
            es.mouse_state.click_and_hold_timer,
            es.mouse_state.mouse_position_v2.x,
            es.mouse_state.mouse_position_v2.y,
            es.mouse_state.select_box.min.x,
            es.mouse_state.select_box.min.y,
            es.mouse_state.select_box.max.x,
            es.mouse_state.select_box.max.y,
        );
        ig.igEndGroup();
    }
    if (ig.igCollapsingHeader("Render Data", ig.ImGuiTreeNodeFlags_None)) {
        const render_pass_count = try std.fmt.allocPrint(es.allocator, "RenderPass Count: {d}", .{es.state.passes.len});
        defer es.allocator.free(render_pass_count);
        ig.igText(render_pass_count.ptr);

        ig.igNewLine();
        ig.igSameLine();
        ig.igText("Selected Layer");
        ig.igText(@tagName(es.selected_layer));
        ig.igNewLine();
        for (std.meta.tags(RenderPassIds)) |id| {
            ig.igPushIDInt(@intCast(@intFromEnum(id)));
            if (ig.igButton(@tagName(id).ptr)) {
                es.selected_layer = id;
            }
            ig.igSameLine();
            _ = ig.igCheckbox("Enable ##c", &es.state.renderer.render_passes.items[@intFromEnum(id)].enabled);
            ig.igPopID();
        }
    }
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
        .window_title = "C-engine",
    });
}

//
// THIS IS A CUSTOM LOG INTERFACE
// It makes logs look better for the default logging interface
// found in std.log
//
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
    const prefix = "[" ++ comptime level.asText() ++ "] " ++ "(" ++ @tagName(scope) ++ "):\t";

    // Print the message to stderr, silently ignoring any errors
    std.debug.lockStdErr();
    defer std.debug.unlockStdErr();
    const stderr = std.io.getStdErr().writer();
    nosuspend stderr.print(prefix ++ format ++ "\n", args) catch return;
}


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

const RenderSystem = @import("render_system.zig");

const Console = @import("editor/console.zig");
const MouseState = @import("editor/mouse.zig");
const EditorConfig = @import("editor/config.zig");
const TypeEditors = @import("editor/entity_editor.zig");
const Quad = @import("render_system/DrawCall.zig");
const Serde = @import("util/serde.zig");
const State = @import("engine_state.zig");
const types = @import("types.zig");
const RenderPassIds = types.RendererTypes.RenderPassIds;
const Scene = types.Scene;
const EntityNs = types.EntityNs;
const Entity = EntityNs.Entity;
const GroupTile = types.GroupTile;
const Tile = types.Tile;
const GlobalConstants = types.GlobalConstants;
const SpriteRenderable = types.RendererTypes.SpriteRenderable;
const AABB = types.AABB;
const util = @import("util.zig");
const math = util.math;
const mat4 = math.Mat4;
