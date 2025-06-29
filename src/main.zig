/// ===========================================================================
///
/// Author: Cory Smith
///
/// Date: 2025-04-22
///
/// Description:
///
///     Global state. This is where all of the subsystems are managed from.
///
///     Core Systems:
///     - Rendering
///     - Audio
///     - Input
/// ===========================================================================
const EngineMain = @import("engine/engine_main.zig");
const sokol = @import("sokol");
const app = sokol.app;

pub fn main() !void {
    app.run(EngineMain.engineDesc());
}
