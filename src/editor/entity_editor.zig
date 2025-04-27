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
const Entity = types.Entity;
const util = @import("../util.zig");
const math = util.math;
const mat4 = math.Mat4;

const log = std.log.scoped(.entity_editor);


const predefined_colors = [_]ig.ImVec4_t{
    .{ .x = 1.0, .y = 0.0, .z = 0.0, .w = 1.0 }, // red
    .{ .x = 0.0, .y = 1.0, .z = 0.0, .w = 1.0 }, // green
    .{ .x = 0.0, .y = 0.0, .z = 1.0, .w = 1.0 }, // blue
    .{ .x = 1.0, .y = 1.0, .z = 0.0, .w = 1.0 }, // yellow
    .{ .x = 1.0, .y = 1.0, .z = 1.0, .w = 1.0 }, // white
    .{ .x = 0.0, .y = 0.0, .z = 0.0, .w = 1.0 }, // black
    .{ .x = 0.824, .y = 0.706, .z = 0.549, .w = 1.0 } // brown
};

pub fn drawEntityEditor(editor_state: *EditorState) !void {
    if (ig.igButton("Add entity")) {
        if (editor_state.state.loaded_scene) |*scene| {
            const new_entity: Entity = .{};
            try scene.entities.append(editor_state.allocator, new_entity);
            editor_state.state.selected_entity = scene.entities.len - 1;
            try editor_state.state.renderer.render_passes.items[@intFromEnum(RenderPassIds.ENTITY_1)].appendSpriteToBatch(new_entity.toSpriteRenderable());
        }
    }
    if (editor_state.state.selected_entity) |s| {
        var entity = editor_state.state.loaded_scene.?.entities.get(s);
        const selected = try std.fmt.allocPrint(
            editor_state.allocator,
            \\ENTID: {d}
                \\Sprite id: {d}
                \\Pos: {d:.1}, {d:.1}
                \\Size: {d:.1}, {d:.1}
                \\Spritesheet id: {s}
                \\AABB:
                \\   min: {d:.1} {d:.1}
                \\   max: {d:.1} {d:.1}
                \\Selected: {}
                ,
            .{
                s,
                entity.sprite_id,
                entity.pos.x,
                entity.pos.y,
                entity.size.x,
                entity.size.y,
                @tagName(entity.spritesheet_id),
                entity.aabb.min.x,
                entity.aabb.min.y,
                entity.aabb.max.x,
                entity.aabb.max.y,
                entity.selected,
            },
        );
        defer editor_state.allocator.free(selected);
        ig.igText(selected.ptr);

        if (ig.igInputFloatEx("Sprite ID:", &entity.sprite_id, 1.0, 5.0, " ", ig.ImGuiInputTextFlags_None)) {
            editor_state.state.loaded_scene.?.entities.set(s, entity);
            try editor_state.updateSpriteRenderable(@constCast(&entity.toSpriteRenderable()), s);
        }
        if (ig.igButton("Move Default Location")) {
            editor_state.mouse_state.cursor = .moving_entity;
        }
        switch(editor_state.mouse_state.cursor) {
            .moving_entity => {
                entity.pos = editor_state.mouse_state.mouse_position_v2;
                editor_state.state.loaded_scene.?.entities.set(s, entity);

                if (editor_state.mouse_state.mouse_clicked_left) {
                    try editor_state.updateSpriteRenderable(@constCast(&entity.toSpriteRenderable()), s);
                    editor_state.mouse_state.cursor = .inactive;
                }
            },
            else => {}
        }
    }
}

            var ttile: Tile = .{};
// @todo add a save custom color button.
// @todo Have a seperate way to grab an item. IE One click. Not click and release.
pub fn drawTileEditor(editor_state: *EditorState) !void {
    if (ig.igButton("Continous Sprite Mode")) {
        editor_state.continuous_sprite_mode = editor_state.continuous_sprite_mode;
    }
    if (editor_state.state.selected_tile) |s| {
        if (editor_state.tile_group_selected.items.len > 0) {
            ig.igText("Group List Size: %d", editor_state.tile_group_selected.items.len);
            const selected = try std.fmt.allocPrint(
                editor_state.allocator,
                    \\Sprite id: {d}
                    \\Pos: {}, {}, {}
                    \\Spawner: {}
                    \\Traversable: {}
                    ,
                .{
                    ttile.sprite_renderable.sprite_id,
                    ttile.sprite_renderable.pos.x,
                    ttile.sprite_renderable.pos.y,
                    ttile.sprite_renderable.pos.z,
                    ttile.spawner,
                    ttile.traversable,
                },
            );
            defer editor_state.allocator.free(selected);
            ig.igText(selected.ptr);

            var color_array = ttile.sprite_renderable.color.toArray();
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
            }
            ttile.sprite_renderable.color = math.Vec4.fromArray(color_array);

            _ = ig.igInputFloatEx("Sprite ID:", &ttile.sprite_renderable.sprite_id, 1.0, 5.0, "%.0f", ig.ImGuiInputTextFlags_None);

            _ = ig.igCheckbox("Spawner", &ttile.spawner);
            _ = ig.igCheckbox("Traversable", &ttile.traversable);
            for (editor_state.tile_group_selected.items) |*gt| {
                gt.*.tile.spawner = ttile.spawner;
                gt.*.tile.traversable = ttile.traversable;
                gt.*.tile.sprite_renderable.sprite_id  = ttile.sprite_renderable.sprite_id;
                gt.*.tile.sprite_renderable.color  = ttile.sprite_renderable.color;
                ig.igText("id %d", gt.id);
                ig.igText("pos %.1f %.1f", gt.tile.sprite_renderable.pos.x, gt.tile.sprite_renderable.pos.y);

                editor_state.state.loaded_scene.?.tiles.set(gt.id, gt.*.tile);

                try editor_state.updateSpriteRenderable(&gt.*.tile.sprite_renderable, gt.id);

            }

        }
        if (editor_state.state.selected_tile_click and editor_state.tile_group_selected.items.len == 0) {
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
            }
            tile.sprite_renderable.color = math.Vec4.fromArray(color_array);

            _ = ig.igInputFloatEx("Sprite ID:", &tile.sprite_renderable.sprite_id, 1.0, 5.0, "%.0f", ig.ImGuiInputTextFlags_None);

            _ = ig.igCheckbox("Spawner", &tile.spawner);
            _ = ig.igCheckbox("Traversable", &tile.traversable);
            editor_state.state.loaded_scene.?.tiles.set(s, tile);

            try editor_state.updateSpriteRenderable(&tile.sprite_renderable, s);
        }
    }
}
