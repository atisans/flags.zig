/// Comptime-first CLI parser with typed flags, positional args, subcommands, and slices.
const std = @import("std");

/// Public error set for parse failures.
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
};

/// Parse args into a struct (single command) or union(enum) (subcommands).
///
/// Caller passes full argv; the parser skips argv[0] (the program name).
/// Allocator is used for slice field allocation; caller owns returned memory.
pub fn parse(allocator: std.mem.Allocator, args: []const []const u8, comptime T: type) !T {
    if (args.len == 0) return Error.InvalidArgument;
    const trimmed = args[1..];
    const info = @typeInfo(T);
    switch (info) {
        .@"struct" => return parse_struct(allocator, trimmed, T),
        .@"union" => {
            if (info.@"union".tag_type == null) {
                @compileError("Args must be a union(enum) to use subcommands");
            }
            return parse_commands(allocator, trimmed, T);
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
fn parse_struct(allocator: std.mem.Allocator, args: []const []const u8, comptime T: type) !T {
    comptime assert_struct(T);

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

    // Initialize accumulators for slice fields.
    var slice_lists: [named_fields.len]std.ArrayList([]const u8) = undefined;
    inline for (named_fields, 0..) |field, fi| {
        if (comptime is_slice_type(field.type)) {
            slice_lists[fi] = .{};
        }
    }
    defer {
        inline for (named_fields, 0..) |field, fi| {
            if (comptime is_slice_type(field.type)) {
                slice_lists[fi].deinit(allocator);
            }
        }
    }

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

                    if (comptime is_slice_type(field.type)) {
                        const fv = flag_value orelse return Error.MissingValue;
                        // --files=a.txt,b.txt or --files=a.txt
                        var iter = std.mem.splitScalar(u8, fv, ',');
                        while (iter.next()) |part| {
                            try slice_lists[field_index].append(allocator, part);
                        }
                        counts[field_index] += 1;
                    } else {
                        if (counts[field_index] > 0) return Error.DuplicateFlag;
                        counts[field_index] += 1;
                        @field(result, field.name) = try parse_value(field.type, flag_value);
                    }
                    break;
                }
            }

            if (!found) return Error.UnknownFlag;
            continue;
        }

        if (std.mem.startsWith(u8, arg, "-")) return Error.UnexpectedArgument;

        if (positional_fields.len == 0) return Error.UnexpectedArgument;

        if (positional_index >= positional_fields.len) return Error.UnexpectedArgument;

        const field = positional_fields[positional_index];
        @field(result, field.name) = try parse_value(field.type, arg);
        positional_index += 1;
        positional_only = true;
    }

    // Build slices and apply defaults.
    inline for (named_fields, 0..) |field, field_index| {
        if (comptime is_slice_type(field.type)) {
            if (counts[field_index] > 0) {
                const items = slice_lists[field_index].items;
                const child = comptime slice_child(field.type);
                const typed = try allocator.alloc(child, items.len);
                errdefer allocator.free(typed);
                for (items, 0..) |raw, j| {
                    typed[j] = try parse_scalar(child, raw);
                }
                @field(result, field.name) = typed;
            } else {
                try apply_default(field, &result, Error.MissingRequiredFlag);
            }
        } else {
            if (counts[field_index] == 0) {
                try apply_default(field, &result, Error.MissingRequiredFlag);
            }
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
fn parse_subcommand(allocator: std.mem.Allocator, comptime field: std.builtin.Type.UnionField, args: []const []const u8) !field.type {
    const subcommand_info = @typeInfo(field.type);
    return switch (subcommand_info) {
        .@"struct" => try parse_struct(allocator, args, field.type),
        .@"union" => blk: {
            if (subcommand_info.@"union".tag_type == null) {
                @compileError("subcommand types must be struct or union(enum)");
            }
            break :blk try parse_commands(allocator, args, field.type);
        },
        else => @compileError("subcommand types must be struct or union(enum)"),
    };
}

/// Match and parse the first arg as a subcommand name, then parse the rest.
fn parse_commands(allocator: std.mem.Allocator, args: []const []const u8, comptime T: type) !T {
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
            const parsed = try parse_subcommand(allocator, field, args[1..]);
            return @unionInit(T, field.name, parsed);
        }
    }

    return Error.UnknownSubcommand;
}

