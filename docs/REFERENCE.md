# flags.zig Reference: Comparison with Go, Rust, and Python CLI Tools

**Purpose**: This document explains flags.zig design decisions by comparing it with industry-standard CLI parsers.

---

## 1. Feature Comparison Table

### Legend
- [x] Implemented (current codebase)
- [P1] Phase 1 (MVP - critical, 50-60 hours)
- [P2] Phase 2 (Common - important, 50-70 hours)
- [P3] Phase 3 (Polish - nice-to-have, 30-40 hours)
- [P4] Phase 4 (Ecosystem - future, 20-30 hours)
- ~ Not implementing (see workarounds)

| Feature | Go flag | Rust clap | Python argparse | flags.zig Phase | Notes |
|---------|---------|-----------|-----------------|-----------------|-------|
| **Type System** | | | | | |
| String type | [x] | [x] | [x] | [x] Implemented |  |
| Boolean type | [x] | [x] | [x] | [x] Implemented |  |
| Integer type (i32) | [x] | [x] | [x] | [x] Implemented |  |
| Float type | [x] | [x] | [x] | [P1] Phase 1 | Critical blocker |
| Unsigned int | [x] | [x] | [x] | [P1] Phase 1 | Critical blocker |
| Duration type | [x] | [x] | [x] | [P1] Phase 1 | Critical blocker |
| Custom types (Value interface) | [x] | [x] | [x] | [P2] Phase 2 | Advanced feature |
| **API Styles** | | | | | |
| Pointer returns (*T) | [x] | N/A | N/A | [P1] Phase 1 | Go-compatible API |
| Variable binding (Var functions) | [x] | N/A | N/A | [P1] Phase 1 | Go pattern |
| Builder pattern (method chaining) | ~ | [x] | ~ | [P2] Phase 2 | Clap inspiration |
| **Parsing Options** | | | | | |
| Equals-separated values (-name=value) | [x] | [x] | [x] | [x] Implemented | Current style |
| Argument passing via parse() | [x] | N/A | N/A | [x] Implemented | New pattern |
| Space-separated values (-name value) | [x] | [x] | [x] | [P2] Phase 2 | Common pattern |
| Short flags (-n value) | [x] | [x] | [x] | [P2] Phase 2 | POSIX standard |
| Combined short flags (-aux) | [x] | [x] | ~ | [P2] Phase 2 | Advanced parsing |
| Flag aliases (-v, --verbose) | [x] | [x] | [x] | [P3] Phase 3 | Nice-to-have |
| **Arguments & Values** | | | | | |
| Positional arguments | [x] | [x] | [x] | [P1] Phase 1 | Args, Arg, NArg |
| Multiple values per flag (append) | [x] | [x] | [x] | [P2] Phase 2 | Action type |
| Count action (-vvv) | [x] | [x] | [x] | [P2] Phase 2 | Action type |
| Default values | [x] | [x] | [x] | [x] Implemented | Basic feature |
| **Validation & Constraints** | | | | | |
| Range validation (min/max) | ~ | [x] | [x] | [P2] Phase 2 | Value validation |
| Choice validation | ~ | [x] | [x] | [P2] Phase 2 | Limited options |
| Custom validators | ~ | [x] | [x] | [P2] Phase 2 | User functions |
| Required flags | ~ | [x] | [x] | [P2] Phase 2 | Validation |
| Mutually exclusive groups | ~ | [x] | [x] | ~ Phase 3 | See workaround |
| **Help System** | | | | | |
| Automatic -h flag | [x] | [x] | [x] | [P1] Phase 1 | Critical UX |
| Automatic --help flag | [x] | [x] | [x] | [P1] Phase 1 | Critical UX |
| PrintDefaults/Usage | [x] | [x] | [x] | [P1] Phase 1 | Help output |
| Custom help templates | ~ | [x] | [x] | [P3] Phase 3 | Advanced UX |
| Value display names (metavar) | ~ | [x] | [x] | [P3] Phase 3 | Help clarity |
| Help grouping | ~ | [x] | [x] | [P3] Phase 3 | Organize output |
| **Subcommands & Structure** | | | | | |
| FlagSet (subcommands) | [x] | [x] | [x] | [P1] Phase 1 | Multi-command tools |
| Nested subcommands | [x] | [x] | [x] | [P2] Phase 2 | Complex hierarchies |
| Independent flag namespaces | [x] | [x] | [x] | [P1] Phase 1 | Per-command flags |
| Automatic subcommand routing | ~ | [x] | [x] | [P2] Phase 2 | Auto-dispatch |
| **Error Handling** | | | | | |
| ErrorHandling enum (ExitOnError, etc.) | [x] | ~ | ~ | [P1] Phase 1 | Go-specific pattern |
| ContinueOnError strategy | [x] | ~ | ~ | [P1] Phase 1 | Error collection |
| Custom error handlers | [x] | ~ | ~ | [P2] Phase 2 | User callbacks |
| ErrHelp error type | [x] | ~ | ~ | [P1] Phase 1 | Help request detection |
| **Callbacks & Functions** | | | | | |
| Func (callback on parse) | [x] | ~ | ~ | ~ Phase 3 | See workaround |
| BoolFunc (special bool handling) | [x] | ~ | ~ | ~ Phase 3 | See workaround |
| Post-parse validation hooks | ~ | ~ | ~ | ~ Phase 3 | User manual |
| **Advanced Features** | | | | | |
| Environment variable binding | ~ | [x] | [x] | [P4] Phase 4 | Config integration |
| Config file support (JSON/YAML) | ~ | [x] | [x] | [P4] Phase 4 | Config integration |
| Shell completion generation | [x] | [x] | [x] | [P4] Phase 4 | bash/zsh/fish |
| Version flag auto-generation | ~ | [x] | [x] | [P4] Phase 4 | Convenience |
| Typo suggestions | ~ | [x] | ~ | [P4] Phase 4 | UX polish |
| **ADVANCED (Phase 3+) Features** | | | | | |
| Duration parsing | [x] | [x] | [x] | ~ ADVANCED | See workaround |
| BoolFunc/Func callbacks | [x] | ~ | ~ | ~ ADVANCED | See workaround |
| Mutually exclusive groups | [x] | [x] | [x] | ~ ADVANCED | See workaround |
| Intermixed parsing | [x] | [x] | ~ | ~ Uncommon | POSIX standard |

