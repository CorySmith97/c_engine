const std = @import("std");
const log = std.log.scoped(.compilation);
const sokol = @import("sokol");

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
    const shd_only = b.option(bool, "shdonly", "compile only the shaders");
    for (shaders) |shader| {
        compileShaders(target, shader);
    }
    if (shd_only) |s| {
        if (s) {
            return;
        }
    }
}

pub fn buildWeb() void {

}

pub fn buildEngineNative() !void {

}

pub fn buildGameNative() !void {

}

pub fn build(b: *std.Build) void {
    const target = b.standardTargetOptions(.{});
    const optimize = b.standardOptimizeOption(.{});

    buildShaders(b, target);

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

    // This is set to true for the mean time as I am primarily working on the editor.
    // @important
    const editor_only = b.option(bool, "editor", "editor mode activated") orelse false;

    if (editor_only) {
        const exe_mod = b.createModule(.{
            .root_source_file = b.path("src/editor.zig"),
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

    //if (target.result.os.tag == .emscripten) {
    //    const emsdk = dep_sokol.builder.dependency("emsdk", .{});
    //    const link_step = try sokol.emLinkStep(b, .{
    //        .lib_main = exe,
    //        .target = target,
    //        .optimize = optimize,
    //        .emsdk = emsdk,
    //        .use_webgl2 = true,
    //        .use_emmalloc = true,
    //        .use_filesystem = false,
    //        .shell_file_path = dep_sokol.path("src/sokol/web/shell.html"),
    //    });

    //    b.getInstallStep().dependOn(&link_step.step);
    //    // ...and a special run step to start the web build output via 'emrun'
    //    const run = sokol.emRunStep(b, .{ .name = "pacman", .emsdk = emsdk });
    //    run.step.dependOn(&link_step.step);
    //    b.step("run", "Run pacman").dependOn(&run.step);
    //    return;

    //}


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

    // Similar to creating the run step earlier, this exposes a `test` step to
    // the `zig build --help` menu, providing a way for the user to request
    // running the unit tests.
    const test_step = b.step("test", "Run unit tests");
    test_step.dependOn(&run_exe_unit_tests.step);
}
