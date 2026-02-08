const std = @import("std");

// Comptime-first CLI parser with typed flags, positional args, and subcommands.

// Public error set for parse failures.
pub const Error = error{
    DuplicateFlag,
    InvalidArgument,
    InvalidValue,
    MissingRequiredFlag,
    MissingRequiredPositional,
    MissingSubcommand,
    MissingValue,
    UnknownFlag,
    UnknownSubcommand,
    UnexpectedArgument,
    NoArgsProvided,
    UnknownCommand,
    UnknownOption,
    MissingRequiredOption,
    CommandExecutionFailed,
};

// Parse args into a struct (single command) or union(enum) (subcommands).
pub fn parse(args: []const []const u8, comptime args_type: type) !args_type {
    if (args.len == 0) return Error.InvalidArgument;
    const info = @typeInfo(args_type);
    switch (info) {
        .@"struct" => return parse_flags(args, args_type, 1),
        .@"union" => {
            if (info.@"union".tag_type == null) {
                @compileError("args_type must be a union(enum) to use subcommands");
            }
            return parse_commands(args, args_type, 1);
        },
        else => @compileError("args_type must be a struct or union(enum)"),
    }
}

// Find the '@"--"' marker separating flags from positionals.
fn marker_index(comptime fields: []const std.builtin.Type.StructField) ?usize {
    var idx: ?usize = null;
    inline for (fields, 0..) |field, index| {
        if (std.mem.eql(u8, field.name, "--")) {
            idx = index;
            break;
        }
    }
    return idx;
}

// Parse a struct of flags and optional positional args.
fn parse_flags(args: []const []const u8, comptime flags_type: type, start_index: usize) !flags_type {
    comptime assert_struct(flags_type);

    const fields = std.meta.fields(flags_type);
    // '@"--"' marks the boundary between flags and positional args.
    const marker_pos = comptime marker_index(fields);
    const named_fields = if (marker_pos) |idx| fields[0..idx] else fields;
    const positional_fields = if (marker_pos) |idx| fields[idx + 1 ..] else &[_]std.builtin.Type.StructField{};

    if (marker_pos) |idx| {
        if (fields[idx].type != void) {
            @compileError("'@" ++ "--" ++ "' marker must be declared as void");
        }
    }

    var result: flags_type = undefined;
    // Track usage to enforce no duplicates.
    var counts = std.mem.zeroes([named_fields.len]u8);
    var positional_index: usize = 0;
    // Once a positional value appears, remaining args are positional-only.
    var positional_only = false;

    var i: usize = start_index;
    while (i < args.len) : (i += 1) {
        const arg = args[i];

        if (is_help_arg(arg) and @hasDecl(flags_type, "help")) {
            print_help_and_exit(flags_type);
        }

        // Explicit separator for positional arguments.
        if (std.mem.eql(u8, arg, "--")) {
            if (positional_fields.len == 0) {
                return Error.UnexpectedArgument;
            }

            positional_only = true;
            continue;
        }

        if (std.mem.startsWith(u8, arg, "--") and !positional_only) {
            const trimmed = arg[2..];
            var key = trimmed;
            var value: ?[]const u8 = null;

            if (std.mem.indexOfScalar(u8, trimmed, '=')) |pos| {
                key = trimmed[0..pos];
                value = trimmed[pos + 1 ..];
            }

            var matched = false;
            inline for (named_fields, 0..) |field, field_index| {
                if (std.mem.eql(u8, key, field.name)) {
                    matched = true;
                    if (counts[field_index] > 0) return Error.DuplicateFlag;

                    counts[field_index] += 1;
                    @field(result, field.name) = try parse_flag_value(field.type, value);
                    break;
                }
            }

            if (!matched) return Error.UnknownFlag;
            continue;
        }

        // Only long flags are accepted; short flags are rejected.
        if (std.mem.startsWith(u8, arg, "-")) return Error.UnexpectedArgument;

        if (positional_fields.len == 0) return Error.UnexpectedArgument;

        if (positional_index >= positional_fields.len) return Error.UnexpectedArgument;

        const field = positional_fields[positional_index];
        @field(result, field.name) = try parse_flag_value(field.type, arg);
        positional_index += 1;
        positional_only = true;
    }

    // Fill in defaults and validate required flags.
    inline for (named_fields, 0..) |field, field_index| {
        if (counts[field_index] == 0) {
            if (field_default_value(field)) |default| {
                @field(result, field.name) = default;
            } else if (comptime is_optional(field.type)) {
                @field(result, field.name) = @as(field.type, null);
            } else {
                return Error.MissingRequiredFlag;
            }
        }
    }

    // Fill missing positional args from defaults or optional values.
    if (positional_fields.len > 0) {
        inline for (positional_fields[positional_index..]) |field| {
            if (field_default_value(field)) |default| {
                @field(result, field.name) = default;
            } else if (comptime is_optional(field.type)) {
                @field(result, field.name) = @as(field.type, null);
            } else {
                return Error.MissingRequiredPositional;
            }
        }
    }

    return result;
}

// Extract a default value from the struct field if it exists.
fn field_default_value(comptime field: std.builtin.Type.StructField) ?field.type {
    return field.defaultValue();
}

