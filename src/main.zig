const std = @import("std");
const flags = @import("flags");

pub fn main() !void {
    _ = try flags.parse();
    const name = flags.string("name", "joe", "A name of the user");
    const is_active = flags.boolean("active", false, "Check is user is active");
    const port = flags.int("port", 5000, "The port to use");
    std.debug.print("Name: {s}\nActive: {}\nPort: {d}\n", .{ name, is_active, port });
}
