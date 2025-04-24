const std = @import("std");
const ig = @import("cimgui");
const log = std.log.scoped(.console);

var console_buf: [8192]u8 = undefined;

const Console = @This();
history_buf: std.ArrayList([]const u8),
open: bool,

pub fn init(
    self: *Console,
    allocator: std.mem.Allocator,
) !void {
    self.history_buf = std.ArrayList([]const u8).init(allocator);
    self.open = false;
}

pub fn console(
    self: *Console,
    allocator: std.mem.Allocator,
) !void {
    _ = ig.igBegin("Drawer", 0, ig.ImGuiWindowFlags_None);
    for (self.history_buf.items) |entry| {
        ig.igText(entry.ptr);
    }
    if (ig.igInputText(" ", &console_buf, console_buf.len, ig.ImGuiInputTextFlags_EnterReturnsTrue)) {
        const console_input: []const u8 = std.mem.span(@as([*c]u8, @ptrCast(console_buf[0..].ptr)));
        try self.history_buf.append(try allocator.dupe(u8, console_input));
        console_buf = std.mem.zeroes([8192]u8);
    }
    ig.igEnd();
}
