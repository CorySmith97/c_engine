const std = @import("std");

//
// Serialization mode. Set in the config_editor.json file
//
const SerdeMode = enum {
    JSON,
    BINARY,
};

//
// Place to store the configuration. Its in its own struct
// as we dont know what other data I may want to have be
// configurable within the editor.
//
pub const EditorConfig = struct {
    mode: SerdeMode = .JSON,
    starting_level: []const u8 = "",

    pub fn loadConfig(
        self: *EditorConfig,
        allo: std.mem.Allocator,
    ) !void {
        var cwd = std.fs.cwd();

        var config_file = try cwd.openFile("config_editor.json", .{ .mode = .read_write });
        defer config_file.close();

        const config_buf = try config_file.readToEndAlloc(allo, 1000);

        const temp = try std.json.parseFromSliceLeaky(EditorConfig, allo, config_buf, .{});
        self.mode = temp.mode;
    }
};
