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
    const StdoutGraphOutputWriter = zigbo.GraphOutputStep(@TypeOf(stdout_writer));
    const graph_step = StdoutGraphOutputWriter.init(b, stdout_writer, null);
    const build_graph_step = b.step("graph", "Output the build graph as a mermaid diagram");
    build_graph_step.dependOn(&graph_step.step);
}
