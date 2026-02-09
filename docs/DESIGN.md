# flags.zig Design Document

## Overview

A type-safe, zero-cost command-line argument parser for Zig, synthesizing the best patterns from **Rust clap**, **Python argparse**, and **TigerBeetle's flags** implementation.

## Design Philosophy

### Core Principles

1. **Type Safety First**: Leverage Zig's comptime type system to catch errors at compile time
2. **Zero Runtime Cost**: Parsing logic evaluated at compile time where possible
3. **Explicit Over Implicit**: Clear, readable API without hidden behaviors
4. **Composability**: Small, reusable pieces that compose into complex CLI tools
5. **Developer Experience**: Excellent error messages and help generation

## Inspirations

### From Rust Clap

| Feature | Clap Approach | Our Adaptation |
|---------|--------------|----------------|
| **Derive Macros** | `#[derive(Parser)]` generates boilerplate | Use Zig's `@Type()` and comptime reflection |
| **Builder Pattern** | `Arg::new().short('v').long("verbose")` | Struct field declarations with defaults |
| **Help Generation** | Auto-generated from doc comments | Comptime introspection + optional `help` decls |
| **Subcommands** | Enum variants with `#[command(subcommand)]` | `union(enum)` types |
| **Validation** | `value_parser`, `value_enum` | Custom types (planned) |

**Key Insight**: Clap's derive macros are essentially compile-time code generation. Zig's `comptime` makes this native.

### From Python Argparse

| Feature | Argparse Approach | Our Adaptation |
|---------|------------------|----------------|
| **Simplicity** | `parser.add_argument('--foo', default=42)` | Struct initialization with defaults |
| **Subparsers** | `add_subparsers()` method | Nested `union(enum)` types |
| **Type Coercion** | `type=int`, `type=float` | Zig's type system (automatic) |
| **Help Messages** | `help="description"` | Comptime doc strings or `help` declarations |
| **Nargs** | `nargs='*'`, `nargs='+'` | Slice types with comptime bounds checking |

**Key Insight**: Argparse's simplicity comes from convention over configuration. Struct defaults provide the same ergonomics.

### From TigerBeetle Flags

| Feature | TigerBeetle Approach | Our Enhancement |
|---------|---------------------|-----------------|
| **Type-Driven** | Parse into Zig types directly | Same, but with richer error messages |
| **Union Subcommands** | `union(enum)` for subcommands | Nested unions for multi-level commands |
| **Positional Args** | `@"--"` marker field | Multiple positional arg types |
| **Fatal Errors** | Direct `fatal()` calls | Configurable error handling |
| **No Auto-Help** | Manual help only | Optional auto-help with `help` decl |

## Type-Safe Argument Design

### The Problem

Traditional CLI parsers pass arguments as strings:

```zig
// [ ] No compile-time validation
const args = try parse(argv, "[]const []const u8");
```

Issues:
- Runtime errors for missing required arguments
- No IDE autocompletion
- Refactoring is fragile
- Type mismatches caught late

### The Solution: Type-Driven Parsing

Define CLI structure as **types**, not strings:

```zig
// The type IS the specification
const Args = struct {
    // Type enforces valid values
    port: u16 = 8080,
    
    // Optional types enforce nullability
    config: ?[]const u8 = null,
    
    // Enum types enforce choices
    format: enum { json, yaml } = .json,
};

// Parse is type-safe
const parsed = try flags.parse(argv, Args);
```

### Type Safety Features

**1. Exhaustive Switch Checking**
```zig
const cli = try flags.parse(args, CLI);

switch (cli) {
    .start => |s| handleStart(s),
    .stop => |s| handleStop(s),
    // Missing variant = compile error
}
```

**2. Compile-time Type Validation**
```zig
const Args = struct {
    // Invalid: floats can't be flags (no equality check)
    threshold: f32 = 0.5,  // Compile error!
    
    // Invalid: pointer types need copy strategy
    buffer: *[1024]u8,      // Compile error!
};
```

**3. Default Value Type Checking**
```zig
const Args = struct {
    // Error: default "ten" doesn't match type u32
    count: u32 = "ten",  // Compile error!
    
    // Valid: default matches type
    name: []const u8 = "default",
};
```

**4. Nested Type Safety**
```zig
const ServerArgs = struct {
    host: []const u8 = "localhost",
    port: u16 = 8080,
};

const CLI = union(enum) {
    server: ServerArgs,
    client: ClientArgs,
};

// cli.server.host is guaranteed to exist
const cli = try flags.parse(args, CLI);
```

## Help Generation Without Strings

### The Challenge

Zig doesn't expose doc comments through `@typeInfo()`, so we can't use:
```zig
/// The port to listen on
port: u16 = 8080,
```

### Solution: Comptime Declarations

Use `pub const help` that is accessible via `@hasDecl()`:

```zig
const Args = struct {
    host: []const u8 = "localhost",
    port: u16 = 8080,

    pub const help =
        \\Usage: myapp [options]
        \\
        \\Options:
        \\  --host    The host address to bind to
        \\  --port    The port number (1-65535)
    ;
};
```

