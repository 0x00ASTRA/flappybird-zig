const std = @import("std");

pub fn build(b: *std.Build) void {
    const target = b.standardTargetOptions(.{});
    const optimize = b.standardOptimizeOption(.{});

    // ########[ Program Executable ]########
    const exe = b.addExecutable(.{
        .name = "FlappyBird-Zig",
        .root_source_file = b.path("src/main.zig"),
        .target = target,
        .optimize = optimize,
    });

    // ########[ Raylib Dependency ]########
    const raylib_dep = b.dependency("raylib_zig", .{
        .target = target,
        .optimize = optimize,
        .shared = true,
    });

    const raylib = raylib_dep.module("raylib"); // main raylib module
    const raygui = raylib_dep.module("raygui"); // raygui module
    const raylib_artifact = raylib_dep.artifact("raylib"); // raylib C library

    exe.linkLibrary(raylib_artifact);
    exe.root_module.addImport("raylib", raylib);
    exe.root_module.addImport("raygui", raygui);

    // ########[ Lua Dependency ]########
    const lua_dep = b.dependency("zlua", .{
        .target = target,
        .optimize = optimize,
    });

    exe.root_module.addImport("zlua", lua_dep.module("zlua"));

    // ########[ TOML Dependency ]########
    const toml_dep = b.dependency("toml", .{
        .target = target,
        .optimize = optimize,
    });

    exe.root_module.addImport("toml", toml_dep.module("zig-toml"));

    // ########[ Install ]########
    b.installArtifact(exe);
    b.installArtifact(raylib_artifact);

    // ########[ Run Step ]########
    const run_cmd = b.addRunArtifact(exe);

    run_cmd.step.dependOn(b.getInstallStep());

    if (b.args) |args| {
        run_cmd.addArgs(args);
    }
    const run_step = b.step("run", "Run the app");
    run_step.dependOn(&run_cmd.step);

    // ########[ Test ]########
    const unit_test = b.addTest(.{
        .root_source_file = b.path("src/test.zig"),
        .optimize = optimize,
        .target = target,
    });

    unit_test.root_module.addImport("raylib", raylib);
    unit_test.root_module.addImport("raygui", raygui);
    unit_test.root_module.addImport("toml", toml_dep.module("zig-toml"));
    unit_test.root_module.addImport("lua", lua_dep.module("zlua"));

    const run_test = b.addRunArtifact(unit_test);
    const test_step = b.step("test", "run unit tests");
    test_step.dependOn(&run_test.step);
    test_step.dependOn(&b.addRunArtifact(unit_test).step);
}
