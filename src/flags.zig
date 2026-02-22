/// Comptime-first CLI parser with typed flags, positional args, and subcommands.
const std = @import("std");

/// error set for parse failures.
const Error = error{
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
};

/// Parse args into a struct (single command) or union(enum) (subcommands).
///
/// Caller passes full argv; the parser skips argv[0] (the program name).
pub fn parse(args: []const []const u8, comptime T: type) !T {
    if (args.len == 0) return Error.InvalidArgument;
    const trimmed = args[1..];
    const info = @typeInfo(T);
    switch (info) {
        .@"struct" => return parse_struct(trimmed, T),
        .@"union" => {
            if (info.@"union".tag_type == null) {
                @compileError("Args must be a union(enum) to use subcommands");
            }
            return parse_commands(trimmed, T);
        },
        else => @compileError("Args must be a struct or union(enum)"),
    }
}

/// Apply default value or null for optional fields, otherwise return the given error.
fn apply_default(comptime field: std.builtin.Type.StructField, result: anytype, comptime error_type: Error) !void {
    if (field.defaultValue()) |default| {
        @field(result, field.name) = default;
    } else if (comptime is_optional(field.type)) {
        @field(result, field.name) = @as(field.type, null);
    } else {
        return error_type;
    }
}

/// Find the index of the '@"--"' field that separates flags from positionals.
fn separator_index(comptime fields: []const std.builtin.Type.StructField) ?usize {
    var idx: ?usize = null;
    inline for (fields, 0..) |field, index| {
        if (std.mem.eql(u8, field.name, "--")) {
            idx = index;
            break;
        }
    }
    return idx;
}

/// Parse a struct schema of named flags and optional positional args.
fn parse_struct(args: []const []const u8, comptime T: type) !T {
    // Ensure the given type is a struct at compile time.
    comptime if (@typeInfo(T) != .@"struct") {
        @compileError("flag definitions must be a struct");
    };

    const fields = std.meta.fields(T);
    const marker_idx = comptime separator_index(fields);
    const named_fields = if (marker_idx) |idx| fields[0..idx] else fields;
    const positional_fields = if (marker_idx) |idx| fields[idx + 1 ..] else &[_]std.builtin.Type.StructField{};

    if (marker_idx) |idx| {
        if (fields[idx].type != void) {
            @compileError("'@" ++ "--" ++ "' marker must be declared as void");
        }
    }

    var result: T = undefined;
    var counts = std.mem.zeroes([named_fields.len]u8);
    var positional_index: usize = 0;
    var positional_only = false;

    var i: usize = 0;
    while (i < args.len) : (i += 1) {
        const arg = args[i];

        if (is_help_arg(arg)) {
            print_help(T);
        }

        if (std.mem.eql(u8, arg, "--")) {
            if (positional_fields.len == 0) {
                return Error.UnexpectedArgument;
            }

            positional_only = true;
            continue;
        }

        if (std.mem.startsWith(u8, arg, "--") and !positional_only) {
            const trimmed = arg[2..];
            var flag_name = trimmed;
            var flag_value: ?[]const u8 = null;

            if (std.mem.indexOfScalar(u8, trimmed, '=')) |pos| {
                flag_name = trimmed[0..pos];
                flag_value = trimmed[pos + 1 ..];
            }

            var found = false;
            inline for (named_fields, 0..) |field, field_index| {
                if (std.mem.eql(u8, flag_name, field.name)) {
                    found = true;
                    if (counts[field_index] > 0) return Error.DuplicateFlag;

                    counts[field_index] += 1;
                    @field(result, field.name) = try parse_value(field.type, flag_value);
                    break;
                }
            }

            if (!found) return Error.UnknownFlag;
            continue;
        }

        // Handle short flags (-v, -p, etc).
        if (std.mem.startsWith(u8, arg, "-") and !positional_only) {
            if (arg.len == 2) {
                const flag_char = arg[1..2];
                var found = false;
                inline for (named_fields, 0..) |field, field_index| {
                    if (field.name.len == 1 and std.mem.eql(u8, flag_char, field.name)) {
                        found = true;
                        if (counts[field_index] > 0) return Error.DuplicateFlag;
                        counts[field_index] += 1;
                        @field(result, field.name) = try parse_value(field.type, null);
                        break;
                    }
                }
                if (!found) return Error.UnknownFlag;
                continue;
            }
        }

        if (std.mem.startsWith(u8, arg, "-")) return Error.UnexpectedArgument;

        if (positional_fields.len == 0) return Error.UnexpectedArgument;

        if (positional_index >= positional_fields.len) return Error.UnexpectedArgument;

        const field = positional_fields[positional_index];
        @field(result, field.name) = try parse_value(field.type, arg);
        positional_index += 1;
        positional_only = true;
    }

    // Apply defaults and validate required flags.
    inline for (named_fields, 0..) |field, field_index| {
        if (counts[field_index] == 0) {
            try apply_default(field, &result, Error.MissingRequiredFlag);
        }
    }

    // Apply defaults for missing positional args.
    if (positional_fields.len > 0) {
        inline for (positional_fields[positional_index..]) |field| {
            try apply_default(field, &result, Error.MissingRequiredPositional);
        }
    }

    return result;
}