/// Ensure the given type is a struct at compile time.
fn assert_struct(comptime T: type) void {
    if (@typeInfo(T) != .@"struct") {
        @compileError("flag definitions must be a struct");
    }
}

/// Check whether a type is an optional.
fn is_optional(comptime T: type) bool {
    return switch (@typeInfo(T)) {
        .optional => true,
        else => false,
    };
}

/// Return true if the type is a slice type (not []const u8 which is a string).
fn is_slice_type(comptime T: type) bool {
    return switch (@typeInfo(T)) {
        .pointer => |ptr| ptr.size == .slice and ptr.child != u8,
        else => false,
    };
}

/// Extract the element type of a slice.
fn slice_child(comptime T: type) type {
    return @typeInfo(T).pointer.child;
}

/// Return true if the argument is a help flag (-h or --help).
fn is_help_arg(arg: []const u8) bool {
    return std.mem.eql(u8, arg, "-h") or std.mem.eql(u8, arg, "--help");
}

/// Print help text and exit. Uses a user-declared help string if available,
/// otherwise generates help from the type schema.
fn print_help(comptime T: type) noreturn {
    if (@hasDecl(T, "help")) {
        std.debug.print("{s}", .{T.help});
    } else {
        print_generated_help(T);
    }
    std.process.exit(0);
}

/// Generate and print help text from the struct/union type schema.
fn print_generated_help(comptime T: type) void {
    const info = @typeInfo(T);
    switch (info) {
        .@"struct" => {
            const fields = std.meta.fields(T);
            std.debug.print("Options:\n", .{});
            inline for (fields) |field| {
                comptime if (std.mem.eql(u8, field.name, "--")) continue;

                if (comptime is_slice_type(field.type)) {
                    const child_name = @typeName(slice_child(field.type));
                    std.debug.print("  --{s:<20} []{s} (multiple values)\n", .{
                        field.name,
                        child_name,
                    });
                } else {
                    const type_name = @typeName(field.type);
                    if (field.defaultValue()) |default| {
                        if (field.type == bool) {
                            const val = @as(*const bool, @ptrCast(&default)).*;
                            std.debug.print("  --{s:<20} {s} (default: {s})\n", .{
                                field.name,
                                type_name,
                                if (val) "true" else "false",
                            });
                        } else if (field.type == []const u8) {
                            const val = @as(*const []const u8, @ptrCast(&default)).*;
                            std.debug.print("  --{s:<20} {s} (default: {s})\n", .{
                                field.name,
                                type_name,
                                val,
                            });
                        } else {
                            std.debug.print("  --{s:<20} {s}\n", .{ field.name, type_name });
                        }
                    } else if (comptime is_optional(field.type)) {
                        std.debug.print("  --{s:<20} {s} (optional)\n", .{
                            field.name,
                            type_name,
                        });
                    } else {
                        std.debug.print("  --{s:<20} {s} (required)\n", .{
                            field.name,
                            type_name,
                        });
                    }
                }
            }
        },
        .@"union" => {
            const fields = std.meta.fields(T);
            std.debug.print("Commands:\n", .{});
            inline for (fields) |field| {
                std.debug.print("  {s}\n", .{field.name});
            }
        },
        else => {},
    }
}

// =============================================================================
// Tests
// =============================================================================

const testing = std.testing;
const talloc = testing.allocator;

test "auto help generation" {
    const Args = struct {
        name: []const u8 = "joe",
        port: u16 = 8080,
        active: bool = false,
    };

    try testing.expect(@hasDecl(Args, "help") == false);
}

