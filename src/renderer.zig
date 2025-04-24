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
const RenderPassIds = types.RendererTypes.RenderPassIds;
pub const RenderPass = @import("renderer/RenderPass.zig");
const RenderConfigs = @import("renderer/RenderConfigs.zig");
const log = std.log.scoped(.renderer);

const Self = @This();
allocator: std.mem.Allocator,
render_passes: std.ArrayList(RenderPass),
basic_shd_vs_params: shd.VsParams,

pub fn init(self: *Self, allocator: std.mem.Allocator) !void {
    log.info("Initializing Renderer", .{});
    self.allocator = allocator;
    self.render_passes = std.ArrayList(RenderPass).init(self.allocator);

    for (RenderConfigs.Defaults) |config| {
        var pass: RenderPass = undefined;
        try pass.init(
            config.id,
            config.path,
            config.sprite_size,
            config.atlas_size,
            self.allocator,
        );
        log.debug("{any}", .{pass});
        try self.render_passes.append(pass);
    }

    for (self.render_passes.items) |pass| {
        log.info("{s}", .{pass.path});
    }
}

pub fn deinit(self: *Self) !void {
    log.info("Deitializing Renderer", .{});
    self.render_passes.deinit();
}
