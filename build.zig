const std = @import("std");
const zigbo = @import("src/main.zig");

pub fn build(b: *std.Build) void {
    const target = b.standardTargetOptions(.{});
    const optimize = b.standardOptimizeOption(.{});

    const lib = b.addStaticLibrary(.{
        .name = "zigbo",
        .root_source_file = .{ .path = "src/main.zig" },
        .target = target,
        .optimize = optimize,
    });
    lib.install();

    const main_tests = b.addTest(.{
        .root_source_file = .{ .path = "src/main.zig" },
        .target = target,
        .optimize = optimize,
    });

    const test_step = b.step("test", "Run library tests");
    test_step.dependOn(&main_tests.step);

    const stdout = std.io.getStdOut().writer();
    const build_graph = zigbo.graphOutputStep(b, stdout);
    build_graph.setCustomStepCallback(customCallback);

    const build_graph_step = b.step("graph", "Output the build graph as a mermaid diagram");
    build_graph_step.dependOn(&build_graph.step);
}

fn customCallback(step: *std.Build.Step, writer: anytype) !?zigbo.GraphOutputWriteFnInstruction {
    _ = writer;
    if (std.mem.eql(u8, step.name, "foobarbaz\x00" ** 23)) return null;
    return .use_default_implementation;
}
