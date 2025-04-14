const Scene = @import("scene.zig");
const std = @import("std");
const assert = std.debug.assert;
const Renderer = @import("renderer.zig");

pub fn writeSceneToBinary(scene: *Scene, file_name: []const u8) !void {
    assert(file_name.len > 0);
    var level_dir = try std.fs.cwd().openDir("levels", .{});

    var file = try level_dir.createFile(file_name, .{});
    defer file.close();

    _ = try file.write(&std.mem.toBytes(scene.id));
    _ = try file.write("\n");
    _ = try file.write(&std.mem.toBytes(scene.width));
    _ = try file.write("\n");
    _ = try file.write(&std.mem.toBytes(scene.height));
    _ = try file.write("\n");
    _ = try file.write(scene.scene_name);
    _ = try file.write("\n");

    _ = try file.write(&std.mem.toBytes(scene.entities.len));
    _ = try file.write("\n");
    for (0..scene.entities.len) |t| {
        _ = try file.write(&std.mem.toBytes(scene.entities.get(t)));
    }

    _ = try file.write(&std.mem.toBytes(scene.tiles.len));
    _ = try file.write("\n");
    for (0..scene.tiles.len) |t| {
        _ = try file.write(&std.mem.toBytes(scene.tiles.get(t)));
    }
}

// 
//id: u32 = 10,
//z_index: f32 = 0,
//entity_type: EntityType = .default,
//pos: math.Vec2 = math.Vec2.zero(),
//sprite_id: f32 = 0,
//aabb: AABB = .{
//    .min = math.Vec2.zero(),
//    .max = math.Vec2.zero(),
//},
//lua_script: []const u8 = "",
//// FLAGS
//selected: bool = false,

pub fn loadScene(scene: *Scene, file_name: []const u8, allocator: std.mem.Allocator) !void {
    assert(file_name.len > 0);
    var level_dir = try std.fs.cwd().openDir("levels", .{});

    var file = try level_dir.openFile(file_name, .{});
    defer file.close();

    var buf: [4096]u8 = undefined;
    var reader = file.reader();

    // Read scene ID
    const scene_id_buf = try reader.readUntilDelimiter(&buf, '\n');
    scene.id = std.mem.bytesToValue(u32, scene_id_buf);

    // Read scene width
    const scene_width_buf = try reader.readUntilDelimiter(&buf, '\n');
    scene.width = std.mem.bytesToValue(f32, scene_width_buf);

    // Read scene height
    const scene_height_buf = try reader.readUntilDelimiter(&buf, '\n');
    scene.height = std.mem.bytesToValue(f32, scene_height_buf);

    // Read scene name
    const name_buf = try reader.readUntilDelimiter(&buf, '\n');
    scene.scene_name = try allocator.dupe(u8, name_buf);

    // Read number of entities
    const entity_count_buf = try reader.readUntilDelimiter(&buf, '\n');
    const entity_count = std.mem.bytesToValue(usize, entity_count_buf);
    try scene.entities.ensureCapacity(entity_count);
    for (0..entity_count) |_| {
        var entity_buf: [Entity.size]u8 = undefined;
        try reader.readExact(&entity_buf);
        const entity = std.mem.bytesToValue(Entity, entity_buf);
        try scene.entities.append(entity);
    }

    // Read number of tiles
    const tile_count_buf = try reader.readUntilDelimiter(&buf, '\n');
    const tile_count = std.mem.bytesToValue(usize, tile_count_buf);
    try scene.tiles.ensureCapacity(tile_count);
    for (0..tile_count) |_| {
        var tile_buf: [Tile.size]u8 = undefined;
        try reader.readExact(&tile_buf);
        const tile = std.mem.bytesToValue(Tile, tile_buf);
        try scene.tiles.append(tile);
    }

}