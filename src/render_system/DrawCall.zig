/// ===========================================================================
///
/// Author: Cory Smith
///
/// Date: 2025-04-22
///
/// Description:
/// ===========================================================================

const std = @import("std");
const ArrayList = std.ArrayList;
const log = std.log.scoped(.render_quad);
const sokol = @import("sokol");
const glue = sokol.glue;
const util = @import("../util.zig");
const math = util.math;
const Vec2 = math.Vec2;
const Vec4 = math.Vec4;
const shd = @import("../shaders/quad.glsl.zig");
const sg = sokol.gfx;

//
// GeneralPurposeRender. The idea here is to be able to request to draw
// simple things. IE shapes, or perhaps one off textures. This then will
// create a command buffer. We then iterate through that command buffer.
//


pub const CommandBuffer = struct {
    add_enabled  : bool = false,
    pass_actions : ArrayList(sg.PassAction),
    pipelines    : ArrayList(sg.Pipeline),
    bindings     : ArrayList(sg.Bindings),
    mvps         : ArrayList(math.Mat4),
    call_count   : u32,

    pub fn init(
    self: *CommandBuffer,
    allocator: std.mem.Allocator,
    ) !void {
        self.pass_actions = ArrayList(sg.PassAction).init(allocator);
        self.pipelines = ArrayList(sg.Pipeline).init(allocator);
        self.bindings = ArrayList(sg.Bindings).init(allocator);
        self.mvps = ArrayList(math.Mat4).init(allocator);
    }
};

pub fn begin_drawing(
) void {
    cmd_buf.add_enabled = true;
}

pub fn end_drawing(
) void {
    cmd_buf.add_enabled = false;

    for (
        cmd_buf.pass_actions.items,
        cmd_buf.pipelines.items,
        cmd_buf.bindings.items,
        cmd_buf.mvps.items
    ) |pa, pipe, bind, mvp| {
        sg.beginPass(.{ .action = pa, .swapchain = glue.swapchain() });
        sg.applyPipeline(pipe);
        sg.applyBindings(bind);
        sg.applyUniforms(shd.UB_vs_params, sg.asRange(&.{.mvp = mvp}));
        sg.draw(0, 6, 1);
        sg.endPass();
    }
}

pub fn draw_rectangle(
    pos: Vec2,
    size: Vec2,
    color: Vec4,
    mvp: math.Mat4,
) !void {
    _ = pos;
    _ = size;
    _ = color;
    _ = mvp;
}

//
// State for basic Draw Calls
// This is immediate mode for the moment. IM TOO STUPID TO MAKE IT EFFECIENT
//
var cmd_buf: CommandBuffer = undefined;

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

const Vao = &[_][]f32{
    [_]f32{},
    [_]f32{},
    [_]f32{},
    [_]f32{},
};

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
