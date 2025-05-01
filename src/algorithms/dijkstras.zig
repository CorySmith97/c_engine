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
    var shortest =  try allocator.alloc(f32, tiles.len);
    defer allocator.free(shortest);
    var prev = try allocator.alloc(Node, tiles.len);
    defer allocator.free(prev);

    var queue = std.PriorityQueue(Node, void, lessThan).init(allocator, {});


    const dirs = [_]isize{
        @intFromFloat(scene.width),
        @intFromFloat(-scene.width),
        1,
        -1,
    };


    for (0.., tiles.items(.traversable)) |i, b| {
        _ = b;
        prev[i] = .{.index = i, .weight = std.math.inf(f32)};
        shortest[i] = std.math.inf(f32);
        //if (!b) {
        //    try queue.add(.{.index = i, .weight = 1.0});
        //} else {
        //    try queue.add(.{.index = i, .weight = std.math.inf(f32)});
        //}
    }

    _ = max_dist;
    shortest[start] = 0;
    prev[start] = .{.index = start, .weight = 0};
    try queue.add(.{.index = start, .weight = 0});

    while (queue.count() > 0) {
        const u = queue.remove();

        const ux = u.index % @as(usize, @intFromFloat(scene.width));

        for (dirs) |d| {
            const vi: isize = d + @as(isize,@intCast(u.index));
            if (vi < 0) continue;
            if (vi >= tiles.len) continue;
            if (d == -1 and ux == 0) continue;
            if (d == 1 and ux == @as(usize,@intFromFloat(scene.width - 1))) continue;

            const v: usize = @intCast(vi);
            const trav = tiles.get(v);
            //std.log.info("trav {any}", .{trav});
            var weight: f32 = 0;

            if (!trav.traversable) {
                weight = 1;
            } else {
                weight = std.math.inf(f32);
            }

            if (shortest[u.index] != std.math.inf(f32) and (shortest[u.index] + weight < shortest[v])) {
                //std.log.info("Weight: {}", .{weight});
                shortest[v] = shortest[u.index] + weight;
                prev[v] = u;

                try queue.add( .{.index = v, .weight = shortest[v]});
            }
        }
    }

    for (0.., prev) |i, p| {
        if (i % 10 == 0) std.debug.print("\n", .{});
        std.debug.print("{}: {}, ", .{p.index, p.weight});
    }
    //std.log.info("Shortest {any}, prev{any}", .{shortest, prev});
    //
    return .{.shortest = shortest, .prev = prev};

}
