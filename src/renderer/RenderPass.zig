const std = @import("std");
const sokol = @import("sokol");
const util = @import("../util.zig");
const math = util.math;
const shd = @import("../shaders/basic.glsl.zig");
const cim = @cImport({
    @cInclude("stb_image.h");
});
const sg = sokol.gfx;
const types = @import("../types.zig");
const Scene = types.Scene;
const Entity = types.Entity;
const RendererTypes = types.RendererTypes;
const SpriteRenderable = RendererTypes.SpriteRenderable;
const log = std.log.scoped(.render_pass);

fn xorshift32() u32 {
    const static = struct {
        var x: u32 = 0x12345678;
    };
    var x = static.x;
    x ^= x << 13;
    x ^= x >> 17;
    x ^= x << 5;
    static.x = x;
    return x;
}

fn rand(min_val: f32, max_val: f32) f32 {
    return (@as(f32, @floatFromInt(xorshift32() & 0xFFFF)) / 0x10000) * (max_val - min_val) + min_val;
}

// @todo This should possibly be split up. Or perhaps there needs to just be a
// a seperate pass type for post processing/3d passes.
// Maybe rename and refactor to Pass2d
const Self = @This();
id: RendererTypes.RenderPassIds,
pass_action: sg.PassAction,
bindings: sg.Bindings,
image: sg.Image,
pipeline: sg.Pipeline,
batch: std.ArrayList(SpriteRenderable),
cur_num_of_sprite: u32 = 0,
max_sprites_per_batch: u32,
sprite_size: [2]f32,
atlas_size: [2]f32,
path: []const u8,

pub fn init(
    self: *Self,
    id: RendererTypes.RenderPassIds,
    spritesheet_path: []const u8,
    sprite_size: [2]f32,
    atlas_size: [2]f32,
    allocator: std.mem.Allocator,
) !void {
    log.info("Render pass initial: {s}", .{spritesheet_path});
    self.id = id;
    self.cur_num_of_sprite = 0;
    self.max_sprites_per_batch = 10000;
    self.batch = try std.ArrayList(SpriteRenderable).initCapacity(allocator, 100);
    self.sprite_size = sprite_size;
    self.atlas_size = atlas_size;
    self.path = spritesheet_path;

    const verts = [_]f32{
        0, 1, 0.0, 0.0, 1.0,
        1, 1, 0.0, 1.0, 1.0,
        1, 0, 0.0, 1.0, 0.0,
        0, 0, 0.0, 0.0, 0.0,
    };

    const indices = [_]u16{
        0, 1, 2,
        0, 2, 3,
    };
    self.bindings = .{};
    self.bindings.images[shd.IMG_tex2d] = sg.allocImage();
    self.bindings.samplers[shd.SMP_smp] = sg.makeSampler(.{
        .min_filter = .NEAREST,
        .mag_filter = .NEAREST,
    });
    self.bindings.vertex_buffers[0] = sg.makeBuffer(.{
        .type = .VERTEXBUFFER,
        .data = sg.asRange(&verts),
    });
    self.bindings.vertex_buffers[1] = sg.makeBuffer(.{
        .usage = .STREAM,
        .size = self.max_sprites_per_batch * @bitSizeOf(SpriteRenderable),
    });
    self.bindings.index_buffer = sg.makeBuffer(.{
        .type = .INDEXBUFFER,
        .data = sg.asRange(&indices),
    });

    self.pipeline = sg.makePipeline(.{
        .shader = sg.makeShader(shd.basicShaderDesc(sg.queryBackend())),
        .layout = init: {
            var l = sg.VertexLayoutState{};
            l.buffers[1].step_func = .PER_INSTANCE;
            l.attrs[shd.ATTR_basic_position] = .{ .format = .FLOAT3, .buffer_index = 0 };
            l.attrs[shd.ATTR_basic_uv_coords] = .{ .format = .FLOAT2, .buffer_index = 0 };
            l.attrs[shd.ATTR_basic_pos] = .{ .format = .FLOAT4, .buffer_index = 1 };
            l.attrs[shd.ATTR_basic_color] = .{ .format = .FLOAT4, .buffer_index = 1 };
            break :init l;
        },
        .index_type = .UINT16,
        .cull_mode = .BACK,
        .sample_count = 1,
        .depth = .{
            .pixel_format = .DEPTH_STENCIL,
            .compare = .LESS_EQUAL,
            .write_enabled = true,
        },
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
    var x: c_int = 0;
    var y: c_int = 0;
    var chan: c_int = 0;

    cim.stbi_set_flip_vertically_on_load(1);
    const data = cim.stbi_load(spritesheet_path.ptr, &x, &y, &chan, 4);

    sg.initImage(self.bindings.images[shd.IMG_tex2d], .{
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

    self.pass_action.colors[0] = .{
        .load_action = .CLEAR,
        .clear_value = .{ .r = 0, .g = 0, .b = 0, .a = 1 },
    };
}

pub fn appendSpriteSliceToBatch(
    self: *Self,
    sprite: []SpriteRenderable,
) !void {
    try self.batch.appendSliceAssumeCapacity(sprite);
    self.cur_num_of_sprite = sprite.len;
}
pub fn appendSpriteToBatch(
    self: *Self,
    sprite: SpriteRenderable,
) !void {
    try self.batch.append(sprite);
    self.cur_num_of_sprite += 1;
}

pub fn updateSpriteRenderables(
    self: *Self,
    index: usize,
    sprite: SpriteRenderable,
) !void {
    self.batch.items[index] = sprite;
}

pub fn updateBuffers(self: *Self) void {
    sg.updateBuffer(
        self.bindings.vertex_buffers[1],
        sg.asRange(self.batch.items[0..self.cur_num_of_sprite]),
    );
}

pub fn render(
    self: *Self,
    vs_params: shd.VsParams,
) void {
    const fs_params = shd.FsParams{
        .atlas_size = self.atlas_size,
        .sprite_size = self.sprite_size,
    };
    sg.applyPipeline(self.pipeline);
    sg.applyBindings(self.bindings);
    sg.applyUniforms(shd.UB_vs_params, sg.asRange(&vs_params));
    sg.applyUniforms(shd.UB_fs_params, sg.asRange(&fs_params));
    sg.draw(0, 6, self.cur_num_of_sprite);
}
