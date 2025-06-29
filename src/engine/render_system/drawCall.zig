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

//
// State for basic Draw Calls
// This is immediate mode for the moment. IM TOO STUPID TO MAKE IT EFFECIENT
//
var cmd_buf: CommandBuffer = undefined;
var default_pass_action: sg.PassAction = .{};
var basic_shd: sg.Shader = .{};

pub const ShaderParams = union {

};

pub const Texture2d = struct {
    image: sg.Image = .{},

    pub fn load_texture(path: []const u8) !Texture2d {
        _ = path;
    }
};

const CommandBuffer = struct {
    add_enabled  : bool = false,
    swapchain    : sg.Swapchain = .{},
    pass_actions : ArrayList(sg.PassAction),
    pipelines    : ArrayList(sg.Pipeline),
    bindings     : ArrayList(sg.Bindings),
    mvps         : ArrayList(math.Mat4),
    call_count   : u32,

    pub fn init(
    self: *CommandBuffer,
    allocator: std.mem.Allocator,
    ) !void {
        default_pass_action.colors[0] = .{
            .clear_value = .{ .r = 0, .g = 0, .b = 0, .a = 1 },
        };
        basic_shd = sg.makeShader(shd.quadShaderDesc(sg.queryBackend()));
        self.pipelines = ArrayList(sg.Pipeline).init(allocator);
        self.pass_actions = ArrayList(sg.PassAction).init(allocator);
        self.bindings = ArrayList(sg.Bindings).init(allocator);
        self.mvps = ArrayList(math.Mat4).init(allocator);
    }

    pub fn deinit(
        self: *CommandBuffer,
    ) void {
        _ = self;
        sg.destroyShader(basic_shd);
    }
};

pub fn init_drawing(allocator: std.mem.Allocator) !void {
    try cmd_buf.init(allocator);
}

pub fn begin_drawing(
) void {
    cmd_buf.add_enabled = true;
    //sg.beginPass(.{ .action = default_pass_action, .swapchain = swapchain });
}

pub fn end_drawing(
) void {
    cmd_buf.add_enabled = false;

    //
    // Draw everything
    //
    for (
        cmd_buf.pipelines.items,
        cmd_buf.bindings.items,
        cmd_buf.mvps.items
    ) |pipe, bind, mvp| {
        sg.applyPipeline(pipe);
        sg.applyBindings(bind);
        sg.applyUniforms(shd.UB_vs_params, sg.asRange(&.{.mvp = mvp}));
        sg.draw(0, 6, 1);
    }
    //sg.endPass();

    //
    // Then Clean it up
    //
}

pub fn cleanup() void {
    for (
        cmd_buf.bindings.items,
        cmd_buf.pipelines.items,
    ) |bind, pipe| {
        sg.destroyPipeline(pipe);
        sg.destroyBuffer(bind.vertex_buffers[0]);
        sg.destroyBuffer(bind.index_buffer);
    }

    cmd_buf.pass_actions.clearRetainingCapacity();
    cmd_buf.pipelines.clearRetainingCapacity();
    cmd_buf.bindings.clearRetainingCapacity();
    cmd_buf.mvps.clearRetainingCapacity();

}

pub fn draw_rectangle(
    pos: Vec2,
    size: Vec2,
    color: Vec4,
    mvp: math.Mat4,
) !void {
    var pass_action: sg.PassAction = .{};
    pass_action.colors[0] = .{
            .clear_value = .{ .r = 0, .g = 0, .b = 0, .a = 1 },
        };
    // create Vao
    // create indices
    // bind
    // use basic shader
    // add everything to the command buffer
    const verts = [_]f32{
        pos.x, pos.y, 0, color.x, color.y, color.z, color.w,
        pos.x, pos.y + size.y, 0, color.x, color.y, color.z, color.w,
        pos.x + size.x, pos.y, 0, color.x, color.y, color.z, color.w,
        pos.x + size.x, pos.y + size.y, 0, color.x, color.y, color.z, color.w,
    };

    const indices = [_]u16{
        0,1,2,
        1,3,2,
    };

    const vao = sg.makeBuffer(.{
        .type = .VERTEXBUFFER,
        .data = sg.asRange(&verts),
    });
    //defer sg.destroyBuffer(vao);

    const ebo = sg.makeBuffer(.{
        .data = sg.asRange(&indices),
        .type = .INDEXBUFFER,
    });
    //defer sg.destroyBuffer(ebo);

    var bindings: sg.Bindings = .{};
    bindings.vertex_buffers[0] = vao;
    bindings.index_buffer = ebo;


    // @todo:cs make this be something that is changed not via function but rather
    // a longer standing structure
    const pipeline = sg.makePipeline(.{
        .shader = basic_shd,
        .layout = init: {
            var l = sg.VertexLayoutState{};
            l.attrs[shd.ATTR_quad_position] = .{ .format = .FLOAT3, .buffer_index = 0 };
            l.attrs[shd.ATTR_quad_color] = .{ .format = .FLOAT4, .buffer_index = 0 };
            break :init l;
        },
        .index_type = .UINT16,
        .cull_mode = .BACK,
        .sample_count = 1,
        .colors = init: {
            var c: [4]sg.ColorTargetState = @splat(.{});
            c[0].pixel_format = .RGBA8;
            c[0].blend = .{
                .enabled = true,
                .src_factor_rgb = .SRC_ALPHA,
                .dst_factor_rgb = .ONE_MINUS_SRC_ALPHA,
                .src_factor_alpha = .ONE,
                .dst_factor_alpha = .ONE_MINUS_SRC_ALPHA,
            };
            break :init c;
        },
    });
    //defer sg.destroyPipeline(pipeline);

    try cmd_buf.pass_actions.append(pass_action);
    try cmd_buf.bindings.append(bindings);
    try cmd_buf.pipelines.append(pipeline);
    try cmd_buf.mvps.append(mvp);
}



// @old:cs I may or may not implement 3d. Havent decided.
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
