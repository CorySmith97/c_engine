/// ===========================================================================
///
/// Author: Cory Smith
///
/// Date: 2025-04-22
///
/// Description:
/// ===========================================================================
const std = @import("std");
const sokol = @import("sokol");
const sg = sokol.gfx;
const sdtx = sokol.debugtext;
const slog = sokol.log;

const util = @import("util.zig");
const math = util.math;

const shd = @import("shaders/basic.glsl.zig");
const cim = @cImport({
    @cInclude("stb_image.h");
});
const types = @import("types.zig");
const SpriteRenderable = types.RendererTypes.SpriteRenderable;
const RenderPassIds = types.RendererTypes.RenderPassIds;
pub const RenderPass = @import("render_system/Pass.zig");
const RenderConfigs = @import("render_system/Configs.zig");

const log = std.log.scoped(.renderer);

const KC853 = 0;
const KC854 = 1;
const Z1013 = 2;
const CPC = 3;
const C64 = 4;
const ORIC = 5;
// font indices

const Self = @This();
allocator: std.mem.Allocator,
render_passes: std.ArrayList(RenderPass),
basic_shd_vs_params: shd.VsParams,


pub fn init(self: *Self, allocator: std.mem.Allocator) !void {
    log.info("Initializing Renderer", .{});
    self.allocator = allocator;
    self.render_passes = std.ArrayList(RenderPass).init(self.allocator);


    sdtx.setup(.{
        .context = .{ .color_format = .RGBA8 },
        .fonts = init: {
            var f: [8]sdtx.FontDesc = @splat(.{});
            f[KC853] = sdtx.fontKc853();
            f[KC854] = sdtx.fontKc854();
            f[Z1013] = sdtx.fontZ1013();
            f[CPC] = sdtx.fontCpc();
            f[C64] = sdtx.fontC64();
            f[ORIC] = sdtx.fontOric();
            break :init f;
        },
        .logger = .{ .func = slog.func },
    });

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


//
// @todo Render UI stats for entity. Have it be in the corners at static locations
// that swap between different corners depnding on where the cursor currently is
//
pub fn printFont(font_index: u32, title: [:0]const u8, r: u8, g: u8, b: u8) void {
    sdtx.font(font_index);
    sdtx.color3b(r, g, b);
    sdtx.puts(title);
    for (32..256) |c| {
        sdtx.putc(@intCast(c));
        if (((c + 1) & 63) == 0) {
            sdtx.crlf();
        }
    }
    sdtx.crlf();
}

// @todo render function.
