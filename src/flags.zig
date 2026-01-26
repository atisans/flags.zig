const std = @import("std");

const Self = @This();

const FlagValues = union(enum) {
    boolean: bool,
    string: []const u8,
};

const Flag = struct {
    value: FlagValues,
    description: ?[]const u8 = null,
};

var entries: std.StringHashMap(Flag) = .init(std.heap.smp_allocator);

pub fn parse(args: []const []const u8) !void {
    for (args) |arg| {
        const trimmed = std.mem.trimStart(u8, arg, "-"); // trim leading dashes

        if (std.mem.indexOfScalar(u8, trimmed, '=') != null) {
            var it = std.mem.splitScalar(u8, trimmed, '=');
            const key = it.first();
            const value = it.rest();

            try entries.put(key, .{ .value = .{ .string = value } });
        } else {
            try entries.put(trimmed, .{ .value = .{ .boolean = true } });
        }
    }
}

pub fn string(name: []const u8, default: []const u8, description: ?[]const u8) []const u8 {
    _ = description;

    if (entries.get(name)) |found| {
        return found.value.string;
    }

    return default;
}

pub fn boolean(name: []const u8, default: bool, description: ?[]const u8) bool {
    _ = description;

    if (entries.get(name)) |found| {
        return switch (found.value) {
            .boolean => |v| return v,
            else => return default,
        };
    }

    return default;
}

pub fn int(name: []const u8, default: i32, description: ?[]const u8) i32 {
    _ = description;
    // std.debug.assert(std.mem.startsWith(u8, @typeName(@TypeOf(default)), "i"));

    if (entries.get(name)) |found| {
        return std.fmt.parseInt(@TypeOf(default), found.value.string, 10) catch default;
    }

    return default;
}
