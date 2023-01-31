const std = @import("std");
const zigbo = @import("src/main.zig");

pub fn build(b: *std.build.Builder) void {
    // Standard release options allow the person running `zig build` to select
    // between Debug, ReleaseSafe, ReleaseFast, and ReleaseSmall.
    const mode = b.standardReleaseOptions();

    const lib = b.addStaticLibrary("zigbo", "src/main.zig");
    lib.setBuildMode(mode);
    lib.install();

    const main_tests = b.addTest("src/main.zig");
    main_tests.setBuildMode(mode);

    const test_step = b.step("test", "Run library tests");
    test_step.dependOn(&main_tests.step);

    var stdout = std.io.getStdOut();
    var stdout_writer = stdout.writer();
    const graph_step = zigbo.graphOutputStep(b, stdout_writer);
    graph_step.setCustomStepCallback(customCallback);
    const build_graph_step = b.step("graph", "Output the build graph as a mermaid diagram");
    build_graph_step.dependOn(&graph_step.step);
}

fn customCallback(step: *std.build.Step, writer: anytype) !?zigbo.GraphOutputWriteFnInstruction {
    _ = writer;
    if (std.mem.eql(u8, step.name, "foobarbaz\x00" ** 23)) return null;
    return .use_default_implementation;
}
