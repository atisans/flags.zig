# flags.zig

A command-line flag parser for Zig, inspired by Go's `flags` package.

## Features

- [x] Multiple flag types (bool, string, int)
- [x] Argument passing via parse(args)
- [ ] Float and Duration types - [P1]
- [ ] Automatic help generation (`-h`, `-help`) - [P1]
- [ ] Positional arguments support - [P1]
- [ ] Short flag names (`-v`) - [P2]
- [ ] Flag sets for subcommands - [P1]
- [ ] Custom flag types via `Value` interface - [P2]
- [ ] Configurable error handling - [P1]
- [ ] Environment variable integration - [P4]
- [ ] Configuration file support - [P4]

## Installation

fetch library
```bash
zig fetch --save git+https://github.com/atisans/flags.zig
```

and add to your `build.zig`:

```zig
const flags = b.dependency("flags", .{});
exe.root_module.addImport("flags", flags.module("flags"));
```


## Basic Usage

```zig
const std = @import("std");
const flags = @import("flags");

pub fn main() !void {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();
    const allocator = gpa.allocator();

    // Get command-line arguments
    const args = try std.process.argsAlloc(allocator);
    defer std.process.argsFree(allocator, args);

    // Parse flags (skip program name)
    try flags.parse(args[1..]);

    // Define and retrieve flags
    const name = flags.string("name", "world", "name to greet");
    const age = flags.int("age", 25, "your age");
    const is_active = flags.boolean("active", false, "check if active");

    // Use the values
    std.debug.print("Hello {s}! Age: {d}, Active: {}\n", .{name, age, is_active});
}
```

## Command Line Examples

```bash
# Basic usage
./program -name=alice -age=30 -active

# Short flags (when implemented)
./program -n alice -a 30 -a

# Help (when implemented)
./program -h # or (--help)

# With positional arguments (when implemented)
./program -name=bob file1.txt file2.txt
```
