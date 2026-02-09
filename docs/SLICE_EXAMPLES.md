# Slice Examples and Usage Patterns

This document provides practical examples of using slice support in flags.zig for real-world applications.

## Basic Examples

### File Processing Tool

```zig
const std = @import("std");
const flags = @import("flags");

// Define CLI with slice support
const Args = struct {
    // Required list of input files
    inputs: []const []const u8,
    
    // Optional list of output files (defaults to inputs with .out extension)
    outputs: []const []const u8 = &[_][]const u8{},
    
    // Processing modes (enum slice)
    modes: []const enum { compress, encrypt, validate, optimize } = &[_]enum { compress, encrypt }{},
    
    // Verbose output for each file
    verbose: bool = false,
    
    // Thread count per file (integer slice)
    threads: []u8 = &[_]u8{1},
};

pub fn main() !void {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();
    const allocator = gpa.allocator();

    const args = try std.process.argsAlloc(allocator);
    defer std.process.argsFree(allocator, args);

    const parsed = try flags.parse(args, Args);
    
    // Process each input file
    for (parsed.inputs, 0..) |input, i| {
        const output = if (i < parsed.outputs.len) parsed.outputs[i] else input ++ ".out";
        const mode = if (i < parsed.modes.len) parsed.modes[i] else .compress;
        const thread_count = if (i < parsed.threads.len) parsed.threads[i] else 1;
        
        if (parsed.verbose) {
            std.debug.print("Processing {s} -> {s} (mode: {}, threads: {})\n", 
                .{ input, output, mode, thread_count });
        }
        
        try processFile(input, output, mode, thread_count);
    }
}
```

#### Usage Examples

```bash
# Basic usage with repeated flags
./processor --inputs=file1.txt --inputs=file2.txt --outputs=out1.txt --outputs=out2.txt

# Space-separated values
./processor --inputs file1.txt file2.txt file3.txt --outputs out1.txt out2.txt out3.txt

# Comma-separated values
./processor --inputs=file1.txt,file2.txt,file3.txt --outputs=out1.txt,out2.txt,out3.txt

# Mixed with enum slices
./processor --inputs file1.txt file2.txt --modes compress,encrypt,validate --threads 2 4

# Using defaults
./processor --inputs single-file.txt
```

### Network Scanner Tool

```zig
const Args = struct {
    // List of hosts to scan
    hosts: []const []const u8,
    
    // List of ports to scan on each host
    ports: []u16 = &[_]u16{ 80, 443, 22, 8080 },
    
    // Scan techniques
    techniques: []const enum { tcp, udp, syn, fin } = &[_]enum { tcp, syn },
    
    // Timeout per host in seconds
    timeouts: []u32 = &[_]u32{5},
    
    // Whether to continue on error
    continue_on_error: bool = false,
    
    // Output format
    format: enum { json, csv, table } = .table,
};

pub fn main() !void {
    const parsed = try flags.parse(args, Args);
    
    var scanner = NetworkScanner.init();
    
    for (parsed.hosts, 0..) |host, host_index| {
        const timeout = if (host_index < parsed.timeouts.len) 
            parsed.timeouts[host_index] else parsed.timeouts[parsed.timeouts.len - 1];
        
        for (parsed.ports) |port| {
            for (parsed.techniques) |technique| {
                const result = try scanner.scanHost(host, port, technique, timeout);
                
                switch (parsed.format) {
                    .table => printTableResult(result),
                    .json => printJsonResult(result),
                    .csv => printCsvResult(result),
                }
                
                if (!parsed.continue_on_error and !result.success) {
                    return error.ScanFailed;
                }
            }
        }
    }
}
```

#### Usage Examples

```bash
# Scan multiple hosts with default ports
./scanner --hosts=192.168.1.1 --hosts=192.168.1.2

# Custom ports with different techniques
./scanner --hosts=192.168.1.1,192.168.1.2 --ports=80,443,8080 --techniques=tcp,syn

# Different timeouts per host
./scanner --hosts server1.com server2.com --timeouts 10 15 --ports 22 80 443

# JSON output with custom scan techniques
./scanner --hosts=api.example.com --ports=80,443 --techniques=syn,fin --format=json
```

### Build System Tool

