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

const Console = @import("editor/console.zig");
const TypeEditors = @import("editor/entity_editor.zig");
const Quad = @import("renderer/RenderQuad.zig");
const Lua = @import("scripting/lua.zig");
const Serde = @import("serde.zig");
const State = @import("state.zig");
const types = @import("types.zig");
const RenderPassIds = types.RendererTypes.RenderPassIds;
const Scene = types.Scene;
const Entity = types.Entity;
const GroupTile = types.GroupTile;
const Tile = types.Tile;
const GlobalConstants = types.GlobalConstants;
const SpriteRenderable = types.RendererTypes.SpriteRenderable;
const AABB = types.AABB;
const util = @import("util.zig");
const math = util.math;
const mat4 = math.Mat4;

//
// EDITOR TYPES
//
pub const Input = struct {
    up        : bool = false,
    down      : bool = false,
    left      : bool = false,
    right     : bool = false,
    forward   : bool = false,
    backwards : bool = false,
};

pub const WindowDropdowns = struct {
    frame_data: bool = false,
    mouse_data: bool = false,
    layer_data: bool = false,
};

pub const Rect = struct {
    x      : f32,
    y      : f32,
    width  : f32,
    height : f32,

    pub fn rectFromAABB(aabb: AABB) Rect {
        return .{
            .x = aabb.min.x,
            .y = aabb.min.y,
            .width = aabb.max.x - aabb.min.x,
            .height = aabb.max.y - aabb.min.y,
        };
    }

    //
    // Assumption that point 2 is further.
    // IE start drag from left to right
    //
    pub fn rectFromPoints(
        p1: math.Vec2,
        p2: math.Vec2,
    ) Rect {
        return .{
            .x = p1.x,
            .y = p1.y,
            .width = p2.x - p1.x,
            .height = p2.y - p1.y,
        };
    }
};

//
// All the possible states that the cursor can be.
//
pub const Cursor = enum {
    inactive,
    editing_tile,
    moving_entity,
    editing_entity,
    moving_scene,
    box_select,
};

