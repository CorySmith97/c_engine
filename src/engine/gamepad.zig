/// ===========================================================================
///
/// Author: Cory Smith
///
/// Date: 2025-05-09
///
/// Description:
/// ===========================================================================
const std = @import("std");

const types = @import("../types.zig");
const Scene = types.Scene;

const Input = @import("input.zig");
const c = @cImport({
    @cInclude("gamepad/Gamepad.h");
});
const State = @import("engine_state.zig");

pub fn gamepadInit() void {
    c.Gamepad_init();
    c.Gamepad_deviceAttachFunc(on_attach, null);
    c.Gamepad_buttonDownFunc(on_button_down, null);
    c.Gamepad_buttonUpFunc(on_button_up, null);
    c.Gamepad_axisMoveFunc(on_axis_move, null);
    c.Gamepad_detectDevices();
}

pub fn gamepadEvent() void {
    c.Gamepad_processEvents();
}

pub fn gamepadCleanup() void {
    c.Gamepad_shutdown();
}

export fn on_attach(device: [*c]c.Gamepad_device, context: ?*anyopaque) callconv(.C) void {
    _ = device;
    _ = context;
    std.log.info("Gamepad attached: ", .{});
}

export fn on_button_down(
    device: [*c]c.Gamepad_device,
    buttonID: u32,
    timestamp: f64,
    context: ?*anyopaque,
) callconv(.C) void {
    var state: *State = @ptrCast(@alignCast(context));
    _ = device;
    _ = timestamp;
    const s: *Scene = &(state.loaded_scene orelse return);
    // x playstation
    if (buttonID == 1) {
        switch (state.game_cursor_mode) {
            .default => {
                Input.selectEntity(s, &state) catch @panic("");
            },
            .selected_entity => {
                Input.placeEntity(s, &state) catch @panic("");
            },
            .selecting_target => {
                if (state.selected_target) |target| {
                    const selected = state.selected_entity orelse return;
                    var ent1 = s.entities.get(selected);
                    const ent2 = s.entities.get(target);

                    const res = EntityNs.combat(ent1.stats, ent1.weapon, ent2.stats, ent2.weapon) catch @panic("");
                    const results = std.fmt.allocPrint(state.allocator, "Ent1 did {} damage to Ent2", .{res}) catch @panic("");
                    defer state.allocator.free(results);

                    state.logger.appendToCombatLog(results) catch @panic("");
                    ent1.flags.turn_over = true;

                    state.updateSpriteRenderable(&ent1.sprite, selected) catch @panic("");
                    s.entities.set(selected, ent1);

                    state.game_cursor_mode = .default;

                    state.selected_entity = null;
                    state.selected_target = null;
                }
            },
            .selecting_action => {
                Input.selectingAction(s, &state) catch @panic("");
            },
            else => {},
        }
    }
    std.log.info("Button {d} down on ID ", .{buttonID});
}

export fn on_button_up(device: [*c]c.Gamepad_device, buttonID: u32, timestamp: f64, context: ?*anyopaque) callconv(.C) void {
    _ = device;
    _ = timestamp;
    _ = context;
    std.log.info("Button {d} up", .{buttonID});
}

export fn on_axis_move(
    device: [*c]c.Gamepad_device,
    axisID: u32,
    value: f32,
    lastValue: f32,
    timestamp: f64,
    context: ?*anyopaque,
) callconv(.C) void {
    const step = 16.0;
    const w2 = app.widthf() / 2 * global_state.camera.zoom;
    const h2 = app.heightf() / 2 * global_state.camera.zoom;
    const marginX = w2 * 2 * global_state.camera.zoom;
    const marginY = h2 * 2 * global_state.camera.zoom;

    const s = global_state.loaded_scene orelse return;
    // DPAD LEFT
    if (axisID == 7 and value == -1) {
        if (global_state.game_cursor_mode == .selecting_target) {
            for (global_state.potential_targets.items) |t| {
                for (s.entities.items(.sprite)) |sprite| {
                    const grid_space = util.vec3ToGridSpace(sprite.pos, 16, s.width);
                    if (grid_space == t) {
                        global_state.game_cursor.x -= 16;
                    }
                }
            }
            return;
        }
        if (global_state.game_cursor_mode == .selecting_action) return;
        if (global_state.game_cursor.x - 16 < global_state.camera.pos.x - marginX) {
            global_state.camera.pos.x -= 16;
        } else {
            global_state.game_cursor.x -= 16;
        }
    }

    // DPAD RIGHT
    if (axisID == 7 and value == 1) {
        if (global_state.game_cursor_mode == .selecting_action) return;
        if (global_state.game_cursor.x + step > global_state.camera.pos.x + marginX) {
            global_state.camera.pos.x += step;
        } else {
            global_state.game_cursor.x += 16;
        }
    }

    // DPAD UP
    if (axisID == 8 and value == -1) {
        if (global_state.game_cursor_mode == .selecting_action) {
            global_state.selected_action = @enumFromInt(if ((@intFromEnum(global_state.selected_action)) == 0) 3 else @intFromEnum(global_state.selected_action) - 1);
            return;
        }

        if (global_state.game_cursor.y + step > global_state.camera.pos.y + marginY) {
            global_state.camera.pos.y += step;
        } else {
            global_state.game_cursor.y += 16;
        }
    }

    // DPAD DOWN
    if (axisID == 8 and value == 1) {
        if (global_state.game_cursor_mode == .selecting_target) {
            const gc = util.vec2ToGridSpace(global_state.game_cursor, 16, s.width);
            for (0.., s.entities.items(.sprite)) |i, sprite| {
                const target = util.vec3ToGridSpace(sprite.pos, 16, s.width);
                if (gc == target) {
                    global_state.selected_target = i;
                }
            }
        }
        if (global_state.game_cursor_mode == .selecting_action) {
            global_state.selected_action = @enumFromInt(if ((@intFromEnum(global_state.selected_action)) == 3) 0 else @intFromEnum(global_state.selected_action) + 1);
            return;
        }
        if (global_state.game_cursor.y - step < global_state.camera.pos.y - marginY) {
            global_state.camera.pos.y -= step;
        } else {
            global_state.game_cursor.y -= 16;
        }
    }
    _ = device;
    _ = lastValue;
    _ = timestamp;
    _ = context;
    if (axisID != 6 and @abs(value) > 0.25) {
        std.log.info("Button {d} up, value: {d}", .{ axisID, value });
    }
}
