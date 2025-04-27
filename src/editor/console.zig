/// ===========================================================================
///
/// Author: Cory Smith
///
/// Date: 2025-04-22
///
/// Description:
///     This is the console found at the bottom of the editor or by pressing
///     L in the game.
/// ===========================================================================

const std = @import("std");
const State = @import("../state.zig");
const EditorState = @import("../editor.zig").EditorState;
const ig = @import("cimgui");
const log = std.log.scoped(.console);

var console_buf: [8192]u8 = undefined;

const cli_fn = *const fn(*State, [][]const u8) anyerror!void;
// @todo cli tools?
pub const cli_tools = std.StaticStringMap(cli_fn).initComptime((.{
}));

const Console = @This();
history_buf: std.ArrayList([]const u8),
history_file: std.fs.File,
open: bool,

// Initialization for the Console
pub fn init(
    self: *Console,
    allocator: std.mem.Allocator,
) !void {
    var dir = try std.fs.cwd().openDir("assets", .{});
    self.history_buf = std.ArrayList([]const u8).init(allocator);
    self.history_file = try dir.openFile("logs", .{ .mode = .read_write });
    self.open = false;
}

pub fn console(
    self: *Console,
    allocator: std.mem.Allocator,
    state: *State,
) !void {
    _ = state;
    _ = ig.igBegin("Drawer", 0, ig.ImGuiWindowFlags_None);
    if (ig.igIsWindowFocused(ig.ImGuiFocusedFlags_RootAndChildWindows)) {
        ig.igSetKeyboardFocusHere();
    }
    for (self.history_buf.items) |entry| {
        ig.igText(entry.ptr);
    }
    ig.igSameLine();

    if (ig.igInputText(
            " ",
            &console_buf, console_buf.len,
            ig.ImGuiInputTextFlags_EnterReturnsTrue | ig.ImGuiInputTextFlags_AllowTabInput,)
        ) {
        const console_input: []const u8 = std.mem.span(@as([*c]u8, @ptrCast(console_buf[0..].ptr)));
        try self.history_buf.append(try allocator.dupe(u8, console_input));
        log.info("{}", .{self.history_buf.items.len});
        console_buf = std.mem.zeroes([8192]u8);
        if (self.history_buf.items.len >= 15) {
            const record = self.history_buf.orderedRemove(0);
            _ = try self.history_file.writeAll(record);
            _ = try self.history_file.write("\n");
        }
    }
    _ = ig.igButton("save logs");
    ig.igEnd();
}
