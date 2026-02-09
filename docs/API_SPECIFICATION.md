# flags.zig - API Specification

## Core Functions

### `parse(args, Args)`

Parse command-line arguments into a type-safe struct or union.

**Signature:**
```zig
pub fn parse(
    args: []const []const u8,
    comptime Args: type
) !Args
```

**Parameters:**
- `args`: Command-line arguments (typically from `std.process.argsAlloc`)
- `Args`: Comptime type defining expected arguments

**Returns:**
- `Args`: Populated struct or union with parsed values
- `error`: Parse error if validation fails

**Example:**
```zig
const Args = struct {
    verbose: bool = false,
    count: u32 = 10,
    name: []const u8 = "default",
};

const parsed = try flags.parse(args, Args);
```

### `parse(args, Args)` behavior

The parser expects the full `args` slice including program name at index `0`.

## Supported Types

### Primitives

| Type | Flag Format | Example |
|------|-------------|---------|
| `bool` | `--flag` or `--flag=true/false` | `--verbose` |
| `u8`-`u64` | `--name=value` | `--port=8080` |
| `i8`-`i64` | `--name=value` | `--offset=-10` |
| `f32`, `f64` | `--name=value` | `--ratio=0.5` |
| `[]const u8` | `--name=value` | `--name=hello` |
| `?T` (optional) | `--name=value` or omit | `--config=path` |

### Enums

Enum types enforce valid choices:

```zig
const Format = enum { json, yaml, toml };

const Args = struct {
    format: Format = .json,
};

// Usage: --format=yaml
```

### Custom Types (Planned)

Custom type support is planned for a future release. The proposed interface:

```zig
const Address = struct {
    host: []const u8,
    port: u16,
    
    pub fn parse_flag_value(string: []const u8) !Address {
        // Custom parsing logic
    }
};

const Args = struct {
    address: Address = .{ .host = "localhost", .port = 8080 },
};
```

**Status:** Not yet implemented

## Help Generation

### Basic Help

```zig
const Args = struct {
    verbose: bool = false,
    port: u16 = 8080,
    
    pub const help =
        \\Options:
        \\  --verbose    Enable verbose output
        \\  --port       Port to listen on
    ;
};
```

### Comprehensive Help

```zig
const Args = struct {
    pub const help =
        \\My application description
        \\ 
        \\Usage: myapp [options] <command>
        \\ 
        \\Options:
        \\  --verbose    Enable verbose output
        \\  --port       Port to listen on
        \\ 
        \\Examples:
        \\  myapp --verbose --port=8080
        \\  myapp --help
        \\ 
        \\Exit Codes:
        \\  0    Success
        \\  1    Invalid arguments
        \\  2    Runtime error
    ;
};
```

### Accessing Help

Help is automatically displayed with `--help` or `-h` flag.

## Subcommands

### Simple Subcommands

```zig
const CLI = union(enum) {
    start: struct {
        host: []const u8 = "localhost",
        port: u16 = 8080,
    },
    stop: struct {
        force: bool = false,
    },
    status,
    
    pub const help = "Server management commands";
};
```

### Nested Subcommands

```zig
const CLI = union(enum) {
    remote: union(enum) {
        add: struct { name: []const u8, url: []const u8 },
        remove: struct { name: []const u8 },
        list,
        
        pub const help = "Manage remote repositories";
    },
    
    branch: union(enum) {
        create: struct { name: []const u8 },
        delete: struct { name: []const u8 },
        list,
        
        pub const help = "Manage branches";
    },
};
```

## Error Handling

### Error Types

```zig
pub const ParseError = error{
    UnknownFlag,
    MissingValue,
    InvalidValue,
    RequiredFlagMissing,
    InvalidSubcommand,
};
```

### Error Handling in Practice

```zig
const result = flags.parse(args, Args) catch |err| {
    std.log.err("Parse error: {}", .{err});
    // Handle error
    return;
};
```

## Type Constraints

### Valid Types

**Supported:**
- All integer types (`u8`-`u64`, `i8`-`i64`)
- Float types (`f32`, `f64`)
- Booleans (`bool`)
- Strings (`[]const u8`)
- Optional types (`?T`)
- Enums with `parse_flag_value` or exhaustive variants
- Structs with `parse_flag_value`

**Not Supported:**
- Custom types with `parse_flag_value` (planned for future)
- Floats as flag keys (equality issues)
- Raw pointers without copy strategy
- Unions (except for subcommands)
- Arrays without slice wrapper

## Best Practices

### Struct Design

```zig
// Good: Clear defaults
const Args = struct {
    verbose: bool = false,
    config: ?[]const u8 = null,
    workers: u32 = 4,
};

// Bad: No defaults provided
const Args = struct {
    verbose: bool,      // Error: no default
    config: []const u8, // Error: no default
};
```

### Help Documentation

```zig
// Good: Comprehensive help
const Args = struct {
    pub const help =
        \\Description of what this does
        \\ 
        \\Options:
        \\  --verbose    Enable verbose logging for debugging
        \\  --config     Path to configuration file
    ;
};

// Minimal: Still valid
const Args = struct {
    pub const help =
        \\Options:
        \\  --verbose    Verbose mode
    ;
};
```

### Subcommand Structure

```zig
// Good: Clear separation of concerns
const CLI = union(enum) {
    // Server commands
    start: ServerArgs,
    stop: StopArgs,
    restart: RestartArgs,
    
    // Client commands  
    query: QueryArgs,
    status,
    
    pub const help = "Database CLI";
};
```

## Performance

### Compile-Time Evaluation

Most parsing logic is evaluated at compile time:

- Field name validation: comptime
- Type checking: comptime
- Help generation: comptime
- Only value parsing: runtime

### Memory Usage

- No allocations for primitive types
- One allocation per string flag
- No global state
- Stack-allocated where possible

### Benchmarks

Expected performance:
- 1000 flags parsed: < 1ms
- Memory overhead: ~0 (comptime evaluation)
- Binary size increase: < 10KB

## Planned Enhancements

### 1. Struct-based Help (Future)

Type-safe help with per-field documentation using anonymous struct literals:

```zig
const Args = struct {
    verbose: bool = false,
    port: u16 = 8080,
    
    pub const help = .{
        .verbose = "Enable verbose output",
        .port = "Port to listen on",
    };
};
```

Benefits:
- Compile-time validation of help field names
- Automatic alignment with struct fields
- Refactoring-safe documentation

### 2. Auto-generated Flag List

Automatic flag documentation generation from struct fields:

```zig
const Args = struct {
    verbose: bool = false,
    port: u16 = 8080,
    
    // Automatically generates:
    // --verbose    bool    default: false
    // --port       u16     default: 8080
    pub const auto_help = true;
};
```

### 3. Structured Examples

Type-safe examples and exit codes as part of help configuration:

```zig
const Args = struct {
    pub const help = .{
        .description = "My application",
        
        .flags = .{
            .verbose = "Enable verbose output",
        },
        
        .examples = &[_][]const u8{
            "myapp --verbose",
            "myapp --help",
        },
        
        .exit_codes = .{
            .{ 0, "Success" },
            .{ 1, "Invalid arguments" },
        },
    };
};
```
