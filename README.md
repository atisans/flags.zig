# flags.zig

A command-line flag parser for Zig, inspired by Go's `flags` package.

## Features

- [~] Multiple flag types (bool, string, int, float, duration)
- [ ] Automatic help generation (`-h`, `-help`)
- [ ] Positional arguments support
- [ ] Short flag names (`-v`)
- [ ] Flag sets for subcommands
- [ ] Custom flag types via `Value` interface
- [ ] Configurable error handling
- [ ] Environment variable integration (planned)
- [ ] Configuration file support (planned)

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
    _ = try flags.parse();    // Parse command line

    // Define flags
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
