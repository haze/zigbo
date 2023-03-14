const std = @import("std");

pub const GraphOutputWriteFnInstruction = enum {
    /// Simply print out "Opaque Custom Step (step_name)"
    use_default_implementation,
};

pub fn graphOutputStep(builder: *std.Build, writer: anytype) *GraphOutputStep(@TypeOf(writer)) {
    return GraphOutputStep(@TypeOf(writer)).init(builder, writer);
}

/// Outputs a mermaid diagram describing the build graph
pub fn GraphOutputStep(comptime WriterType: type) type {
    return struct {
        const Self = @This();
        writer: Writer,
        builder: *std.Build,
        step: std.Build.Step,
        custom_step_callback: *const GraphOutputWriteFn = defaultCustomStepCallback,

        pub const Writer = WriterType;

        pub fn defaultCustomStepCallback(step: *std.Build.Step, writer: Writer) Writer.Error!?GraphOutputWriteFnInstruction {
            _ = writer;
            _ = step;
            return .use_default_implementation;
        }

        pub fn init(builder: *std.Build, writer: Writer) *Self {
            var graph_output_step = builder.allocator.create(Self) catch unreachable;
            graph_output_step.* = Self{
                .writer = writer,
                .builder = builder,
                .step = std.Build.Step.init(.custom, "zigbo graph", builder.allocator, Self.make),
            };
            return graph_output_step;
        }

        pub fn setCustomStepCallback(self: *Self, comptime callback: anytype) void {
            switch (@typeInfo(@TypeOf(callback))) {
                .Fn => {},
                else => @compileError("Expected function, got " ++ @typeName(@TypeOf(callback))),
            }

            const gen = struct {
                fn callbackWrapper(step: *std.Build.Step, writer: Writer) Writer.Error!?GraphOutputWriteFnInstruction {
                    return @call(.always_inline, callback, .{ step, writer });
                }
            };

            self.custom_step_callback = gen.callbackWrapper;
        }

        pub const AnnotatedBuiltinStep = struct {
            step: *std.Build.Step,
            graph_output_step: *Self,

            pub fn format(
                annotated_builtin_step: AnnotatedBuiltinStep,
                comptime fmt: []const u8,
                options: std.fmt.FormatOptions,
                writer: Writer,
            ) !void {
                _ = fmt;
                _ = options;

                return switch (annotated_builtin_step.step.id) {
                    .top_level => step_inspection_functions.annotateTopLevelStep(annotated_builtin_step.step, writer),
                    .install_artifact => step_inspection_functions.annotateInstallArtifactStep(annotated_builtin_step.step, writer),
                    .compile => step_inspection_functions.annotateCompileStep(annotated_builtin_step.step, writer, .{
                        .print_newlines = true,
                        .print_in_between_quotes = true,
                    }),
                    .run => step_inspection_functions.annotateRunStep(annotated_builtin_step.step, writer),
                    .custom => blk: {
                        const customFormatFn = annotated_builtin_step.graph_output_step.custom_step_callback;
                        const maybe_instruction = try customFormatFn(annotated_builtin_step.step, writer);
                        const instruction = maybe_instruction orelse break :blk;
                        switch (instruction) {
                            .use_default_implementation => try writer.print("\"{s} (Custom)\"", .{annotated_builtin_step.step.name}),
                        }
                    },

                    // TODO(haze): better messages for these
                    .options => try writer.writeAll("Options step"),
                    .objcopy => try writer.writeAll("ObjCopy step"),
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

        pub const Header = struct {
            direction: Direction,

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
                    writer: Writer,
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

            pub fn format(
                header: Header,
                comptime fmt: []const u8,
                options: std.fmt.FormatOptions,
                writer: Writer,
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
                    writer: Writer,
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
                    writer: Writer,
                ) !void {
                    _ = end;
                    _ = options;
                    _ = fmt;
                    try writer.writeAll("end");
                }
            };
        };

        pub const Edge = struct {
            parent: *std.Build.Step,
            parent_id: usize,
            include_parent_description: bool,

            child: *std.Build.Step,
            child_id: usize,
            include_child_description: bool,

            graph_output_step: *Self,

            pub fn format(
                edge: Edge,
                comptime fmt: []const u8,
                options: std.fmt.FormatOptions,
                writer: Writer,
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
            item: *std.Build.Step,
            id: usize,
            include_description: bool,
            graph_output_step: *Self,

            pub fn format(
                node: Node,
                comptime fmt: []const u8,
                options: std.fmt.FormatOptions,
                writer: Writer,
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

        pub const GraphOutputWriteFn = fn (step: *std.Build.Step, writer: Writer) Writer.Error!?GraphOutputWriteFnInstruction;

        fn make(type_erased_graph_output_step: *std.Build.Step) anyerror!void {
            const graph_output_step = @fieldParentPtr(Self, "step", type_erased_graph_output_step);
            try graph_output_step.writer.print("{}\n", .{Header{ .direction = .top_down }});
            var subgraph_counter: usize = 0;

            var step_id_map = std.AutoHashMapUnmanaged(*std.Build.Step, usize){};
            var running_step_id: usize = 0;
            defer step_id_map.deinit(graph_output_step.builder.allocator);

            var step_visited_map = std.AutoHashMapUnmanaged(*std.Build.Step, void){};
            defer step_visited_map.deinit(graph_output_step.builder.allocator);

            for (graph_output_step.builder.top_level_steps.items) |top_level_step| {
                try graph_output_step.writer.print("\t{}\n", .{Subgraph.Start{
                    .name = top_level_step.description,
                    .id = subgraph_counter,
                }});

                var dependency_stack = std.ArrayListUnmanaged(*std.Build.Step){};
                defer dependency_stack.deinit(graph_output_step.builder.allocator);

                var parent_map = std.AutoHashMapUnmanaged(*std.Build.Step, *std.Build.Step){};
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

const step_inspection_functions = struct {
    pub fn annotateTopLevelStep(step: *std.Build.Step, writer: anytype) !void {
        // TODO: This is a hack around the fact that `std.build.Builder.TopLevelStep` is a private decl.
        // Look into whether it could be made public upstream.
        const TopLevelStep = std.meta.FieldType(std.build.Builder, .install_tls);
        std.debug.assert(step.cast(TopLevelStep) != null);
        try writer.print("\"{s} (Top Level)\"", .{step.name});
    }

    pub fn annotateCompileStep(step: *std.Build.Step, writer: anytype, options: struct {
        print_newlines: bool,
        print_in_between_quotes: bool,
    }) !void {
        const compile_step = @fieldParentPtr(std.Build.CompileStep, "step", step);
        if (options.print_in_between_quotes) {
            try writer.writeByte('"');
        }

        try writer.print("{s} (Compile)", .{compile_step.name});

        if (options.print_newlines) {
            try writer.writeAll("\\n");
        } else {
            try writer.writeAll(", ");
        }

        try writer.print("kind: {s}", .{@tagName(compile_step.kind)});

        if (options.print_newlines) {
            try writer.writeAll("\\n");
        } else {
            try writer.writeAll(", ");
        }
        try writer.print("mode: {s}", .{@tagName(compile_step.optimize)});

        if (compile_step.linkage) |linkage| {
            if (options.print_newlines) {
                try writer.writeAll("\\n");
            } else {
                try writer.writeAll(", ");
            }
            try writer.print("linkage: {s}", .{@tagName(linkage)});
        }

        if (compile_step.root_src) |root_src| {
            if (options.print_newlines) {
                try writer.writeAll("\\n");
            } else {
                try writer.writeAll(", ");
            }
            try writer.print("root_src: '{}'", .{formatting.fmtFileSource(compile_step.builder, root_src)});
        }

        if (compile_step.version) |version| {
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

    // TODO(haze): annotate envmap
    pub fn annotateRunStep(step: *std.Build.Step, writer: anytype) !void {
        const run_step = @fieldParentPtr(std.Build.RunStep, "step", step);

        try writer.writeAll("\"Run\\nargv: [");
        for (run_step.argv.items, 0..) |arg, index| {
            try writer.print("{}", .{formatting.RunStepArg{ .arg = arg, .builder = run_step.builder }});
            if (index != run_step.argv.items.len - 1) {
                try writer.writeAll(", ");
            }
        }
        try writer.writeAll("]");

        if (run_step.cwd) |cwd| {
            try writer.print("\\ncwd: '{s}'", .{cwd});
        }

        if (run_step.expected_term) |exit_code| {
            try writer.print("\\nexpecting exit code: {}", .{exit_code});
        }

        try writer.writeAll("\"");
    }

    pub fn annotateInstallArtifactStep(step: *std.Build.Step, writer: anytype) !void {
        const install_artifact_step = @fieldParentPtr(std.Build.InstallArtifactStep, "step", step);
        const builder = install_artifact_step.builder;

        try writer.print(
            "\"{s} (Install Artifact)\\ndestination: '{}'\"",
            .{ install_artifact_step.step.name, formatting.fmtInstallDir(builder, install_artifact_step.dest_dir) },
        );

        if (install_artifact_step.pdb_dir) |pdb_directory| {
            try writer.print("\\nPDB directory: '{}'", .{formatting.fmtInstallDir(builder, pdb_directory)});
        }

        if (install_artifact_step.pdb_dir) |header_directory| {
            try writer.print("\\nHeader directory: '{}'", .{formatting.fmtInstallDir(builder, header_directory)});
        }
    }
};

const formatting = struct {
    pub const Artifact = struct {
        compile_step: *std.Build.CompileStep,

        pub fn format(
            artifact: Artifact,
            comptime fmt: []const u8,
            options: std.fmt.FormatOptions,
            writer: anytype,
        ) !void {
            _ = fmt;
            _ = options;
            try step_inspection_functions.annotateCompileStep(&artifact.compile_step.step, writer, .{
                .print_newlines = false,
                .print_in_between_quotes = false,
            });
        }
    };

    pub const FormattedFileSource = struct {
        builder: *std.Build,
        file_source: std.Build.FileSource,

        pub fn format(
            formatter: FormattedFileSource,
            comptime fmt: []const u8,
            options: std.fmt.FormatOptions,
            writer: anytype,
        ) !void {
            _ = fmt;
            _ = options;
            const path = formatter.file_source.getPath(formatter.builder);
            const relative_path = formatter.builder.build_root.join(formatter.builder.allocator, &.{path}) catch unreachable;
            defer formatter.builder.allocator.free(relative_path); // there's a chance this could get freed, with it (presumably) being the latest allocation.
            try writer.writeAll(relative_path);
        }
    };
    pub fn fmtFileSource(builder: *std.Build, file_source: std.Build.FileSource) FormattedFileSource {
        return .{
            .builder = builder,
            .file_source = file_source,
        };
    }

    pub const FormattedInstallDir = struct {
        builder: *std.Build,
        install_dir: std.Build.InstallDir,

        pub fn format(
            formatter: FormattedInstallDir,
            comptime fmt: []const u8,
            options: std.fmt.FormatOptions,
            writer: anytype,
        ) !void {
            _ = fmt;
            _ = options;

            const builder = formatter.builder;
            const install_path = builder.getInstallPath(formatter.install_dir, ".");

            const dst_rel_path = builder.build_root.join(builder.allocator, &.{install_path}) catch unreachable;
            defer builder.allocator.free(dst_rel_path); // there's a chance this could get freed, with it (presumably) being the latest allocation.

            try writer.writeAll(dst_rel_path);
        }
    };
    pub fn fmtInstallDir(builder: *std.Build, install_dir: std.Build.InstallDir) FormattedInstallDir {
        return .{
            .builder = builder,
            .install_dir = install_dir,
        };
    }

    pub const RunStepArg = struct {
        arg: std.Build.RunStep.Arg,
        builder: *std.Build,

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
                .artifact => |artifact| try writer.print("{}", .{formatting.Artifact{ .compile_step = artifact }}),
                .output => |out| try writer.print("{s}", .{out.basename}),
            }
        }
    };
};
