/// ===========================================================================
///
/// Author: Cory Smith
///
/// Date: 2025-06-30
///
/// Description:
/// This is a dialog graph system for branching story based games. As this
/// engine intends to have lots of story based mechanics, I need a good
/// visual graph based editor. Thats the idea of this. Be able to build a
/// full graph of possible dialog options that can be navigated at free will
/// by the player.
/// ===========================================================================
const std = @import("std");

pub const TreeNode = struct {
    children: []*TreeNode,
    // Actual Dialog
    dialog: []const u8,
    // Audio buffer
    audio: []f32,

    callback_event: ?*const fn (*anyopaque) anyerror!void,

    // This needs to be a platform agnostic thing. IE Clay
    pub fn draw_node(
        self: *TreeNode,
    ) !void {
        _ = self;
    }
};