test "invalid flag" {
    const Args = struct {
        name: []const u8 = "joe",
    };

    try testing.expectError(Error.UnexpectedArgument, parse(talloc, &.{ "prog", "name=jack" }, Args));
}

test "parse defaults" {
    const Args = struct {
        name: []const u8 = "joe",
        active: bool = false,
        port: u16 = 5000,
        rate: f32 = 1.0,
    };

    const flags = try parse(talloc, &.{"prog"}, Args);
    try testing.expect(std.mem.eql(u8, flags.name, "joe"));
    try testing.expect(flags.active == false);
    try testing.expect(flags.port == 5000);
    try testing.expect(flags.rate == 1.0);
}

test "parse primitives" {
    const Args = struct {
        name: []const u8 = "default",
        port: u16 = 8080,
        rate: f32 = 1.0,
        active: bool = false,
    };

    const flags = try parse(talloc, &.{ "prog", "--name=test", "--port=9090", "--rate=2.5", "--active" }, Args);
    try testing.expect(std.mem.eql(u8, flags.name, "test"));
    try testing.expect(flags.port == 9090);
    try testing.expect(flags.rate == 2.5);
    try testing.expect(flags.active == true);
}

test "parse enum" {
    const Format = enum { json, yaml, toml };
    const Args = struct {
        format: Format = .json,
    };

    const flags = try parse(talloc, &.{ "prog", "--format=yaml" }, Args);
    try testing.expect(flags.format == .yaml);
}

test "parse enum with default" {
    const Format = enum { json, yaml, toml };
    const Args = struct {
        format: Format = .json,
    };

    const flags = try parse(talloc, &.{"prog"}, Args);
    try testing.expect(flags.format == .json);
}

test "parse optional string" {
    const Args = struct {
        config: ?[]const u8 = null,
    };

    const flags1 = try parse(talloc, &.{"prog"}, Args);
    try testing.expect(flags1.config == null);

    const flags2 = try parse(talloc, &.{ "prog", "--config=/path/to/config" }, Args);
    try testing.expect(flags2.config != null);
    try testing.expect(std.mem.eql(u8, flags2.config.?, "/path/to/config"));
}

test "parse optional int" {
    const Args = struct {
        count: ?u32 = null,
    };

    const flags1 = try parse(talloc, &.{"prog"}, Args);
    try testing.expect(flags1.count == null);

    const flags2 = try parse(talloc, &.{ "prog", "--count=42" }, Args);
    try testing.expect(flags2.count != null);
    try testing.expect(flags2.count.? == 42);
}

test "parse optional bool" {
    const Args = struct {
        verbose: ?bool = null,
    };

    const flags1 = try parse(talloc, &.{"prog"}, Args);
    try testing.expect(flags1.verbose == null);

    const flags2 = try parse(talloc, &.{ "prog", "--verbose" }, Args);
    try testing.expect(flags2.verbose != null);
    try testing.expect(flags2.verbose.? == true);
}

test "parse boolean formats" {
    const Args = struct {
        flag: bool = false,
    };

    const flags1 = try parse(talloc, &.{ "prog", "--flag" }, Args);
    try testing.expect(flags1.flag == true);

    const flags2 = try parse(talloc, &.{ "prog", "--flag=true" }, Args);
    try testing.expect(flags2.flag == true);

    const flags3 = try parse(talloc, &.{ "prog", "--flag=false" }, Args);
    try testing.expect(flags3.flag == false);
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

    const result1 = try parse(talloc, &.{ "prog", "start", "--host=0.0.0.0", "--port=3000" }, CLI);
    try testing.expect(std.mem.eql(u8, result1.start.host, "0.0.0.0"));
    try testing.expect(result1.start.port == 3000);

    const result2 = try parse(talloc, &.{ "prog", "stop", "--force" }, CLI);
    try testing.expect(result2.stop.force == true);
}

