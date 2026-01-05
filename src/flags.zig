const std = @import("std");

const Self = @This();

const FlagValues = union(enum) {
    boolean: bool,
    string: []const u8,
    int: i32,
};

const Flag = struct {
    value: FlagValues,
    description: []const u8 = "",
};

var entries: std.StringHashMap(Flag) = .init(std.heap.smp_allocator);

pub fn parse() !void {
    var args = std.process.args();
    defer args.deinit();
    _ = args.skip(); // skip the first argument (program name)

    while (args.next()) |arg| {
        const trimmed = std.mem.trimStart(u8, arg, "-"); // trim leading dashes

        if (std.mem.indexOfScalar(u8, trimmed, '=') != null) {
            var it = std.mem.splitScalar(u8, trimmed, '=');
            const key = it.first();
            const value = it.rest();

            const is_int = std.fmt.parseInt(i32, value, 10) catch 0;

            if (is_int == 0) {
                try entries.put(key, .{ .value = .{ .string = value } });
            }

            try entries.put(key, .{ .value = .{ .int = is_int } });
        } else {
            try entries.put(trimmed, .{ .value = .{ .boolean = true } });
        }
    }
}

pub fn string(name: []const u8, value: []const u8, description: []const u8) []const u8 {
    if (entries.get(name)) |found| {
        var updated = found;
        updated.description = description;

        _ = entries.put(name, updated) catch unreachable;

        return switch (updated.value) {
            .string => |v| return v,
            else => return value,
        };
    }

    _ = entries.put(name, .{ .value = .{ .string = value }, .description = description }) catch unreachable;
    return value;
}

pub fn boolean(name: []const u8, value: bool, description: []const u8) bool {
    if (entries.get(name)) |found| {
        var updated = found;
        updated.description = description;

        _ = entries.put(name, updated) catch unreachable;

        return switch (updated.value) {
            .boolean => |v| return v,
            else => return value,
        };
    }

    _ = entries.put(name, .{ .value = .{ .boolean = value }, .description = description }) catch unreachable;
    return value;
}

pub fn int(name: []const u8, value: i32, description: []const u8) i32 {
    if (entries.get(name)) |found| {
        var updated = found;
        updated.description = description;

        _ = entries.put(name, updated) catch unreachable;

        return switch (updated.value) {
            .int => |v| return v,
            else => return value,
        };
    }

    _ = entries.put(name, .{ .value = .{ .int = value }, .description = description }) catch unreachable;
    return value;
}
