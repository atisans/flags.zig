# Building CLI Applications with flags.zig

This guide shows how to use the **flags.zig** library to build command-line applications following the architectural patterns outlined in rebuild-x's Zig CLI tutorial.

## Table of Contents

- [Overview](#overview)
- [Project Structure](#project-structure)
- [Step 1: Core CLI Types with flags.zig](#step-1-core-cli-types-with-flagszig)
- [Step 2: Parser Setup](#step-2-parser-setup)
- [Step 3: Command Handlers](#step-3-command-handlers)
- [Step 4: Main Application](#step-4-main-application)
- [Advanced Patterns](#advanced-patterns)
- [Complete Example](#complete-example)

## Overview

The **flags.zig** library provides a Go-like flag parsing approach that integrates seamlessly into your Zig CLI applications. Instead of manually parsing command-line arguments, flags.zig handles:

- Multiple flag types (bool, string, int, float, uint)
- Short and long-form options (`-n` vs `--name`)
- Default values
- Help generation
- Positional arguments
- Subcommands via FlagSet
- Custom types via the `Value` interface

## Project Structure

```
my-cli/
├── src/
│   ├── main.zig              # Main application entry point
│   ├── commands.zig          # Command handlers
│   └── cli.zig               # CLI utilities (colors, etc.)
├── build.zig                 # Build configuration
├── build.zig.zon             # Dependencies
└── README.md                 # Documentation
```

## Step 1: Core CLI Types with flags.zig

Instead of building a custom command/option system, flags.zig provides the foundation. You define commands and their flags declaratively:

```zig
const std = @import("std");
const flags = @import("flags");

// In cli.zig - define your command context
pub const CommandContext = struct {
    allocator: std.mem.Allocator,
    flagset: *flags.FlagSet,
    // Add any shared state your commands need
};

// Define command handlers that work with flags
pub const CommandHandler = fn (*CommandContext) !void;

pub const Command = struct {
    name: []const u8,
    description: []const u8,
    handler: CommandHandler,
};
```

## Step 2: Parser Setup

flags.zig handles argument parsing with direct function calls. Currently, use the module-level parse function:

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
    
    // Parse arguments (skip program name)
    try flags.parse(args[1..]);
    
    // Get values from parsed flags
    const name = flags.string("name", "World", "Name to greet");
    const greeting = flags.string("greeting", "Hello", "Greeting to use");
    const shout = flags.boolean("shout", false, "Use uppercase");
}

pub fn setupUserCommand(allocator: std.mem.Allocator) !*flags.FlagSet {
    var fs = try flags.FlagSet.init(allocator, "user");
    
    // Define flags for user subcommand
    _ = fs.string("username", "", "Username (required)");
    _ = fs.string("email", "", "Email address");
    _ = fs.boolean("admin", false, "Admin privileges");
    
    return fs;
}
```

## Step 3: Command Handlers

Implement command handlers that extract and use parsed flags:

```zig
// In commands.zig
const std = @import("std");
const flags = @import("flags");
const cli = @import("cli.zig");

pub fn helloHandler(ctx: *cli.CommandContext) !void {
    const fs = ctx.flagset;
    
    // Get the parsed flag values
    const name = fs.string("name") catch |err| {
        std.debug.print("Error getting name flag: {}\n", .{err});
        return;
    };
    
    const greeting = fs.string("greeting") catch |err| {
        std.debug.print("Error getting greeting flag: {}\n", .{err});
        return;
    };
    
    const shout = fs.boolean("shout") catch |err| {
        std.debug.print("Error getting shout flag: {}\n", .{err});
        return;
    };
    
    var output: []const u8 = undefined;
    if (shout) {
        output = try std.fmt.allocPrint(ctx.allocator, "{s}, {s}!", .{ 
            try upperString(ctx.allocator, greeting),
            try upperString(ctx.allocator, name)
        });
    } else {
        output = try std.fmt.allocPrint(ctx.allocator, "{s}, {s}!", .{ greeting, name });
    }
    defer ctx.allocator.free(output);
    
    std.debug.print("{s}\n", .{output});
}

pub fn userCreateHandler(ctx: *cli.CommandContext) !void {
    const fs = ctx.flagset;
    
    const username = fs.string("username") catch |err| {
        std.debug.print("Error: username is required\n", .{});
        return err;
    };
    
    if (username.len == 0) {
        std.debug.print("Error: username cannot be empty\n", .{});
        return;
    }
    
    const email = fs.string("email") catch "";
    const is_admin = fs.boolean("admin") catch false;
    
    std.debug.print("Creating user: {s} (email: {s}, admin: {})\n", .{ 
        username, 
        if (email.len > 0) email else "not set",
        is_admin 
    });
}

fn upperString(allocator: std.mem.Allocator, s: []const u8) ![]const u8 {
    var result = try allocator.alloc(u8, s.len);
    for (s, 0..) |char, i| {
        result[i] = std.ascii.toUpper(char);
    }
    return result;
}
```

## Step 4: Main Application

Tie it all together in main.zig with command dispatch:

```zig
const std = @import("std");
const flags = @import("flags");
const cmd = @import("commands.zig");
const cli = @import("cli.zig");

const Command = struct {
    name: []const u8,
    description: []const u8,
    setupFn: *const fn (std.mem.Allocator) !*flags.FlagSet,
    handlerFn: *const fn (*cli.CommandContext) !void,
};

pub fn main() !void {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();
    const allocator = gpa.allocator();

    // Get command-line arguments
    const args = try std.process.argsAlloc(allocator);
    defer std.process.argsFree(allocator, args);

    // Define available commands
    const commands = [_]Command{
        Command{
            .name = "hello",
            .description = "Greet someone",
            .setupFn = cli.setupHelloCommand,
            .handlerFn = cmd.helloHandler,
        },
        Command{
            .name = "user",
            .description = "User management commands",
            .setupFn = cli.setupUserCommand,
            .handlerFn = cmd.userCreateHandler,
        },
        Command{
            .name = "help",
            .description = "Show help message",
            .setupFn = undefined,
            .handlerFn = cmd.helpHandler,
        },
    };

    // Parse command name
    if (args.len < 2) {
        try cmd.printHelp(&commands, null);
        return;
    }

    const command_name = args[1];

    // Find matching command
    var matched_command: ?Command = null;
    for (commands) |c| {
        if (std.mem.eql(u8, c.name, command_name)) {
            matched_command = c;
            break;
        }
    }

    if (matched_command == null) {
        std.debug.print("Unknown command: {s}\n", .{command_name});
        try cmd.printHelp(&commands, null);
        std.process.exit(1);
    }

    const selected_cmd = matched_command.?;

    // Special case: help command doesn't use flagset
    if (std.mem.eql(u8, selected_cmd.name, "help")) {
        var ctx = cli.CommandContext{
            .allocator = allocator,
            .flagset = undefined,
        };
        try selected_cmd.handlerFn(&ctx);
        return;
    }

    // Set up and parse flags for this command
    var fs = try selected_cmd.setupFn(allocator);
    defer fs.deinit();

    // Parse remaining arguments
    try fs.parseFromArgs(args[2..]);

    // Create context and execute handler
    var ctx = cli.CommandContext{
        .allocator = allocator,
        .flagset = fs,
    };

    try selected_cmd.handlerFn(&ctx);
}
```

## Advanced Patterns

### 1. Required Flags Validation

```zig
pub fn userCreateHandler(ctx: *cli.CommandContext) !void {
    const fs = ctx.flagset;
    
    const username = fs.string("username") catch "";
    if (username.len == 0) {
        std.debug.print("Error: --username is required\n", .{});
        return error.MissingRequiredFlag;
    }
    
    // Continue with handler...
}
```

### 2. Flag Callbacks

Use the Value interface for custom flag types with validation:

```zig
pub const PortValue = struct {
    value: u16,
    
    pub fn init(allocator: std.mem.Allocator, s: []const u8) !*PortValue {
        const port = try std.fmt.parseInt(u16, s, 10);
        if (port < 1024 or port > 65535) {
            return error.InvalidPort;
        }
        var pv = try allocator.create(PortValue);
        pv.value = port;
        return pv;
    }
    
    pub fn parse(self: *PortValue, s: []const u8) !void {
        self.value = try std.fmt.parseInt(u16, s, 10);
    }
    
    pub fn string(self: *PortValue, buf: []u8) []const u8 {
        return std.fmt.bufPrint(buf, "{d}", .{self.value}) catch "";
    }
};

// In your command setup:
pub fn setupServerCommand(allocator: std.mem.Allocator) !*flags.FlagSet {
    var fs = try flags.FlagSet.init(allocator, "server");
    
    var port_value = try PortValue.init(allocator, "8080");
    _ = fs.value("port", port_value, "Server port");
    
    return fs;
}
```

### 3. Subcommands (Command Groups)

```zig
// Organize commands hierarchically
const commands = [_]Command{
    // User commands
    Command{
        .name = "user:create",
        .description = "Create a new user",
        .setupFn = setupUserCreateCommand,
        .handlerFn = userCreateHandler,
    },
    Command{
        .name = "user:list",
        .description = "List all users",
        .setupFn = setupUserListCommand,
        .handlerFn = userListHandler,
    },
    // Config commands
    Command{
        .name = "config:set",
        .description = "Set configuration value",
        .setupFn = setupConfigSetCommand,
        .handlerFn = configSetHandler,
    },
};
```

## Complete Example (Current Implementation)

Here's a complete working example showing current capabilities:

```zig
// main.zig
const std = @import("std");
const flags = @import("flags");

pub fn main() !void {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();
    const allocator = gpa.allocator();

    // Get and parse command line arguments
    const args = try std.process.argsAlloc(allocator);
    defer std.process.argsFree(allocator, args);
    
    try flags.parse(args[1..]);  // Skip program name

    // Define and retrieve flag values (in order: name, default, description)
    const name = flags.string("name", "World", "Name to greet");
    const loud = flags.boolean("loud", false, "Print in uppercase");
    const count = flags.int("count", 1, "Number of repetitions");

    var output = try std.fmt.allocPrint(allocator, "Hello, {s}!", .{name});
    defer allocator.free(output);

    var i: i32 = 0;
    while (i < count) : (i += 1) {
        if (loud) {
            var upper = try allocator.alloc(u8, output.len);
            defer allocator.free(upper);
            for (output, 0..) |char, j| {
                upper[j] = std.ascii.toUpper(char);
            }
            std.debug.print("{s}\n", .{upper});
        } else {
            std.debug.print("{s}\n", .{output});
        }
    }
}
```

Usage:
```bash
$ zig build run -- -name=Alice -count=2
Hello, Alice!
Hello, Alice!

$ zig build run -- -name=Bob -loud
HELLO, BOB!

$ zig build run -- -count=3
Hello, World!
Hello, World!
Hello, World!
```

## Integration Checklist (Current Phase)

When using flags.zig in its current state:

- [x] Parse command line arguments via parse(args)
- [x] Define flags using string(), boolean(), int()
- [ ] Handle space-separated values (-name value) - [P2]
- [ ] Implement help command generation - [P1]
- [ ] Add validation for required flags
- [ ] Handle error cases gracefully
- [ ] Implement FlagSet for subcommands - [P1]
- [ ] Test flag parsing with various argument combinations
- [ ] Document available commands and flags

**Note**: FlagSet-based advanced patterns are planned for Phase 1. The current version uses simple module-level functions.

## Next Steps

1. See [CODE_PATTERNS.md](CODE_PATTERNS.md) for more flag usage examples
2. Check [API_SPECIFICATION.md](API_SPECIFICATION.md) for all available flag types and features
3. Review [ARCHITECTURE.md](ARCHITECTURE.md) for design details on how flags.zig works internally