/// Unwrap optional types before parsing the inner scalar value.
fn parse_value(comptime T: type, value: ?[]const u8) !T {
    return switch (@typeInfo(T)) {
        .optional => |opt| blk: {
            const parsed = try parse_scalar(opt.child, value);
            break :blk @as(T, parsed);
        },
        else => parse_scalar(T, value),
    };
}

/// Parse a scalar type: bool, int, float, enum, or string.
fn parse_scalar(comptime T: type, value: ?[]const u8) !T {
    if (T == bool) {
        if (value == null) return true;
        return parse_bool(value.?);
    }

    const v = value orelse return Error.MissingValue;

    if (T == []const u8) return v;
    if (T == []u8) @compileError("use []const u8 for flag values");

    switch (@typeInfo(T)) {
        .int => return std.fmt.parseInt(T, v, 10) catch return Error.InvalidValue,
        .float => return std.fmt.parseFloat(T, v) catch return Error.InvalidValue,
        .@"enum" => return std.meta.stringToEnum(T, v) orelse Error.InvalidValue,
        else => @compileError("Unsupported flag type: " ++ @typeName(T)),
    }
}

/// Parse a boolean string value; accepts "true" or "false" only.
fn parse_bool(value: []const u8) Error!bool {
    if (std.mem.eql(u8, value, "true")) return true;
    if (std.mem.eql(u8, value, "false")) return false;
    return Error.InvalidValue;
}

/// Parse a subcommand field as either a struct or nested union(enum).
fn parse_subcommand(comptime field: std.builtin.Type.UnionField, args: []const []const u8) !field.type {
    const subcommand_info = @typeInfo(field.type);
    return switch (subcommand_info) {
        .@"struct" => try parse_struct(args, field.type),
        .@"union" => blk: {
            if (subcommand_info.@"union".tag_type == null) {
                @compileError("subcommand types must be struct or union(enum)");
            }
            break :blk try parse_commands(args, field.type);
        },
        else => @compileError("subcommand types must be struct or union(enum)"),
    };
}

/// Match and parse the first arg as a subcommand name, then parse the rest.
fn parse_commands(args: []const []const u8, comptime T: type) !T {
    const fields = std.meta.fields(T);

    if (args.len == 0) {
        return Error.MissingSubcommand;
    }

    const arg = args[0];
    if (is_help_arg(arg)) {
        print_help(T);
    }

    inline for (fields) |field| {
        if (std.mem.eql(u8, arg, field.name)) {
            const parsed = try parse_subcommand(field, args[1..]);
            return @unionInit(T, field.name, parsed);
        }
    }

    return Error.UnknownSubcommand;
}

/// Check whether a type is an optional.
fn is_optional(comptime T: type) bool {
    return switch (@typeInfo(T)) {
        .optional => true,
        else => false,
    };
}

/// Return true if the argument is a help flag (-h or --help).
fn is_help_arg(arg: []const u8) bool {
    return std.mem.eql(u8, arg, "-h") or std.mem.eql(u8, arg, "--help");
}

