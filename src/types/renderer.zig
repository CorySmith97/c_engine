/// ===========================================================================
///
/// Author: Cory Smith
///
/// Date: 2025-04-22
///
/// Description:
/// ===========================================================================


const math = @import("../util.zig").math;

pub const SpriteRenderable = extern struct {
    pos: math.Vec3,
    sprite_id: f32,
    color: math.Vec4,

    pub fn jsonStringify(self: *const SpriteRenderable, jws: anytype) !void {
        try jws.beginObject();
        try jws.objectField("pos");
        try jws.beginObject();
        try jws.objectField("x");
        try jws.print("{}", .{self.pos.x});
        try jws.objectField("y");
        try jws.print("{}", .{self.pos.y});
        try jws.objectField("z");
        try jws.print("{}", .{self.pos.z});
        try jws.endObject();

        try jws.objectField("sprite_id");
        try jws.print("{}", .{self.sprite_id});

        try jws.objectField("color");
        try jws.beginObject();
        try jws.objectField("x");
        try jws.print("{}", .{self.color.x});
        try jws.objectField("y");
        try jws.print("{}", .{self.color.y});
        try jws.objectField("z");
        try jws.print("{}", .{self.color.z});
        try jws.objectField("w");
        try jws.print("{}", .{self.color.w});
        try jws.endObject();

        try jws.endObject();
    }
};

pub const pass_count: u32 = 4;

pub const RenderPassIds = enum {
    TILES_1,
    TILES_2,
    ENTITY_1,
    UI_1,
};
