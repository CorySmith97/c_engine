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

        if (ig.igInputFloat("Sprite ID:", &entity.sprite_id)) {
            editor_state.state.loaded_scene.?.entities.set(s, entity);
            if (editor_state.state.renderer.render_passes.items[@intFromEnum(editor_state.selected_layer)].batch.items.len > s) {
                try editor_state.state.renderer.render_passes.items[@intFromEnum(editor_state.selected_layer)].updateSpriteRenderables(s, entity.toSpriteRenderable());
            }
        }
        if (ig.igButton("Move Default Location")) {
            editor_state.mouse_state.cursor = .moving_entity;
        }
        switch(editor_state.mouse_state.cursor) {
            .moving_entity => {
                entity.pos = editor_state.mouse_state.mouse_position_v2;
                editor_state.state.loaded_scene.?.entities.set(s, entity);

                if (editor_state.mouse_state.mouse_clicked_left) {
                    if (editor_state.state.renderer.render_passes.items[@intFromEnum(editor_state.selected_layer)].batch.items.len > s) {
                        try editor_state.state.renderer.render_passes.items[@intFromEnum(editor_state.selected_layer)].updateSpriteRenderables(s, entity.toSpriteRenderable());
                    }
                    editor_state.mouse_state.cursor = .inactive;
                }
            },
            else => {}
        }
    }
}

pub fn drawTileEditor(editor_state: *EditorState) !void {
    if (editor_state.state.selected_tile) |s| {
        if (editor_state.state.selected_tile_click) {
            var tile = editor_state.state.loaded_scene.?.tiles.get(s);
            const selected = try std.fmt.allocPrint(
                editor_state.allocator,
                "ENTID: {d}\nSprite id: {d}\nPos: {}, {}, {}",
                .{
                    s,
                    tile.sprite_renderable.sprite_id,
                    tile.sprite_renderable.pos.x,
                    tile.sprite_renderable.pos.y,
                    tile.sprite_renderable.pos.z,
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
            _ = ig.igInputFloat("Sprite ID: ", &tile.sprite_renderable.sprite_id);

            _ = ig.igCheckbox("Spawner", &tile.spawner);
            _ = ig.igCheckbox("Traversable", &tile.traversable);
            editor_state.state.loaded_scene.?.tiles.set(s, tile);

            if (editor_state.state.renderer.render_passes.items[@intFromEnum(editor_state.selected_layer)].batch.items.len > s) {
                try editor_state.state.renderer.render_passes.items[@intFromEnum(editor_state.selected_layer)].updateSpriteRenderables(s, tile.sprite_renderable);
            }
        }
    }
}
