# Code Patterns for flags.zig

Complete, runnable patterns organized by feature maturity level. Each pattern demonstrates a real-world use case and can be compiled and executed immediately.

## Overview

- **Phase 1 (Foundation)**: Core flag types and basic parsing (6 patterns)
- **Phase 2 (Common)**: Advanced binding and subcommands (4 patterns)
- **Phase 3 (Advanced)**: Complex scenarios and validation (2 patterns)

---

## Phase 1: Foundation Patterns

### Pattern 1: Basic Boolean Flags

**Problem**: Simple on/off configuration for CLI tools (verbosity, debug mode, etc.)

**Code**:
```zig
const std = @import("std");
const flags = @import("flags");

pub fn main() !void {
    // Parse command line arguments
    _ = try flags.parse();

    // Define boolean flags
    const verbose = flags.boolean("verbose", false, "Enable verbose output");
    const debug = flags.boolean("debug", false, "Enable debug mode");

    // Use the values
    std.debug.print("Verbose: {}\n", .{verbose});
    std.debug.print("Debug: {}\n", .{debug});
}
```

**Usage**:
```bash
# No flags (use defaults)
$ zig build run
# Output:
# Verbose: false
# Debug: false

# With boolean flags
$ zig build run -- -verbose -debug
# Output:
# Verbose: true
# Debug: true

# Only one flag
$ zig build run -- -verbose
# Output:
# Verbose: true
# Debug: false
```

**Notes**: 
- Phase 1 pattern: Covers basic boolean flag parsing
- Works with current implementation
- Foundation for more complex patterns
- Use case: CLI tools with simple feature toggles

---

### Pattern 2: String Flags with Defaults

**Problem**: Capture configuration values (names, paths, URLs) with sensible defaults

**Code**:
```zig
const std = @import("std");
const flags = @import("flags");

pub fn main() !void {
    _ = try flags.parse();

    // Define string flags with defaults
    const name = flags.string("name", "world", "Name to greet");
    const host = flags.string("host", "localhost", "Server host");
    const version = flags.string("version", "1.0.0", "Application version");

    // Use the values
    std.debug.print("Hello, {s}!\n", .{name});
    std.debug.print("Server: {s}\n", .{host});
    std.debug.print("Version: {s}\n", .{version});
}
```

**Usage**:
```bash
# Use defaults
$ zig build run
# Output:
# Hello, world!
# Server: localhost
# Version: 1.0.0

# Override one value
$ zig build run -- -name=alice
# Output:
# Hello, alice!
# Server: localhost
# Version: 1.0.0

# Override multiple values
$ zig build run -- -name=bob -host=example.com -version=2.0.0
# Output:
# Hello, bob!
# Server: example.com
# Version: 2.0.0
```

**Notes**:
- Phase 1 pattern: Core string parsing functionality
- Works with current implementation
- Default values provide good UX
- Use case: Configuration defaults for servers, tools, libraries

---

### Pattern 3: Mixed Flag Types

**Problem**: Combine multiple flag types in a single application

**Code**:
```zig
const std = @import("std");
const flags = @import("flags");

pub fn main() !void {
    _ = try flags.parse();

    // Mix different flag types
    const user = flags.string("user", "guest", "Username for authentication");
    const enable_ssl = flags.boolean("ssl", true, "Enable SSL/TLS");
    const config_path = flags.string("config", "/etc/app.conf", "Path to config file");
    const quiet = flags.boolean("quiet", false, "Suppress output");

    // Process configuration
    std.debug.print("User: {s}\n", .{user});
    std.debug.print("SSL Enabled: {}\n", .{enable_ssl});
    std.debug.print("Config: {s}\n", .{config_path});
    std.debug.print("Quiet: {}\n", .{quiet});

    // Conditional logic based on flags
    if (!quiet) {
        std.debug.print("Configuration loaded successfully.\n", .{});
    }
}
```

**Usage**:
```bash
$ zig build run -- -user=alice -ssl=false -config=/tmp/custom.conf
# Output:
# User: alice
# SSL Enabled: false
# Config: /tmp/custom.conf
# Quiet: false
# Configuration loaded successfully.

$ zig build run -- -user=bob -quiet
# Output:
# User: bob
# SSL Enabled: true
# Config: /etc/app.conf
# Quiet: true
```

**Notes**:
- Phase 1 pattern: Demonstrates real-world flag combinations
- Works with current implementation
- Shows how to use flags for conditional logic
- Use case: Web servers, databases, CLI utilities

---

### Pattern 4: Configuration Structure (Phase 1 Foundation)

**Problem**: Organize related configuration values into a struct for easier management