test "parse subcommand with defaults" {
    const CLI = union(enum) {
        start: struct {
            host: []const u8 = "localhost",
            port: u16 = 8080,
        },
        stop: struct {},
    };

    const result = try parse(talloc, &.{ "prog", "start" }, CLI);
    try testing.expect(std.mem.eql(u8, result.start.host, "localhost"));
    try testing.expect(result.start.port == 8080);
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

    try testing.expectError(Error.MissingSubcommand, parse(talloc, &.{"prog"}, CLI));
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

    try testing.expectError(Error.UnknownSubcommand, parse(talloc, &.{ "prog", "restart" }, CLI));
}

test "duplicate flag" {
    const Args = struct {
        port: u16 = 8080,
    };

    try testing.expectError(Error.DuplicateFlag, parse(talloc, &.{ "prog", "--port=8080", "--port=9090" }, Args));
}

test "missing value" {
    const Args = struct {
        name: []const u8,
    };

    try testing.expectError(Error.MissingValue, parse(talloc, &.{ "prog", "--name" }, Args));
}

test "invalid enum value" {
    const Format = enum { json, yaml, toml };
    const Args = struct {
        format: Format = .json,
    };

    try testing.expectError(Error.InvalidValue, parse(talloc, &.{ "prog", "--format=xml" }, Args));
}

test "invalid int value" {
    const Args = struct {
        port: u16 = 8080,
    };

    try testing.expectError(Error.InvalidValue, parse(talloc, &.{ "prog", "--port=not-a-number" }, Args));
}

test "no args provided" {
    const Args = struct {
        port: u16 = 8080,
    };

    try testing.expectError(Error.InvalidArgument, parse(talloc, &.{}, Args));
}

test "missing required flag" {
    const Args = struct {
        name: []const u8,
    };

    try testing.expectError(Error.MissingRequiredFlag, parse(talloc, &.{"prog"}, Args));
}

test "help declaration exists" {
    const Args = struct {
        verbose: bool = false,
        pub const help = "Test help message";
    };

    try testing.expect(@hasDecl(Args, "help"));
    try testing.expect(std.mem.eql(u8, Args.help, "Test help message"));
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

    const result = try parse(talloc, &.{ "prog", "server", "start", "--port=9090" }, CLI);
    switch (result) {
        .server => |s| switch (s) {
            .start => |start| {
                try testing.expect(std.mem.eql(u8, start.host, "0.0.0.0"));
                try testing.expect(start.port == 9090);
            },
            else => unreachable,
        },
        else => unreachable,
    }
}

test "unexpected argument error" {
    const Args = struct {
        port: u16 = 8080,
    };

    try testing.expectError(Error.UnexpectedArgument, parse(talloc, &.{ "prog", "--port=8080", "extra" }, Args));
}

// --- Slice tests ---

test "slice repeated flags" {
    const Args = struct {
        files: []const []const u8 = &[_][]const u8{},
    };

    const result = try parse(talloc, &.{ "prog", "--files=a.txt", "--files=b.txt", "--files=c.txt" }, Args);
    defer talloc.free(result.files);

    try testing.expectEqual(@as(usize, 3), result.files.len);
    try testing.expect(std.mem.eql(u8, result.files[0], "a.txt"));
    try testing.expect(std.mem.eql(u8, result.files[1], "b.txt"));
    try testing.expect(std.mem.eql(u8, result.files[2], "c.txt"));
}

test "slice comma separated" {
    const Args = struct {
        files: []const []const u8 = &[_][]const u8{},
    };

    const result = try parse(talloc, &.{ "prog", "--files=a.txt,b.txt,c.txt" }, Args);
    defer talloc.free(result.files);

    try testing.expectEqual(@as(usize, 3), result.files.len);
    try testing.expect(std.mem.eql(u8, result.files[0], "a.txt"));
    try testing.expect(std.mem.eql(u8, result.files[1], "b.txt"));
    try testing.expect(std.mem.eql(u8, result.files[2], "c.txt"));
}

