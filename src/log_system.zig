/// ===========================================================================
///
/// Author: Cory Smith
///
/// Date: 2025-04-28
///
/// Description:
/// ===========================================================================

const std = @import("std");


pub const LogSystem = struct {
    logs: std.ArrayList(Log),
};

pub const Log = struct {
    tag  : LogTag,
    file : std.fs.File,

    const LogTag = enum {
        combat,
    };
};
