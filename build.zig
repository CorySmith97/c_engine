const std = @import("std");
const log = std.log.scoped(.compilation);
const sokol = @import("sokol");
const builtin = @import("builtin");

const BuildModes = enum {
    shaders,
    engine,
    editor,
    game,
    vk,
};

pub fn build(b: *std.Build) void {
    const target = b.standardTargetOptions(.{});
    const optimize = b.standardOptimizeOption(.{});

    const build_mode = b.option(BuildModes, "mode", "build mode") orelse .engine;

    switch (build_mode) {
        .vk => try buildVkRenderer(b, target, optimize),
        .shaders => buildShaders(b,target),
        .editor => try buildEditor(b, target, optimize),
        .engine => try buildEngine(b, target, optimize),
        .game => try buildGame(b, target, optimize),
    }
    return;
}

pub fn buildGame(
    b: *std.Build,
    target: std.Build.ResolvedTarget,
    optimize: std.builtin.OptimizeMode,
) !void {
    const exe_mod = b.createModule(.{
        .root_source_file = b.path("src/game/game.zig"),
        .target = target,
        .optimize = optimize,
        .imports = &.{
        },
    });
    const exe = b.addSharedLibrary(.{
        .name = "c_engine",
        .root_module = exe_mod,
    });

    b.installArtifact(exe);
}


pub fn buildEngine(
    b: *std.Build,
    target: std.Build.ResolvedTarget,
    optimize: std.builtin.OptimizeMode,
) !void {
    const dep_sokol = b.dependency("sokol", .{
        .target = target,
        .optimize = optimize,
        .with_sokol_imgui = true,
    });
    const dep_cimgui = b.dependency("cimgui", .{
        .target = target,
        .optimize = optimize,
    });

    dep_sokol.artifact("sokol_clib").addIncludePath(dep_cimgui.path("src-docking"));

    const exe_mod = b.createModule(.{
        .root_source_file = b.path("src/main.zig"),
        .target = target,
        .optimize = optimize,
        .imports = &.{
            .{ .name = "sokol", .module = dep_sokol.module("sokol") },
            .{ .name = "cimgui", .module = dep_cimgui.module("cimgui") },
        },
    });
    const exe = b.addExecutable(.{
        .name = "c_engine",
        .root_module = exe_mod,
    });


    exe.linkLibC();
    exe.addCSourceFiles(.{
        .root = b.path("libs/"),
        .files = &[_][]const u8{
            "stb_impl.c",
            //"gamepad/Gamepad_linux.c",
            //"gamepad/Gamepad_windows_dinput.c",
            //"gamepad/Gamepad_windows_mm.c",
        },
        .flags = &[_][]const u8{
            "-std=c23",
        },
    });

    //
    // @todo(cs) add extra stuff for the linux/windows support for gamepad
    //
    if (target.result.os.tag == .macos) {
        exe.addCSourceFile(.{ .file = b.path("libs/gamepad/Gamepad_macosx.c")});
        exe.linkFramework("IOKit");
        exe.linkFramework("CoreFoundation");
    }

    exe.addCSourceFile(.{.file = b.path("libs/gamepad/Gamepad_private.c")});

    exe.addIncludePath(b.path("libs/"));
    exe.addIncludePath(b.path("libs/gamepad/"));
    exe.installHeader(b.path("libs/stb_image.h"), "stb_image.h");
    exe.installHeader(b.path("libs/gamepad/Gamepad.h"), "Gamepad.h");
    exe.installHeader(b.path("libs/gamepad/Gamepad_private.h"), "Gamepad_private.h");


    exe.root_module.addImport("sokol", dep_sokol.module("sokol"));


    b.installArtifact(exe);

    const run_cmd = b.addRunArtifact(exe);

    run_cmd.step.dependOn(b.getInstallStep());

    if (b.args) |args| {
        run_cmd.addArgs(args);
    }

    const run_step = b.step("run", "Run the app");
    run_step.dependOn(&run_cmd.step);

    const exe_unit_tests = b.addTest(.{
        .root_module = exe_mod,
    });

    const run_exe_unit_tests = b.addRunArtifact(exe_unit_tests);

    const test_step = b.step("test", "Run unit tests");
    test_step.dependOn(&run_exe_unit_tests.step);

}

pub fn buildVkRenderer(
    b: *std.Build,
    target: std.Build.ResolvedTarget,
    optimize: std.builtin.OptimizeMode,
) !void {
    const exe = b.addExecutable(.{
        .name = "zig-vulkan",
        .root_source_file = b.path("src/vk/main.zig"),
        .target = target,
        .optimize = optimize,
    });

    exe.linkSystemLibrary("glfw3");
    exe.linkSystemLibrary("vulkan");
    exe.linkLibC();

    b.installArtifact(exe);
    const run_cmd = b.addRunArtifact(exe);

    run_cmd.step.dependOn(b.getInstallStep());

    if (b.args) |args| {
        run_cmd.addArgs(args);
    }

    const run_step = b.step("run", "Run the app");
    run_step.dependOn(&run_cmd.step);
    return;
}

