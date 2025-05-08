/// ===========================================================================
///
/// Author: Cory Smith
///
/// Date: 2025-04-22
///
/// Description:
/// ===========================================================================
const std = @import("std");

const ig = @import("cimgui");
const sokol = @import("sokol");
const app = sokol.app;
const sg = sokol.gfx;
const slog = sokol.log;
const glue = sokol.glue;
const imgui = sokol.imgui;

const EditorState = @import("../editor.zig").EditorState;
const State = @import("../state.zig");
const types = @import("../types.zig");
const Tile = types.Tile;
const RenderPassIds = types.RendererTypes.RenderPassIds;
const EntityNs = types.EntityNs;
const Entity = EntityNs.Entity;
const util = @import("../util.zig");
const math = util.math;
const mat4 = math.Mat4;

const log = std.log.scoped(.entity_editor);

const predefined_colors = [_]ig.ImVec4_t{
    .{ .x = 0.0, .y = 0.0, .z = 0.0, .w = 1.0 },         // Black (0, 0, 0)
    .{ .x = 1.0, .y = 0.0, .z = 0.0, .w = 1.0 },         // Red (31, 0, 0)
    .{ .x = 0.0, .y = 1.0, .z = 0.0, .w = 1.0 },         // Green (0, 31, 0)
    .{ .x = 0.0, .y = 0.0, .z = 1.0, .w = 1.0 },         // Blue (0, 0, 31)
    .{ .x = 1.0, .y = 1.0, .z = 0.0, .w = 1.0 },         // Yellow (31, 31, 0)
    .{ .x = 1.0, .y = 0.0, .z = 1.0, .w = 1.0 },         // Magenta (31, 0, 31)
    .{ .x = 0.0, .y = 1.0, .z = 1.0, .w = 1.0 },         // Cyan (0, 31, 31)
    .{ .x = 1.0, .y = 1.0, .z = 1.0, .w = 1.0 },         // White (31, 31, 31)
    .{ .x = 0.5, .y = 0.5, .z = 0.5, .w = 1.0 },         // Gray (15, 15, 15)
    .{ .x = 1.0, .y = 0.5, .z = 0.5, .w = 1.0 },         // Light Red (31, 15, 15)
    .{ .x = 0.5, .y = 1.0, .z = 0.5, .w = 1.0 },         // Light Green (15, 31, 15)
    .{ .x = 0.5, .y = 0.5, .z = 1.0, .w = 1.0 },         // Light Blue (15, 15, 31)
    .{ .x = 1.0, .y = 1.0, .z = 0.5, .w = 1.0 },         // Light Yellow (31, 31, 15)
    .{ .x = 1.0, .y = 0.5, .z = 1.0, .w = 1.0 },         // Light Magenta (31, 15, 31)
    .{ .x = 0.5, .y = 1.0, .z = 1.0, .w = 1.0 },         // Light Cyan (15, 31, 31)
    .{ .x = 0.824, .y = 0.706, .z = 0.549, .w = 1.0 },   // Brown ()
};

