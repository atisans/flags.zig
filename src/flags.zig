const std = @import("std");

fn print_help(comptime Args: type, arg: []const u8) void {
    const fields = @typeInfo(Args).@"struct".fields;
    const decls = @typeInfo(Args).@"struct".decls;

    std.debug.print("Usage:\n  {s} [options]\n\nOptions:\n", .{arg});

    inline for (0..fields.len) |idx| {
        const field = fields[idx];
        const doc = if (decls.len > 0) decls[idx].name else "";

        if (field.type == bool) {
            std.debug.print("  --{s:<12} {s}\n", .{ field.name, "<bool>" });
        } else {
            std.debug.print("  --{s:<12} <{s}>  {s}\n", .{
                field.name,
                @typeName(field.type),
                doc,
            });
        }
    }

    std.debug.print("  --help         Show this help page\n", .{});
}

fn set_field(
    comptime Args: type,
    result: *Args,
    field: std.builtin.Type.StructField,
    value: ?[]const u8,
) !void {
    const T = field.type;

    if (T == bool) {
        @field(result, field.name) = if (value) |v|
            std.mem.eql(u8, v, "true") // or std.mem.eql(u8, v, "1")
        else
            true;

        return;
    }

    const v = value orelse return error.MissingValue;

    if (T == []const u8) {
        @field(result, field.name) = v;
        return;
    }

    if (@typeInfo(T) == .int) {
        @field(result, field.name) =
            std.fmt.parseInt(T, v, 10) catch return error.InvalidValue;
        return;
    }

    if (@typeInfo(T) == .float) {
        @field(result, field.name) =
            std.fmt.parseFloat(T, v) catch return error.InvalidValue;
        return;
    }

    @compileError("Unsupported flag type: " ++ @typeName(T));
}

pub fn parse(allocator: std.mem.Allocator, comptime Args: type, args: []const []const u8) !Args {
    _ = allocator; // autofix

    var results: Args = .{};

    const fields = @typeInfo(Args).@"struct".fields;

    var i: usize = 0; // include program name in processing
    while (i < args.len) : (i += 1) {
        const arg = args[i];

        if (std.mem.eql(u8, arg, "--help")) {
            print_help(Args, args[0]);
            std.process.exit(0);
        }

        if (!std.mem.startsWith(u8, arg, "--")) {
            if (i == 0) continue; // skip program name
            return error.InvalidArgument;
        }

        const trimmed = std.mem.trim(u8, arg[2..], " \t");
        var key: []const u8 = trimmed;
        var value: ?[]const u8 = null;

        if (std.mem.indexOfScalar(u8, trimmed, '=')) |pos| {
            key = trimmed[0..pos];
            value = trimmed[pos + 1 ..];
        }

        var found_match = false;
        inline for (fields) |field| {
            if (std.mem.eql(u8, key, field.name)) {
                found_match = true;
                try set_field(Args, &results, field, value);
            }
        }

        if (!found_match) return error.UnknownFlag;
    }

    return results;
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
