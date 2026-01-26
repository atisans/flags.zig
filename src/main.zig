const std = @import("std");
const flags = @import("flags");

pub fn main() !void {
    const args = try std.process.argsAlloc(std.heap.page_allocator);
    defer std.process.argsFree(std.heap.page_allocator, args);

    _ = try flags.parse(args);
    const name = flags.string("name", "joe", "A name of the user");
    const is_active = flags.boolean("active", false, "Check is user is active");
    const port = flags.int("port", 5000, "The port to use");
    std.debug.print("Name: {s}\nActive: {}\nPort: {d}\n", .{ name, is_active, port });
}