pub fn drawEntityEditor(
    editor_state: *EditorState,
) !void {

    const child_size = ig.ImVec2{ .x = 0, .y = 200 };

    if (ig.igBeginChild("Adding Entity", child_size, 0, ig.ImGuiWindowFlags_None)) {
        if (editor_state.state.loaded_scene) |*scene| {
            for (EntityNs.EntityList.keys()) |key|{
                if (ig.igButton(key.ptr)) {
                    const new_entity = EntityNs.EntityList.get(key).?;
                    try scene.entities.append(editor_state.allocator, new_entity);
                    editor_state.state.selected_entity = scene.entities.len - 1;
                    try editor_state.state.renderer.render_passes.items[@intFromEnum(RenderPassIds.map_entity_1)].appendSpriteToBatch(new_entity.sprite);
                }
            }
        }
    }
    ig.igEndChild();
    if (editor_state.state.selected_entity) |s| {
        var entity = editor_state.state.loaded_scene.?.entities.get(s);
        const selected = try std.fmt.allocPrint(
            editor_state.allocator,
            \\ENTID: {d}
            \\Sprite id: {d}
            \\Pos: {d:.1}, {d:.1}
            \\Spritesheet id: {s}
            \\AABB:
            \\   min: {d:.1} {d:.1}
            \\   max: {d:.1} {d:.1}
            \\Selected: {}
            \\Animation Frame: {}
        ,
            .{
                s,
                entity.sprite.sprite_id,
                entity.sprite.pos.x,
                entity.sprite.pos.y,
                @tagName(entity.spritesheet_id),
                entity.aabb.min.x,
                entity.aabb.min.y,
                entity.aabb.max.x,
                entity.aabb.max.y,
                entity.flags.selected,
                entity.animation.cur_frame,
            },
        );
        defer editor_state.allocator.free(selected);
        ig.igText(selected.ptr);

        if (ig.igInputFloatEx("Sprite ID:", &entity.sprite.sprite_id, 1.0, 5.0, " ", ig.ImGuiInputTextFlags_None)) {
        }

        try colorPickerEntity(&entity, editor_state);
        if (ig.igButton("Move Default Location")) {
            editor_state.mouse_state.cursor = .moving_entity;
        }
        switch (editor_state.mouse_state.cursor) {
            .moving_entity => {
                entity.sprite.pos = .{.x = editor_state.mouse_state.mouse_position_clamped_v2.x,
                                      .y = editor_state.mouse_state.mouse_position_clamped_v2.y,
                                      };
                editor_state.state.loaded_scene.?.entities.set(s, entity);

                if (editor_state.mouse_state.mouse_clicked_left) {
                    try editor_state.updateSpriteRenderable(&entity.sprite, s);
                    editor_state.mouse_state.cursor = .inactive;
                }
            },
            else => {},
        }
        editor_state.state.loaded_scene.?.entities.set(s, entity);
        try editor_state.updateSpriteRenderable(&entity.sprite, s);
    }
}

var model_tile: Tile = .{};