**Code**:
```zig
const std = @import("std");
const flags = @import("flags");

const ServerConfig = struct {
    host: []const u8,
    port_str: []const u8,
    workers_str: []const u8,
    verbose: bool,
    ssl: bool,
};

pub fn main() !void {
    _ = try flags.parse();

    // Define flags and collect in struct
    var config: ServerConfig = undefined;
    config.host = flags.string("host", "0.0.0.0", "Server host");
    config.port_str = flags.string("port", "8080", "Server port");
    config.workers_str = flags.string("workers", "4", "Worker threads");
    config.verbose = flags.boolean("verbose", false, "Verbose logging");
    config.ssl = flags.boolean("ssl", true, "Enable SSL");

    // Display configuration
    std.debug.print("=== Server Configuration ===\n", .{});
    std.debug.print("Host: {s}\n", .{config.host});
    std.debug.print("Port: {s}\n", .{config.port_str});
    std.debug.print("Workers: {s}\n", .{config.workers_str});
    std.debug.print("Verbose: {}\n", .{config.verbose});
    std.debug.print("SSL: {}\n", .{config.ssl});
}
```

**Usage**:
```bash
$ zig build run -- -host=example.com -port=9000 -workers=8 -verbose
# Output:
# === Server Configuration ===
# Host: example.com
# Port: 9000
# Workers: 8
# Verbose: true
# SSL: true

$ zig build run
# Output:
# === Server Configuration ===
# Host: 0.0.0.0
# Port: 8080
# Workers: 4
# Verbose: false
# SSL: true
```

**Notes**:
- Phase 1 foundation for Phase 2's struct binding
- Works with current implementation
- Organizing flags in structs improves code clarity
- Shows pattern leading to Phase 2's StringVar/IntVar
- Use case: Complex applications with many configuration options

---

### Pattern 5: Help Message Implementation (Manual)

**Problem**: Display usage information and flag descriptions (manual implementation until Phase 1 is complete)

**Code**:
```zig
const std = @import("std");
const flags = @import("flags");

const AppFlags = struct {
    help: bool,
    verbose: bool,
    input: []const u8,
    output: []const u8,
};

pub fn printUsage(program_name: []const u8) void {
    std.debug.print(
        \\Usage: {s} [options] <file>
        \\
        \\Options:
        \\  -help              Show this help message
        \\  -verbose           Enable verbose output
        \\  -input string      Input file path (default: "input.txt")
        \\  -output string     Output file path (default: "output.txt")
        \\
    , .{program_name});
}

pub fn main() !void {
    _ = try flags.parse();

    var app_flags: AppFlags = undefined;
    app_flags.help = flags.boolean("help", false, "Show this help message");
    app_flags.verbose = flags.boolean("verbose", false, "Enable verbose output");
    app_flags.input = flags.string("input", "input.txt", "Input file path");
    app_flags.output = flags.string("output", "output.txt", "Output file path");

    if (app_flags.help) {
        printUsage("myapp");
        return;
    }

    std.debug.print("Processing file: {s}\n", .{app_flags.input});
    std.debug.print("Output to: {s}\n", .{app_flags.output});

    if (app_flags.verbose) {
        std.debug.print("Verbose mode enabled.\n", .{});
    }
}
```

**Usage**:
```bash
$ zig build run -- -help
# Output:
# Usage: myapp [options] <file>
#
# Options:
#   -help              Show this help message
#   -verbose           Enable verbose output
#   -input string      Input file path (default: "input.txt")
#   -output string     Output file path (default: "output.txt")

$ zig build run -- -verbose -input=data.txt
# Output:
# Processing file: data.txt
# Output to: output.txt
# Verbose mode enabled.
```

**Notes**:
- Phase 1 foundation: Manual help until automatic generation is implemented
- Shows where automatic Phase 1 help generation will fit
- Current workaround for missing feature
- Use case: All CLI applications need help text
- Future Phase 1 will make this automatic

---

### Pattern 6: Input Validation with Flags

**Problem**: Validate flag values and provide meaningful error messages

