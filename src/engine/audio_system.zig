/// ==========================================================================
///
/// Author: Cory Smith
///
/// Date: 2025-04-26
///
/// Description
/// ===========================================================================


const std = @import("std");
const sokol = @import("sokol");
const audio = sokol.audio;
const slog = sokol.log;

var sample_counter: u32 = 0;

const Self = @This();
gpa: std.heap.GeneralPurposeAllocator(.{}),
allocator: std.mem.Allocator,
buffer: []f32,

pub fn stream_cb(buffer: [*c]f32, num_frames: i32, num_channels: i32) callconv(.C) void {
    const total_samples = @as(usize, @intCast(num_frames)) * @as(usize, @intCast(num_channels));
    for (0..total_samples) |i| {
        const phase = (sample_counter >> 3) & 1;
        buffer[i] = if (phase == 0) 0.5 else -0.5;
        sample_counter += 1;
    }
}

pub fn init(self: *Self) !void {
    self.gpa = std.heap.GeneralPurposeAllocator(.{}){};
    self.allocator = self.gpa.allocator();
    self.buffer = try self.allocator.alloc(f32, 1000);
    audio.setup(.{
        .stream_cb = stream_cb,
        .logger = .{ .func = slog.func },
    });
}

pub fn deinit(self: *Self) void {
    self.allocator.free(self.buffer);
    _ = self.gpa.deinit();
    audio.shutdown();
}
