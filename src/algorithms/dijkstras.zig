/// ===========================================================================
///
/// Author: Cory Smith
///
/// Date: 2025-04-30
///
/// Description:
/// ===========================================================================

const std = @import("std");
const types = @import("../types.zig");
const Scene = types.Scene;
const Tile = types.Tile;
const math = @import("../util.zig").math;


//Procedure RELAX(u, v)
//Inputs: u, v: vertices such that there is an edge (u, v).
//Result: The value of shortest[v] might decrease, and if it does, then
//pred[v] becomes u.
//1. If shortest(u C weight(u; v) < shortest[v], then set shortest[v] to
//shortest[u] C weight(u; v) and set pred[v] to u.

//Procedure DIJKSTRA.G; s/
//Inputs:
//G: a directed graph containing a set V of n vertices and a set E of
//m directed edges with nonnegative weights.
//s: a source vertex in V.
//Result: For each non-source vertex v in V , shortest[v] is the weight
//sp.s; v/ of a shortest path from s to v and predŒv is the vertex
//preceding v on some shortest path. For the source vertex s,
//shortest[s]= 0 and pred[s]= NULL. If there is no path from s to v,
//then shortest[v] = D 1 and pred[v] = NULL. (Same as
//DAG-SHORTEST-PATHS on page 87.)
//1. Set shortestŒv to 1 for each vertex v except s, set shortestŒs
//to 0, and set predŒv to NULL for each vertex v.
//2. 3. Set Q to contain all vertices.
//While Q is not empty, do the following:
//A. Find the vertex u in set Q with the lowest shortest value and
//remove it from Q.
//B. For each vertex v adjacent

pub const Node = struct {
    index: usize,
    weight: f32,
};

fn lessThan(
   context: void,
   a: Node,
   b: Node,
) std.math.Order {
    _ = context;
    return std.math.order(a.weight, b.weight);
}

pub const PathField = struct {
    shortest: []f32,
    prev: []Node,
};

//
// Owner is responible for releasing this memory.
// This needs to be rewritten to allow for a smaller subset
// of possible paths. Like I dont want to run pathfinding on a
// huge level if units cant reach the full level space. Additionally,
// there needs to be extra checks for if tiles are occupied
//
pub fn findAllPaths(
    start: usize,
    scene: Scene,
    max_dist: u16,
    tiles: std.MultiArrayList(Tile),
) !PathField {
    const allocator = std.heap.page_allocator;
    var shortest = try allocator.alloc(f32, tiles.len);
    var prev = try allocator.alloc(Node, tiles.len);
    var queue = std.PriorityQueue(Node, void, lessThan).init(allocator, {});
    var visited = try allocator.alloc(bool, tiles.len);
    defer queue.deinit(); // Clean up the queue

    const dirs = [_]isize{
        @intFromFloat(scene.width),  // Down
        @intFromFloat(-scene.width), // Up
        1,                           // Right
        -1,                          // Left
    };

    // Initialize distances and previous nodes
    for (0..tiles.len) |i| {
        shortest[i] = std.math.inf(f32);
        prev[i] = .{ .index = i, .weight = std.math.inf(f32) };
        visited[i] = false;
    }

    // Set start node
    shortest[start] = 0;
    prev[start] = .{ .index = start, .weight = 0 };  // Set proper initial value
    try queue.add(.{ .index = start, .weight = 0 });

    // BFS/Dijkstra search
    while (queue.count() > 0) {
        const u = queue.remove();

        // Skip if we're beyond max distance or already found a shorter path
        if (shortest[u.index] < u.weight) continue;  // Skip outdated entries
        //if (shortest[u.index] > @as(f32, @floatFromInt(max_dist))) continue;
        if (visited[u.index]) continue;

        _ = max_dist;
        const ux = u.index % @as(usize, @intFromFloat(scene.width));

        visited[u.index] = true;

        for (dirs) |d| {
            const vi: isize = d + @as(isize, @intCast(u.index));

            // Boundary checks
            if (vi < 0 or vi >= @as(isize, @intCast(tiles.len))) continue;

            // Edge wrapping checks
            if (d == -1 and ux == 0) continue;
            if (d == 1 and ux == @as(usize, @intFromFloat(scene.width - 1))) continue;


            const v: usize = @intCast(vi);

            if (v == u.index) continue;

            if (visited[v]) continue;
            const trav = tiles.get(v);

            // Check if the tile is traversable (skip non-traversable tiles)
            if (trav.traversable) {
                continue;
            }

            // Optional: Check if tile is occupied by another unit
            // if (isOccupied(v)) continue;

            const new_dist = shortest[u.index] + 1.0;
            if (new_dist < shortest[v]) {
                shortest[v] = new_dist;
                prev[v] = .{ .index = u.index, .weight = new_dist };
                try queue.add(.{ .index = v, .weight = new_dist });
            }
        }
    }
    const path: PathField = .{ .shortest = shortest, .prev = prev };

    //debugPrintPathField(path, 10);

    return path;
}

// Helper function for debugging the path field
pub fn debugPrintPathField(field: PathField, width: usize) void {
    std.debug.print("\nPath distances:\n", .{});

    for (0..field.shortest.len) |i| {
        if (i % width == 0) std.debug.print("\n", .{});

        if (field.shortest[i] == std.math.inf(f32)) {
            std.debug.print("  X  ", .{});
        } else {
            std.debug.print("{d:4.0} ", .{field.shortest[i]});
        }
    }

    std.debug.print("\n\nPrevious nodes:\n", .{});

    for (0..field.prev.len) |i| {
        if (i % width == 0) std.debug.print("\n", .{});
        std.debug.print("{d:4} ", .{field.prev[i].index});
    }

    std.debug.print("\n", .{});
}