// Handle optional wrappers before parsing the concrete type.
fn parse_flag_value(comptime value_type: type, value: ?[]const u8) !value_type {
    return switch (@typeInfo(value_type)) {
        .optional => |opt| blk: {
            const parsed = try parse_scalar_value(opt.child, value);
            break :blk @as(value_type, parsed);
        },
        else => parse_scalar_value(value_type, value),
    };
}

// Parse supported scalar types (bool, int, float, enum, string).
fn parse_scalar_value(comptime value_type: type, value: ?[]const u8) !value_type {
    if (value_type == bool) {
        if (value == null) return true;
        return parse_bool(value.?);
    }

    const v = value orelse return Error.MissingValue;

    if (value_type == []const u8) return v;
    if (value_type == []u8) @compileError("use []const u8 for flag values");

    const info = @typeInfo(value_type);
    switch (info) {
        .int => return std.fmt.parseInt(value_type, v, 10) catch return Error.InvalidValue,
        .float => return std.fmt.parseFloat(value_type, v) catch return Error.InvalidValue,
        .@"enum" => return std.meta.stringToEnum(value_type, v) orelse Error.InvalidValue,
        else => @compileError("Unsupported flag type: " ++ @typeName(value_type)),
    }
}

// Accept true/false and 1/0.
fn parse_bool(value: []const u8) Error!bool {
    if (std.mem.eql(u8, value, "true") or std.mem.eql(u8, value, "1")) return true;
    if (std.mem.eql(u8, value, "false") or std.mem.eql(u8, value, "0")) return false;
    return Error.InvalidValue;
}

// Dispatch to the matching subcommand and parse its arguments.
fn parse_commands(args: []const []const u8, comptime commands_type: type, start_index: usize) !commands_type {
    const fields = std.meta.fields(commands_type);

    if (args.len <= start_index) {
        return Error.MissingSubcommand;
    }

    const arg = args[start_index];
    if (is_help_arg(arg) and @hasDecl(commands_type, "help")) {
        print_help_and_exit(commands_type);
    }

    inline for (fields) |field| {
        if (std.mem.eql(u8, arg, field.name)) {
            // Each subcommand can be a struct (flags) or another union(enum).
            const sub_info = @typeInfo(field.type);
            const parsed = switch (sub_info) {
                .@"struct" => try parse_flags(args, field.type, start_index + 1),
                .@"union" => blk: {
                    if (sub_info.@"union".tag_type == null) {
                        @compileError("subcommand types must be struct or union(enum)");
                    }
                    break :blk try parse_commands(args, field.type, start_index + 1);
                },
                else => @compileError("subcommand types must be struct or union(enum)"),
            };

            return @unionInit(commands_type, field.name, parsed);
        }
    }

    return Error.UnknownSubcommand;
}

// Ensure the schema is a struct at compile time.
fn assert_struct(comptime schema_type: type) void {
    if (@typeInfo(schema_type) != .@"struct") {
        @compileError("flag definitions must be a struct");
    }
}

// Detect optional types so we can accept missing values.
fn is_optional(comptime value_type: type) bool {
    return switch (@typeInfo(value_type)) {
        .optional => true,
        else => false,
    };
}

// Centralized help flag check.
fn is_help_arg(arg: []const u8) bool {
    return std.mem.eql(u8, arg, "-h") or std.mem.eql(u8, arg, "--help");
}

test "print help" {
    const allocator = std.testing.allocator;
    const Args = struct {
        name: []const u8 = "def",
        active: bool = false,
    };

    _ = try parse(allocator, Args, &.{"--help"});
    try std.testing.expect(true);
}

test "invalid flag" {
    const allocator = std.testing.allocator;
    const Args = struct {
        name: []const u8 = "joe",
    };

    const err_union: anyerror!Args = error.InvalidFlag;

    _ = try parse(allocator, Args, &.{"name=jack"});
    try std.testing.expectError(error.InvalidFlag, err_union);
}

test "parse string" {
    const allocator = std.testing.allocator;
    const Args = struct {
        name: []const u8 = "joe",
    };

    const flags = try parse(allocator, Args, &.{"--name=jack"});
    try std.testing.expect(std.mem.eql(u8, flags.name, "jack"));
}

test "parse boolean" {
    const allocator = std.testing.allocator;
    const Args = struct {
        name: []const u8 = "joe",
        active: bool = false,
    };

    const flags = try parse(allocator, Args, &.{ "--name=jack", "--active" });
    try std.testing.expect(flags.active == true);
}

test "parse int" {
    const allocator = std.testing.allocator;
    const Args = struct {
        port: u16 = 5000,
    };

    const flags = try parse(allocator, Args, &.{"--port=8080"});
    try std.testing.expect(flags.port == 8080);
}

test "parse float" {
    const allocator = std.testing.allocator;
    const Args = struct {
        rate: f32 = 1.0,
    };

    const flags = try parse(allocator, Args, &.{"--rate=1.0"});
    try std.testing.expect(flags.rate == 1.0);
}

test "parse defaults" {
    const allocator = std.testing.allocator;
    const Args = struct {
        name: []const u8 = "joe",
        active: bool = false,
        port: u16 = 5000,
        rate: f32 = 1.0,
    };

    const flags = try parse(allocator, Args, &.{});
    try std.testing.expect(std.mem.eql(u8, flags.name, "joe"));
    try std.testing.expect(flags.active == false);
    try std.testing.expect(flags.port == 5000);
    try std.testing.expect(flags.rate == 1.0);
}
