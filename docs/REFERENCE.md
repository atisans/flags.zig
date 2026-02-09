# flags.zig Reference: Design Decisions and Comparisons

**Purpose**: This document explains flags.zig design decisions and compares it with industry-standard CLI parsers.

---

## 1. Feature Comparison Table

| Feature | Go flag | Rust clap | Python argparse | flags.zig | Notes |
|---------|---------|-----------|-----------------|-----------|-------|
| **Type System** | | | | | |
| String type | [x] | [x] | [x] | [x] | `[]const u8` |
| Boolean type | [x] | [x] | [x] | [x] | `bool` with true/false |
| Integer types | [x] | [x] | [x] | [x] | `i8`-`i64`, `u8`-`u64` |
| Float types | [x] | [x] | [x] | [x] | `f32`, `f64` |
| Optional types | ~ | [x] | [x] | [x] | `?T` for nullable values |
| Enum types | ~ | [x] | [x] | [x] | Zig enums with validation |
| **API Styles** | | | | | |
| Struct-based | ~ | [x] | ~ | [x] | Define CLI as struct |
| Comptime parsing | ~ | [x] | ~ | [x] | Parse at compile time |
| Builder pattern | ~ | [x] | [x] | ~ | Not implemented |
| **Parsing Options** | | | | | |
| Equals-separated values | [x] | [x] | [x] | [x] | `--name=value` |
| Space-separated values | [x] | [x] | [x] | ~ | Not implemented |
| Short flags | [x] | [x] | [x] | ~ | Not implemented |
| **Arguments** | | | | | |
| Positional arguments | [x] | [x] | [x] | [x] | Via `@"--"` marker |
| Default values | [x] | [x] | [x] | [x] | Struct field defaults |
| **Help System** | | | | | |
| Automatic --help | [x] | [x] | [x] | [x] | With `pub const help` |
| **Subcommands** | | | | | |
| Subcommand support | [x] | [x] | [x] | [x] | `union(enum)` |
| Nested subcommands | [x] | [x] | [x] | [x] | Nested unions |
| **Error Handling** | | | | | |
| Compile-time errors | ~ | [x] | ~ | [x] | Type checking at comptime |
| Runtime error types | [x] | [x] | [x] | [x] | `DuplicateFlag`, `InvalidValue`, etc. |

---

## 2. Design Philosophy: Why Struct-Based Parsing?

### 2.1 The Problem with Traditional Approaches

**Go's flag package** (procedural, runtime):
```go
name := flag.String("name", "default", "usage")
flag.Parse()
// name is *string, requires dereferencing
```
- Runtime registration
- Global state
- Pointer returns
- No compile-time validation

**Rust's clap** (declarative, macros):
```rust
#[derive(Parser)]
struct Cli {
    #[arg(short, long)]
    name: String,
}
```
- Requires derive macros
- Complex for simple cases
- Runtime overhead

**Python's argparse** (builder pattern):
```python
parser = argparse.ArgumentParser()
parser.add_argument('--name', default='default')
args = parser.parse_args()
```
- Verbose boilerplate
- Runtime type checking
- No IDE support

### 2.2 The flags.zig Solution

**Zig's comptime struct parsing**:
```zig
const Args = struct {
    name: []const u8 = "default",
    port: u16 = 8080,
};

const parsed = try flags.parse(args, Args);
// parsed.name is directly accessible, type-safe
```

**Advantages:**
- [x] Zero runtime overhead (comptime parsing)
- [x] Full type safety (compile-time validation)
- [x] No global state
- [x] IDE autocompletion
- [x] Simple API (one function)
- [x] Composable (nested structs/unions)

---

## 3. Comparison by Use Case

### 3.1 Simple CLI Tool

**Go:**
```go
package main
import "flag"

func main() {
    name := flag.String("name", "world", "Name to greet")
    flag.Parse()
    fmt.Printf("Hello, %s!\n", *name)
}
```

**flags.zig:**
```zig
const std = @import("std");
const flags = @import("flags");

pub fn main() !void {
    const args = try std.process.argsAlloc(std.heap.page_allocator);
    defer std.process.argsFree(std.heap.page_allocator, args);
    
    const Args = struct {
        name: []const u8 = "world",
    };
    
    const parsed = try flags.parse(args, Args);
    std.debug.print("Hello, {s}!\n", .{parsed.name});
}
```

**Comparison:**
- Both are simple for basic cases
- Zig has no global state
- Zig validates at compile time

### 3.2 Subcommands

