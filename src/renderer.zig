const std = @import("std");
const sokol = @import("sokol");
const util = @import("util.zig");
const math = util.math;
const shd = @import("shaders/basic.glsl.zig");
const cim = @cImport({
    @cInclude("stb_image.h");
});
const sg = sokol.gfx;
const types = @import("types.zig");
const SpriteRenderable = types.RendererTypes.SpriteRenderable;
pub const RenderPass = @import("renderer/RenderPass.zig");

const Self = @This();
allocator: std.mem.Allocator,
render_passes: std.ArrayList(RenderPass),