---

## 2. Go's `flag` Package: Why We're Using This Approach

### 2.1 Design Decision: Go Over Rust/Python

**We chose Go's `flag` package as our primary inspiration because:**

1. **Simplicity First**: Go's flag is minimal but complete. It fits Zig's philosophy of "do one thing well"
2. **Procedural API**: Go uses simple functions, not decorators or derive macros—perfect match for Zig
3. **Pointer Returns**: Go's design (`*T` returns) enables storing flag pointers before parsing—crucial pattern in systems languages
4. **Type-Safe**: Each type has dedicated functions (Int, Float, Uint, Duration), not generic converters
5. **Error Control**: ErrorHandling enum gives explicit control over failure modes
6. **FlagSet Pattern**: Clean subcommand/namespace design that maps naturally to Zig

### 2.2 Core API Functions We're Implementing

```zig
// Type Functions - Returning Pointers
pub fn String(name: []const u8, default: []const u8, usage: []const u8) *[]const u8
pub fn Bool(name: []const u8, default: bool, usage: []const u8) *bool
pub fn Int(name: []const u8, default: i32, usage: []const u8) *i32
pub fn Float64(name: []const u8, default: f64, usage: []const u8) *f64
pub fn Uint(name: []const u8, default: u32, usage: []const u8) *u32
pub fn Duration(name: []const u8, default: u64, usage: []const u8) *u64

// Variable Binding - Pointer to Existing Variable
pub fn StringVar(p: *[]const u8, name: []const u8, default: []const u8, usage: []const u8)
pub fn BoolVar(p: *bool, name: []const u8, default: bool, usage: []const u8)
pub fn IntVar(p: *i32, name: []const u8, default: i32, usage: []const u8)
pub fn Float64Var(p: *f64, name: []const u8, default: f64, usage: []const u8)

// Parsing & Arguments
pub fn Parse() !void
pub fn Parsed() bool
pub fn Args() [][]const u8        // Remaining arguments after flags
pub fn Arg(i: usize) ?[]const u8 // Get i-th argument
pub fn NArg() usize               // Count of arguments

// Help & Usage
pub fn PrintDefaults() void
pub fn SetOutput(writer: std.io.AnyWriter) void
pub const Usage: ?*const fn() void = null;  // Customizable

// Error Handling
pub const ErrorHandling = enum {
    ContinueOnError,  // Return error, collect mistakes
    ExitOnError,      // Exit immediately on error
    PanicOnError,     // Panic on error
};

// FlagSet for Subcommands
pub fn NewFlagSet(name: []const u8, errorHandling: ErrorHandling) !*FlagSet
```

