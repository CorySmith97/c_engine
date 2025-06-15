/// ===========================================================================
///
/// Author: Cory Smith
///
/// Date: 2025-04-22
///
/// Description:
/// ===========================================================================


const math = @import("../util.zig").math;
const std = @import("std");
const log = std.log.scoped(.RenderSystem);
const c = @cImport({
    @cInclude("cgltf.h");
});

//
// Flag for if render should shimmer
//
pub const SpriteRenderable = extern struct {
    pos       : math.Vec3 = .{},
    sprite_id : f32 = 0,
    color     : math.Vec4 = .{},
};

pub const Model = struct {
    pos         : math.Vec3 = .{},
    orientation : math.Mat4 = math.Mat4.identity(),
    mesh_count  : u32 = 0,
    meshes      : []f32 = undefined,
    data        : [*c]c.cgltf_data = undefined,


    pub fn init(
        m: *Model,
        path: []const u8,
    ) void {
        var cgltf_options: c.cgltf_options = .{};
        const res = c.cgltf_parse_file(&cgltf_options, path.ptr, &m.data);
        if (res == c.cgltf_result_success) {
            log.info("Mesh loaded: {s}", .{path});
        } else {
            log.info("Mesh failed to load: {s}", .{path});
        }

        const ld = c.cgltf_load_buffers(&cgltf_options, m.data, path.ptr);
        if (ld != c.cgltf_result_success) {
            return;
        }

        m.mesh_count = @intCast(m.data.*.meshes_count);
    }

    pub fn deinit(
        m: *Model,
    ) void {
        c.gltf_free(m.data);
    }

};

pub const pass_count: u32 = 4;

//
// map_ for map sprite
// combat_ for combat sprite
//
pub const RenderPassIds = enum(usize) {
    map_tiles_1,
    map_tiles_2,
    map_entity_1,
    //battle_entity_1,
    map_ui_1,
};