**Code**:
```zig
const std = @import("std");
const flags = @import("flags");

pub fn isValidPort(port_str: []const u8) bool {
    // Simple validation: try to parse as integer in valid range
    if (std.fmt.parseInt(u16, port_str, 10)) |port| {
        return port > 0 and port <= 65535;
    } else |_| {
        return false;
    }
}

pub fn main() !void {
    _ = try flags.parse();

    const host = flags.string("host", "localhost", "Server host");
    const port_str = flags.string("port", "8080", "Server port (1-65535)");
    const max_connections_str = flags.string("max-connections", "100", "Max connections");
    const timeout_str = flags.string("timeout", "30", "Timeout in seconds");

    // Validate port
    if (!isValidPort(port_str)) {
        std.debug.print("Error: Invalid port '{s}'. Must be 1-65535.\n", .{port_str});
        return;
    }

    // Validate max connections
    if (std.fmt.parseInt(u32, max_connections_str, 10)) |_| {
        // Valid
    } else |_| {
        std.debug.print("Error: max-connections must be a positive integer.\n", .{});
        return;
    }

    // Validate timeout
    if (std.fmt.parseInt(u32, timeout_str, 10)) |_| {
        // Valid
    } else |_| {
        std.debug.print("Error: timeout must be a positive integer.\n", .{});
        return;
    }

    std.debug.print("Configuration validated:\n", .{});
    std.debug.print("  Host: {s}\n", .{host});
    std.debug.print("  Port: {s}\n", .{port_str});
    std.debug.print("  Max connections: {s}\n", .{max_connections_str});
    std.debug.print("  Timeout: {s}s\n", .{timeout_str});
}
```

**Usage**:
```bash
$ zig build run -- -host=localhost -port=3000
# Output:
# Configuration validated:
#   Host: localhost
#   Port: 3000
#   Max connections: 100
#   Timeout: 30s

$ zig build run -- -port=99999
# Output:
# Error: Invalid port '99999'. Must be 1-65535.

$ zig build run -- -port=abc
# Output:
# Error: Invalid port 'abc'. Must be 1-65535.
```

**Notes**:
- Phase 1 foundation: Manual validation until Phase 2 adds validation framework
- Shows current approach to error handling
- Demonstrates need for Phase 2 validation features
- Use case: Configuration validation for production systems
- Future improvement: Phase 2 will add built-in validators

---

## Phase 2: Common Patterns

### Pattern 7: Struct-Based Configuration with Variable Binding (Phase 2 - Proposed)

**Problem**: Bind flag values directly to struct fields, avoiding repeated lookups

**Code** (Phase 2 - not yet implemented):
```zig
const std = @import("std");
const flags = @import("flags");

const DatabaseConfig = struct {
    host: []const u8,
    port: u16,
    database: []const u8,
    username: []const u8,
    password: []const u8,
    max_connections: u32,
    timeout_seconds: u32,
};

pub fn main() !void {
    var config: DatabaseConfig = .{
        .host = "localhost",
        .port = 5432,
        .database = "myapp",
        .username = "user",
        .password = "secret",
        .max_connections = 10,
        .timeout_seconds = 30,
    };

    var fs = try flags.newFlagSet("dbconfig", flags.ContinueOnError);
    defer fs.deinit();

    // Phase 2: Var functions bind flags to existing struct fields
    fs.stringVar(&config.host, "host", "localhost", "Database host");
    fs.intVar(&config.port, "port", 5432, "Database port");
    fs.stringVar(&config.database, "db", "myapp", "Database name");
    fs.stringVar(&config.username, "user", "user", "Database user");
    fs.stringVar(&config.password, "pass", "secret", "Database password");
    fs.uintVar(&config.max_connections, "max-conn", 10, "Max connections");
    fs.uintVar(&config.timeout_seconds, "timeout", 30, "Timeout in seconds");

    try fs.parse(std.os.argv[1..]);

    // Config struct automatically updated by flag parsing
    std.debug.print("=== Database Configuration ===\n", .{});
    std.debug.print("Host: {s}:{d}\n", .{config.host, config.port});
    std.debug.print("Database: {s}\n", .{config.database});
    std.debug.print("User: {s}\n", .{config.username});
    std.debug.print("Max connections: {d}\n", .{config.max_connections});
    std.debug.print("Timeout: {d}s\n", .{config.timeout_seconds});
}
```

**Usage** (Phase 2):
```bash
$ myapp -host=db.example.com -port=3306 -db=production -user=admin
# Output:
# === Database Configuration ===
# Host: db.example.com:3306
# Database: production
# User: admin
# Max connections: 10
# Timeout: 30s
```

**Notes**:
- Phase 2 feature: Not yet implemented
- Requires: IntVar, stringVar functions
- Benefits: Type-safe, no string-to-int conversion needed
- Pattern inspired by Go's flag.IntVar, flag.StringVar
- Use case: Complex applications with typed configuration structs
- Advantage over Phase 1: Type safety and automatic conversions

---

### Pattern 8: Custom Value Type Implementation (Phase 2 - Proposed)

**Problem**: Parse custom types (URLs, IPs, Durations) that aren't built-in