### 2.3 Why Go Over Alternatives

#### vs Rust clap
```rust
// Rust clap: Derive macros not feasible in Zig
#[derive(Parser)]
struct Cli {
    #[arg(short)]
    verbose: bool,  // Requires macros
}

// Rust clap: Builder pattern too verbose for simple cases
Command::new("app")
    .arg(Arg::new("name").short('n').long("name"))
    .get_matches()

// Go flag: Simple and clear
namePtr := flag.String("name", "default", "usage")
flag.Parse()
```

**Lesson**: Go's imperative functions are more Zig-idiomatic than Rust's declarative approach. We'll add builder pattern later (Phase 2) as optional.

#### vs Python argparse
```python
# Python: Type conversion separate from definition (confusing)
parser.add_argument('--count', type=int, default=1)

# Python: Subparsers less intuitive than Go's FlagSet
subparsers = parser.add_subparsers()
add = subparsers.add_parser('add')

# Go: Type in function name, explicit
countPtr := flag.Int("count", 1, "usage")
addFs := flag.NewFlagSet("add", flag.ExitOnError)
```

**Lesson**: Go's explicit typing and clear error handling model beats Python's implicit type coercion.

### 2.4 Example: Go vs flags.zig

#### Go Example
```go
package main
import (
    "flag"
    "fmt"
)

func main() {
    // Define pointers to flags
    name := flag.String("name", "world", "name to greet")
    count := flag.Int("count", 1, "repetitions")
    verbose := flag.Bool("verbose", false, "verbose output")
    
    flag.Parse()  // Parse command line
    
    // Use pointers
    for i := 0; i < *count; i++ {
        fmt.Printf("Hello %s\n", *name)
        if *verbose {
            fmt.Println("Greeting sent")
        }
    }
    
    // Get remaining args
    files := flag.Args()
    for _, f := range files {
        fmt.Println("File:", f)
    }
}
```

#### flags.zig Equivalent (Phase 1 Target)
```zig
const std = @import("std");
const flag = @import("flags");

pub fn main() !void {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();
    const alloc = gpa.allocator();

    // Define pointers to flags
    const namePtr = flag.String("name", "world", "name to greet");
    const countPtr = flag.Int("count", 1, "repetitions");
    const verbosePtr = flag.Bool("verbose", false, "verbose output");
    
    try flag.Parse();  // Parse command line
    
    // Use pointers
    for (0..@intCast(countPtr.*)) |_| {
        std.debug.print("Hello {s}\n", .{namePtr.*});
        if (verbosePtr.*) {
            std.debug.print("Greeting sent\n", .{});
        }
    }
    
    // Get remaining args
    const args = flag.Args();
    for (args) |f| {
        std.debug.print("File: {s}\n", .{f});
    }
}
```

---

## 3. Python's argparse: Why NOT This Approach

### 3.1 Core Differences

#### Problem 1: Type Conversion Separated from Definition
```python
# Python: Type is separate, leads to errors
parser.add_argument('--count', type=int, default=1)
# What if you forget type? Becomes string, breaks silently later

# Go: Type in function name
countPtr := flag.Int("count", 1, "usage")  // Can't forget type
```

**For Zig**: Type safety is paramount. Function names encode types.

