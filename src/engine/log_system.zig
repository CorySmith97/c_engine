/// ===========================================================================
///
/// Author: Cory Smith
///
/// Date: 2025-04-28
///
/// Description:
/// ===========================================================================

const std = @import("std");


// @cleanup Possibly use a queue for no memory allocations after setup?

pub const LogSystem = struct {
    allocator: std.mem.Allocator,
    combat_logs: std.ArrayList([:0]const u8),


    pub fn init(
        self: *LogSystem,
        allocator: std.mem.Allocator,
    ) !void {
        self.allocator  = allocator;
        self.combat_logs = std.ArrayList([:0]const u8).init(allocator);
    }

    pub fn appendToCombatLog(
        self: *LogSystem,
        string: []const u8,
    ) !void {
        const new_log = try std.fmt.allocPrintZ(self.allocator, "{s}" , .{string});
        try self.combat_logs.append(new_log);
    }

    pub fn deinit(
        self: *LogSystem,
    ) void {
        self.combat_logs.deinit();
    }
};