**Code** (Phase 2 - not yet implemented):
```zig
const std = @import("std");
const flags = @import("flags");

const Duration = struct {
    milliseconds: u64,

    fn parse(value: []const u8) !Duration {
        // Support formats: "100ms", "5s", "2m"
        var multiplier: u64 = 1;
        var num_str = value;

        if (std.mem.endsWith(u8, value, "ms")) {
            multiplier = 1;
            num_str = value[0..value.len-2];
        } else if (std.mem.endsWith(u8, value, "s")) {
            multiplier = 1000;
            num_str = value[0..value.len-1];
        } else if (std.mem.endsWith(u8, value, "m")) {
            multiplier = 60000;
            num_str = value[0..value.len-1];
        }

        const num = try std.fmt.parseInt(u64, num_str, 10);
        return Duration{ .milliseconds = num * multiplier };
    }

    fn format(self: Duration, comptime fmt: []const u8, options: std.fmt.FormatOptions, writer: anytype) !void {
        _ = fmt;
        _ = options;
        try writer.print("{d}ms", .{self.milliseconds});
    }
};

const Color = struct {
    r: u8,
    g: u8,
    b: u8,

    fn parse(value: []const u8) !Color {
        // Support: "#RRGGBB" or "r,g,b"
        if (value[0] == '#') {
            const hex = value[1..];
            if (hex.len != 6) return error.InvalidFormat;
            const r = try std.fmt.parseInt(u8, hex[0..2], 16);
            const g = try std.fmt.parseInt(u8, hex[2..4], 16);
            const b = try std.fmt.parseInt(u8, hex[4..6], 16);
            return Color{ .r = r, .g = g, .b = b };
        } else {
            var parts = std.mem.split(u8, value, ",");
            const r = try std.fmt.parseInt(u8, parts.next() orelse return error.InvalidFormat, 10);
            const g = try std.fmt.parseInt(u8, parts.next() orelse return error.InvalidFormat, 10);
            const b = try std.fmt.parseInt(u8, parts.next() orelse return error.InvalidFormat, 10);
            return Color{ .r = r, .g = g, .b = b };
        }
    }
};

pub fn main() !void {
    var fs = try flags.newFlagSet("custom-types", flags.ContinueOnError);
    defer fs.deinit();

    var timeout: Duration = Duration{ .milliseconds = 5000 };
    var bg_color: Color = Color{ .r = 255, .g = 255, .b = 255 };

    // Phase 2: Custom Value interface
    fs.var(&timeout, "timeout", "Request timeout (100ms, 5s, 2m)", &Duration.parse);
    fs.var(&bg_color, "bgcolor", "Background color (#RRGGBB or r,g,b)", &Color.parse);

    try fs.parse(std.os.argv[1..]);

    std.debug.print("Timeout: {d}ms\n", .{timeout.milliseconds});
    std.debug.print("Background: RGB({d}, {d}, {d})\n", .{bg_color.r, bg_color.g, bg_color.b});
}
```

**Usage** (Phase 2):
```bash
$ myapp -timeout=30s -bgcolor=#FF00FF
# Output:
# Timeout: 30000ms
# Background: RGB(255, 0, 255)

$ myapp -timeout=100ms -bgcolor=128,64,32
# Output:
# Timeout: 100ms
# Background: RGB(128, 64, 32)
```