#### Problem 2: Subparsers Less Intuitive
```python
# Python: Cryptic subparsers API
subparsers = parser.add_subparsers(dest='command')
add_parser = subparsers.add_parser('add', help='add files')
add_parser.add_argument('files', nargs='+')

# Go: Clear FlagSet ownership
addFs := flag.NewFlagSet("add", flag.ExitOnError)
addFs.String("message", "", "commit message")
```

#### Problem 3: nargs Magic
```python
# Python: Too many magic values
parser.add_argument('files', nargs='+')   # 1+
parser.add_argument('files', nargs='*')   # 0+
parser.add_argument('files', nargs='?')   # 0-1

# Go/Zig: Explicit
flagSet.Args()  // All remaining arguments (simple)
```

#### Problem 4: Procedural Nature Breaks Type Safety
```python
# Python: Can't define flags before parsing
# Must use argparse.ArgumentParser, add_argument in sequence

# Go/Zig: Define pointers up front
namePtr := flag.String("name", "world", "usage")
agePtr := flag.Int("age", 25, "usage")
flag.Parse()  // Now pointers are valid
```

### 3.2 What argparse Does Well (We'll Borrow)

| Feature | How We Use It |
|---------|---------------|
| `nargs` (multiple values) | Implement as Phase 2 Append action |
| `choices` validation | Implement as Phase 2 constraint |
| `required=True` | Implement as Phase 2 flag property |
| Subparsers | Already have FlagSet from Go |
| Type conversion | Explicit function names (Int, Float) |
| `metavar` (display names) | Phase 3: nice-to-have |

---

## 4. Rust's clap: Why NOT This Approach (Directly)

### 4.1 Core Differences

#### Problem 1: Derive Macros Not Feasible in Zig
```rust
// Rust clap: Uses derive macros (Zig has no macro system)
#[derive(Parser)]
struct Cli {
    #[arg(short, long)]
    name: String,
    
    #[arg(short, long)]
    count: u32,
}

// Zig: Can't do this. Need imperative code
```

**For Zig**: Build.zig code generation possible, but complex for Phase 1.

#### Problem 2: Builder Pattern Too Verbose for Simple Cases
```rust
// Rust clap: Fluent builder (elegant but verbose)
Command::new("myapp")
    .version("1.0.0")
    .about("My awesome app")
    .arg(Arg::new("name")
        .short('n')
        .long("name")
        .value_name("NAME")
        .help("Person to greet")
        .required(false)
        .default_value("world"))
    .arg(Arg::new("count")
        .short('c')
        .long("count")
        .value_parser(value_parser!(u32))
        .help("Repetitions")
        .default_value("1"))
    .get_matches();

// Go flag: Simple imperative
namePtr := flag.String("name", "world", "person to greet")
countPtr := flag.Int("count", 1, "repetitions")
flag.Parse()
```

#### Problem 3: Type Validation Too Complex
```rust
// Rust clap: Generic value_parser system
.arg(Arg::new("port")
    .value_parser(value_parser!(u16).range(1..=65535))
    .help("Port number"))

// Go flag: String, then manual validation or custom type
portPtr := flag.Int("port", 8080, "port number")
flag.Parse()
if *portPtr < 1 || *portPtr > 65535 {
    log.Fatal("invalid port")
}
```

### 4.2 What clap Does Well (We'll Borrow)

| Feature | Phase | How We Use It |
|---------|-------|---------------|
| Builder pattern | Phase 2+ | Optional fluent API |
| Action types (Count, Append) | Phase 2 | Implement as enum |
| Validation (ranges, choices) | Phase 2 | Constraint system |
| Subcommand handling | Phase 2 | Automatic routing |
| Mutually exclusive groups | Phase 3 | See workaround |
| Help customization | Phase 3 | Templates |

---

## 5. Features NOT Implementing (With Workarounds)

### 5.1 Duration Type (Phase 3 ADVANCED)

**Why Not Direct Duration Support**:
- Duration is complex: "5s", "10ms", "1h30m" → parse & convert
- Go supports it because it has `time.Duration` type (u64 nanoseconds)
- Zig: Would need custom string parser for each unit