```zig
const Args = struct {
    // List of targets to build
    targets: []const []const u8 = &[_][]const u8{"default"},
    
    // Build configurations
    configs: []const enum { debug, release, release_safe } = &[_]enum { debug },
    
    // Compiler flags per configuration
    flags: []const []const u8 = &[_][]const u8{},
    
    // Include directories
    includes: []const []const u8 = &[_][]const u8{"src", "include"},
    
    // Library paths
    lib_paths: []const []const u8 = &[_][]const u8{},
    
    // Parallel jobs count
    jobs: []u16 = &[_]u16{4},
    
    // Clean before build
    clean: bool = false,
};

pub fn main() !void {
    const parsed = try flags.parse(args, Args);
    
    var builder = Builder.init();
    
    if (parsed.clean) {
        try builder.clean();
    }
    
    // Add include directories
    for (parsed.includes) |include| {
        try builder.addIncludePath(include);
    }
    
    // Add library paths
    for (parsed.lib_paths) |lib_path| {
        try builder.addLibraryPath(lib_path);
    }
    
    // Build each target with each configuration
    for (parsed.targets) |target| {
        for (parsed.configs, 0..) |config, config_index| {
            const jobs = if (config_index < parsed.jobs.len) 
                parsed.jobs[config_index] else parsed.jobs[parsed.jobs.len - 1];
            
            std.debug.print("Building {s} in {s} mode with {} jobs\n", 
                .{ target, @tagName(config), jobs });
            
            const build_result = try builder.build(target, config, jobs, parsed.flags);
            if (!build_result.success) {
                return error.BuildFailed;
            }
        }
    }
}
```

#### Usage Examples

```bash
# Default build
./builder

# Multiple targets and configurations
./builder --targets=server,client,lib --configs=debug,release --jobs 4 8

# With custom flags and include paths
./builder --targets=app --includes=src,external/include,tests --flags="-Wall,-O3" --lib_paths=lib

# Build specific configuration only
./builder --targets=benchmark --configs=release --jobs 16 --clean
```

## Advanced Examples

### Database Migration Tool

```zig
const Args = struct {
    // Migration files to apply
    migrations: []const []const u8,
    
    // Files to skip (optional)
    skip: ?[]const []const u8 = null,
    
    // Migration steps within each file
    steps: []const []const u8 = &[_][]const u8{},
    
    // Database connection strings for different environments
    databases: []const []const u8 = &[_][]const u8{"postgres://localhost:5432/myapp"},
    
    // Migration types
    types: []const enum { schema, data, permission, index } = &[_]enum { schema, data },
    
    // Dry run without executing
    dry_run: bool = false,
    
    // Force apply even if already applied
    force: bool = false,
};

pub fn main() !void {
    const parsed = try flags.parse(args, Args);
    
    var migrator = Migrator.init();
    
    // Connect to all databases
    for (parsed.databases) |db_url| {
        try migrator.addDatabase(db_url);
    }
    
    // Apply each migration
    for (parsed.migrations) |migration_file| {
        // Skip if in skip list
        if (parsed.skip) |skip_list| {
            for (skip_list) |skip_file| {
                if (std.mem.eql(u8, migration_file, skip_file)) {
                    std.debug.print("Skipping migration: {s}\n", .{migration_file});
                    continue;
                }
            }
        }
        
        const migration = try loadMigration(migration_file);
        
        // Apply specific steps if provided
        if (parsed.steps.len > 0) {
            for (parsed.steps) |step| {
                if (migration.hasStep(step)) {
                    if (parsed.dry_run) {
                        std.debug.print("Would apply step {s} from {s}\n", .{ step, migration_file });
                    } else {
                        try migrator.applyStep(migration, step, parsed.force);
                    }
                }
            }
        } else {
            // Apply all steps
            for (parsed.types) |migration_type| {
                const steps_of_type = migration.getStepsByType(migration_type);
                for (steps_of_type) |step| {
                    if (parsed.dry_run) {
                        std.debug.print("Would apply {s} step {s} from {s}\n", 
                            .{ @tagName(migration_type), step, migration_file });
                    } else {
                        try migrator.applyStep(migration, step, parsed.force);
                    }
                }
            }
        }
    }
}
```

#### Usage Examples

```bash
# Apply specific migrations
./migrate --migrations=001_initial.sql --migrations=002_users.sql

# Skip certain migrations and run specific steps
./migrate --migrations=*.sql --skip=001_initial.sql --steps=create_users,create_posts

# Apply to multiple databases with specific migration types
./migrate --migrations=003_*.sql --databases=postgres://prod:5432/app,postgres://staging:5432/app --types=schema,permission

# Dry run to preview changes
./migrate --migrations=004_permissions.sql --dry_run --types=permission

# Force reapply migrations
./migrate --migrations=005_data.sql --force --types=data
```

### Container Orchestration Tool

