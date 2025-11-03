const std = @import("std");
const flags = @import("flags");

pub fn main() !void {
    _ = try flags.parse();
    const name = flags.string("name", "joe", "A name of the user");
    const is_active = flags.boolean("active", false, "Check is user is active");
    std.debug.print("Name: {s}\nActive: {}\n", .{ name, is_active });
}