**Workaround: Custom Type**
```zig
// Define custom Duration type
const Duration = struct {
    nanos: u64,
    
    pub fn fromString(str: []const u8) !Duration {
        // Parse "5s", "10ms", etc.
    }
    
    pub fn set(self: *Duration, str: []const u8) !void {
        self.* = try fromString(str);
    }
    
    pub fn string(self: Duration) []const u8 {
        // Convert back to string
    }
};

// Use with custom Value interface (Phase 2)
var timeout: Duration = .{ .nanos = 5_000_000_000 };
try flags.Var(&timeout, "timeout", "request timeout");
```

**Real-World Example**:
```zig
// Instead of flag.Duration()
var timeout: u64 = 5 * std.time.ns_per_s;  // 5 seconds in nanoseconds
try flags.Int64Var(&timeout, "timeout", ..);
// User provides: -timeout 5000000000 (nanoseconds)

// OR use custom type for ergonomics
const duration = try parseDuration("5s");  // Helper function
```

### 5.2 BoolFunc/Func Callbacks (Phase 3 ADVANCED)

**Why Not Implement**:
- Callbacks during parsing add complexity
- Not POSIX standard
- Breaks error handling guarantees
- Hard to compose multiple callbacks

**Workaround: Post-Parse Validation**
```zig
// Go: Func callback
flag.Func("output", "output format", func(s string) error {
    if s != "json" && s != "yaml" {
        return errors.New("invalid format")
    }
    return nil
})

// Zig: Manual validation after parse
const output = flagSet.String("output", "json", "output format");
try flagSet.Parse(args);

if (!std.mem.eql(u8, output.*, "json") and 
    !std.mem.eql(u8, output.*, "yaml")) {
    return error.InvalidFormat;
}
```

**Better Pattern: Custom Type**
```zig
const Format = enum {
    json,
    yaml,
    
    pub fn set(self: *Format, str: []const u8) !void {
        if (std.mem.eql(u8, str, "json")) {
            self.* = .json;
        } else if (std.mem.eql(u8, str, "yaml")) {
            self.* = .yaml;
        } else {
            return error.InvalidFormat;
        }
    }
    
    pub fn string(self: Format) []const u8 {
        return switch (self) {
            .json => "json",
            .yaml => "yaml",
        };
    }
};

var format: Format = .json;
try flags.Var(&format, "output", "output format");
// Validation happens automatically in set()
```

### 5.3 Mutually Exclusive Groups (Phase 3 ADVANCED)

**Why Not Implement**:
- Rare in actual CLI tools
- Adds significant complexity
- Easy to implement in user code

**Workaround: Post-Parse Validation**
```zig
// Go: Mutually exclusive
group := parser.add_mutually_exclusive_group()
group.add_argument('--json')
group.add_argument('--yaml')

// Zig: Manual check
const json_ptr = flags.Bool("json", false, "output as JSON");
const yaml_ptr = flags.Bool("yaml", false, "output as YAML");
try flags.Parse();

if (json_ptr.* and yaml_ptr.*) {
    return error.ConflictingOptions;  // "Can't use both --json and --yaml"
}
```

**Or: Use Enum Pattern** (Cleaner)
```zig
const OutputFormat = enum {
    json,
    yaml,
    text,
};

var output_format: OutputFormat = .json;

// Only ONE flag needed
const format_str = flags.String("output", "json", "output format (json|yaml|text)");
try flags.Parse();

output_format = std.meta.stringToEnum(OutputFormat, format_str.*) 
    orelse return error.InvalidFormat;
```

### 5.4 Intermixed Parsing (Uncommon, POSIX Standard)

**Why Not Implement**:
- Violates POSIX standard argument parsing
- GNU extension, not portable
- Adds parser complexity
- Rare actual use case

**What It Does**: Allow flags after positional args
```bash
# Standard (POSIX)
$ program -v file.txt  # -v is flag
$ program file.txt -v  # -v is positional arg

# Intermixed (GNU extension)
$ program file.txt -v  # Both work the same
```

**Workaround: Document POSIX Order**
```zig
// flags.zig follows POSIX standard:
// All flags BEFORE positional arguments
// $ program -verbose -name alice file1.txt file2.txt
//            ^^^^^^  ^^^^^^^^^^^ flags
//                                 ^^^^^^^^^^^^^^^^^^^^ positional args

// This allows simple parsing: stop at first non-flag arg
```

