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
const shd = @import("../shaders/basic.glsl.zig");
const sg = sokol.gfx;

const c = @cImport({
    @cInclude("stb_image.h");
});

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
    width: f32 = 0,
    height: f32 = 0,
    image: sg.Image = .{},

    pub fn load_texture(
        path: []const u8
    ) !Texture2d {
        var text: Texture2d = .{};
        var x: c_int = 0;
        var y: c_int = 0;
        var chan: c_int = 0;

        c.stbi_set_flip_vertically_on_load(1);
        const data = c.stbi_load(path.ptr, &x, &y, &chan, 4);

        sg.initImage(text.image, .{
            .width = x,
            .height = y,
            .pixel_format = .RGBA8,
            .data = init: {
                var idata = sg.ImageData{};
                idata.subimage[0][0] = .{
                    .ptr = data,
                    .size = @as(usize, @intCast(x * y * chan)),
                };
                break :init idata;
            },
        });

        text.width = x;
        text.height = y;
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
        basic_shd = sg.makeShader(shd.basicTextureShaderDesc(sg.queryBackend()));
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
            var col: [4]sg.ColorTargetState = @splat(.{});
            col[0].pixel_format = .RGBA8;
            col[0].blend = .{
                .enabled = true,
                .src_factor_rgb = .SRC_ALPHA,
                .dst_factor_rgb = .ONE_MINUS_SRC_ALPHA,
                .src_factor_alpha = .ONE,
                .dst_factor_alpha = .ONE_MINUS_SRC_ALPHA,
            };
            break :init col;
        },
    });
    //defer sg.destroyPipeline(pipeline);

    try cmd_buf.pass_actions.append(pass_action);
    try cmd_buf.bindings.append(bindings);
    try cmd_buf.pipelines.append(pipeline);
    try cmd_buf.mvps.append(mvp);
}

pub fn drawTexture(
    texture: Texture2d,
    pos: Vec2,
    scale: f32,
    color: Vec4,
) !void {
    _ = scale;
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
        pos.x, pos.y + texture.height, 0, color.x, color.y, color.z, color.w,
        pos.x + texture.width, pos.y, 0, color.x, color.y, color.z, color.w,
        pos.x + texture.width, pos.y + texture.height, 0, color.x, color.y, color.z, color.w,
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
            var col: [4]sg.ColorTargetState = @splat(.{});
            col[0].pixel_format = .RGBA8;
            col[0].blend = .{
                .enabled = true,
                .src_factor_rgb = .SRC_ALPHA,
                .dst_factor_rgb = .ONE_MINUS_SRC_ALPHA,
                .src_factor_alpha = .ONE,
                .dst_factor_alpha = .ONE_MINUS_SRC_ALPHA,
            };
            break :init col;
        },
    });
    //defer sg.destroyPipeline(pipeline);

    try cmd_buf.pass_actions.append(pass_action);
    try cmd_buf.bindings.append(bindings);
    try cmd_buf.pipelines.append(pipeline);
    //try cmd_buf.mvps.append(mvp);
}

pub fn drawLine(
    start: Vec2,
    end: Vec2,
    color: Vec4,
) !void {
    _ = color;
    _ = start;
    _ = end;
}
