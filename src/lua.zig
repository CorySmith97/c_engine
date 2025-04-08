const std = @import("std");
pub const c = @cImport({
    @cInclude("lua.h");
    @cInclude("lauxlib.h");
    @cInclude("lualib.h");
});

const Self = @This();
state: ?*c.lua_State,

pub fn luaTest() !void {
    const lua_state = c.luaL_newstate();
    if (lua_state == null) {
        return error.LuaInitFailed;
    }

    // Open standard Lua libraries (math, string, etc.)
    c.luaL_openlibs(lua_state);

    var buf: [4096]u8 = undefined;
    var file = try std.fs.cwd().openFile("src/scripts/test.lua", .{});
    const length = try file.readAll(&buf);
    file.close();

    buf[length] = 0;

    const status = c.luaL_loadstring(lua_state, &buf);
    if (status != c.LUA_OK) {
        std.log.err("loadstring error: {}", .{status});
        return error.LuaLoadFailed;
    }

    const call_status = c.lua_pcallk(lua_state, 0, 0, 0, 0, null);
    if (call_status != c.LUA_OK) {
        std.log.err("run err loadstring error: {}", .{status});
        return error.LuaCallFailed;
    }
    c.lua_close(lua_state);
}

pub fn loadScript(self: *Self, script: []const u8) !void {
    const status = c.luaL_loadstring(self.state, script.ptr);
    if (status != c.LUA_OK) {
        std.log.err("loadstring error: {}", .{status});
        return error.LuaLoadFailed;
    }
}

pub fn runScripts(self: *Self) void {
    const call_status = c.lua_pcallk(self.state, 0, 0, 0, 0, null);
    if (call_status != c.LUA_OK) {
        std.log.err("run err loadstring error: {}", .{call_status});
        return error.LuaCallFailed;
    }
}

pub fn deinit(self: *Self) void {
    _ = self;
    c.lua_close();
}
