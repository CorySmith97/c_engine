//const std = @import("std");
//const c = @import("c.zig");
//const types = @import("../types.zig");
//const Entity = types.Entity;
//
//var e: Entity = .{};
//
///// Interfaces for LUA types.
/////
///// Entity API
///// Algorithms API
//const Self = @This();
//state: ?*c.lua_State,
//
//export fn getId(state: ?*c.lua_State) c_int {
//    // Get the entity from the upvalue
//    const entity_ptr = c.lua_touserdata(state, c.lua_upvalueindex(1));
//    const entity: *Entity = @ptrCast(@alignCast(entity_ptr));
//    c.lua_pushinteger(state, @intCast(entity.id));
//    return 1;
//}
//
//export fn testIndex(state: ?*c.lua_State) void {
//    // Create a table that will be our API
//    c.lua_newtable(state);
//
//    // Setup the getId function with entity as upvalue
//    c.lua_pushlightuserdata(state, &e);
//    c.lua_pushcclosure(state, getId, 1);
//    c.lua_setfield(state, -2, "getId");
//
//    // Set the table as a global named "entity"
//    c.lua_setglobal(state, "entity");
//}
//
//pub fn luaTest() !void {
//    const lua_state = c.luaL_newstate();
//    if (lua_state == null) {
//        return error.LuaInitFailed;
//    }
//
//    // Open standard Lua libraries (math, string, etc.)
//    c.luaL_openlibs(lua_state);
//    testIndex(lua_state);
//
//    var buf: [4096]u8 = undefined;
//    var file = try std.fs.cwd().openFile("src/scripts/test.lua", .{});
//    const length = try file.readAll(&buf);
//    file.close();
//
//    buf[length] = 0;
//
//    const status = c.luaL_loadstring(lua_state, &buf);
//    if (status != c.LUA_OK) {
//        std.log.err("loadstring error: {}", .{status});
//        return error.LuaLoadFailed;
//    }
//
//    const call_status = c.lua_pcallk(lua_state, 0, 0, 0, 0, null);
//    if (call_status != c.LUA_OK) {
//        std.log.err("run err loadstring error: {}", .{status});
//        return error.LuaCallFailed;
//    }
//    c.lua_close(lua_state);
//}
//
//pub fn loadScript(self: *Self, script: []const u8) !void {
//    const status = c.luaL_loadstring(self.state, script.ptr);
//    if (status != c.LUA_OK) {
//        std.log.err("loadstring error: {}", .{status});
//        return error.LuaLoadFailed;
//    }
//}
//
//pub fn runScripts(self: *Self) void {
//    const call_status = c.lua_pcallk(self.state, 0, 0, 0, 0, null);
//    if (call_status != c.LUA_OK) {
//        std.log.err("run err loadstring error: {}", .{call_status});
//        return error.LuaCallFailed;
//    }
//}
//
//pub fn deinit(self: *Self) void {
//    _ = self;
//    c.lua_close();
//}
