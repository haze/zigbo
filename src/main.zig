const std = @import("std");

/// Outputs a mermaid diagram describing the build graph
pub fn GraphOutputStep(comptime WriterType: type) type {
    return struct {
        const Self = @This();
        pub const formatting = struct {
            pub const Artifact = struct {
                lib_exe_obj_step: *std.build.LibExeObjStep,

                pub fn format(
                    artifact: Artifact,
                    comptime fmt: []const u8,
                    options: std.fmt.FormatOptions,
                    writer: anytype,
                ) !void {
                    _ = fmt;
                    _ = options;
                    try step_inspection_functions.annotateLibExeObjStep(&artifact.lib_exe_obj_step.step, writer, .{
                        .print_newlines = false,
                        .print_in_between_quotes = false,
                    });
                }
            };

            pub const FormattedFileSource = struct {
                builder: *std.build.Builder,
                file_source: std.build.FileSource,

                pub fn format(
                    file_source: FormattedFileSource,
                    comptime fmt: []const u8,
                    options: std.fmt.FormatOptions,
                    writer: anytype,
                ) !void {
                    _ = fmt;
                    _ = options;
                    const path = file_source.file_source.getPath(file_source.builder);
                    defer file_source.builder.allocator.free(path);
                    try writer.writeAll(path);
                }
            };

            pub const FormattedInstallDir = struct {
                install_dir: std.build.InstallDir,

                pub fn format(
                    formatted_install_directory: FormattedInstallDir,
                    comptime fmt: []const u8,
                    options: std.fmt.FormatOptions,
                    writer: anytype,
                ) !void {
                    _ = fmt;
                    _ = options;

                    switch (formatted_install_directory.install_dir) {
                        .prefix => try writer.writeAll("prefix"),
                        .lib => try writer.writeAll("lib"),
                        .bin => try writer.writeAll("bin"),
                        .header => try writer.writeAll("header"),
                        .custom => |path| try writer.print("'{s}'", .{path}),
                    }
                }
            };

            pub const RunStepArg = struct {
                arg: std.build.RunStep.Arg,
                builder: *std.build.Builder,

                pub fn format(
                    run_step_arg: RunStepArg,
                    comptime fmt: []const u8,
                    options: std.fmt.FormatOptions,
                    writer: anytype,
                ) !void {
                    _ = options;
                    _ = fmt;
                    switch (run_step_arg.arg) {
                        .bytes => |bytes| try writer.print("&quot;{s}&quot;", .{bytes}),
                        .file_source => |file_source| try writer.print("{}", .{formatting.FormattedFileSource{ .file_source = file_source, .builder = run_step_arg.builder }}),
                        .artifact => |artifact| try writer.print("{}", .{formatting.Artifact{ .lib_exe_obj_step = artifact }}),
                    }
                }
            };
        };

        pub const AnnotatedBuiltinStep = struct {
            step: *std.build.Step,
            graph_output_step: *Self,

            pub fn format(
                annotated_builtin_step: AnnotatedBuiltinStep,
                comptime fmt: []const u8,
                options: std.fmt.FormatOptions,
                writer: anytype,
            ) !void {
                _ = fmt;
                _ = options;

                return switch (annotated_builtin_step.step.id) {
                    .top_level => step_inspection_functions.annotateTopLevelStep(annotated_builtin_step.step, writer),
                    .install_artifact => step_inspection_functions.annotateInstallArtifactStep(annotated_builtin_step.step, writer),
                    .lib_exe_obj => step_inspection_functions.annotateLibExeObjStep(annotated_builtin_step.step, writer, .{
                        .print_newlines = true,
                        .print_in_between_quotes = true,
                    }),
                    .run => step_inspection_functions.annotateRunStep(annotated_builtin_step.step, writer),
                    .custom => {
                        var should_use_default_implementation = false;
                        if (annotated_builtin_step.graph_output_step.maybe_custom_step_callback) |customFormatFn| {
                            const maybe_instruction = try customFormatFn(annotated_builtin_step.step, writer);
                            should_use_default_implementation = maybe_instruction != null and maybe_instruction.? == .use_default_implementation;
                        } else {
                            should_use_default_implementation = true;
                        }
                        if (should_use_default_implementation) {
                            try writer.print("\"Opaque Custom Step ({s})\"", .{annotated_builtin_step.step.name});
                        }
                    },
                    // TODO(haze): better messages for these
                    .options => try writer.writeAll("Options step"),
                    .install_raw => try writer.writeAll("InstallRaw step"),
                    .config_header => try writer.writeAll("Configure Header step"),
                    .check_object => try writer.writeAll("CHeck Object step"),
                    .check_file => try writer.writeAll("Check File step"),
                    .emulatable_run => try writer.writeAll("Emulatable Run step"),
                    .write_file => try writer.writeAll("Write File step"),
                    .translate_c => try writer.writeAll("Translate-C step"),
                    .fmt => try writer.writeAll("Format step"),
                    .remove_dir => try writer.writeAll("Remove Directory step"),
                    .log => try writer.writeAll("Log step"),
                    .install_dir => try writer.writeAll("Install Directory step"),
                    .install_file => try writer.writeAll("Install File step"),
                };
            }
        };

        pub const step_inspection_functions = struct {
            pub fn annotateTopLevelStep(step: *std.build.Step, writer: anytype) !void {
                _ = step;
                try writer.writeAll("Opaque Top Level Step");
                // Disabled until TopLevelStep is marked as public
                // const top_level_step = @fieldParentPtr(std.build.Builder.TopLevelStep, "step", step);
                // try writer.writeAll(top_level_step.description);
            }

            pub fn annotateLibExeObjStep(step: *std.build.Step, writer: anytype, options: struct {
                print_newlines: bool,
                print_in_between_quotes: bool,
            }) !void {
                const lib_exe_obj_step = @fieldParentPtr(std.build.LibExeObjStep, "step", step);
                if (options.print_in_between_quotes) {
                    try writer.writeByte('"');
                }

                try writer.writeAll("LibExeObjStep");

                if (!options.print_in_between_quotes) {
                    try writer.print("{{name: '{s}'", .{lib_exe_obj_step.name});
                } else {
                    try writer.print(" ({s})", .{lib_exe_obj_step.name});
                }

                if (options.print_newlines) {
                    try writer.writeAll("\\n");
                } else {
                    try writer.writeAll(", ");
                }

                try writer.print("kind: {s}", .{@tagName(lib_exe_obj_step.kind)});

                if (options.print_newlines) {
                    try writer.writeAll("\\n");
                } else {
                    try writer.writeAll(", ");
                }
                try writer.print("mode: {s}", .{@tagName(lib_exe_obj_step.build_mode)});

                if (lib_exe_obj_step.linkage) |linkage| {
                    if (options.print_newlines) {
                        try writer.writeAll("\\n");
                    } else {
                        try writer.writeAll(", ");
                    }
                    try writer.print("linkage: {s}", .{@tagName(linkage)});
                }

                if (lib_exe_obj_step.root_src) |root_src| {
                    if (options.print_newlines) {
                        try writer.writeAll("\\n");
                    } else {
                        try writer.writeAll(", ");
                    }
                    try writer.print("root_src: '{}'", .{formatting.FormattedFileSource{ .file_source = root_src, .builder = lib_exe_obj_step.builder }});
                }

                if (lib_exe_obj_step.version) |version| {
                    if (options.print_newlines) {
                        try writer.writeAll("\\n");
                    } else {
                        try writer.writeAll(", ");
                    }
                    try writer.print("version: {}", .{version});
                }

                if (options.print_in_between_quotes) {
                    try writer.writeByte('"');
                } else {
                    try writer.writeByte('}');
                }
            }

            pub fn annotateGraphOutputStep(step: *std.Build.Step, writer: anytype) !void {
                _ = step;
                try writer.writeAll("GraphOutputStep");
            }

            // TODO(haze): annotate envmap
            pub fn annotateRunStep(step: *std.build.Step, writer: anytype) !void {
                const run_step = @fieldParentPtr(std.build.RunStep, "step", step);

                try writer.writeAll("\"RunStep\\nargv: [");
                for (run_step.argv.items) |arg, index| {
                    try writer.print("{}", .{formatting.RunStepArg{ .arg = arg, .builder = run_step.builder }});
                    if (index != run_step.argv.items.len - 1) {
                        try writer.writeAll(", ");
                    }
                }
                try writer.writeAll("]");

                if (run_step.cwd) |cwd| {
                    try writer.print("\\ncwd: '{s}'", .{cwd});
                }

                if (run_step.expected_exit_code) |exit_code| {
                    try writer.print("\\nexpecting exit code: {}", .{exit_code});
                }

                try writer.writeAll("\"");
            }

            pub fn annotateInstallArtifactStep(step: *std.build.Step, writer: anytype) !void {
                const install_artifact_step = @fieldParentPtr(std.build.InstallArtifactStep, "step", step);

                try writer.print("\"InstallArtifactStep: ({s})\\ndestination: {}\"", .{ install_artifact_step.step.name, install_artifact_step.dest_dir });

                if (install_artifact_step.pdb_dir) |pdb_directory| {
                    try writer.print("\\nPDB directory: {}", .{pdb_directory});
                }

                if (install_artifact_step.pdb_dir) |header_directory| {
                    try writer.print("\\nHeader directory: {}", .{header_directory});
                }
            }
        };

        pub const Header = struct {
            pub const Direction = enum {
                top_to_bottom,
                top_down,
                bottom_to_top,
                right_to_left,
                left_to_right,

                pub fn format(
                    direction: Direction,
                    comptime fmt: []const u8,
                    options: std.fmt.FormatOptions,
                    writer: anytype,
                ) !void {
                    _ = options;
                    _ = fmt;
                    try writer.writeAll(switch (direction) {
                        .top_to_bottom => "TB",
                        .top_down => "TD",
                        .bottom_to_top => "BT",
                        .right_to_left => "RL",
                        .left_to_right => "LR",
                    });
                }
            };

            direction: Direction,

            pub fn format(
                header: Header,
                comptime fmt: []const u8,
                options: std.fmt.FormatOptions,
                writer: anytype,
            ) !void {
                _ = options;
                _ = fmt;
                try writer.print("flowchart {}", .{header.direction});
            }
        };

        pub const Subgraph = struct {
            pub const Start = struct {
                name: []const u8,
                id: usize,

                pub fn format(
                    start: Start,
                    comptime fmt: []const u8,
                    options: std.fmt.FormatOptions,
                    writer: anytype,
                ) !void {
                    _ = options;
                    _ = fmt;
                    try writer.print("subgraph tls_{} [{s}]", .{ start.id, start.name });
                }
            };
            pub const End = struct {
                pub fn format(
                    end: End,
                    comptime fmt: []const u8,
                    options: std.fmt.FormatOptions,
                    writer: anytype,
                ) !void {
                    _ = end;
                    _ = options;
                    _ = fmt;
                    try writer.writeAll("end");
                }
            };
        };

        pub const Edge = struct {
            parent: *std.build.Step,
            parent_id: usize,
            include_parent_description: bool,

            child: *std.build.Step,
            child_id: usize,
            include_child_description: bool,

            graph_output_step: *Self,

            pub fn format(
                edge: Edge,
                comptime fmt: []const u8,
                options: std.fmt.FormatOptions,
                writer: anytype,
            ) !void {
                _ = options;
                _ = fmt;
                try writer.print("step_{}", .{
                    edge.parent_id,
                });
                if (edge.include_parent_description) {
                    try writer.print("[{}]", .{
                        AnnotatedBuiltinStep{
                            .step = edge.parent,
                            .graph_output_step = edge.graph_output_step,
                        },
                    });
                }
                try writer.writeAll(" --> ");
                try writer.print("step_{}", .{
                    edge.child_id,
                });
                if (edge.include_child_description) {
                    try writer.print("[{}]", .{
                        AnnotatedBuiltinStep{
                            .step = edge.child,
                            .graph_output_step = edge.graph_output_step,
                        },
                    });
                }
            }
        };

        pub const Node = struct {
            item: *std.build.Step,
            id: usize,
            include_description: bool,
            graph_output_step: *Self,

            pub fn format(
                node: Node,
                comptime fmt: []const u8,
                options: std.fmt.FormatOptions,
                writer: anytype,
            ) !void {
                _ = options;
                _ = fmt;
                try writer.print("step_{}", .{
                    node.id,
                });
                if (node.include_description) {
                    try writer.print("[{}]", .{
                        AnnotatedBuiltinStep{
                            .step = node.item,
                            .graph_output_step = node.graph_output_step,
                        },
                    });
                }
            }
        };

        pub const GraphOutputWriteFnInstruction = enum {
            /// Simply print out "Opaque Custom Step (step_name)"
            use_default_implementation,
        };
        pub const GraphOutputWriteFnResult = Writer.Error!?GraphOutputWriteFnInstruction;
        pub const GraphOutputWriteFn = *const fn (step: *std.build.Step, writer: Writer) GraphOutputWriteFnResult;

        pub const Writer = WriterType;
        writer: Writer,
        builder: *std.build.Builder,
        step: std.build.Step,
        maybe_custom_step_callback: ?GraphOutputWriteFn,

        pub fn init(builder: *std.build.Builder, writer: Writer, maybe_custom_step_output_fn: ?GraphOutputWriteFn) *@This() {
            var graph_output_step = builder.allocator.create(@This()) catch unreachable;
            graph_output_step.* = @This(){
                .writer = writer,
                .builder = builder,
                .step = std.build.Step.init(.custom, "Graph Output", builder.allocator, @This().make),
                .maybe_custom_step_callback = maybe_custom_step_output_fn,
            };
            return graph_output_step;
        }

        pub fn make(type_erased_graph_output_step: *std.build.Step) !void {
            const graph_output_step = @fieldParentPtr(@This(), "step", type_erased_graph_output_step);
            try graph_output_step.writer.print("{}\n", .{
                Header{
                    .direction = .top_down,
                },
            });
            var subgraph_counter: usize = 0;

            var step_id_map = std.AutoHashMapUnmanaged(*std.build.Step, usize){};
            var running_step_id: usize = 0;
            defer step_id_map.deinit(graph_output_step.builder.allocator);

            var step_visited_map = std.AutoHashMapUnmanaged(*std.build.Step, void){};
            defer step_visited_map.deinit(graph_output_step.builder.allocator);

            for (graph_output_step.builder.top_level_steps.items) |top_level_step| {
                try graph_output_step.writer.print("\t{}\n", .{Subgraph.Start{
                    .name = top_level_step.description,
                    .id = subgraph_counter,
                }});

                var dependency_stack = std.ArrayListUnmanaged(*std.build.Step){};
                defer dependency_stack.deinit(graph_output_step.builder.allocator);

                var parent_map = std.AutoHashMapUnmanaged(*std.build.Step, *std.build.Step){};
                defer parent_map.deinit(graph_output_step.builder.allocator);

                try dependency_stack.append(graph_output_step.builder.allocator, &top_level_step.step);

                while (dependency_stack.popOrNull()) |step| {
                    var include_step_description: bool = false;
                    if (step_id_map.get(step) == null) {
                        try step_id_map.put(graph_output_step.builder.allocator, step, running_step_id);
                        include_step_description = true;
                        running_step_id += 1;
                    }
                    const step_id = step_id_map.get(step).?;

                    if (step_visited_map.get(step) == null) {
                        if (parent_map.get(step)) |parent_step| {
                            try graph_output_step.writer.print("\t{}\n", .{Edge{
                                .parent = parent_step,
                                .parent_id = step_id_map.get(parent_step).?,
                                .include_parent_description = false,
                                .child = step,
                                .child_id = step_id,
                                .include_child_description = include_step_description,
                                .graph_output_step = graph_output_step,
                            }});
                        } else {
                            try graph_output_step.writer.print("\t{}\n", .{Node{
                                .item = step,
                                .id = step_id,
                                .include_description = include_step_description,
                                .graph_output_step = graph_output_step,
                            }});
                        }
                        try step_visited_map.put(graph_output_step.builder.allocator, step, {});
                    }

                    for (step.dependencies.items) |dependency_step| {
                        if (!dependency_step.loop_flag) {
                            try parent_map.put(graph_output_step.builder.allocator, dependency_step, step);
                            try dependency_stack.append(graph_output_step.builder.allocator, dependency_step);
                        }
                    }
                }

                try graph_output_step.writer.print("\t{}\n", .{Subgraph.End{}});

                subgraph_counter += 1;
            }
        }
    };
}
