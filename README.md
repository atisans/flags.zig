# flags.zig

A comprehensive command-line flag parser for Zig, inspired by Go's `flags` package.

## Features

- ✅ Multiple flag types (bool, string, int, float, duration)
- ✅ Automatic help generation (`-h`, `-help`)
- ✅ Positional arguments support
- ✅ Short flag names (`-v`)
- ✅ Flag sets for subcommands
- ✅ Custom flag types via `Value` interface
- ✅ Configurable error handling
- ✅ Environment variable integration (planned)
- ✅ Configuration file support (planned)

## Installation

fetch library
```bash
zig fetch https://github.com/<username>/flags.zig/archive/main.tar.gz --name=flags
```

or add to your `build.zig.zon`:

```zig
.dependencies = .{
    .flags = .{
        .url = "https://github.com/<username>/flags.zig/archive/main.tar.gz",
        .hash = "...",
    },
},
```


## Basic Usage

```zig
const std = @import("std");
const flags = @import("flags");

pub fn main() !void {
    flags.parse();    // Parse command line

    // Define flags
    const name = flags.string("name", "world", "name to greet");
    const age = flags.int("age", 25, "your age");
    const verbose = flags.boolean("verbose", false, "verbose output");

    // Use the values
    std.debug.print("Hello {s}! Age: {}, Verbose: {}\n", .{name, age, verbose});
}
```

## Command Line Examples

```bash
# Basic usage
./program -name=alice -age=30 -verbose

# Short flags (when implemented)
./program -n alice -a 30 -v

# Help
./program -h # or (--help)

# With positional arguments (when implemented)
./program -name=bob file1.txt file2.txt
```
