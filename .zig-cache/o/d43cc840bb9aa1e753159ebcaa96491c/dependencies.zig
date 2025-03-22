pub const packages = struct {
    pub const @"N-V-__8AAOG3BQCJ9cn-N2swm2o5cLmDhmdHmtwNngOChK78" = struct {
        pub const build_root = "/Users/corysmith/.cache/zig/p/N-V-__8AAOG3BQCJ9cn-N2swm2o5cLmDhmdHmtwNngOChK78";
        pub const deps: []const struct { []const u8, []const u8 } = &.{};
    };
    pub const @"cimgui-0.1.0-44ClkVShhQApVaApfb_mhXPpp08yqiB3zIBR0WYjbwwI" = struct {
        pub const build_root = "/Users/corysmith/.cache/zig/p/cimgui-0.1.0-44ClkVShhQApVaApfb_mhXPpp08yqiB3zIBR0WYjbwwI";
        pub const build_zig = @import("cimgui-0.1.0-44ClkVShhQApVaApfb_mhXPpp08yqiB3zIBR0WYjbwwI");
        pub const deps: []const struct { []const u8, []const u8 } = &.{
        };
    };
    pub const @"sokol-0.1.0-pb1HK8eOOQDLJmFo5VGGCVo2GxDm27dSsTHX8rsVb2bJ" = struct {
        pub const build_root = "/Users/corysmith/.cache/zig/p/sokol-0.1.0-pb1HK8eOOQDLJmFo5VGGCVo2GxDm27dSsTHX8rsVb2bJ";
        pub const build_zig = @import("sokol-0.1.0-pb1HK8eOOQDLJmFo5VGGCVo2GxDm27dSsTHX8rsVb2bJ");
        pub const deps: []const struct { []const u8, []const u8 } = &.{
            .{ "emsdk", "N-V-__8AAOG3BQCJ9cn-N2swm2o5cLmDhmdHmtwNngOChK78" },
        };
    };
};

pub const root_deps: []const struct { []const u8, []const u8 } = &.{
    .{ "sokol", "sokol-0.1.0-pb1HK8eOOQDLJmFo5VGGCVo2GxDm27dSsTHX8rsVb2bJ" },
    .{ "cimgui", "cimgui-0.1.0-44ClkVShhQApVaApfb_mhXPpp08yqiB3zIBR0WYjbwwI" },
};
