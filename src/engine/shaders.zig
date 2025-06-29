/// ===========================================================================
///
/// Author: Cory Smith
///
/// Date: 2025-04-26
///
/// Description:
/// ===========================================================================


const std = @import("std");
pub const Basic = @import("shaders/basic.glsl.zig");

pub const Tags = enum { basic };

pub const Shaders = std.StaticStringMap(Tags).initComptime(.{

});
