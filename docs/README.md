# flags.zig Documentation

Type-safe command-line argument parsing for Zig using struct-based definitions.

## Quick Start

```zig
const std = @import("std");
const flags = @import("flags");

pub fn main() !void {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();
    const allocator = gpa.allocator();

    const args = try std.process.argsAlloc(allocator);
    defer std.process.argsFree(allocator, args);

    const Args = struct {
        name: []const u8 = "world",
        count: u32 = 1,
        verbose: bool = false,
    };

    const parsed = try flags.parse(args, Args);
    std.debug.print("Hello, {s}!\n", .{parsed.name});
}
```

## Supported Types

| Type | Example | Notes |
|------|---------|-------|
| `bool` | `--verbose` or `--verbose=true/false` | Presence = true |
| Integers | `--port=8080` | `u8`-`u64`, `i8`-`i64` |
| Floats | `--rate=0.5` | `f32`, `f64` |
| Strings | `--name=value` | `[]const u8` only |
| Enums | `--format=json` | Validates against variants |
| Optionals | `--config=path` or omit | `?T` for nullable values |
| Slices | `--files=a.txt --files=b.txt` | `[]const []const u8`, `[]u32`, etc. |

## Features

### Struct-Based Flags

Define CLI structure as a struct with defaults:

```zig
const Args = struct {
    host: []const u8 = "localhost",
    port: u16 = 8080,
    verbose: bool = false,
};

const parsed = try flags.parse(args, Args);
```

### Subcommands

Use `union(enum)` for git-style commands:

```zig
const CLI = union(enum) {
    start: struct {
        host: []const u8 = "localhost",
        port: u16 = 8080,
    },
    stop: struct {
        force: bool = false,
    },
};

const cli = try flags.parse(args, CLI);
switch (cli) {
    .start => |s| startServer(s.host, s.port),
    .stop => |s| stopServer(s.force),
}
```

### Multiple Value Flags

Support for slices with three syntax patterns:

```zig
const Args = struct {
    // String slice - accepts multiple file paths
    files: []const []const u8 = &[_][]const u8{},
    
    // Integer slice - accepts multiple ports
    ports: []u16 = &[_]u16{},
    
    // Optional slice - null vs empty distinction
    config: ?[]const []const u8 = null,
};

// Repeated flags (default pattern)
./program --files=a.txt --files=b.txt --files=c.txt

// Space-separated values
./program --files a.txt b.txt c.txt

// Comma-separated values
./program --files=a.txt,b.txt,c.txt
```

**Memory Management**: Slices use arena-based allocation for predictable cleanup. Empty slices (`[]`) are distinct from missing flags (`null` for optional slices).

### Positional Arguments

Use the `@"--"` marker field to separate flags from positional args:

```zig
const Args = struct {
    verbose: bool = false,
    @"--": void,
    input: []const u8,
    output: []const u8 = "output.txt",
};

// Usage: program --verbose input.txt --output=result.txt
```

### Help Generation

**Automatic help** - Generated from struct fields if no `help` const declared:

```bash
$ program --help
Options:
  --verbose            bool (default: false)
  --port               u16 (default: 8080)
  --config             ?[]const u8 (optional)
  --input              []const u8 (required)
```

**Custom help** - Add a `pub const help` declaration:

```zig
const Args = struct {
    verbose: bool = false,
    port: u16 = 8080,
    
    pub const help =
        \\Usage: myapp [options]
        \\
        \\Options:
        \\  --verbose    Enable verbose output
        \\  --port       Port to listen on (default: 8080)
    ;
};
```

## Error Handling

```zig
pub const Error = error{
    DuplicateFlag,
    InvalidArgument,
    InvalidValue,
    MissingRequiredFlag,
    MissingRequiredPositional,
    MissingSubcommand,
    MissingValue,
    UnknownFlag,
    UnknownSubcommand,
    UnexpectedArgument,
};

const parsed = flags.parse(args, Args) catch |err| {
    std.log.err("Parse error: {s}\n", .{@errorName(err)});
    return;
};
```

## Examples

### HTTP Client

```zig
const CLI = union(enum) {
    get: struct {
        url: []const u8,
        output: ?[]const u8 = null,
    },
    post: struct {
        url: []const u8,
        data: ?[]const u8 = null,
    },
};
```

### Database CLI

```zig
const CLI = union(enum) {
    connect: struct {
        host: []const u8 = "localhost",
        port: u16 = 5432,
        user: []const u8 = "postgres",
    },
    query: struct {
        sql: []const u8,
        format: enum { table, json, csv } = .table,
    },
    migrate: struct {
        // Slice of migration files to apply
        files: []const []const u8,
        // Optional slice of migration steps to skip
        skip: ?[]const []const u8 = null,
        dry_run: bool = false,
    },
};
```

### File Processor with Slices

```zig
const Args = struct {
    // Input files (required slice)
    inputs: []const []const u8,
    
    // Output files (optional with default)
    outputs: []const []const u8 = &[_][]const u8{"output.txt"},
    
    // Processing options (enums in slice)
    operations: []const enum { compress, encrypt, validate } = &[_]enum { compress, encrypt, validate }{},
    
    // Verbose flag per file
    verbose: bool = false,
};

// Usage examples:
// ./process --files=file1.txt --files=file2.txt --outputs=out1.txt --outputs=out2.txt
// ./process --files=file1.txt,file2.txt --outputs=out.txt --operations=compress,encrypt
// ./process --files file1.txt file2.txt --outputs out.txt --operations compress
```

## Design Principles

1. **Type-Driven**: CLI schema defined as Zig structs with comptime parsing
2. **Zero-cost**: No runtime overhead where possible
3. **Simple API**: Single `parse(args, Args)` function
4. **Explicit**: No hidden behaviors or magic

## Limitations

- **No short flags** (`-v` for `--verbose`) - use long flags only
- **No custom types** - only built-in types and enums
- **No nested slices** - slices of slices not supported
- **Fixed slice syntax precedence** - repeated flags take precedence over space-separated

## Running Tests

```bash
zig build test
```

Current test coverage: 23 tests covering all supported types, subcommands, error cases, and help generation.

## Design Document

## Further Reading

- [DESIGN.md](DESIGN.md) for architecture overview and design decisions
- [SLICE_IMPLEMENTATION.md](SLICE_IMPLEMENTATION.md) for detailed slice implementation guide
- [SLICE_EXAMPLES.md](SLICE_EXAMPLES.md) for comprehensive slice usage examples

## Slice Support Documentation

For detailed information about the new slice support:

- **Implementation Guide**: See [SLICE_IMPLEMENTATION.md](SLICE_IMPLEMENTATION.md) for technical implementation details
- **Usage Examples**: See [SLICE_EXAMPLES.md](SLICE_EXAMPLES.md) for practical examples and best practices
- **Architecture**: See DESIGN.md for design decisions and limitations
