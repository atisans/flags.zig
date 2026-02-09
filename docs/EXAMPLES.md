# flags.zig - Usage Examples

## Table of Contents

1. [Basic Usage](#basic-usage)
2. [Subcommands](#subcommands)
3. [Help Generation](#help-generation)
4. [Custom Types](#custom-types)
5. [Real-World Examples](#real-world-examples)

---

## Basic Usage

### Simple Program

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
    
    if (parsed.verbose) {
        std.debug.print("Verbose mode enabled\n", .{});
    }
    
    var i: u32 = 0;
    while (i < parsed.count) : (i += 1) {
        std.debug.print("Hello, {s}!\n", .{parsed.name});
    }
}
```

**Usage:**
```bash
$ ./hello
Hello, world!

$ ./hello --name=Alice --count=3
Hello, Alice!
Hello, Alice!
Hello, Alice!

$ ./hello --verbose --name=Bob
Verbose mode enabled
Hello, Bob!
```

### Optional Values

```zig
const Args = struct {
    // Required (no default)
    input: []const u8,
    
    // Optional with default
    output: []const u8 = "output.txt",
    
    // Truly optional (can be null)
    config: ?[]const u8 = null,
};

const parsed = try flags.parse(args, Args);

// Check optional
if (parsed.config) |config_path| {
    std.debug.print("Using config: {s}\n", .{config_path});
}
```

### Enum Choices

```zig
const Format = enum {
    json,
    yaml,
    toml,
};

const Args = struct {
    format: Format = .json,
    pretty: bool = false,
};

const parsed = try flags.parse(args, Args);

switch (parsed.format) {
    .json => try outputJson(parsed.pretty),
    .yaml => try outputYaml(parsed.pretty),
    .toml => try outputToml(parsed.pretty),
}
```

**Usage:**
```bash
$ ./converter --format=yaml --pretty
```

---

## Subcommands

### Git-Style CLI

```zig
const flags = @import("flags");

const CLI = union(enum) {
    // Init command with no args
    init: struct {
        bare: bool = false,
    },
    
    // Clone command
    clone: struct {
        recursive: bool = false,
        depth: ?u32 = null,
        repository: []const u8,
        directory: ?[]const u8 = null,
    },
    
    // Remote subcommands
    remote: union(enum) {
        add: struct {
            name: []const u8,
            url: []const u8,
            track: ?[]const u8 = null,
        },
        remove: struct {
            name: []const u8,
        },
        list: struct {
            verbose: bool = false,
        },
        
        pub const help = "Manage remote repositories";
    },
    
    // Branch subcommands
    branch: union(enum) {
        create: struct {
            name: []const u8,
            from: ?[]const u8 = null,
        },
        delete: struct {
            name: []const u8,
            force: bool = false,
        },
        list: struct {
            all: bool = false,
        },
        
        pub const help = "Manage branches";
    },
    
    pub const help =
        \\Usage: git-clone [options] <command>
        \\
        \\Commands:
        \\  init              Initialize a new repository
        \\  clone             Clone a repository
        \\  remote            Manage remotes
        \\  branch            Manage branches
    ;
};

pub fn main() !void {
    const args = try std.process.argsAlloc(allocator);
    defer std.process.argsFree(allocator, args);

    const cli = try flags.parse(args, CLI);
    
    switch (cli) {
        .init => |i| try cmdInit(i.bare),
        .clone => |c| try cmdClone(c),
        .remote => |r| switch (r) {
            .add => |a| try cmdRemoteAdd(a),
            .remove => |r| try cmdRemoteRemove(r.name),
            .list => |l| try cmdRemoteList(l.verbose),
        },
        .branch => |b| switch (b) {
            .create => |c| try cmdBranchCreate(c),
            .delete => |d| try cmdBranchDelete(d),
            .list => |l| try cmdBranchList(l.all),
        },
    }
}
```

### Comptime Parser (Typed Flags)

```zig
const flags = @import("flags");

const Args = struct {
    config: []const u8,
    verbose: bool = false,
    pub const help =
        \\myapp --config=<path> [--verbose]
        \\  --config  path to the config file
        \\  --verbose enable verbose logging
    ;
};

pub fn main() !void {
    const args = try std.process.argsAlloc(allocator);
    defer std.process.argsFree(allocator, args);

    const parsed = try flags.parse(args, Args);
    _ = parsed;
}
```

### Comptime Parser (Subcommands + Positionals)

```zig
const flags = @import("flags");

const CLI = union(enum) {
    start: struct {
        address: []const u8,
        replica: u32,
    },
    format: struct {
        verbose: bool = false,
        @"--": void,
        path: []const u8,
    },

    pub const help =
        \\myapp start --address=<addr> --replica=<n>
        \\myapp format [--verbose] <path>
    ;
};

pub fn main() !void {
    const args = try std.process.argsAlloc(allocator);
    defer std.process.argsFree(allocator, args);

    const cli = try flags.parse(args, CLI);
    _ = cli;
}
```

**Usage:**
```bash
$ ./git-clone init
$ ./git-clone init --bare
$ ./git-clone clone --recursive https://github.com/user/repo.git
$ ./git-clone remote add origin https://github.com/user/repo.git
$ ./git-clone remote list --verbose
$ ./git-clone branch create feature-branch --from=main
$ ./git-clone branch delete old-branch --force
```

### Server CLI

```zig
const CLI = union(enum) {
    start: struct {
        host: []const u8 = "0.0.0.0",
        port: u16 = 8080,
        workers: u32 = 4,
        daemon: bool = false,
        
        pub const help =
            \\Start the server
            \\
            \\Options:
            \\  --host string    Host address to bind to (default: "0.0.0.0")
            \\  --port int       Port to listen on (default: 8080)
            \\  --workers int    Number of worker threads (default: 4)
            \\  --daemon         Run as daemon
        ;
    },
    
    stop: struct {
        graceful: bool = true,
        timeout: u32 = 30,
        
        pub const help =
            \\Stop the server
            \\
            \\Options:
            \\  --graceful       Wait for connections to close (default: true)
            \\  --timeout int    Seconds to wait before force stop (default: 30)
        ;
    },
    
    status: struct {
        verbose: bool = false,
        
        pub const help =
            \\Show server status
            \\
            \\Options:
            \\  --verbose    Show detailed status
        ;
    },
    
    pub const help =
        \\Usage: server [options] <command>
        \\
        \\Commands:
        \\  start     Start the server
        \\  stop      Stop the server
        \\  status    Show server status
    ;
};
```

---

## Help Generation

**Note:** The current implementation uses multi-line string help. Struct-based help with per-field documentation is planned for a future release.

### Basic Help

```zig
const Args = struct {
    verbose: bool = false,
    config: []const u8 = "config.json",
    port: u16 = 8080,
    
    pub const help =
        \\Usage: myapp [options]
        \\
        \\Options:
        \\  --verbose    Enable verbose output
        \\  --config     Path to configuration file (default: "config.json")
        \\  --port       Port to listen on (default: 8080)
    ;
};

Output:
```
Usage: myapp [options]

Options:
  --verbose    Enable verbose output
  --config     Path to configuration file (default: "config.json")
  --port       Port to listen on (default: 8080)
```

### Comprehensive Help

```zig
const Args = struct {
    pub const help =
        \\A high-performance web server with configurable options.
        \\
        \\This server supports HTTP/2, WebSockets, and static file serving.
        \\
        \\Usage: server [options] <command>
        \\
        \\Options:
        \\  --host string    Host address to bind to (default: "0.0.0.0")
        \\  --port int       Port number (default: 8080)
        \\  --workers int    Worker thread count (default: 4)
        \\  --config string  Configuration file path
        \\  --verbose        Enable verbose logging
        \\
        \\Examples:
        \\  server start --port=3000
        \\  server start --config=server.json --verbose
        \\  server status
        \\  server stop --graceful
        \\
        \\Exit Codes:
        \\  0    Success
        \\  1    Invalid arguments
        \\  2    Configuration error
        \\  3    Runtime error
    ;
};

Output:
```
A high-performance web server with configurable options.

This server supports HTTP/2, WebSockets, and static file serving.

Usage: server [options] <command>

Options:
  --host string    Host address to bind to (default: "0.0.0.0")
  --port int       Port number (default: 8080)
  --workers int    Worker thread count (default: 4)
  --config string  Configuration file path
  --verbose        Enable verbose logging

Examples:
  server start --port=3000
  server start --config=server.json --verbose
  server status
  server stop --graceful

Exit Codes:
  0    Success
  1    Invalid arguments
  2    Configuration error
  3    Runtime error
```

---

## Custom Types (Planned Feature)

**Note:** Custom type parsing is not yet implemented. The examples below show the proposed API for a future release.

### IP Address

```zig
const Address = struct {
    host: []const u8,
    port: u16,
    
    pub fn parse_flag_value(
        string: []const u8,
        diagnostic: *?[]const u8,
    ) error{InvalidFlagValue}!Address {
        const colon = std.mem.indexOfScalar(u8, string, ':') 
            orelse {
                diagnostic.* = "expected host:port format:";
                return error.InvalidFlagValue;
            };
        
        const port = std.fmt.parseInt(u16, string[colon+1..], 10) 
            catch {
                diagnostic.* = "invalid port number:";
                return error.InvalidFlagValue;
            };
        
        return Address{
            .host = string[0..colon],
            .port = port,
        };
    }
};

const Args = struct {
    listen: Address = .{ .host = "0.0.0.0", .port = 8080 },
    upstream: ?Address = null,
};

// Usage: --listen=127.0.0.1:3000 --upstream=backend:8080
```

### Duration

```zig
const Duration = struct {
    nanoseconds: u64,
    
    pub fn parse_flag_value(
        string: []const u8,
        diagnostic: *?[]const u8,
    ) error{InvalidFlagValue}!Duration {
        // Parse "1h30m", "500ms", "5s"
        var total: u64 = 0;
        var i: usize = 0;
        
        while (i < string.len) {
            const start = i;
            while (i < string.len and std.ascii.isDigit(string[i])) : (i += 1) {}
            
            if (i == start) {
                diagnostic.* = "expected number:";
                return error.InvalidFlagValue;
            }
            
            const num = std.fmt.parseInt(u64, string[start..i], 10) catch {
                diagnostic.* = "invalid number:";
                return error.InvalidFlagValue;
            };
            
            if (i >= string.len) {
                diagnostic.* = "expected unit (h, m, s, ms):";
                return error.InvalidFlagValue;
            }
            
            const unit = string[i];
            i += 1;
            
            const multiplier: u64 = switch (unit) {
                'h' => 60 * 60 * 1_000_000_000,
                'm' => 60 * 1_000_000_000,
                's' => 1_000_000_000,
                'S' => 1_000_000, // ms
                else => {
                    diagnostic.* = "unknown unit (use h, m, s, ms):";
                    return error.InvalidFlagValue;
                },
            };
            
            total += num * multiplier;
        }
        
        return Duration{ .nanoseconds = total };
    }
};

const Args = struct {
    timeout: Duration = .{ .nanoseconds = 30 * 1_000_000_000 }, // 30s
};

// Usage: --timeout=1h30m or --timeout=500ms
```

### File Path with Validation

```zig
const InputFile = struct {
    path: []const u8,
    
    pub fn parse_flag_value(
        string: []const u8,
        diagnostic: *?[]const u8,
    ) error{InvalidFlagValue}!InputFile {
        // Check file exists
        std.fs.cwd().access(string, .{}) catch {
            diagnostic.* = "file not found:";
            return error.InvalidFlagValue;
        };
        
        return InputFile{ .path = string };
    }
};

const Args = struct {
    input: InputFile,
};

// Usage: --input=data.json (validates file exists)
```

---

## Real-World Examples

### HTTP Client

```zig
const CLI = union(enum) {
    get: struct {
        url: []const u8,
        headers: ?[]const u8 = null,
        output: ?[]const u8 = null,
    },
    
    post: struct {
        url: []const u8,
        data: ?[]const u8 = null,
        file: ?[]const u8 = null,
        headers: ?[]const u8 = null,
    },
    
    pub const help = "Simple HTTP client";
};

pub fn main() !void {
    const args = try std.process.argsAlloc(allocator);
    defer std.process.argsFree(allocator, args);

    const cli = try flags.parse(args, CLI);
    
    const client = std.http.Client{ .allocator = allocator };
    defer client.deinit();
    
    switch (cli) {
        .get => |g| try httpGet(&client, g),
        .post => |p| try httpPost(&client, p),
    }
}
```

**Usage:**
```bash
$ http get https://api.example.com/data
$ http get https://api.example.com/data --output=response.json
$ http post https://api.example.com/data --data='{"key":"value"}'
```

### Build Tool

```zig
const CLI = union(enum) {
    build: struct {
        release: bool = false,
        target: ?[]const u8 = null,
        jobs: u32 = 4,
    },
    
    test: struct {
        filter: ?[]const u8 = null,
        verbose: bool = false,
    },
    
    clean,
    
    run: struct {
        args: ?[]const u8 = null,
    },
    
    pub const help = "Build tool for Zig projects";
};
```

**Usage:**
```bash
$ buildtool build --release
$ buildtool build --target=wasm32-freestanding
$ buildtool test --filter=network
$ buildtool clean
$ buildtool run --args="--help"
```

### Database CLI

```zig
const CLI = union(enum) {
    connect: struct {
        host: []const u8 = "localhost",
        port: u16 = 5432,
        user: []const u8 = "postgres",
        password: ?[]const u8 = null,
        database: []const u8 = "postgres",
    },
    
    query: struct {
        sql: []const u8,
        format: enum { table, json, csv } = .table,
    },
    
    migrate: struct {
        direction: enum { up, down } = .up,
        version: ?u32 = null,
    },
    
    backup: struct {
        output: []const u8 = "backup.sql",
        compress: bool = false,
    },
    
    pub const help = "Database management CLI";
};
```

**Usage:**
```bash
$ dbcli connect --host=db.example.com --user=admin
$ dbcli query --sql="SELECT * FROM users" --format=json
$ dbcli migrate --direction=up
$ dbcli backup --output=backup.sql --compress
```