### Advantages

1. **Comptime Accessible**: Available via `@hasDecl(Args, "help")`
2. **Type-Safe**: Struct literal ensures every field has documentation
3. **Zero Runtime Cost**: Help text can be compiled away if not used
4. **Extensible**: Can include examples, exit codes, etc.

### Extended Help Example

```zig
const Args = struct {
    pub const help =
        \\Start the server
        \\
        \\Usage: myapp start [options]
        \\
        \\Options:
        \\  --host    The host address to bind to
        \\  --port    The port number
        \\
        \\Examples:
        \\  myapp start --host=0.0.0.0 --port=80
        \\  myapp start -h
        \\
        \\Exit Codes:
        \\  0  Success
        \\  1  Invalid arguments
    ;
};
```

### Alternative: Build Step Enhancement

For true doc comment support:

```zig
// build.zig
const generate_help = @import("flags_build").generateHelp;

pub fn build(b: *std.Build) void {
    generate_help(b, "src/main.zig");
}
```

**Trade-offs**:
- [x] True doc comment support
- [ ] Requires build step integration
- [ ] More complex tooling

## Subcommand Design

### Multi-Level Commands

Support git-style nested commands:

```zig
const CLI = union(enum) {
    // Simple command
    version,
    
    // Command with flags
    serve: struct {
        host: []const u8 = "localhost",
        port: u16 = 8080,
    },
    
    // Nested subcommands (git remote add)
    remote: union(enum) {
        add: struct { name: []const u8, url: []const u8 },
        remove: struct { name: []const u8 },
        list,
        
        pub const help =
            \\\Manage remote repositories
            \\
            \\\Usage: myapp remote <command> [options]
        ;
    },

    pub const help =
        \\Git-like CLI example
        \\
        \\Usage: myapp <command> [options]
    ;
};
```

### Usage

```zig
const cli = try flags.parse(args, CLI);

switch (cli) {
    .version => printVersion(),
    .serve => |s| startServer(s.host, s.port),
    .remote => |r| switch (r) {
        .add => |a| addRemote(a.name, a.url),
        .remove => |r| removeRemote(r.name),
        .list => listRemotes(),
    },
}
```

## Error Handling

flags.zig uses Zig's error union mechanism. All parsing errors are returned and can be handled with `try` or `catch`.

### Error Types

```zig
pub const Error = error{
    DuplicateFlag,              // --port=8080 --port=9090
    InvalidArgument,            // No args provided
    InvalidValue,               // --port=not_a_number
    MissingRequiredFlag,        // Required field with no default
    MissingRequiredPositional,  // Positional arg not provided
    MissingSubcommand,          // No subcommand for union
    MissingValue,               // --name (no value after =)
    UnknownFlag,                // --unknown-flag
    UnknownSubcommand,          // prog unknown-cmd
    UnexpectedArgument,         // Extra positional arg
};
```

### Usage

```zig
// Propagate error (caller handles)
const parsed = try flags.parse(args, Args);

// Custom error handling
const parsed = flags.parse(args, Args) catch |err| {
    std.log.err("Parse error: {}", .{err});
    return;
};

// Ignore specific errors
const parsed = flags.parse(args, Args) catch |err| switch (err) {
    error.UnknownFlag => {
        std.log.warn("Unknown flag, using defaults");
        // Use default values
    },
    else => return err,
};
```

## Best Practices

### DO

1. **Use struct defaults** for common values
2. **Define help** via `pub const help` declarations
3. **Use unions** for mutually exclusive subcommands
4. **Leverage enums** for constrained choices
5. **Use optional types** for truly optional flags

### DON'T

1. **Don't** use floats for flags (equality issues)
2. **Don't** use raw pointers without copy strategy
3. **Don't** skip error handling
4. **Don't** make all flags optional (defeats type safety)
5. **Don't** use runtime string manipulation for help

## Implementation Status

### Implemented [x]
- [x] Struct-based flag parsing
- [x] Basic types (bool, int, float, string)
- [x] Optional types (?T)
- [x] Enum types with validation
- [x] Default values via struct fields
- [x] Union(enum) subcommands (including nested)
- [x] Help generation via `pub const help`
- [x] Positional arguments (via `@"--"` marker)
- [x] Comprehensive error handling

### Planned [~]
- [ ] Custom types via `parse_flag_value` convention
- [ ] Short flag names (-v for --verbose)
- [ ] Space-separated values (-name value)
- [ ] Validation framework (ranges, choices, required)
- [ ] Shell completions
- [ ] Environment variable binding
- [ ] Config file support

## Future Features

- Struct-based help generation (for type-safe, auto-generated help)
- Per-field documentation
- Auto-generated examples
- Exit code documentation

## Summary

This design synthesizes:
- **Clap's** type safety and derive patterns
- **Argparse's** simplicity and conventions
- **TigerBeetle's** zero-cost abstractions

The result: A CLI parser that leverages Zig's unique strengths (comptime, type safety, zero-cost) while providing an ergonomic, familiar API.