//
// @todo add a save custom color button.
// @todo Have a seperate way to grab an item. IE One click. Not click and release.
// @todo This needs to be show lasso, and then if the user wants, upate the sprites. Not default
// everything to black.
//
pub fn drawTileEditor(
    editor_state: *EditorState,
) !void {
    if (ig.igButton("Reset saved tile")) {
        model_tile = .{};
    }

    // @copypasta
    if (editor_state.state.selected_tile) |s| {
        if (editor_state.al_tile_group_selected.items.len > 0) {
            model_tile = editor_state.al_tile_group_selected.items[0].tile;
            ig.igText("Group List Size: %d", editor_state.al_tile_group_selected.items.len);
            const selected = try std.fmt.allocPrint(
                editor_state.allocator,
                \\Sprite id: {d}
                \\Pos: {}, {}, {}
                \\Spawner: {}
                \\Traversable: {}
            ,
                .{
                    model_tile.sprite_renderable.sprite_id,
                    model_tile.sprite_renderable.pos.x,
                    model_tile.sprite_renderable.pos.y,
                    model_tile.sprite_renderable.pos.z,
                    model_tile.spawner,
                    model_tile.traversable,
                },
            );
            defer editor_state.allocator.free(selected);
            ig.igText(selected.ptr);

            try colorPickerTile(&model_tile, editor_state);

            _ = ig.igInputFloatEx("Sprite ID:", &model_tile.sprite_renderable.sprite_id, 1.0, 5.0, "%.0f", ig.ImGuiInputTextFlags_None);

            _ = ig.igCheckbox("Spawner", &model_tile.spawner);
            _ = ig.igCheckbox("Traversable", &model_tile.traversable);


            //
            // @todo this needs to be not written until the user asks, or there
            // needs to be an undo button.
            //
            for (editor_state.al_tile_group_selected.items) |*gt| {

                //
                // Update each tile with the model tile.
                //
                gt.*.tile.spawner = model_tile.spawner;
                gt.*.tile.traversable = model_tile.traversable;
                gt.*.tile.sprite_renderable.sprite_id = model_tile.sprite_renderable.sprite_id;
                gt.*.tile.sprite_renderable.color = model_tile.sprite_renderable.color;

                // Update the tile in the scene
                editor_state.state.loaded_scene.?.tiles.set(gt.id, gt.*.tile);

                // Update renderer with the new sprite data
                try editor_state.updateSpriteRenderable(&gt.*.tile.sprite_renderable, gt.id);
            }
        }
        if (editor_state.state.selected_tile_click and editor_state.al_tile_group_selected.items.len == 0) {
            var tile = editor_state.state.loaded_scene.?.tiles.get(s);
            const selected = try std.fmt.allocPrint(
                editor_state.allocator,
                \\Tile id: {d}
                \\Sprite id: {d}
                \\Pos: {}, {}, {}
                \\Spawner: {}
                \\Traversable: {}
            ,
                .{
                    s,
                    tile.sprite_renderable.sprite_id,
                    tile.sprite_renderable.pos.x,
                    tile.sprite_renderable.pos.y,
                    tile.sprite_renderable.pos.z,
                    tile.spawner,
                    tile.traversable,
                },
            );
            defer editor_state.allocator.free(selected);
            ig.igText(selected.ptr);

            try colorPickerTile(&tile, editor_state);

            _ = ig.igInputFloatEx("Sprite ID:", &tile.sprite_renderable.sprite_id, 1.0, 5.0, "%.0f", ig.ImGuiInputTextFlags_None);

            _ = ig.igCheckbox("Spawner", &tile.spawner);
            _ = ig.igCheckbox("Traversable", &tile.traversable);

            editor_state.state.loaded_scene.?.tiles.set(s, tile);

            try editor_state.updateSpriteRenderable(&tile.sprite_renderable, s);
        }
    }
}



fn colorPickerEntity(
    entity: *Entity,
    editor_state: *EditorState,
) !void {
    var color_array = entity.sprite.color.toArray();

    _ = ig.igColorPicker4("Color", &color_array, ig.ImGuiColorEditFlags_None, null);
    _ = ig.igText("Preset Colors:");

    ig.igNewLine();

    for (predefined_colors, 0..) |preset, i| {
        ig.igSameLine();

        const str = try std.fmt.allocPrintZ(editor_state.allocator, "##c{}", .{i});
        defer editor_state.allocator.free(str);

        if (ig.igColorButton(
            str.ptr,
            preset,
            ig.ImGuiColorEditFlags_None,
        )) {
            color_array = [4]f32{ preset.x, preset.y, preset.z, preset.w };
        }

        if (@mod(i + 1, 5) == 0) {
            ig.igNewLine();
        }
    }
    entity.*.sprite.color = math.Vec4.fromArray(color_array);
}

fn colorPickerTile(
    tile: *Tile,
    editor_state: *EditorState,
) !void {
    var color_array = tile.sprite_renderable.color.toArray();

    _ = ig.igColorPicker4("Color", &color_array, ig.ImGuiColorEditFlags_None, null);
    _ = ig.igText("Preset Colors:");

    ig.igNewLine();

    for (predefined_colors, 0..) |preset, i| {
        ig.igSameLine();

        const str = try std.fmt.allocPrintZ(editor_state.allocator, "##c{}", .{i});
        defer editor_state.allocator.free(str);

        if (ig.igColorButton(
            str.ptr,
            preset,
            ig.ImGuiColorEditFlags_None,
        )) {
            color_array = [4]f32{ preset.x, preset.y, preset.z, preset.w };
        }

        if (@mod(i + 1, 5) == 0) {
            ig.igNewLine();
        }
    }
    tile.sprite_renderable.color = math.Vec4.fromArray(color_array);
}
