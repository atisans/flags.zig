const std = @import("std");

pub fn build(b: *std.Build) void {
    const target = b.standardTargetOptions(.{});
    const optimize = b.standardOptimizeOption(.{});

    const flags_mod = b.addModule("flags", .{
        .root_source_file = b.path("src/flags.zig"),
        .target = target,
        .optimize = optimize,
    });

    if (b.args) |args| {
        _ = args; // autofix
    }

    // Creates an executable that will run `test` blocks from the provided module.
    // Here `mod` needs to define a target, which is why earlier we made sure to
    // set the releative field.
    const flags_tests = b.addTest(.{
        .root_module = flags_mod,
    });

    // A run step that will run the test executable.
    const run_flags_tests = b.addRunArtifact(flags_tests);

    const test_step = b.step("test", "Run tests");
    test_step.dependOn(&run_flags_tests.step);
}
