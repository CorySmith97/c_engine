const std = @import("std");
const ig = @import("cimgui");
const sokol = @import("sokol");
const app = sokol.app;
const sg = sokol.gfx;
const slog = sokol.log;
const glue = sokol.glue;
const imgui = sokol.imgui;
const shd = @import("shaders/basic.glsl.zig");
const math = @import("math.zig");
const Camera = @import("camera.zig").Camera;
const mat4 = math.Mat4;
const c = @cImport({
    @cInclude("stb_image.h");
});

pub const SpritesheetId = enum {
    basic,
};

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

const RenderPass = struct {
    spritesheet_id: SpritesheetId,
    spritesheet_height: f32,
    spritesheet_width: f32,
    pass_action: sg.PassAction,
    bindings: sg.Bindings,
    image: sg.Image,
    pipeline: sg.Pipeline,
    batch: [10]math.Vec4,
    max_sprites_per_batch: u32 = 10,
    cur_num_of_sprite: u32 = 0,

    pub fn init(self: *RenderPass) void {
        self.max_sprites_per_batch = 4;
        const verts = [_]f32{
            -0.5, 0.5,  0.0, 0.0, 1.0,
            0.5,  0.5,  0.0, 1.0, 1.0,
            0.5,  -0.5, 0.0, 1.0, 0.0,
            -0.5, -0.5, 0.0, 0.0, 0.0,
        };

        const indices = [_]u16{
            0, 1, 2,
            0, 2, 3,
        };
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
            .size = self.max_sprites_per_batch * @bitSizeOf(math.Vec4),
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
                break :init l;
            },
            .index_type = .UINT16,
            .depth = .{
                .compare = .LESS_EQUAL,
                .write_enabled = true,
            },
            .primitive_type = .TRIANGLE_STRIP,
        });
        var x: c_int = 0;
        var y: c_int = 0;
        var chan: c_int = 0;

        c.stbi_set_flip_vertically_on_load(1);
        const data = c.stbi_load("assets/spritesheet-1.png", &x, &y, &chan, 4);
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

    pub fn updateBuffers(self: *RenderPass) void {
        for (0..3) |_| {
            if (self.cur_num_of_sprite < self.max_sprites_per_batch) {
                self.batch[self.cur_num_of_sprite] = .{
                    .x = rand(-2, 2),
                    .y = rand(-2, 2),
                    .z = 0,
                    .a = 0,
                };
                self.cur_num_of_sprite += 1;
            } else {
                break;
            }
        }
        sg.updateBuffer(
            self.bindings.vertex_buffers[1],
            sg.asRange(self.batch[0..self.cur_num_of_sprite]),
        );
    }

    pub fn render(self: *RenderPass, vs_params: shd.VsParams, fs_params: shd.FsParams) void {
        sg.applyPipeline(self.pipeline);
        sg.applyBindings(self.bindings);
        sg.applyUniforms(shd.UB_vs_params, sg.asRange(&vs_params));
        sg.applyUniforms(shd.UB_fs_params, sg.asRange(&fs_params));
        sg.draw(0, 6, self.cur_num_of_sprite);
    }
};

var camera: Camera = undefined;
var view: math.Mat4 = undefined;
var pass: RenderPass = undefined;
var passaction: sg.PassAction = .{};
var image: sg.Image = .{};
var r: f32 = 0;
export fn init() void {
    sg.setup(.{
        .environment = glue.environment(),
        .logger = .{ .func = slog.func },
    });

    imgui.setup(.{
        .logger = .{ .func = slog.func },
    });

    pass.init();
    passaction.colors[0] = .{
        .load_action = .CLEAR,
        .clear_value = .{ .r = 0, .g = 0, .b = 0, .a = 0 },
    };
    camera = .{
        .up = .{ .x = 0, .y = 1, .z = 0 },
        .front = .{ .x = 0, .y = 0, .z = 0 },
        .target = .{ .x = 0, .y = 0, .z = 0 },
        .pos = .{ .x = 0, .y = 0, .z = -10 },
        .vel = .{ .x = 0, .y = 0, .z = 0 },
    };
    view = math.Mat4.lookat(camera.pos, math.Vec3.zero(), camera.up);
}

export fn frame() void {
    const alloc = std.heap.page_allocator;
    const text = std.fmt.allocPrint(alloc,
        \\R: {}
        \\sprite count: {}
    , .{ r, pass.cur_num_of_sprite }) catch unreachable;
    defer alloc.free(text);
    imgui.newFrame(.{
        .width = app.width(),
        .height = app.height(),
        .delta_time = app.frameDuration(),
        .dpi_scale = app.dpiScale(),
    });

    //=== UI CODE STARTS HERE
    ig.igSetNextWindowPos(.{ .x = 10, .y = 10 }, ig.ImGuiCond_Once);
    ig.igSetNextWindowSize(.{ .x = 400, .y = 100 }, ig.ImGuiCond_Once);
    _ = ig.igBegin("Hello Dear ImGui!", 0, ig.ImGuiWindowFlags_None);
    ig.igText(text.ptr);
    if (ig.igButton("Increment R")) {
        r += 1;
    }
    ig.igEnd();
    //=== UI CODE ENDS HERE
    //

    pass.updateBuffers();
    const vs_params = computeVsParams(1.0, r);
    const fs_params = shd.FsParams{
        .atlas_size = .{ 256, 256 },
        .sprite_size = .{ 16, 16 },
    };

    // call simgui.render() inside a sokol-sg pass
    sg.beginPass(.{ .action = passaction, .swapchain = glue.swapchain() });
    pass.render(vs_params, fs_params);
    imgui.render();
    sg.endPass();
    sg.commit();
}

export fn cleanup() void {
    imgui.shutdown();
}
export fn event(ev: [*c]const app.Event) void {
    // forward input events to sokol-imgui
    _ = imgui.handleEvent(ev.*);
}

pub fn main() !void {
    app.run(.{
        .init_cb = init,
        .frame_cb = frame,
        .event_cb = event,
        .cleanup_cb = cleanup,
        .width = 800,
        .height = 600,
        .window_title = "HELLO",
    });
}

fn computeVsParams(rx: f32, ry: f32) shd.VsParams {
    const rxm = mat4.rotate(rx, .{ .x = 1.0, .y = 0.0, .z = 0.0 });
    const rym = mat4.rotate(ry, .{ .x = 0.0, .y = 1.0, .z = 0.0 });
    const model = mat4.mul(rxm, rym);
    const aspect = app.widthf() / app.heightf();
    const proj = mat4.persp(60.0, aspect, 0.01, 50.0);
    return shd.VsParams{ .mvp = mat4.mul(mat4.mul(proj, view), model) };
}