```zig
const Args = struct {
    // Service definitions
    services: []const []const u8,
    
    // Container images per service
    images: []const []const u8 = &[_][]const u8{},
    
    // Environment variables for services
    env_files: []const []const u8 = &[_][]const u8{".env"},
    
    // Port mappings
    ports: []const []const u8 = &[_][]const u8{},
    
    // Volume mounts
    volumes: []const []const u8 = &[_][]const u8{},
    
    // Network configurations
    networks: []const []const u8 = &[_][]const u8{"default"},
    
    // Deployment strategies
    strategies: []const enum { rolling, recreate, blue_green } = &[_]enum { rolling },
    
    // Health check intervals per service
    health_intervals: []const u32 = &[_]u32{30},
    
    // Replica counts
    replicas: []const u8 = &[_]u8{1},
};

pub fn main() !void {
    const parsed = try flags.parse(args, Args);
    
    var orchestrator = Orchestrator.init();
    
    // Load environment files
    for (parsed.env_files) |env_file| {
        try orchestrator.loadEnvFile(env_file);
    }
    
    // Setup networks
    for (parsed.networks) |network| {
        try orchestrator.createNetwork(network);
    }
    
    // Deploy each service
    for (parsed.services, 0..) |service, i| {
        const image = if (i < parsed.images.len) 
            parsed.images[i] else service;
        
        const strategy = if (i < parsed.strategies.len) 
            parsed.strategies[i] else parsed.strategies[parsed.strategies.len - 1];
        
        const health_interval = if (i < parsed.health_intervals.len) 
            parsed.health_intervals[i] else parsed.health_intervals[parsed.health_intervals.len - 1];
        
        const replica_count = if (i < parsed.replicas.len) 
            parsed.replicas[i] else parsed.replicas[parsed.replicas.len - 1];
        
        const deployment = Deployment{
            .service = service,
            .image = image,
            .strategy = strategy,
            .health_interval = health_interval,
            .replicas = replica_count,
            .ports = if (i < parsed.ports.len) 
                try parsePortMappings(parsed.ports[i]) else &[_]PortMapping{},
            .volumes = if (i < parsed.volumes.len) 
                try parseVolumeMappings(parsed.volumes[i]) else &[_]VolumeMapping{},
        };
        
        try orchestrator.deploy(deployment);
    }
}
```

#### Usage Examples

```bash
# Deploy multiple services
./orchestrator --services=web,api,db --images=nginx:latest,node:16,postgres:13

# With custom configurations
./orchestrator --services web api --images nginx:1.21 node:16-alpine --ports "80:8080,3000:3000" --volumes "/data:/var/lib/data"

# Different deployment strategies
./orchestrator --services frontend backend --strategies rolling blue_green --replicas 3 2

# Complex deployment with environment and networking
./orchestrator --services=app,worker,cache --env=prod.env,prod.env,cache.env --networks=frontend,backend,cache --health-intervals 60 30 45

# Scale existing services
./orchestrator --services=web,api --replicas 5 3 --strategies rolling,rolling
```

## Best Practices

### 1. Slice vs Optional Slices

```zig
const GoodExample = struct {
    // Use empty slice for optional lists
    files: []const []const u8 = &[_][]const u8{},
    
    // Use optional slice when null vs empty matters
    config_files: ?[]const []const u8 = null,
};

const Args = struct {
    // Required slice - must be provided
    inputs: []const []const u8,
    
    // Optional slice with default empty value
    options: []const []const u8 = &[_][]const u8{},
    
    // Optional slice where null means "use system default"
    profiles: ?[]const []const u8 = null,
};
```

### 2. Type Safety with Enum Slices

```zig
const LogLevel = enum { debug, info, warn, error };
const Args = struct {
    // Typed enum slice - compile-time validation
    log_levels: []const LogLevel = &[_]LogLevel{.info, .warn},
    
    // Valid usage only: --log_levels=debug,info,warn
    // Invalid usage caught at parse time: --log_levels=invalid
};
```

### 3. Memory-Efficient Defaults

```zig
const Args = struct {
    // Use empty slices for defaults (no allocation)
    files: []const []const u8 = &[_][]const u8{},
    
    // Avoid large default allocations
    config: []const []const u8 = &[_][]const u8{"/etc/config"},
};
```

### 4. Error Handling

```zig
const parsed = flags.parse(args, Args) catch |err| {
    switch (err) {
        error.InvalidSliceElement => |e| {
            std.log.err("Invalid value in slice: {s}", .{e.message});
        },
        error.MixedSyntax => {
            std.log.err("Cannot mix comma and space separation for the same flag");
        },
        else => {
            std.log.err("Parse error: {s}", .{@errorName(err)});
        }
    }
    return;
};
```

These examples demonstrate the flexibility and power of slice support in flags.zig, enabling complex CLI applications while maintaining type safety and ergonomic usage.