---

## 6. Implementation Roadmap by Phase

### Phase 1 (MVP) - 50-60 hours
**Critical blockers**: Without these, library is unusable

```zig
// Type Functions
pub fn Int(name: []const u8, default: i32, usage: []const u8) *i32
pub fn IntVar(p: *i32, name: []const u8, default: i32, usage: []const u8)
pub fn Int64(name: []const u8, default: i64, usage: []const u8) *i64
pub fn Int64Var(p: *i64, name: []const u8, default: i64, usage: []const u8)
pub fn Uint(name: []const u8, default: u32, usage: []const u8) *u32
pub fn UintVar(p: *u32, name: []const u8, default: u32, usage: []const u8)
pub fn Uint64(name: []const u8, default: u64, usage: []const u8) *u64
pub fn Uint64Var(p: *u64, name: []const u8, default: u64, usage: []const u8)
pub fn Float64(name: []const u8, default: f64, usage: []const u8) *f64
pub fn Float64Var(p: *f64, name: []const u8, default: f64, usage: []const u8)
pub fn Duration(name: []const u8, default: u64, usage: []const u8) *u64
pub fn DurationVar(p: *u64, name: []const u8, default: u64, usage: []const u8)

// Fix existing functions to return pointers
pub fn Bool(name: []const u8, default: bool, usage: []const u8) *bool
pub fn BoolVar(p: *bool, name: []const u8, default: bool, usage: []const u8)
pub fn String(name: []const u8, default: []const u8, usage: []const u8) *[]const u8
pub fn StringVar(p: *[]const u8, name: []const u8, default: []const u8, usage: []const u8)

// Positional Arguments
pub fn Args() [][]const u8
pub fn Arg(i: usize) ?[]const u8
pub fn NArg() usize

// Help System
pub fn PrintDefaults() void
pub fn SetOutput(writer: std.io.AnyWriter) void
pub const Usage: ?*const fn() void = null;

// FlagSet for Subcommands
pub fn NewFlagSet(name: []const u8, errorHandling: ErrorHandling) !*FlagSet
pub const ErrorHandling = enum { ContinueOnError, ExitOnError, PanicOnError };

// Parsing
pub fn Parse() !void
pub fn Parsed() bool
pub const ErrHelp = error.HelpRequested;
```

### Phase 2 (Common) - 50-70 hours
```zig
// Space-separated values (-name value, not just -name=value)
// Short flags (-n for --name)
// Combined short flags (-aux for -a -u -x)

// Action types
pub const Action = enum { Set, Append, Count };

// Validation
pub fn (flag: *Flag) choices(values: []const []const u8) !void
pub fn (flag: *Flag) min(value: i64) !void
pub fn (flag: *Flag) max(value: i64) !void
pub fn (flag: *Flag) required(val: bool) !void

// Custom types
pub const Value = interface {
    set(str: []const u8) !void,
    get() []const u8,
    string() []const u8,
};
pub fn Var(value: *anytype, name: []const u8, usage: []const u8) !void
```

### Phase 3 (Polish) - 30-40 hours
```zig
// Builder pattern (method chaining)
// Flag aliases
// Mutually exclusive groups
// Custom help templates
// Metavar (display names)
// Value hints for shell completion
```

### Phase 4 (Ecosystem) - 20-30 hours
```zig
// Environment variable binding
// Config file support (JSON/YAML)
// Shell completion generation
// Automatic version flag
```

---

## 7. Testing Against Go stdlib (Verification Strategy)

### 7.1 Comparison Tool: parser_comparison.zig

Located at `/home/sparrow/Desktop/flags.zig/parser_comparison.zig`

Tests feature parity:
```zig
// Compare Go vs Zig behavior for same CLI

// Test 1: Basic parsing
// Go:  name := flag.String("name", "world", "...")
// Zig: const namePtr = flags.String("name", "world", "...")

// Test 2: Integer parsing
// Go:  port := flag.Int("port", 8080, "...")
// Zig: const portPtr = flags.Int("port", 8080, "...")

// Test 3: Positional arguments
// Go:  files := flag.Args()
// Zig: const files = flags.Args()
```