pub fn buildEditor(
    b: *std.Build,
    target: std.Build.ResolvedTarget,
    optimize: std.builtin.OptimizeMode,
) !void {

    const dep_sokol = b.dependency("sokol", .{
        .target = target,
        .optimize = optimize,
        .with_sokol_imgui = true,
    });
    const dep_cimgui = b.dependency("cimgui", .{
        .target = target,
        .optimize = optimize,
    });

    dep_sokol.artifact("sokol_clib").addIncludePath(dep_cimgui.path("src-docking"));

    const exe_mod = b.createModule(.{
        .root_source_file = b.path("src/engine/editor.zig"),
        .target = target,
        .optimize = optimize,
        .imports = &.{
            .{ .name = "sokol", .module = dep_sokol.module("sokol") },
            .{ .name = "cimgui", .module = dep_cimgui.module("cimgui") },
        },
    });

    const exe = b.addExecutable(.{
        .name = "c_engine_editor",
        .root_module = exe_mod,
    });

    exe.linkLibC();
    exe.addCSourceFiles(.{
        .root = b.path("libs/"),
        .files = &[_][]const u8{
            "stb_impl.c",
        },
        .flags = &[_][]const u8{
            "-std=c23",
        },
    });
    //exe.addLibraryPath(b.path("libs/lua/install/lib"));
    //exe.linkSystemLibrary("lua");
    exe.addIncludePath(b.path("libs/"));
    //exe.addIncludePath(b.path("libs/lua/install/include"));
    exe.installHeader(b.path("libs/stb_image.h"), "stb_image.h");
    //exe.installHeader(b.path("libs/lua/install/include/lua.h"), "lua.h");
    //exe.installHeader(b.path("libs/lua/install/include/lualib.h"), "lualib.h");
    //exe.installHeader(b.path("libs/lua/install/include/lauxlib.h"), "lauxlib.h");
    //exe.installHeader(b.path("libs/lua/install/include/luaconf.h"), "luaconf.h");

    exe.root_module.addImport("sokol", dep_sokol.module("sokol"));

    b.installArtifact(exe);

    const run_cmd = b.addRunArtifact(exe);

    run_cmd.step.dependOn(b.getInstallStep());

    if (b.args) |args| {
        run_cmd.addArgs(args);
    }

    const run_step = b.step("run", "Run the app");
    run_step.dependOn(&run_cmd.step);

    const exe_unit_tests = b.addTest(.{
        .root_module = exe_mod,
    });

    const run_exe_unit_tests = b.addRunArtifact(exe_unit_tests);

    const test_step = b.step("test", "Run unit tests");
    test_step.dependOn(&run_exe_unit_tests.step);
    return;
}

pub fn buildGameNative(b: *std.Build, target: std.Build.ResolvedTarget, opt: std.builtin.OptimizeMode) !*std.Build.Step.Compile {
    const game = b.addStaticLibrary(.{
        .name = "game",
        .target = target,
        .optimize = opt,
        .root_source_file = b.path("src/game/game.zig"),
    });

    b.installArtifact(game);


    return game;
}

//
// SHADERS
//
const shaders = [2][]const u8{
    "src/engine/shaders/basic.glsl",
    "src/engine/shaders/quad.glsl",
};

pub fn compileShaders(target: std.Build.ResolvedTarget, file_name: []const u8) void {
    var buf: [1024]u8 = undefined;
    const out_name = std.fmt.bufPrint(&buf, "{s}.zig", .{file_name}) catch @panic("failed to format");
    std.log.info("{s}", .{std.fs.selfExePathAlloc(std.heap.page_allocator) catch unreachable});
    var sokol_proc: []const u8 = undefined;
    if (target.result.isMinGW()) {
        sokol_proc = "./shader_comp_tools/sokol-shdc.exe";
    } else {
        sokol_proc = "./shader_comp_tools/sokol-shdc";
    }
    const args = [_][]const u8{
        sokol_proc,
        "--input",
        file_name,
        "--output",
        out_name,
        "--slang",
        "glsl430:metal_macos:hlsl5",
        "--format",
        "sokol_zig",
    };

    var compiler = std.process.Child.init(&args, std.heap.page_allocator);
    _ = compiler.spawnAndWait() catch @panic("Failed to compile shader");
}

pub fn buildShaders(b: *std.Build, target: std.Build.ResolvedTarget) void {
    _ = b;
    for (shaders) |shader| {
        compileShaders(target, shader);
    }
}