**Notes**:
- Phase 2 feature: Custom Value interface (inspired by Go's flag.Value)
- Requires: Generic Var function or Value interface
- Benefits: Reusable type definitions, clean separation
- Pattern inspired by Go's flag.Value interface
- Use case: Complex CLI tools with specialized types
- Enables: Duration, Color, URL, IP address parsing

---

### Pattern 9: Subcommands (Phase 2 - Proposed)

**Problem**: Build multi-command tools like `git` (add, commit, push) or `docker` (run, build, ps)

**Code** (Phase 2 - not yet implemented):
```zig
const std = @import("std");
const flags = @import("flags");

const AddCmd = struct {
    paths: [][]const u8,
    force: bool,
};

const CommitCmd = struct {
    message: []const u8,
    author: []const u8,
};

const PushCmd = struct {
    remote: []const u8,
    branch: []const u8,
    force: bool,
};

pub fn cmdAdd(args: [][]const u8) !void {
    var fs = try flags.newFlagSet("add", flags.ExitOnError);
    defer fs.deinit();

    var force = false;
    fs.boolVar(&force, "force", false, "Add with force");

    try fs.parse(args);

    std.debug.print("Add command:\n", .{});
    std.debug.print("  Force: {}\n", .{force});
    
    var paths = fs.args();
    for (paths) |path| {
        std.debug.print("  Path: {s}\n", .{path});
    }
}

pub fn cmdCommit(args: [][]const u8) !void {
    var fs = try flags.newFlagSet("commit", flags.ExitOnError);
    defer fs.deinit();

    var message = [_]u8{0} ** 256;
    var author = [_]u8{0} ** 256;

    fs.stringVar(&message, "m", "", "Commit message");
    fs.stringVar(&author, "author", "", "Commit author");

    try fs.parse(args);

    std.debug.print("Commit command:\n", .{});
    std.debug.print("  Message: {s}\n", .{&message});
    std.debug.print("  Author: {s}\n", .{&author});
}

pub fn cmdPush(args: [][]const u8) !void {
    var fs = try flags.newFlagSet("push", flags.ExitOnError);
    defer fs.deinit();

    var remote = [_]u8{0} ** 256;
    var branch = [_]u8{0} ** 256;
    var force = false;

    fs.stringVar(&remote, "remote", "origin", "Remote name");
    fs.stringVar(&branch, "branch", "main", "Branch name");
    fs.boolVar(&force, "force", false, "Force push");

    try fs.parse(args);

    std.debug.print("Push command:\n", .{});
    std.debug.print("  Remote: {s}\n", .{&remote});
    std.debug.print("  Branch: {s}\n", .{&branch});
    std.debug.print("  Force: {}\n", .{force});
}

pub fn main() !void {
    var args = std.process.args();
    defer args.deinit();
    
    _ = args.next(); // skip program name

    const cmd = args.next() orelse {
        std.debug.print("Usage: git <command> [options]\n", .{});
        std.debug.print("Commands: add, commit, push\n", .{});
        return;
    };

    var cmd_args = std.ArrayList([]const u8).init(std.heap.page_allocator);
    defer cmd_args.deinit();

    while (args.next()) |arg| {
        try cmd_args.append(arg);
    }

    if (std.mem.eql(u8, cmd, "add")) {
        try cmdAdd(cmd_args.items);
    } else if (std.mem.eql(u8, cmd, "commit")) {
        try cmdCommit(cmd_args.items);
    } else if (std.mem.eql(u8, cmd, "push")) {
        try cmdPush(cmd_args.items);
    } else {
        std.debug.print("Unknown command: {s}\n", .{cmd});
    }
}
```

**Usage** (Phase 2):
```bash
$ mygit add -force file1.txt file2.txt
# Output:
# Add command:
#   Force: true
#   Path: file1.txt
#   Path: file2.txt

$ mygit commit -m="Initial commit" -author="Alice"
# Output:
# Commit command:
#   Message: Initial commit
#   Author: Alice

$ mygit push -remote=upstream -branch=develop -force
# Output:
# Push command:
#   Remote: upstream
#   Branch: develop
#   Force: true
```

**Notes**:
- Phase 2 feature: FlagSet for independent command contexts
- Requires: FlagSet type with separate flag registry
- Benefits: Modular CLI architecture, reusable commands
- Pattern inspired by Go's flag.FlagSet
- Use case: Tools like git, docker, kubectl with multiple commands
- Key advantage: Each command can have independent flags

---

### Pattern 10: Error Handling Modes (Phase 2 - Proposed)

**Problem**: Control how parsing errors are handled (exit, return error, continue)

**Code** (Phase 2 - not yet implemented):
```zig
const std = @import("std");
const flags = @import("flags");

const ErrorHandlingMode = enum {
    ExitOnError,     // Exit immediately on error
    PanicOnError,    // Panic on error
    ContinueOnError, // Collect errors, return them
};

pub fn exampleExitOnError() !void {
    std.debug.print("\n=== ExitOnError Mode ===\n", .{});
    
    var fs = try flags.newFlagSet("test", flags.ExitOnError);
    defer fs.deinit();

    var port = 8080;
    fs.intVar(&port, "port", 8080, "Server port");

    // If parsing fails with ExitOnError, the program exits
    const args = [_][]const u8{ "-port=invalid" };
    _ = fs.parse(args[0..]) catch {
        std.debug.print("Error caught (shouldn't reach here with ExitOnError)\n", .{});
    };
}

pub fn exampleContinueOnError() !void {
    std.debug.print("\n=== ContinueOnError Mode ===\n", .{});
    
    var fs = try flags.newFlagSet("test", flags.ContinueOnError);
    defer fs.deinit();

    var port = 8080;
    var host = [_]u8{0} ** 256;

    fs.intVar(&port, "port", 8080, "Server port");
    fs.stringVar(&host, "host", "localhost", "Server host");

    const args = [_][]const u8{ "-port=invalid", "-host=example.com" };
    
    // ContinueOnError mode: parsing returns error but doesn't exit
    if (fs.parse(args[0..])) |_| {
        std.debug.print("Parsed successfully (unexpected with invalid port)\n", .{});
    } else |err| {
        std.debug.print("Error occurred: {}\n", .{err});
        std.debug.print("Port: {d}\n", .{port});
        std.debug.print("Host was still updated: {s}\n", .{&host});
    }
}

pub fn examplePanicOnError() !void {
    std.debug.print("\n=== PanicOnError Mode ===\n", .{});
    
    var fs = try flags.newFlagSet("test", flags.PanicOnError);
    defer fs.deinit();

    var workers = 4;
    fs.intVar(&workers, "workers", 4, "Worker threads");

    // This would panic on error, so we demonstrate with valid args
    const args = [_][]const u8{ "-workers=8" };
    try fs.parse(args[0..]);
    
    std.debug.print("Parsed successfully with workers: {d}\n", .{workers});
}

pub fn main() !void {
    std.debug.print("Flag Error Handling Modes\n", .{});
    std.debug.print("========================\n", .{});

    // ExitOnError: Program exits on parse error
    // (skipped in example to continue execution)
    
    // ContinueOnError: Return error, caller decides
    try exampleContinueOnError();
    
    // PanicOnError: Panic on any error
    try examplePanicOnError();

    std.debug.print("\nError handling configured per FlagSet.\n", .{});
}
```

**Usage** (Phase 2):
```bash
$ myapp (with ContinueOnError)
# Output:
# === ContinueOnError Mode ===
# Error occurred: error.InvalidInteger
# Port: 8080
# Host was still updated: example.com
#
# === PanicOnError Mode ===
# Parsed successfully with workers: 8
#
# Error handling configured per FlagSet.
```

**Notes**:
- Phase 2 feature: ErrorHandlingMode for flexible error strategies
- Requires: FlagSet with configurable error behavior
- Three modes:
  - ExitOnError: Call std.process.exit() on error
  - ContinueOnError: Return error to caller
  - PanicOnError: Panic on error (useful for testing)
- Pattern inspired by Go's flag.ErrorHandling
- Use case: CLI tools (exit), libraries (return error), tests (panic)
- Benefits: Libraries can use flags without affecting caller

---

## Phase 3: Advanced Patterns

### Pattern 11: Flag Visiting with Callbacks (Phase 3 - Advanced/Proposed)

**Problem**: Inspect all defined flags, implement custom help, or debug flag configuration

**Code** (Phase 3 - not yet implemented, ADVANCED):
```zig
const std = @import("std");
const flags = @import("flags");

const FlagInfo = struct {
    name: []const u8,
    usage: []const u8,
    value: []const u8,
    kind: FlagKind,
};

const FlagKind = enum {
    boolean,
    string,
    integer,
    float,
};

pub fn visitFlags(fs: *flags.FlagSet, visitor: *const fn (FlagInfo) void) void {
    // Phase 3: Iterate over all registered flags
    // This requires internal FlagSet state to be accessible
    var flag_iter = fs.flags();
    
    while (flag_iter.next()) |flag_info| {
        visitor(flag_info);
    }
}

pub fn printCustomHelp(fs: *flags.FlagSet) void {
    std.debug.print("╔═══════════════════════════════╗\n", .{});
    std.debug.print("║     Custom Flag Inspector     ║\n", .{});
    std.debug.print("╚═══════════════════════════════╝\n\n", .{});

    visitFlags(fs, &struct {
        fn visit(info: FlagInfo) void {
            std.debug.print("Flag: -{s}\n", .{info.name});
            std.debug.print("  Type: {}\n", .{info.kind});
            std.debug.print("  Default: {s}\n", .{info.value});
            std.debug.print("  Usage: {s}\n\n", .{info.usage});
        }
    }.visit);
}

pub fn countFlags(fs: *flags.FlagSet) u32 {
    var count: u32 = 0;
    visitFlags(fs, &struct {
        fn visit(info: FlagInfo) void {
            _ = info;
            count += 1;
        }
    }.visit);
    return count;
}

pub fn main() !void {
    var fs = try flags.newFlagSet("myapp", flags.ContinueOnError);
    defer fs.deinit();

    var verbose = false;
    var config_path = [_]u8{0} ** 256;
    var port = 8080;
    var rate = 0.5;

    fs.boolVar(&verbose, "verbose", false, "Enable verbose output");
    fs.stringVar(&config_path, "config", "/etc/app.conf", "Configuration file path");
    fs.intVar(&port, "port", 8080, "Server port (1-65535)");
    fs.floatVar(&rate, "rate", 0.5, "Processing rate (0.0-1.0)");

    // Phase 3: Print custom help with flag visitor
    printCustomHelp(&fs);

    // Phase 3: Count total flags
    std.debug.print("Total flags defined: {d}\n\n", .{countFlags(&fs)});

    // Demonstrate that visitor doesn't affect parsing
    const args = [_][]const u8{ "-verbose", "-port=9000" };
    try fs.parse(args[0..]);

    std.debug.print("After parsing:\n", .{});
    std.debug.print("  Verbose: {}\n", .{verbose});
    std.debug.print("  Port: {d}\n", .{port});
}
```

**Usage** (Phase 3):
```bash
$ myapp (Phase 3 with flag visiting)
# Output:
# ╔═══════════════════════════════╗
# ║     Custom Flag Inspector     ║
# ╚═══════════════════════════════╝
#
# Flag: -verbose
#   Type: boolean
#   Default: false
#   Usage: Enable verbose output
#
# Flag: -config
#   Type: string
#   Default: /etc/app.conf
#   Usage: Configuration file path
#
# Flag: -port
#   Type: integer
#   Default: 8080
#   Usage: Server port (1-65535)
#
# Flag: -rate
#   Type: float
#   Default: 0.5
#   Usage: Processing rate (0.0-1.0)
#
# Total flags defined: 4
#
# After parsing:
#   Verbose: true
#   Port: 9000
```

**Notes**:
- Phase 3 feature: ADVANCED - Flag visiting for introspection
- Requires: Internal flag registry and iterator
- Benefits: Custom help, debugging, validation, auto-documentation
- Pattern inspired by Go's flag.VisitAll
- Use cases:
  - Custom help formatting (colorized, grouped)
  - Flag documentation generation
  - Validation helpers
  - Configuration file generation
- Advanced feature: Rarely needed in basic CLI tools

---

### Pattern 12: Required Flags Validation (Phase 3 - Proposed)

**Problem**: Ensure critical configuration flags are provided, with custom validation

**Code** (Phase 3 - not yet implemented):
```zig
const std = @import("std");
const flags = @import("flags");

const RequiredFlags = struct {
    names: std.ArrayList([]const u8),
    allocator: std.mem.Allocator,

    fn init(allocator: std.mem.Allocator) RequiredFlags {
        return .{
            .names = std.ArrayList([]const u8).init(allocator),
            .allocator = allocator,
        };
    }

    fn markRequired(self: *RequiredFlags, name: []const u8) !void {
        try self.names.append(name);
    }

    fn validate(self: *RequiredFlags, fs: *flags.FlagSet) !void {
        var missing = std.ArrayList([]const u8).init(self.allocator);
        defer missing.deinit();

        for (self.names.items) |required_name| {
            if (!fs.isFlagSet(required_name)) {
                try missing.append(required_name);
            }
        }

        if (missing.items.len > 0) {
            std.debug.print("Error: Missing required flags:\n", .{});
            for (missing.items) |name| {
                std.debug.print("  -{s}\n", .{name});
            }
            return error.MissingRequiredFlags;
        }
    }

    fn deinit(self: *RequiredFlags) void {
        self.names.deinit();
    }
};

pub fn main() !void {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();
    const allocator = gpa.allocator();

    var fs = try flags.newFlagSet("deploy", flags.ContinueOnError);
    defer fs.deinit();

    var app_name = [_]u8{0} ** 256;
    var environment = [_]u8{0} ** 256;
    var version = [_]u8{0} ** 256;
    var force = false;
    var dry_run = false;

    // Define flags
    fs.stringVar(&app_name, "app", "", "Application name (required)");
    fs.stringVar(&environment, "env", "", "Environment: dev, staging, prod (required)");
    fs.stringVar(&version, "version", "", "Version to deploy (required)");
    fs.boolVar(&force, "force", false, "Force deployment");
    fs.boolVar(&dry_run, "dry-run", false, "Perform dry run");

    // Phase 3: Mark required flags
    var required = RequiredFlags.init(allocator);
    defer required.deinit();

    try required.markRequired("app");
    try required.markRequired("env");
    try required.markRequired("version");

    // Parse arguments
    const args = std.process.args();
    defer args.deinit();
    var arg_list = std.ArrayList([]const u8).init(allocator);
    defer arg_list.deinit();

    var skip_first = true;
    while (args.next()) |arg| {
        if (skip_first) {
            skip_first = false;
            continue;
        }
        try arg_list.append(arg);
    }

    if (arg_list.items.len > 0) {
        try fs.parse(arg_list.items);
    }

    // Phase 3: Validate required flags
    if (required.validate(&fs)) |_| {
        std.debug.print("Configuration validated!\n", .{});
        std.debug.print("Deploying {s} v{s} to {s}\n", .{&app_name, &version, &environment});
        
        if (dry_run) {
            std.debug.print("[DRY RUN - no changes made]\n", .{});
        }
        
        if (force) {
            std.debug.print("[FORCE MODE - skipping confirmations]\n", .{});
        }
    } else |err| {
        std.debug.print("Validation failed: {}\n\n", .{err});
        std.debug.print("Usage: deploy -app=APPNAME -env=ENV -version=VERSION [options]\n", .{});
        std.debug.print("  -app string         Application name (required)\n", .{});
        std.debug.print("  -env string         Environment: dev, staging, prod (required)\n", .{});
        std.debug.print("  -version string     Version to deploy (required)\n", .{});
        std.debug.print("  -force              Force deployment\n", .{});
        std.debug.print("  -dry-run            Perform dry run\n", .{});
    }
}
```

**Usage** (Phase 3):
```bash
# Missing required flags
$ zig build run
# Output:
# Error: Missing required flags:
#   -app
#   -env
#   -version
#
# Usage: deploy -app=APPNAME -env=ENV -version=VERSION [options]
#   -app string         Application name (required)
#   -env string         Environment: dev, staging, prod (required)
#   -version string     Version to deploy (required)
#   -force              Force deployment
#   -dry-run            Perform dry run

# All required flags provided
$ zig build run -- -app=myapp -env=prod -version=1.2.3 -force
# Output:
# Configuration validated!
# Deploying myapp v1.2.3 to prod
# [FORCE MODE - skipping confirmations]

# Dry run
$ zig build run -- -app=myapp -env=staging -version=1.0.0 -dry-run
# Output:
# Configuration validated!
# Deploying myapp v1.0.0 to staging
# [DRY RUN - no changes made]
```

**Notes**:
- Phase 3 feature: Required flag validation framework
- Requires: Flag introspection (isFlagSet method)
- Benefits: Ensure critical config is always provided
- Use cases:
  - Deployment tools (require environment, version)
  - Database migration (require connection string)
  - File processors (require input/output paths)
- Can be extended with:
  - Custom validators per flag
  - Mutually exclusive flags
  - Conditional requirements
  - Environment variable overrides

---

## Implementation Checklist

Use this to track which patterns can run with each implementation phase:

### Phase 1 (Current + Foundation)
- ✅ Pattern 1: Basic Boolean Flags
- ✅ Pattern 2: String Flags with Defaults
- ✅ Pattern 3: Mixed Flag Types
- ✅ Pattern 4: Configuration Structure
- ✅ Pattern 5: Help Message (Manual)
- ✅ Pattern 6: Input Validation
- ⏳ Pattern 7: Struct-Based Config (needs IntVar)
- ⏳ Pattern 8: Custom Value Types (needs Value interface)
- ⏳ Pattern 9: Subcommands (needs FlagSet)
- ⏳ Pattern 10: Error Handling (needs FlagSet + modes)

### Phase 2 (Common)
- ✅ Pattern 7: Struct-Based Config
- ✅ Pattern 8: Custom Value Types
- ✅ Pattern 9: Subcommands
- ✅ Pattern 10: Error Handling
- ⏳ Pattern 11: Flag Visiting (needs introspection)
- ⏳ Pattern 12: Required Flags (needs introspection)

### Phase 3+ (Advanced)
- ✅ Pattern 11: Flag Visiting (ADVANCED)
- ✅ Pattern 12: Required Flags

---

## Pattern Selection Guide

**Choose Pattern 1-2** if you need:
- Simple on/off toggles (verbose, debug)
- Basic configuration (names, paths)
- Quick CLI prototype

**Choose Pattern 3-4** if you need:
- Multiple related configuration options
- Organization into logical groupings
- Better code structure

**Choose Pattern 5-6** if you need:
- Help text for users
- Validation of user input
- Error messages

**Choose Pattern 7-8** if you need:
- Type-safe numeric configuration
- Custom types (Duration, Color, etc)
- Reusable configuration objects

**Choose Pattern 9-10** if you need:
- Multi-command tools (git, docker)
- Independent flag contexts
- Flexible error handling

**Choose Pattern 11-12** if you need:
- Custom help formatting
- Required flag validation
- Flag introspection and debugging

---

## Testing These Patterns

Each pattern is designed to be copied into a separate `example_N.zig` file and tested:

```bash
# Copy pattern into example file
cp src/main.zig src/main_backup.zig
# Edit src/main.zig with pattern code

# Test the pattern
zig build run

# Restore
mv src/main_backup.zig src/main.zig
```

Or create separate test files:
```bash
# Create separate example project
mkdir examples
cd examples
# Create each pattern in separate .zig file
# Build and test each independently
```

---

## Future Enhancements

These patterns can be extended with:

- **Logging**: Add logging to show flag values as they're processed
- **Config Files**: Load flags from JSON/YAML before CLI parsing
- **Environment Variables**: Override with env vars (CLI > env > default)
- **Completion Scripts**: Generate bash/zsh completion from flag definitions
- **Validation Chains**: Combine validators (required, range, pattern)
- **Flag Groups**: Organize related flags in help output
- **Aliases**: Support multiple names for same flag
- **Deprecated Flags**: Show warnings for old flag names
