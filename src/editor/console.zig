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
const assert = std.debug.assert;

const State = @import("../state.zig");
const EditorState = @import("../editor.zig").EditorState;
const ig = @import("cimgui");
const log = std.log.scoped(.console);
const Serde = @import("../util/serde.zig");
const Scene = @import("../types.zig").Scene;

var console_buf: [8192]u8 = undefined;

//
// @todo this needs to have access to the file in order to write
// out any data that may result from the tool
//
const cli_fn = *const fn (*State, [][]const u8) anyerror!void;

pub fn cliLevel(
    state: *State,
    args: [][]const u8,
) !void {
    assert(args.len > 1);
    var failed: bool = false;

    if (state.loaded_scene) |*s| {
        s.deloadScene(state.allocator, state);
    }

    var scene: Scene = undefined;
    log.info("{s}, {s}", .{args[0], args[1]});

    Serde.loadSceneFromJson(&scene, args[1], state.allocator) catch |e| {
        state.errors += 1;
        log.err("{s}", .{@errorName(e)});
        failed = true;
    };

    if (!failed) {
        state.loaded_scene = scene;
        try state.loaded_scene.?.loadScene(&state.renderer);
    } else {
        state.loaded_scene = null;
    }
}

// @todo cli tools?
pub const cli_tools = std.StaticStringMap(cli_fn).initComptime((.{
    .{"level", cliLevel},
}));

const Console = @This();
history_buf: std.ArrayList([]const u8),
history_file: std.fs.File,
open: bool,

//
// ===========================================================================
// Initialization for the Console.
//
pub fn init(
    self: *Console,
    allocator: std.mem.Allocator,
) !void {
    var dir = try std.fs.cwd().openDir("assets", .{});
    self.history_buf = std.ArrayList([]const u8).init(allocator);
    self.history_file = try dir.openFile("logs", .{ .mode = .read_write });
    self.open = false;
}

//
// ===========================================================================
// Main loop for the console to run within an imgui window
//
pub fn console(
    self: *Console,
    allocator: std.mem.Allocator,
    state: *State,
) !void {
    _ = ig.igBegin("Drawer", 0, ig.ImGuiWindowFlags_None);
    if (ig.igIsWindowFocused(ig.ImGuiFocusedFlags_RootAndChildWindows)) {
        ig.igSetKeyboardFocusHere();
    }
    for (self.history_buf.items) |entry| {
        ig.igText(entry.ptr);
    }

    if (ig.igInputText(
        " ",
        &console_buf,
        console_buf.len,
        ig.ImGuiInputTextFlags_EnterReturnsTrue | ig.ImGuiInputTextFlags_AllowTabInput,
    )) {
        const console_input: []const u8 = std.mem.span(@as([*c]u8, @ptrCast(console_buf[0..].ptr)));
        try self.history_buf.append(try allocator.dupe(u8, console_input));
        var args: [][]const u8 = try allocator.alloc([]const u8, 0);

        if (std.mem.startsWith(u8, console_input, "level")) {
            var iter = std.mem.splitAny(u8, console_input, " ");
            var i: usize = 0;
            while (iter.next()) | arg| {
                args = try allocator.realloc(args, args.len + 1);
                args[i] = arg;

                i += 1;
            }

            try cliLevel(state, args);

        }

        //log.info("{}", .{self.history_buf.items.len});
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
