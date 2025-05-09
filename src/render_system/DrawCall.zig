/// ===========================================================================
///
/// Author: Cory Smith
///
/// Date: 2025-04-22
///
/// Description:
/// ===========================================================================

const std = @import("std");
const log = std.log.scoped(.render_quad);
const sokol = @import("sokol");
const glue = sokol.glue;
const util = @import("../util.zig");
const math = util.math;
const shd = @import("../shaders/quad.glsl.zig");
const sg = sokol.gfx;

const Vao = &[_][]f32{
    [_]f32{},
    [_]f32{},
    [_]f32{},
    [_]f32{},
};

pub const GeneralPurposeRender = struct {
    draw_calls: std.ArrayList(DrawCall),
};

pub const DrawCall = struct {
    const Self = @This();
    pass_action: sg.PassAction = .{},
    pipeline: sg.Pipeline = .{},
    bindings: sg.Bindings = .{},
};

pub const ModelVertex = packed struct {
    pos: math.Vec3,
    normal: math.Vec3,
    uv: math.Vec2,
};

pub const Mesh = struct {
    vertices: std.ArrayList(ModelVertex),
    indices: std.ArrayList(u16),
};

//pub fn loadMeshObj(
//    path: []const u8,
//    mesh: *Mesh,
//) !void {
//    var file = try std.fs.cwd().openFile(path, .{});
//    defer file.close();
//
//    var reader = file.reader();
//
//
// 
//
//}



//
// Create Vertex bindings per frame for items such as quads.
//
pub fn drawQuad2dSpace(pos: math.Vec2, color: math.Vec3, mvp: math.Mat4) void {

    var dc: DrawCall = .{};
    const verts = [_]f32{
        0 + pos.x, 1 + pos.y, 0.0, color.x, color.y, color.z,
        1 + pos.x, 1 + pos.y, 0.0, color.x, color.y, color.z,
        1 + pos.x, 0 + pos.y, 0.0, color.x, color.y, color.z,
        0 + pos.x, 0 + pos.y, 0.0, color.x, color.y, color.z,
    };

    const indices = [_]u16{
        0, 1, 2,
        0, 2, 3,
    };
    dc.bindings.vertex_buffers[0] = sg.makeBuffer(.{
        .type = .VERTEXBUFFER,
        .data = sg.asRange(&verts),
    });
    defer sg.destroyBuffer(dc.bindings.vertex_buffers[0]);
    dc.bindings.index_buffer = sg.makeBuffer(.{
        .type = .INDEXBUFFER,
        .data = sg.asRange(&indices),
    });
    defer sg.destroyBuffer(dc.bindings.index_buffer);

    const quad_shd = sg.makeShader(shd.quadShaderDesc(sg.queryBackend()));
    defer sg.destroyShader(quad_shd);

    dc.pipeline = sg.makePipeline(.{
        .shader = quad_shd,
        .layout = init: {
            var l = sg.VertexLayoutState{};
            l.attrs[shd.ATTR_quad_position] = .{ .format = .FLOAT3, .buffer_index = 0 };
            l.attrs[shd.ATTR_quad_color] = .{ .format = .FLOAT3, .buffer_index = 0 };
            break :init l;
        },
        .index_type = .UINT16,
        .cull_mode = .BACK,
        .sample_count = 1,
    });
    defer sg.destroyPipeline(dc.pipeline);

    dc.pass_action.colors[0] = .{
        .load_action = .CLEAR,
        .clear_value = .{ .r = 0, .g = 0, .b = 0, .a = 1 },
    };

    sg.beginPass(.{ .action = dc.pass_action, .swapchain = glue.swapchain() });
    sg.applyPipeline(dc.pipeline);
    sg.applyBindings(dc.bindings);
    sg.applyUniforms(shd.UB_vs_params, sg.asRange(&.{.mvp = mvp}));
    sg.draw(0, 6, 1);
    sg.endPass();
}
