const types = @import("types.zig");
const Scene = types.Scene;
const Entity = types.Entity;
const Tile = types.Tile;
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

pub fn loadSceneFromBinary(scene: *Scene, file_name: []const u8, allocator: std.mem.Allocator) !void {
    assert(file_name.len > 0);
    var level_dir = try std.fs.cwd().openDir("levels", .{});

    var file = try level_dir.openFile(file_name, .{});
    defer file.close();

    var buf: [4096]u8 = undefined;
    var reader = file.reader();

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

    const entity_count = try reader.readInt(usize, .little);
    try scene.entities.setCapacity(allocator, entity_count);
    _ = try reader.readUntilDelimiter(&buf, '\n');
    std.log.info("Entity Size: {}\nTile Size: {}", .{ @sizeOf(Entity), @sizeOf(Tile) });
    for (0..entity_count) |_| {
        var entity_buf: [@sizeOf(Entity)]u8 = undefined;
        const len = try reader.readAtLeast(&entity_buf, @sizeOf(Entity));
        const entity: Entity = std.mem.bytesToValue(Entity, entity_buf[0..len]);
        try scene.entities.append(allocator, entity);
    }

    const tile_count = try reader.readInt(usize, .little);
    try scene.tiles.setCapacity(allocator, tile_count);
    _ = try reader.readUntilDelimiter(&buf, '\n');
    for (0..tile_count) |_| {
        var tile_buf: [@sizeOf(Tile)]u8 = undefined;
        const len = try reader.readAtLeast(&tile_buf, @sizeOf(Tile));
        const tile: Tile = std.mem.bytesToValue(Tile, tile_buf[0..len]);
        try scene.tiles.append(allocator, tile);
    }
}

pub fn loadSceneFromJson(
    scene: *Scene,
    file_name: []const u8,
    allocator: std.mem.Allocator,
) !void {
    assert(file_name.len > 0);
    var level_dir = try std.fs.cwd().openDir("levels", .{});

    var file = try level_dir.createFile(file_name, .{});
    defer file.close();

    var reader = file.reader();

    const file_buf = try reader.readAllAlloc(allocator, 10_000_000);
    _ = file_buf;
    _ = scene;

    //scene.* = try std.json.parseFromSliceLeaky(Scene, allocator, file_buf, .{ .allocate = .alloc_always });
}

pub fn writeSceneToJson(
    scene: *Scene,
    file_name: []const u8,
    allocator: std.mem.Allocator,
) !void {
    assert(file_name.len > 0);
    var level_dir = try std.fs.cwd().openDir("levels", .{});

    var file = try level_dir.createFile(file_name, .{});
    defer file.close();

    var writer = file.writer();

    const stringified = try std.json.stringifyAlloc(allocator, @constCast(scene), .{ .whitespace = .indent_1 });

    try writer.writeAll(stringified);
}
