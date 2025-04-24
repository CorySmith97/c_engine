const std = @import("std");
const ig = @import("cimgui");
const sokol = @import("sokol");
const app = sokol.app;
const sg = sokol.gfx;
const slog = sokol.log;
const glue = sokol.glue;
const imgui = sokol.imgui;
const util = @import("../util.zig");
const math = util.math;
const mat4 = math.Mat4;
const types = @import("../types.zig");
const Entity = types.Entity;
const State = @import("../state.zig");
const EditorState = @import("../editor.zig").EditorState;

const predefined_colors = [_]ig.ImVec4_t{
    .{ .x = 1.0, .y = 0.0, .z = 0.0, .w = 1.0 }, // red
    .{ .x = 0.0, .y = 1.0, .z = 0.0, .w = 1.0 }, // green
    .{ .x = 0.0, .y = 0.0, .z = 1.0, .w = 1.0 }, // blue
    .{ .x = 1.0, .y = 1.0, .z = 0.0, .w = 1.0 }, // yellow
    .{ .x = 1.0, .y = 1.0, .z = 1.0, .w = 1.0 }, // white
    .{ .x = 0.0, .y = 0.0, .z = 0.0, .w = 1.0 }, // black
};

pub fn drawEntityEditor() !void {}

pub fn drawTileEditor(editor_state: *EditorState) !void {
    if (editor_state.state.selected_entity) |s| {
        if (editor_state.state.selected_entity_click) {
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