test "slice integer values" {
    const Args = struct {
        ports: []const u16 = &[_]u16{},
    };

    const result = try parse(talloc, &.{ "prog", "--ports=8080", "--ports=9090", "--ports=3000" }, Args);
    defer talloc.free(result.ports);

    try testing.expectEqual(@as(usize, 3), result.ports.len);
    try testing.expectEqual(@as(u16, 8080), result.ports[0]);
    try testing.expectEqual(@as(u16, 9090), result.ports[1]);
    try testing.expectEqual(@as(u16, 3000), result.ports[2]);
}

test "slice enum values" {
    const Format = enum { json, yaml, toml };
    const Args = struct {
        formats: []const Format = &[_]Format{},
    };

    const result = try parse(talloc, &.{ "prog", "--formats=json,yaml,toml" }, Args);
    defer talloc.free(result.formats);

    try testing.expectEqual(@as(usize, 3), result.formats.len);
    try testing.expectEqual(Format.json, result.formats[0]);
    try testing.expectEqual(Format.yaml, result.formats[1]);
    try testing.expectEqual(Format.toml, result.formats[2]);
}

test "slice with default" {
    const Args = struct {
        files: []const []const u8 = &[_][]const u8{},
    };

    const result = try parse(talloc, &.{"prog"}, Args);
    // Default is used (no allocation), nothing to free.
    try testing.expectEqual(@as(usize, 0), result.files.len);
}

test "slice mixed with scalar flags" {
    const Args = struct {
        files: []const []const u8 = &[_][]const u8{},
        verbose: bool = false,
        port: u16 = 8080,
    };

    const result = try parse(talloc, &.{ "prog", "--files=a.txt", "--verbose", "--files=b.txt", "--port=3000" }, Args);
    defer talloc.free(result.files);

    try testing.expectEqual(@as(usize, 2), result.files.len);
    try testing.expect(std.mem.eql(u8, result.files[0], "a.txt"));
    try testing.expect(std.mem.eql(u8, result.files[1], "b.txt"));
    try testing.expect(result.verbose == true);
    try testing.expectEqual(@as(u16, 3000), result.port);
}

test "slice comma separated integers" {
    const Args = struct {
        ports: []const u16 = &[_]u16{},
    };

    const result = try parse(talloc, &.{ "prog", "--ports=80,443,8080" }, Args);
    defer talloc.free(result.ports);

    try testing.expectEqual(@as(usize, 3), result.ports.len);
    try testing.expectEqual(@as(u16, 80), result.ports[0]);
    try testing.expectEqual(@as(u16, 443), result.ports[1]);
    try testing.expectEqual(@as(u16, 8080), result.ports[2]);
}

test "slice invalid element" {
    const Args = struct {
        ports: []const u16 = &[_]u16{},
    };

    try testing.expectError(Error.InvalidValue, parse(talloc, &.{ "prog", "--ports=80,not_a_number" }, Args));
}

test "slice single value" {
    const Args = struct {
        tags: []const []const u8 = &[_][]const u8{},
    };

    const result = try parse(talloc, &.{ "prog", "--tags=only-one" }, Args);
    defer talloc.free(result.tags);

    try testing.expectEqual(@as(usize, 1), result.tags.len);
    try testing.expect(std.mem.eql(u8, result.tags[0], "only-one"));
}

test "multiple slice fields" {
    const Args = struct {
        files: []const []const u8 = &[_][]const u8{},
        ports: []const u16 = &[_]u16{},
    };

    const result = try parse(talloc, &.{ "prog", "--files=a.txt,b.txt", "--ports=80,443" }, Args);
    defer talloc.free(result.files);
    defer talloc.free(result.ports);

    try testing.expectEqual(@as(usize, 2), result.files.len);
    try testing.expect(std.mem.eql(u8, result.files[0], "a.txt"));
    try testing.expect(std.mem.eql(u8, result.files[1], "b.txt"));
    try testing.expectEqual(@as(usize, 2), result.ports.len);
    try testing.expectEqual(@as(u16, 80), result.ports[0]);
    try testing.expectEqual(@as(u16, 443), result.ports[1]);
}
