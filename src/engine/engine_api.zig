/// Public API for games to use the engine.
pub const RendererTypes = @import("types/render.zig");
pub const Editor = @import("types/editor.zig");
const Types = @import("types.zig");

pub const EngineApi = extern struct {
    // Types
    pub const Runtime = @import("globals.zig");
    pub const Camera = @import("types/camera.zig").Camera;
    pub const Camera3d = @import("types/camera.zig").Camera3d;
    pub const math = @import("util/math.zig");

    // Subsystems
    pub const Audio = @import("audio.zig");
    pub const Render = @import("render.zig");
};