//
// Data structure to manage mouse information over
// many different files.
//
pub const MouseState = struct {
    cursor                    : Cursor = .inactive,
    mouse_position_ig         : ig.ImVec2_t = .{},
    mouse_position_v2         : math.Vec2 = .{},
    mouse_position_clamped_v2 : math.Vec2 = .{},
    hover_over_scene          : bool = false,
    moving_entity             : bool = false,
    mouse_clicked_left        : bool = false,
    click_and_hold_timer      : u32 = 0,
    select_box                : AABB = .{},
    select_box_start_grabed   : bool = false,

    //
    // Convert float mouse coords to snapped grid coords
    //
    pub fn mouseToGridv2(
        self: *MouseState,
    ) math.Vec2 {
        return .{
            .x = @intFromFloat(self.mouse_position_v2.x / 16.0),
            .y = @intFromFloat(self.mouse_position_v2.y / 16.0),
        };
    }

    //
    // This is the function that handles mouse input for the sokol events
    //
    pub fn mouseEvents(
        self: *MouseState,
        ev: [*c]const app.Event,
    ) !void {
        const eve = ev.*;

        if (eve.type == .MOUSE_SCROLL) {
            if (zoom_factor - 0.02 < 0.1) {
                zoom_factor = 0.1;
            }

            if (eve.scroll_y > 0.1 and zoom_factor < 5) {
                zoom_factor += 0.02;
            }

            if (eve.scroll_y < 0.1 and zoom_factor > 0.1) {
                zoom_factor -= 0.02;
            }

            es.proj = mat4.ortho(
                -app.widthf() / 2 * zoom_factor,
                app.widthf() / 2 * zoom_factor,
                -app.heightf() / 2 * zoom_factor,
                app.heightf() / 2 * zoom_factor,
                -1,
                1,
            );
        }

        if (ev.*.type == .MOUSE_MOVE) {}

        if (ev.*.type == .MOUSE_MOVE) {
            const mouse_rel_x = self.mouse_position_ig.x - scene_window_pos.x;
            const mouse_rel_y = self.mouse_position_ig.y - scene_window_pos.y;

            const texture_x = mouse_rel_x / 700.0;
            const texture_y = mouse_rel_y / 440.0;


            //
            // Adjust for texture coordinates for different
            // graphics apis
            //
            var ndc_x: f32 = 0;
            var ndc_y: f32 = 0;
            if (builtin.os.tag == .linux) {
                ndc_x = 1.0 - texture_x * 2.0;
                ndc_y = texture_y * 2.0 - 1.0;
            } else {
                ndc_x = texture_x * 2.0 - 1.0;
                ndc_y = 1.0 - texture_y * 2.0;
            }

            const view_proj = math.Mat4.mul(es.proj, es.view);
            const inv = math.Mat4.inverse(view_proj);
            mouse_world_space = math.Mat4.mulByVec4(inv, .{ .x = ndc_x, .y = ndc_y, .z = 0, .w = 1 });
        }
        if (ev.*.type == .MOUSE_MOVE and mouse_middle_down) {
            es.mouse_state.cursor = .moving_scene;
            if (builtin.os.tag == .linux) {
                es.view = math.Mat4.mul(es.view, math.Mat4.translate(.{
                    .x = zoom_factor * ev.*.mouse_dx,
                    .y = zoom_factor * ev.*.mouse_dy,
                    .z = 0,
                }));
            } else {
                es.view = math.Mat4.mul(es.view, math.Mat4.translate(.{
                    .x = zoom_factor * ev.*.mouse_dx,
                    .y = zoom_factor * -ev.*.mouse_dy,
                    .z = 0,
                }));
            }
        }


        if (ev.*.type == .MOUSE_DOWN or ev.*.type == .MOUSE_UP) {
            const mouse_pressed = ev.*.type == .MOUSE_DOWN;
            switch (ev.*.mouse_button) {
                .MIDDLE => {
                    mouse_middle_down = mouse_pressed;
                    if (!mouse_pressed) {
                        es.mouse_state.cursor = .inactive;
                    }
                },
                .LEFT => {
                    try self.leftMouseClick(mouse_pressed);
                },
                .RIGHT => {
                    if (es.state.selected_tile_click) {
                        es.state.selected_entity = null;
                        es.state.selected_tile_click = false;
                        es.state.selected_tile = null;
                        es.mouse_state.select_box = .{};
                    }

                    //
                    // Clear the group on click so as to not continue to break stuff.
                    //
                    es.al_tile_group_selected.clearAndFree();
                },

                else => {},
            }
        }
    }

    fn leftMouseClick(self: *MouseState, mouse_pressed: bool) !void {
        es.mouse_state.click_and_hold_timer = 0;
        es.mouse_state.mouse_clicked_left = mouse_pressed;

        if (!mouse_pressed) {
            if (es.mouse_state.cursor == .box_select and es.mouse_state.hover_over_scene) {
                es.mouse_state.select_box.max = es.mouse_state.mouse_position_v2;
                es.mouse_state.select_box_start_grabed = false;

                if (es.state.loaded_scene) |s| {
                    switch (es.selected_layer) {
                        .TILES_1 => {
                            try self.leftMouseClickTile1(&s);
                        },
                        .ENTITY_1 => {
                            for (0..s.entities.len) |i| {
                                const ent = s.entities.get(i);
                                if (util.aabbIG(
                                    .{.x = mouse_world_space.x, .y = mouse_world_space.y},
                                    .{.x = ent.pos.x, .y = ent.pos.y} ,
                                    .{.x = GlobalConstants.grid_size, .y = GlobalConstants.grid_size},)
                                 ) {
                                    es.state.selected_entity = i;
                                }
                            }
                        },
                        else => {},
                    }
                }
            }
            es.mouse_state.cursor = .inactive;
        }
        switch (es.mouse_state.cursor) {
            .inactive => {
                if (self.hover_over_scene) {
                    switch (es.selected_layer) {
                        .ENTITY_1 => {
                            if (es.state.loaded_scene) |s| {
                                for (0.., s.entities.items(.aabb)) |i, aabb| {
                                    if (util.aabbRec(es.mouse_state.mouse_position_v2, aabb)) {
                                        es.state.selected_entity = i;
                                    }
                                }
                            }
                        },
                        else => {},
                    }
                    if (es.state.selected_tile) |_| {
                        es.state.selected_tile_click = true;
                    }
                }
            },
            .editing_tile => {},
            .moving_entity => {},
            .editing_entity => {},
            .moving_scene => {},
            .box_select => {
                if (self.hover_over_scene) {
                    es.al_tile_group_selected.clearAndFree();
                    if (es.state.loaded_scene) |s| {
                        switch (es.selected_layer) {
                            .TILES_1 => {
                                try self.boxselectTile1(&s);
                            },
                            else => {},
                        }
                    }
                }
            },
        }

        // End switch
    }

    fn leftMouseClickTile1(
        self: *MouseState,
        s: *const Scene,
    ) !void {
        _ = self;
        for (0..s.tiles.len) |i| {
            const t = s.tiles.get(i);

            const tile_aabb: AABB = .{
                .min = .{
                    .x = t.sprite_renderable.pos.x,
                    .y = t.sprite_renderable.pos.y,
                },
                .max = .{
                    .x = t.sprite_renderable.pos.x + 16,
                    .y = t.sprite_renderable.pos.y + 16,
                },
            };

            const normalized_select_box: AABB = .{
                .min = .{
                    .x = @min(es.mouse_state.select_box.min.x, es.mouse_state.select_box.max.x),
                    .y = @min(es.mouse_state.select_box.min.y, es.mouse_state.select_box.max.y),
                },
                .max = .{
                    .x = @max(es.mouse_state.select_box.min.x, es.mouse_state.select_box.max.x),
                    .y = @max(es.mouse_state.select_box.min.y, es.mouse_state.select_box.max.y),
                },
            };

            if (util.aabbColl(tile_aabb, normalized_select_box)) {
                try es.al_tile_group_selected.append(.{ .id = i, .tile = t });
            }
        }
    }

    fn boxselectTile1(
        self: *MouseState,
        s: *const Scene,
    ) !void {
        _ = self;
        for (0..s.tiles.len) |i| {
            const t = s.tiles.get(i);

            const tile_aabb: AABB = .{
                .min = .{
                    .x = t.sprite_renderable.pos.x,
                    .y = t.sprite_renderable.pos.y,
                },
                .max = .{
                    .x = t.sprite_renderable.pos.x + 16,
                    .y = t.sprite_renderable.pos.y + 16,
                },
            };

            if (util.aabbColl(tile_aabb, es.mouse_state.select_box)) {
                try es.al_tile_group_selected.append(.{ .id = i, .tile = t });
            }
        }
}
};

