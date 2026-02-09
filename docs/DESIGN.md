# flags.zig Design Document

## Overview

A type-safe, zero-cost command-line argument parser for Zig, inspired by **Rust clap**, **Python argparse**, and **TigerBeetle's flags** implementation.

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

**Key Insight**: Clap's derive macros are essentially compile-time code generation. Zig's `comptime` makes this native.

### From Python Argparse

| Feature | Argparse Approach | Our Adaptation |
|---------|------------------|----------------|
| **Simplicity** | `parser.add_argument('--foo', default=42)` | Struct initialization with defaults |
| **Subparsers** | `add_subparsers()` method | Nested `union(enum)` types |
| **Type Coercion** | `type=int`, `type=float` | Zig's type system (automatic) |
| **Help Messages** | `help="description"` | Comptime doc strings or `help` declarations |

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
// No compile-time validation
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
    // Invalid: floats work but be careful with equality
    threshold: f32 = 0.5,
    
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

## Help Generation

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

If no `help` declaration exists, the library auto-generates help from struct fields.

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
        \\  myapp start --help
        \\
        \\Exit Codes:
        \\  0  Success
        \\  1  Invalid arguments
    ;
};
```

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
            \\Manage remote repositories
            \\
            \\Usage: myapp remote <command> [options]
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
    std.log.err("Parse error: {s}", .{@errorName(err)});
    return;
};
```

### Slice Support Examples

#### Basic Slice Usage

```zig
const Args = struct {
    files: []const []const u8 = &[_][]const u8{},
    ports: []u16 = &[_]u16{},
    tags: []const []const u8 = &[_][]const u8{},
};

// All equivalent:
./program --files=a.txt --files=b.txt --files=c.txt
./program --files a.txt b.txt c.txt  
./program --files=a.txt,b.txt,c.txt
```

#### Optional vs Empty Slices

```zig
const Args = struct {
    // Required slice - must be provided
    inputs: []const []const u8,
    
    // Optional slice - null vs empty distinction
    excludes: ?[]const []const u8 = null,
    
    // Default empty slice
    outputs: []const []const u8 = &[_][]const u8{},
};
```

#### Slice with Custom Types

```zig
const LogLevel = enum { debug, info, warn, error };
const Args = struct {
    // Slice of enums
    levels: []const LogLevel = &[_]LogLevel{.info, .warn},
    
    // Slice of integers
    retry_counts: []u32 = &[_]u32{3},
    
    // Mixed with other types
    config: []const []const u8 = &[_][]const u8{"default.conf"},
    verbose: bool = false,
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

1. **Don't** skip error handling
2. **Don't** make all flags optional (defeats type safety)
3. **Don't** use runtime string manipulation for help

## Implementation Status

### Implemented

- [x] Struct-based flag parsing
- [x] Basic types (bool, int, float, string)
- [x] Optional types (?T)
- [x] Enum types with validation
- [x] Default values via struct fields
- [x] Union(enum) subcommands (including nested)
- [x] Help generation via `pub const help`
- [x] Positional arguments (via `@"--"` marker)
- [x] Comprehensive error handling
- [x] Auto-generated help from struct fields
- [x] Slice support (multiple values per flag)
- [x] Three parsing patterns: repeated, space-separated, comma-separated

## Slice Support Architecture

### Memory Allocation Strategy

Slices use **arena-based allocation** for predictable cleanup:
- Arena allocator created at start of parsing
- All slice values allocated from the same arena
- Single cleanup point at end of parsing
- Pre-allocation based on argument count for performance

### Parsing Algorithm

1. **Type Detection**: Detect slice types via `@typeInfo(T).pointer`
2. **Value Accumulation**: Collect values across argument boundaries
3. **Syntax Patterns**: Support three patterns with precedence rules:
   - **Repeated flags** (highest precedence): `--files=a.txt --files=b.txt`
   - **Space-separated** (medium): `--files a.txt b.txt c.txt`
   - **Comma-separated** (lowest): `--files=a.txt,b.txt,c.txt`
4. **Individual Validation**: Validate each element independently
5. **Error Context**: Provide specific error messages for failing elements

### Error Handling for Slices

```zig
pub const Error = error{
    // ... existing errors
    InvalidSliceElement,  // One element in slice failed validation
    EmptySlice,           // Empty slice provided when not allowed
    MixedSyntax,          // Mixing comma and space separation (disallowed)
};
```

### Performance Considerations

- **Pre-allocation**: Estimate capacity based on arg count
- **Growth Factor**: Exponential growth (2x) for unpredictable sizes
- **Memory Locality**: All slice elements allocated sequentially
- **Zero-cost for non-slices**: No overhead for non-slice types

### Type Safety

- **Comptime Validation**: Slice element types checked at compile time
- **Nested Slices**: Explicitly disallowed (`[][]T`) for complexity control
- **Mixed Types**: Prevent mixing different element types in same slice

## Limitations

- **No short flags** - Use long flags (`--verbose` not `-v`)
- **No custom types** - Only built-in types and enums
- **No nested slices** - Slices of slices not supported (`[][]T`)
- **Mixed syntax disallowed** - Cannot mix comma and space separation for same flag

## Summary

This design synthesizes:
- **Clap's** type safety and derive patterns
- **Argparse's** simplicity and conventions
- **TigerBeetle's** zero-cost abstractions

The result: A CLI parser that leverages Zig's unique strengths (comptime, type safety, zero-cost) while providing an ergonomic, familiar API.
