const std = @import("std");
const sokol = @import("sokol");
const math = @import("math.zig");
const shd = @import("shaders/basic.glsl.zig");
const cim = @cImport({
    @cInclude("stb_image.h");
});
const sg = sokol.gfx;
pub const SpriteRenderable = @import("renderer/SpriteRenderable.zig").SpriteRenderable;
pub const RenderPass = @import("renderer/RenderPass.zig");

const Self = @This();
allocator: std.mem.Allocator,
render_passes: std.ArrayList(RenderPass),