//
// Serialization mode. Set in the config_editor.json file
//
const SerdeMode = enum {
    JSON,
    BINARY,
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
// Place to store the configuration. Its in its own struct
// as we dont know what other data I may want to have be
// configurable within the editor.
//
pub const EditorConfig = struct {
    mode: SerdeMode = .JSON,
    starting_level: []const u8 = "t1.json",

    pub fn loadConfig(
        self: *EditorConfig,
        allo: std.mem.Allocator,
    ) !void {
        var cwd = std.fs.cwd();

        var config_file = try cwd.openFile("config_editor.json", .{});
        defer config_file.close();

        const config_buf = try config_file.readToEndAlloc(allo, 1000);

        const temp = try std.json.parseFromSliceLeaky(EditorConfig, allo, config_buf, .{});
        self.mode = temp.mode;
    }
};

//
// This is the state management for the editor. This will likely
// be a changin structure as I figure out how to better abstract.
// However for the meantime having it be a monolith data structure
// I think is fine. It allows for easy iteration speeds.
//
pub const EditorState = struct {
    gpa                      : std.heap.GeneralPurposeAllocator(.{}),
    allocator                : std.mem.Allocator = undefined,

    // Global state
    state                    : State = undefined,

    //
    // @cleanup move these into a camera class. That allows for swapping
    // from orthographic to perspective if we move to 3d.
    //
    view                     : math.Mat4 = undefined,
    proj                     : math.Mat4 = undefined,
    mouse_state              : MouseState = .{},
    zoom_factor              : f32 = 0.25,

    // Render Surface
    editor_scene_image       : sg.Image = .{},
    editor_scene_image_depth : sg.Image = .{},
    attachment               : sg.Attachments = .{},

    // Serde info
    editor_config            : EditorConfig = .{},
    selected_layer           : RenderPassIds = .TILES_1,
    frame_count              : std.ArrayList(f32) = undefined,
    continuous_sprite_mode   : bool = false,
    al_tile_group_selected   : std.ArrayList(GroupTile) = undefined,
    al_lasso_tool_buffer     : std.ArrayList(SpriteRenderable) = undefined,

    window_dropdowns         : WindowDropdowns = .{},

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
            .selected_layer = .TILES_1,
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
        switch (self.editor_config.mode) {
            .BINARY => try Serde.loadSceneFromBinary(&scene, "t2.txt", std.heap.page_allocator),
            .JSON => try Serde.loadSceneFromJson(&scene, self.editor_config.starting_level, std.heap.page_allocator),
        }

        self.state.loaded_scene = scene;
        try self.state.loaded_scene.?.loadScene(&self.state.renderer);
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
                            try occupied.put(.{.x = @intFromFloat(lasso_sprite.pos.x) , .y = @intFromFloat(lasso_sprite.pos.y)}, true);
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
        self.state.renderer.render_passes.items[@intFromEnum(RenderPassIds.UI_1)].batch.clearRetainingCapacity();
        self.state.renderer.render_passes.items[@intFromEnum(RenderPassIds.UI_1)].cur_num_of_sprite = 0;
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


                try self.state.renderer.render_passes.items[@intFromEnum(RenderPassIds.UI_1)].appendSpriteToBatch(
                    item.*
                );
            }

            if (self.mouse_state.cursor != .box_select) {
                try self.state.renderer.render_passes.items[@intFromEnum(RenderPassIds.UI_1)].appendSpriteToBatch(
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
var es                 : EditorState = undefined;
var mouse_middle_down  : bool = false;
var view               : math.Mat4 = undefined;
var passaction         : sg.PassAction = .{};
var offscreen          : sg.PassAction = .{};
var image              : sg.Image = .{};
var input              : Input = .{};
var r                  : f32 = 0;
var proj               : math.Mat4 = undefined;
var zoom_factor        : f32 = 0.25;
var settings_docked    : bool = false;
var attachment         : sg.Attachments = .{};
var layout_initialized : bool = false;
var mouse_world_space  : math.Vec4 = .{};
var scene_window_pos = ig.ImVec2_t{};
var scene_window_size = ig.ImVec2_t{};
var is_mouse_in_scene  : bool = false;
var scene              : Scene = undefined;
var buf                : [8192]u8 = undefined;
var mouse_state        : MouseState = .{};
var scene_list_buffer  : std.ArrayList([]const u8) = undefined;
var new_temp_scene     : Scene = .{};
var new_scene_open     : bool = false;
var load_scene_open    : bool = false;
var editor_config      : EditorConfig = .{};
var console_buf        : [8192]u8 = undefined;
var occupied           : std.AutoHashMap(math.Vec2i, bool) = undefined;

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
    if (es.selected_layer == .TILES_1 or es.selected_layer == .TILES_2) {
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
    sg.endPass();

    //Quad.drawQuad2dSpace(.{ .x = 10, .y = 10 }, .{ .x = 1, .y = 0, .z = 0 }, .{ .mvp = vs_params.mvp });

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
            var level_dir = try std.fs.cwd().openDir("levels", .{ .iterate = true });
            var level_walker = try level_dir.walk(es.allocator);
            while (try level_walker.next()) |entry| {
                if (es.editor_config.mode == .JSON and std.mem.containsAtLeast(u8, entry.basename, 1, ".json")) {
                    try scene_list_buffer.append(try es.allocator.dupe(u8, entry.basename));
                } else if (es.editor_config.mode == .BINARY and std.mem.containsAtLeast(u8, entry.basename, 1, ".txt")) {
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
            ig.igPushIDInt(@intFromEnum(id));
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
