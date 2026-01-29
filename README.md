# flags.zig

A command-line flag parser for Zig. Define flags using a struct and parse command-line arguments into it.

## Features

- [x] Multiple flag types (bool, string, int, float)
- [x] Struct-based argument definition
- [x] Default values via struct fields
- [x] Automatic help generation (`--help`)
- [x] Error handling for invalid/unknown flags
- [ ] Positional arguments support - [P1]
- [ ] Short flag names (`-v`) - [P2]
- [ ] Duration type - [P1]
- [ ] Flag sets for subcommands - [P1]
- [ ] Custom flag types via `Value` interface - [P2]
- [ ] Environment variable integration - [P4]
- [ ] Configuration file support - [P4]

## Installation

Fetch library:
```bash
zig fetch --save git+https://github.com/atisans/flags.zig
```

Add to your `build.zig`:

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

    // Define flags as a struct
    const Args = struct {
        name: []const u8 = "world",
        age: u32 = 25,
        active: bool = false,
    };

    // Parse flags into the struct
    const parsed = try flags.parse(allocator, Args, args);

    // Use the parsed values
    std.debug.print("Hello {s}! Age: {d}, Active: {}\n", .{ parsed.name, parsed.age, parsed.active });
}
```

## Command Line Examples

```bash
# Basic usage
./program --name=alice --age=30 --active

# String flag
./program --name=bob

# Integer flag
./program --age=40

# Boolean flag (no value needed)
./program --active

# Help
./program --help

# Mixed flags
./program --name=charlie --age=35 --active
```

## Supported Types

- `bool` - Boolean flags (presence = true, or `--flag=true/false`)
- `[]const u8` - String values
- `i8`, `i16`, `i32`, `i64`, `u8`, `u16`, `u32`, `u64` - Integer values
- `f32`, `f64` - Floating-point values

## Error Handling

The parser returns errors for:
- `error.InvalidArgument` - Non-flag argument found
- `error.UnknownFlag` - Flag not defined in struct
- `error.MissingValue` - Flag requires a value but none provided
- `error.InvalidValue` - Value cannot be parsed (e.g., non-integer for int flag)
