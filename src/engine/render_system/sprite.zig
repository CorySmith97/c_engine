// @todo this is a new interface for drawing sprites similar to the sprites drawing available in raylib.
//
//      - draw_sprite
//      - draw_sprite_ex
//      - draw_sprite_pro
const std = @import("std");
const HashMap = std.AutoHashMapUnmanaged;

var spritesheets: HashMap(Spritesheet) = .{};

pub fn getSpritesheet(path: []const u8) !Spritesheet {
    _ = path;
}

pub const Spritesheet = struct {
    name: []const u8,
};
