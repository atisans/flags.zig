const std = @import("std");

const FlagValues = union(enum) {
    boolean: bool,
    string: []const u8,
};

const Flag = struct {
    value: FlagValues,
    description: ?[]const u8 = null,
};

const Flags = struct {
    const Self = @This();

    entries: std.StringHashMap(Flag),
    allocator: std.mem.Allocator,

    pub fn init(allocator: std.mem.Allocator) Flags {
        return .{
            .allocator = allocator,
            .entries = std.StringHashMap(Flag).init(allocator),
        };
    }

    pub fn deinit(self: *Self) void {
        self.entries.deinit();
    }

    pub fn parse(self: *Self, args: []const []const u8) !void {
        for (args) |arg| {
            const trimmed = std.mem.trimStart(u8, arg, "-"); // trim leading dashes

            if (std.mem.indexOfScalar(u8, trimmed, '=') != null) {
                var it = std.mem.splitScalar(u8, trimmed, '=');
                const key = it.first();
                const value = it.rest();

                try self.entries.put(key, .{ .value = .{ .string = value } });
            } else {
                try self.entries.put(trimmed, .{ .value = .{ .boolean = true } });
            }
        }
    }

    pub fn string(self: *Self, name: []const u8, default: []const u8, description: ?[]const u8) []const u8 {
        _ = description;

        if (self.entries.get(name)) |found| {
            return found.value.string;
        }

        return default;
    }

    pub fn boolean(self: *Self, name: []const u8, default: bool, description: ?[]const u8) bool {
        _ = description;

        if (self.entries.get(name)) |found| {
            return switch (found.value) {
                .boolean => |v| return v,
                else => return default,
            };
        }

        return default;
    }

    pub fn int(self: *Self, name: []const u8, default: i32, description: ?[]const u8) i32 {
        _ = description;
        // std.debug.assert(std.mem.startsWith(u8, @typeName(@TypeOf(default)), "i"));

        if (self.entries.get(name)) |found| {
            return std.fmt.parseInt(@TypeOf(default), found.value.string, 10) catch default;
        }

        return default;
    }
};

test "test flags parse string" {
    const allocator = std.testing.allocator;
    var flags = Flags.init(allocator);
    defer flags.deinit();

    _ = try flags.parse(&.{"--name=jack"});
    const name = flags.string("name", "joe", "A name of the user");
    try std.testing.expect(std.mem.eql(u8, name, "jack"));
}

test "test flags parse boolean" {
    const allocator = std.testing.allocator;
    var flags = Flags.init(allocator);
    defer flags.deinit();

    _ = try flags.parse(&.{"--active"});
    const is_active = flags.boolean("active", false, "Check is user is active");
    try std.testing.expect(is_active == true);
}

test "test flags parse int" {
    const allocator = std.testing.allocator;
    var flags = Flags.init(allocator);
    defer flags.deinit();

    _ = try flags.parse(&.{"--port=8080"});
    const port = flags.int("port", 5000, "The port to use");
    try std.testing.expect(port == 8080);
}

test "test flags parse int using default" {
    const allocator = std.testing.allocator;
    var flags = Flags.init(allocator);
    defer flags.deinit();

    _ = try flags.parse(&.{});
    const port = flags.int("port", 5000, "The port to use");
    try std.testing.expect(port == 5000);
}
