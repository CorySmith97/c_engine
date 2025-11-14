const std = @import("std");
const builtin = @import("builtin");

const State = *anyopaque;

var init: *const fn () State = undefined;
var tick: *const fn (State) void = undefined;
var draw: *const fn (State) void = undefined;
var reload: *const fn (State) void = undefined;

var game_dll: ?std.DynLib = null;


pub fn loadDll() !void {
    if (game_dll != null) return error.DllAlreadyLoaded;

    if (builtin.os.tag == .linux) {
        game_dll = std.DynLib.open("zig-out/lib/libc_engine.so") catch {
            return error.CouldntFind;
        };
    } else if (builtin.os.tag == .macos) {
        game_dll = std.DynLib.open("zig-out/lib/libc_engine.dylib") catch {
            return error.CouldntFind;
        };
    } else if (builtin.os.tag == .windows) {
        game_dll = std.DynLib.open("zig-out/bin/c_engine.lib") catch {
            return error.CouldntFind;
        };
    }

    if (game_dll) |*g| {
        init = g.lookup(@TypeOf(init), "init") orelse return error.LoopupInitFailed;
        tick = g.lookup(@TypeOf(tick), "tick") orelse return error.LoopupInitFailed;
        reload = g.lookup(@TypeOf(reload), "reload") orelse return error.LoopupInitFailed;
        draw = g.lookup(@TypeOf(draw), "draw") orelse return error.LoopupInitFailed;
    }
}

pub fn unloadDll() !void {
    if (game_dll) |*game| {
        game.close();
        game_dll = null;
    } else {
        return error.AlreadyUnloaded;
    }
}

pub fn recompileDll() !void {
    std.log.info("RECOMPILING", .{});
    const args = [_][]const u8{
        "zig",
        "build",
        "-Dmode=game",
    };

    var child = std.process.Child.init(&args, std.heap.page_allocator);
    const term = try child.spawnAndWait();
    switch (term) {
        .Exited => |exited| {
            if (exited == 2) return error.compileFailed;
        },
        else => {},
    }
}

