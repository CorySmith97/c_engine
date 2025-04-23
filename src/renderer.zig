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
gpa: std.heap.GeneralPurposeAllocator(.{}),
allocator: std.mem.Allocator,
render_passes: std.ArrayList(RenderPass),
basic_shd_vs_params: shd.VsParams,

pub fn init(self: *Self) !void {
    log.info("Initializing Renderer", .{});
    self.gpa = std.heap.GeneralPurposeAllocator(.{}){};
    self.allocator = self.gpa.allocator();
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
        try self.render_passes.append(pass);
    }
}

pub fn deinit(self: *Self) !void {
    log.info("Deitializing Renderer", .{});
    self.render_passes.deinit();
    const check = self.gpa.deinit();
    if (check == .leak) {
        return error.LeakingMemoryUpInThisHoe;
    }
}
