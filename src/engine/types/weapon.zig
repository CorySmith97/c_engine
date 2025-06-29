/// ===========================================================================
///
/// Author: Cory Smith
///
/// Date: 2025-04-27
///
/// Description:
/// ===========================================================================
const std = @import("std");

//
// Global weapons list with all the default weapon types.
//
pub const WeaponList = std.StaticStringMap(Self).initComptime(.{
    .{
        "iron sword",
        .{ .tag = .sword_iron, .subtype = .physical, .weight  = 1, .damage  = 2 }
    },
});

pub const Tag = enum {
    fist,

    // Sword class
    sword_iron,
    sword_copper,

    // Lance class
    lance_iron,
    lance_copper,
};

pub const Subtype = enum {
    magical,
    physical_str,
    physical_dex,
};

const Self = @This();
tag     : Tag = .fist,
subtype : Subtype = .physical_str,
weight  : f32 = 0,
damage  : f32 = 1,
