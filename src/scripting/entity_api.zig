const std = @import("std");
const Lua = @import("lua.zig");
const types = @import("../types.zig");
const Entity = types.Entity;
const c = @import("c.zig");

export fn setMetaTable(state: *Lua, e: *Entity) void {
    c.lua_newtable(state);

    // Setup the getId function with entity as upvalue
    c.lua_pushlightuserdata(state, &e);
    // format for adding methods
    //c.lua_pushcclosure(state, getId, 1);
    //c.lua_setfield(state, -2, "getId");

    // Set the table as a global named "entity"
    c.lua_setglobal(state, "entity");
}
