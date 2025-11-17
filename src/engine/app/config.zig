pub const AppConfig = extern struct {
    name: []const u8,
    user_init: ?*const fn() void,
    user_tick: ?*const fn() void,
    user_input: ?*const fn([*c]const app.Event) void,
    user_deinit: ?*const fn() void,
};

const std = @import("std");
const sokol = @import("sokol");
const app = sokol.app;