### 7.2 Test Cases by Feature

| Feature | Go Command | flags.zig Equivalent | Status |
|---------|-----------|----------------------|--------|
| String flag | `go run main.go -name=alice` | `zig build run -- -name=alice` | [x] |
| Boolean flag | `go run main.go -verbose` | `zig build run -- -verbose` | [x] |
| Integer flag | `go run main.go -port=8080` | `zig build run -- -port=8080` | [x] |
| Space-separated | `go run main.go -name alice` | `zig build run -- -name alice` | [P2] TODO |
| Positional args | `go run main.go file1 file2` | `zig build run -- file1 file2` | [P2] TODO |
| Help flag | `go run main.go -h` | `zig build run -- -h` | [P2] TODO |

### 7.3 Verification Checklist

```bash
# Phase 1 Verification (Current)
[x] String type implemented
[x] Boolean type implemented
[x] Integer type (i32) implemented
[x] parse() accepts args slice
[x] Basic -name=value parsing works
[x] Unit tests for parsing working
[ ] Float, Uint, Duration types - TODO
[ ] pointer returns match Go (*T pattern) - TODO
[ ] Var functions work identically - TODO
[ ] Args/Arg/NArg behavior identical - TODO
[ ] Help generation matches - TODO
[ ] FlagSet independent namespaces work - TODO
[ ] ErrorHandling enum modes correct - TODO
[ ] Parse error handling matches - TODO

# Phase 2 Verification (Planned)
[ ] Space-separated values (-name value)
[ ] Short flags (-n value)
[ ] Combined short flags (-nxvf value)
[ ] Action types (Append, Count) work
[ ] Validation (min, max, choices) enforced
[ ] Custom types (Value interface) work

# Phase 3+ Verification (Planned)
[ ] Builder pattern produces same results
[ ] Aliases work
[ ] Mutually exclusive groups validated
[ ] Help templates match expectations
```

---

## 8. Quick Reference: API Comparison

### Go Example
```go
package main
import "flag"

func main() {
    name := flag.String("name", "world", "name")
    count := flag.Int("count", 1, "repetitions")
    flag.Parse()
    
    for i := 0; i < *count; i++ {
        fmt.Println(*name)
    }
}
```

### flags.zig Equivalent (Phase 1 Target)
```zig
const flags = @import("flags");

pub fn main() !void {
    const namePtr = flags.String("name", "world", "name");
    const countPtr = flags.Int("count", 1, "repetitions");
    try flags.Parse();
    
    var i: i32 = 0;
    while (i < countPtr.*) : (i += 1) {
        std.debug.print("{s}\n", .{namePtr.*});
    }
}
```

### Design Principles

| Principle | Reason | Example |
|-----------|--------|---------|
| Type in function name | Type safety | `Int()` not `parse("int")` |
| Pointers, not values | Define before parse | `namePtr := flag.String()` then `parse()` |
| ErrorHandling enum | Explicit error modes | ExitOnError vs ContinueOnError |
| FlagSet for namespaces | Clean subcommands | Each command has own flags |
| POSIX compliance | Standard behavior | Flags before positional args |

---

## Summary

flags.zig is **inspired by Go's `flag` package** because:

1. ✅ Go's approach is **procedural** (fits Zig)
2. ✅ Go's **pointer returns** enable store-before-parse pattern
3. ✅ Go's **type-safe API** (function names encode types)
4. ✅ Go's **error control** (ErrorHandling enum)
5. ✅ Go's **FlagSet** pattern for subcommands

We're **borrowing key ideas** from Rust (clap) and Python (argparse) for:
- Action types (Append, Count)
- Validation systems
- Builder patterns
- Custom types interface

We're **not implementing** (with workarounds):
- Duration parsing → Custom type
- Callbacks (Func/BoolFunc) → Post-parse validation
- Mutually exclusive groups → Manual validation
- Intermixed parsing → Follow POSIX standard

See `MISSING_FEATURES.md` for detailed gaps, and `PROJECT_STATUS.md` for implementation roadmap.