/// Print help text and exit. Requires `pub const help` on the type.
/// Help is the user's responsibility — the parser handles parsing, not presentation.
fn print_help(comptime T: type) noreturn {
    if (@hasDecl(T, "help")) {
        std.debug.print("{s}", .{T.help});
    } else {
        std.debug.print("No help available. Declare `pub const help` on your type.\n", .{});
    }
    std.process.exit(0);
}

test "auto help generation" {
    const Args = struct {
        name: []const u8 = "joe",
        port: u16 = 8080,
        active: bool = false,
    };

    try std.testing.expect(@hasDecl(Args, "help") == false);
}

test "invalid flag" {
    const Args = struct {
        name: []const u8 = "joe",
    };

    try std.testing.expectError(Error.UnexpectedArgument, parse(&.{ "prog", "name=jack" }, Args));
}

test "parse defaults" {
    const Args = struct {
        name: []const u8 = "joe",
        active: bool = false,
        port: u16 = 5000,
        rate: f32 = 1.0,
    };

    const flags = try parse(&.{"prog"}, Args);
    try std.testing.expect(std.mem.eql(u8, flags.name, "joe"));
    try std.testing.expect(flags.active == false);
    try std.testing.expect(flags.port == 5000);
    try std.testing.expect(flags.rate == 1.0);
}

test "parse primitives" {
    const Args = struct {
        name: []const u8 = "default",
        port: u16 = 8080,
        rate: f32 = 1.0,
        active: bool = false,
    };

    const flags = try parse(&.{ "prog", "--name=test", "--port=9090", "--rate=2.5", "--active" }, Args);
    try std.testing.expect(std.mem.eql(u8, flags.name, "test"));
    try std.testing.expect(flags.port == 9090);
    try std.testing.expect(flags.rate == 2.5);
    try std.testing.expect(flags.active == true);
}

test "parse enum" {
    const Format = enum { json, yaml, toml };
    const Args = struct {
        format: Format = .json,
    };

    const flags = try parse(&.{ "prog", "--format=yaml" }, Args);
    try std.testing.expect(flags.format == .yaml);
}

test "parse enum with default" {
    const Format = enum { json, yaml, toml };
    const Args = struct {
        format: Format = .json,
    };

    const flags = try parse(&.{"prog"}, Args);
    try std.testing.expect(flags.format == .json);
}

test "parse optional string" {
    const Args = struct {
        config: ?[]const u8 = null,
    };

    const flags1 = try parse(&.{"prog"}, Args);
    try std.testing.expect(flags1.config == null);

    const flags2 = try parse(&.{ "prog", "--config=/path/to/config" }, Args);
    try std.testing.expect(flags2.config != null);
    try std.testing.expect(std.mem.eql(u8, flags2.config.?, "/path/to/config"));
}

test "parse optional int" {
    const Args = struct {
        count: ?u32 = null,
    };

    const flags1 = try parse(&.{"prog"}, Args);
    try std.testing.expect(flags1.count == null);

    const flags2 = try parse(&.{ "prog", "--count=42" }, Args);
    try std.testing.expect(flags2.count != null);
    try std.testing.expect(flags2.count.? == 42);
}

test "parse optional bool" {
    const Args = struct {
        verbose: ?bool = null,
    };

    const flags1 = try parse(&.{"prog"}, Args);
    try std.testing.expect(flags1.verbose == null);

    const flags2 = try parse(&.{ "prog", "--verbose" }, Args);
    try std.testing.expect(flags2.verbose != null);
    try std.testing.expect(flags2.verbose.? == true);
}

test "parse boolean formats" {
    const Args = struct {
        flag: bool = false,
    };

    const flags1 = try parse(&.{ "prog", "--flag" }, Args);
    try std.testing.expect(flags1.flag == true);

    const flags2 = try parse(&.{ "prog", "--flag=true" }, Args);
    try std.testing.expect(flags2.flag == true);

    const flags3 = try parse(&.{ "prog", "--flag=false" }, Args);
    try std.testing.expect(flags3.flag == false);
}

test "parse subcommand" {
    const CLI = union(enum) {
        start: struct {
            host: []const u8 = "localhost",
            port: u16 = 8080,
        },
        stop: struct {
            force: bool = false,
        },
    };

    const result1 = try parse(&.{ "prog", "start", "--host=0.0.0.0", "--port=3000" }, CLI);
    try std.testing.expect(std.mem.eql(u8, result1.start.host, "0.0.0.0"));
    try std.testing.expect(result1.start.port == 3000);

    const result2 = try parse(&.{ "prog", "stop", "--force" }, CLI);
    try std.testing.expect(result2.stop.force == true);
}