**Go:**
```go
addCmd := flag.NewFlagSet("add", flag.ExitOnError)
name := addCmd.String("name", "", "Name")
addCmd.Parse(os.Args[2:])
```

**flags.zig:**
```zig
const CLI = union(enum) {
    add: struct {
        name: []const u8,
    },
    remove: struct {
        force: bool = false,
    },
};

const cli = try flags.parse(args, CLI);
switch (cli) {
    .add => |a| handleAdd(a.name),
    .remove => |r| handleRemove(r.force),
}
```

**Comparison:**
- Go uses FlagSet with manual dispatch
- Zig uses union(enum) with exhaustive switch
- Zig's approach is type-safe (missing variant = compile error)

### 3.3 Custom Types (Planned)

**Note:** Custom type support is planned but not yet implemented.

**Proposed API:**
```zig
const Address = struct {
    host: []const u8,
    port: u16,
    
    pub fn parse_flag_value(string: []const u8) !Address {
        const colon = std.mem.indexOfScalar(u8, string, ':') orelse {
            return error.InvalidValue;
        };
        return Address{
            .host = string[0..colon],
            .port = try std.fmt.parseInt(u16, string[colon+1..], 10),
        };
    }
};

const Args = struct {
    address: Address = .{ .host = "localhost", .port = 8080 },
};
```

**Status:** Planned for future release

---

## 4. When to Use flags.zig

### Perfect For

- **Zig projects**: Native integration, zero overhead
- **Type safety**: Compile-time validation
- **Performance**: No runtime parsing overhead
- **Simple CLIs**: Quick to set up with minimal boilerplate
- **Subcommands**: Type-safe dispatch with union(enum)

### Consider Alternatives If

- **Need short flags** (-v, -h): Not currently supported
- **Space-separated values**: Not currently supported
- **Complex validation**: Limited validation framework
- **Shell completion**: Not built-in
- **Cross-language**: Need bindings for other languages

---

## 5. Implementation Details

### 5.1 How Parsing Works

1. **Comptime**: Extract struct fields using `@typeInfo()`
2. **Comptime**: Generate parsing code for each field
3. **Runtime**: Iterate args and match against field names
4. **Runtime**: Parse values using type-specific parsers
5. **Comptime + Runtime**: Fill defaults for missing fields

### 5.2 Type Support

**Fully Supported:**
- All integer types (`u8`-`u64`, `i8`-`i64`)
- Float types (`f32`, `f64`)
- Booleans (`bool`)
- Strings (`[]const u8`)
- Optional types (`?T`)
- Enums
- Custom types with `parse_flag_value` (planned)

**Not Supported:**
- Slices (arrays of values)
- Nested structs (except for subcommands)
- Unions (except for subcommands)

### 5.3 Error Handling

All errors are returned (not panics):
```zig
pub const Error = error{
    DuplicateFlag,      // --port=8080 --port=9090
    InvalidArgument,    // No args provided
    InvalidValue,       // --port=not_a_number
    MissingRequiredFlag, // Required field with no default
    MissingRequiredPositional,
    MissingSubcommand,  // No subcommand for union
    MissingValue,       // --name (no value)
    UnknownFlag,        // --unknown-flag
    UnknownSubcommand,  // prog unknown-cmd
    UnexpectedArgument, // Extra positional arg
};
```

---

## 6. Future Directions

### Planned Features
- Short flag names (-v for --verbose)
- Space-separated values (-name value)
- Validation framework (ranges, choices)
- Shell completion generation
- Environment variable binding

### Explicitly NOT Planned
- FlagSet/FlagSet-based API (use struct/union instead)
- Pointer returns (values are simpler and safer)
- ErrorHandling enum (try/catch is idiomatic Zig)
- Builder pattern (structs are sufficient)

---

## 7. Testing

Run tests:
```bash
zig build test
```

Current test coverage: 23 tests covering:
- All primitive types
- Optional types
- Enums
- Subcommands (including nested)
- Error cases
- Help generation

---

## 8. Credits

### TigerBeetle
The struct-based flag parsing approach and union(enum) subcommands are heavily inspired by [TigerBeetle's flags implementation](https://github.com/tigerbeetle/tigerbeetle). Their demonstration of type-safe, performant CLI parsing in Zig showed the power of leveraging comptime.

### Rust clap
The excellent error messages and developer experience patterns from [Rust's clap crate](https://github.com/clap-rs/clap) informed the design philosophy, though the implementation differs significantly.

### Go flag
While the API differs, Go's philosophy of simplicity and clarity influenced the decision to avoid complex builder patterns and macros.
