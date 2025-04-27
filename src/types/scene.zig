/// ===========================================================================
///
/// Author: Cory Smith
///
/// Date: 2025-04-26
///
/// Description:
///     There is a lot for this class. The main idea is that we construct
///     scenes similar to the way Godot handles scenes, but some more simple.
/// ===========================================================================

const std = @import("std");
const assert = std.debug.assert;
const testing = std.testing;

const State = @import("../state.zig");
const Entity = @import("entity.zig");
const Renderer = @import("../renderer.zig");
const RendererTypes = @import("renderer.zig");
const Tile = @import("tile.zig");
const log = std.log.scoped(.scene);

const Self = @This();
id         : u32 = 0,
height     : f32 = 0,
width      : f32 = 0,
scene_name : []const u8 = "",
entities   : std.MultiArrayList(Entity) = .{},
tiles      : std.MultiArrayList(Tile) = .{},

//
// Default Scene configuration
//
pub fn default(self: *Self, allocator: std.mem.Allocator, state: *State) !void {
    self.id = 0;
    self.height = 16.0;
    self.width = 16.0;
    self.scene_name = "Default Scene";

    try self.tiles.append(allocator, .{
        .sprite_renderable = .{
            .pos = .{
                .x = 0,
                .y = 0,
                .z = 0,
            },
            .sprite_id = 0,
            .color = .{
                .x = 1.0,
                .y = 1.0,
                .z = 1.0,
                .w = 1.0,
            },
        },
    });
    for (self.tiles.items(.sprite_renderable)) |i| {
        try state.passes[0].appendSpriteToBatch(i);
    }
}

//
// This is Deprecated. Was to set up initial scene testing
//
pub fn loadTestScene(
    self: *Self,
    allocator: std.mem.Allocator,
    state: *State,
) !void {
    _ = state;
    self.id = 0;
    var file = try std.fs.cwd().openFile("levels/t1.txt", .{});
    defer file.close();

    var reader = file.reader();

    self.scene_name = "Test Level";
    try reader.context.seekTo(0);

    const width = try reader.readUntilDelimiterAlloc(allocator, '\n', 40);
    defer allocator.free(width);
    const height = try reader.readUntilDelimiterAlloc(allocator, '\n', 40);
    defer allocator.free(height);
    self.width = try std.fmt.parseFloat(f32, width);
    self.height = try std.fmt.parseFloat(f32, height);

    var y: f32 = 0;
    while (try reader.readUntilDelimiterOrEofAlloc(allocator, '\n', 10_000)) |line| {
        for (0.., line) |i, char| {
            const f: f32 = @floatFromInt(i);
            try self.tiles.append(allocator, .{
                .sprite_renderable = .{
                    .pos = .{
                        .x = f * 16,
                        .y = y,
                        .z = 0,
                    },
                    .sprite_id = @floatFromInt(char),
                    .color = .{
                        .x = 1,
                        .y = 1,
                        .z = 1,
                        .w = 1,
                    },
                },
            });
        }
        y += 16;
    }

    log.info("Tile count {}", .{self.tiles.len});

    //for (self.tiles.items(.sprite_renderable)) |i| {
    //    try state.renderer.render_passes.items[@intFromEnum(RendererTypes.RenderPassIds.TILES_1)].appendSpriteToBatch(i);
    //}

    try self.writeSceneToBinary("t2.txt");
}

pub fn reloadScene(self: *Self, allocator: std.mem.Allocator) !void {
    self.tiles.deinit(allocator);
    self.tiles = .{};
}

pub fn loadScene(self: *Self, renderer: *Renderer) !void {
    for (self.tiles.items(.sprite_renderable)) |i| {
        try renderer.render_passes.items[@intFromEnum(RendererTypes.RenderPassIds.TILES_1)].appendSpriteToBatch(i);
    }
}

pub fn saveScene(self: *Self) !void {
    _ = self;
}

pub fn renderScene(self: *Self) void {
    _ = self;
}

pub fn loadSceneToBinary(self: *Self, file_name: []const u8) !void {
    assert(file_name.len > 0);
    _ = self;
    var level_dir = try std.fs.cwd().openDir("levels", .{});

    var file = try level_dir.openFile(file_name, .{});
    defer file.close();
    var buf: [4096]u8 = undefined;
    var reader = file.reader();

    const u = try reader.readUntilDelimiter(&buf, '\n');
    const len = std.mem.bytesToValue(usize, u);

    for (0..len) |_| {
        const sr = try reader.readStruct(Renderer.SpriteRenderable);
        std.log.info("{any}", .{sr});
    }
}

pub fn writeSceneToBinary(self: *Self, file_name: []const u8) !void {
    assert(file_name.len > 0);
    var level_dir = try std.fs.cwd().openDir("levels", .{});

    var file = try level_dir.createFile(file_name, .{});
    defer file.close();

    _ = try file.write(&std.mem.toBytes(self.id));
    _ = try file.write("\n");
    _ = try file.write(&std.mem.toBytes(self.width));
    _ = try file.write("\n");
    _ = try file.write(&std.mem.toBytes(self.height));
    _ = try file.write("\n");
    _ = try file.write(self.scene_name);
    _ = try file.write("\n");

    _ = try file.write(&std.mem.toBytes(self.entities.len));
    _ = try file.write("\n");
    for (0..self.entities.len) |t| {
        _ = try file.write(&std.mem.toBytes(self.entities.get(t)));
    }

    _ = try file.write(&std.mem.toBytes(self.tiles.len));
    _ = try file.write("\n");
    for (0..self.tiles.len) |t| {
        _ = try file.write(&std.mem.toBytes(self.tiles.get(t)));
    }
}

pub fn deloadScene(
    self: *Self,
    allocator: std.mem.Allocator,
    state: *State,
) void {
    self.entities.deinit(allocator);
    self.tiles.deinit(allocator);
    for (state.renderer.render_passes.items) |*pass| {
        pass.batch.clearAndFree();
        pass.cur_num_of_sprite = 0;
    }
}

pub fn jsonStringify(self: *const Self, jws: anytype) !void {
    try jws.beginObject();
    try jws.objectField("id");
    try jws.print("{}", .{self.id});
    try jws.objectField("height");
    try jws.print("{}", .{self.height});
    try jws.objectField("width");
    try jws.print("{}", .{self.width});
    try jws.objectField("scene_name");
    try jws.print("{s}", .{self.scene_name});
    try jws.objectField("entities");
    try jws.beginArray();
    for (0..self.entities.len) |i| {
        var entity: Entity = self.entities.get(i);

        try entity.jsonStringify(jws);
    }
    try jws.endArray();

    try jws.objectField("tiles");
    try jws.beginArray();
    for (0..self.tiles.len) |i| {
        var tile: Tile = self.tiles.get(i);

        try tile.jsonStringify(jws);
    }
    try jws.endArray();
    try jws.endObject();
}

test "Scene serde" {
    try testing.expect(1 == 1);
}