test "parse subcommand with defaults" {
    const CLI = union(enum) {
        start: struct {
            host: []const u8 = "localhost",
            port: u16 = 8080,
        },
        stop: struct {},
    };

    const result = try parse(&.{ "prog", "start" }, CLI);
    try std.testing.expect(std.mem.eql(u8, result.start.host, "localhost"));
    try std.testing.expect(result.start.port == 8080);
}

test "missing subcommand" {
    const CLI = union(enum) {
        start: struct {
            host: []const u8 = "localhost",
        },
        stop: struct {
            force: bool = false,
        },
    };

    try std.testing.expectError(Error.MissingSubcommand, parse(&.{"prog"}, CLI));
}

test "unknown subcommand" {
    const CLI = union(enum) {
        start: struct {
            host: []const u8 = "localhost",
        },
        stop: struct {
            force: bool = false,
        },
    };

    try std.testing.expectError(Error.UnknownSubcommand, parse(&.{ "prog", "restart" }, CLI));
}

test "duplicate flag" {
    const Args = struct {
        port: u16 = 8080,
    };

    try std.testing.expectError(Error.DuplicateFlag, parse(&.{ "prog", "--port=8080", "--port=9090" }, Args));
}

test "missing value" {
    const Args = struct {
        name: []const u8,
    };

    try std.testing.expectError(Error.MissingValue, parse(&.{ "prog", "--name" }, Args));
}

test "invalid enum value" {
    const Format = enum { json, yaml, toml };
    const Args = struct {
        format: Format = .json,
    };

    try std.testing.expectError(Error.InvalidValue, parse(&.{ "prog", "--format=xml" }, Args));
}

test "invalid int value" {
    const Args = struct {
        port: u16 = 8080,
    };

    try std.testing.expectError(Error.InvalidValue, parse(&.{ "prog", "--port=not-a-number" }, Args));
}

test "no args provided" {
    const Args = struct {
        port: u16 = 8080,
    };

    try std.testing.expectError(Error.InvalidArgument, parse(&.{}, Args));
}

test "missing required flag" {
    const Args = struct {
        name: []const u8,
    };

    try std.testing.expectError(Error.MissingRequiredFlag, parse(&.{"prog"}, Args));
}

test "help declaration exists" {
    const Args = struct {
        verbose: bool = false,
        pub const help = "Test help message";
    };

    try std.testing.expect(@hasDecl(Args, "help"));
    try std.testing.expect(std.mem.eql(u8, Args.help, "Test help message"));
}

test "complex subcommand structure" {
    const CLI = union(enum) {
        server: union(enum) {
            start: struct {
                host: []const u8 = "0.0.0.0",
                port: u16 = 8080,
            },
            stop: struct {
                force: bool = false,
            },
            pub const help = "Server commands";
        },
        client: struct {
            url: []const u8,
            timeout: u32 = 30,
        },
    };

    const result = try parse(&.{ "prog", "server", "start", "--port=9090" }, CLI);
    switch (result) {
        .server => |s| switch (s) {
            .start => |start| {
                try std.testing.expect(std.mem.eql(u8, start.host, "0.0.0.0"));
                try std.testing.expect(start.port == 9090);
            },
            else => unreachable,
        },
        else => unreachable,
    }
}

test "short flags" {
    const Args = struct {
        v: bool = false,
        q: bool = false,
    };

    const flags1 = try parse(&.{ "prog", "-v" }, Args);
    try std.testing.expect(flags1.v == true);
    try std.testing.expect(flags1.q == false);

    const flags2 = try parse(&.{ "prog", "-v", "-q" }, Args);
    try std.testing.expect(flags2.v == true);
    try std.testing.expect(flags2.q == true);
}

test "unexpected argument error" {
    const Args = struct {
        port: u16 = 8080,
    };

    try std.testing.expectError(Error.UnexpectedArgument, parse(&.{ "prog", "--port=8080", "extra" }, Args));
}
