# Slice Support Implementation Guide

This document provides detailed technical guidance for implementing slice support in flags.zig.

## Overview

Slice support allows users to specify multiple values for a single flag using three syntax patterns:
1. **Repeated flags**: `--files=a.txt --files=b.txt --files=c.txt`
2. **Space-separated**: `--files a.txt b.txt c.txt`
3. **Comma-separated**: `--files=a.txt,b.txt,c.txt`

## Core Implementation Changes

### 1. Type Detection (parse_scalar_value function)

```zig
fn parse_scalar_value(comptime T: type, value: ?[]const u8) !T {
    // ... existing logic for other types
    
    switch (@typeInfo(T)) {
        .pointer => |ptr| {
            if (ptr.size == .Slice) {
                return parse_slice_value(ptr.child, value);
            }
            // Handle existing pointer types
        },
        // ... other existing cases
    }
}
```

### 2. Flag Counting Logic (parse_flags function)

Replace the duplicate flag check for slice types:

```zig
if (std.mem.eql(u8, flag_name, field.name)) {
    found = true;
    if (counts[field_index] > 0 and !comptime is_slice(field.type)) {
        return Error.DuplicateFlag;
    }
    counts[field_index] += 1;
    
    if (comptime is_slice(field.type)) {
        // Accumulate slice values
        try accumulate_slice_value(&result, field.name, field.type, flag_value);
    } else {
        @field(result, field.name) = try parse_flag_value(field.type, flag_value);
    }
    break;
}
```

### 3. Memory Management

#### Arena-Based Allocation

```zig
fn parse_flags(args: []const []const u8, comptime T: type, start_index: usize) !T {
    const allocator = std.heap.page_allocator; // Or passed in allocator
    var arena = std.heap.ArenaAllocator.init(allocator);
    defer arena.deinit();
    
    var result: T = undefined;
    var slice_accumulator = SliceAccumulator.init(arena.allocator());
    
    // ... parsing logic
}
```

#### Slice Accumulator Structure

```zig
const SliceAccumulator = struct {
    allocator: std.mem.Allocator,
    values: std.StringHashMap(std.ArrayList([]const u8)),
    
    fn init(allocator: std.mem.Allocator) SliceAccumulator {
        return .{
            .allocator = allocator,
            .values = std.StringHashMap(std.ArrayList([]const u8)).init(allocator),
        };
    }
    
    fn add(self: *SliceAccumulator, field_name: []const u8, value: []const u8) !void {
        const entry = try self.values.getOrPut(field_name);
        if (!entry.found_existing) {
            entry.value_ptr.* = std.ArrayList([]const u8).init(self.allocator);
        }
        try entry.value_ptr.append(value);
    }
    
    fn finalize(self: *SliceAccumulator, field_name: []const u8, comptime T: type) !T {
        if (self.values.get(field_name)) |values| {
            return values.toOwnedSlice();
        }
        return &[_]@typeInfo(T).pointer.child{};
    }
};
```

## Parsing Algorithm Implementation

### 1. Syntax Pattern Detection

```zig
const SliceSyntax = enum {
    Repeated,      // --files=a.txt --files=b.txt
    SpaceSeparated, // --files a.txt b.txt c.txt
    CommaSeparated, // --files=a.txt,b.txt,c.txt
};

fn detect_slice_syntax(arg: []const u8, flag_value: ?[]const u8) SliceSyntax {
    // Determine syntax pattern based on current context
}
```

### 2. Value Extraction

```zig
fn extract_slice_values(
    args: []const []const u8, 
    current_index: *usize, 
    field_name: []const u8,
    syntax: SliceSyntax
) ![][]const u8 {
    var values = std.ArrayList([]const u8).init(allocator);
    
    switch (syntax) {
        .CommaSeparated => {
            const raw = args[current_index.*][2 + field_name.len + 1 ..]; // Skip "--name="
            var iter = std.mem.splitScalar(u8, raw, ',');
            while (iter.next()) |value| {
                try values.append(value);
            }
            current_index.* += 1;
        },
        .SpaceSeparated => {
            current_index.* += 1; // Skip the flag itself
            while (current_index.* < args.len) {
                const arg = args[current_index.*];
                if (std.mem.startsWith(u8, arg, "--")) break;
                if (std.mem.startsWith(u8, arg, "-")) break;
                try values.append(arg);
                current_index.* += 1;
            }
        },
        .Repeated => {
            // Single value from this flag, more may come in subsequent iterations
            if (std.mem.indexOfScalar(u8, args[current_index.*], '=')) |pos| {
                const value = args[current_index.*][pos + 1..];
                try values.append(value);
            }
            current_index.* += 1;
        }
    }
    
    return values.toOwnedSlice();
}
```

### 3. Mixed Syntax Handling

```zig
fn validate_slice_consistency(
    accumulator: *SliceAccumulator, 
    field_name: []const u8,
    new_syntax: SliceSyntax
) !void {
    if (accumulator.getSyntax(field_name)) |existing_syntax| {
        if (existing_syntax != new_syntax) {
            return Error.MixedSyntax;
        }
    } else {
        accumulator.setSyntax(field_name, new_syntax);
    }
}
```

## Error Handling Implementation

### New Error Types

```zig
pub const Error = error{
    // ... existing errors
    InvalidSliceElement,  // "Invalid value 'not_a_number' in --ports at position 2"
    EmptySlice,           // "Slice --files cannot be empty"
    MixedSyntax,          // "Cannot mix repeated flags with space-separated values for --files"
};
```

### Contextual Error Messages

```zig
fn format_slice_error(err: Error, field_name: []const u8, element_index: ?usize, invalid_value: ?[]const u8) []const u8 {
    return switch (err) {
        .InvalidSliceElement => std.fmt.allocPrint(
            allocator,
            "Invalid value '{s}' in --{s} at position {d}",
            .{ invalid_value.?, field_name, element_index.? }
        ),
        .EmptySlice => std.fmt.allocPrint(
            allocator,
            "Slice --{s} cannot be empty when required",
            .{field_name}
        ),
        .MixedSyntax => std.fmt.allocPrint(
            allocator,
            "Cannot mix repeated flags with space-separated values for --{s}",
            .{field_name}
        ),
        else => @errorName(err),
    };
}
```

## Help Generation Updates

### Slice Type Detection

```zig
fn print_auto_help(comptime T: type) void {
    switch (@typeInfo(T)) {
        .@"struct" => {
            const fields = std.meta.fields(T);
            std.debug.print("Options:\n", .{});
            inline for (fields) |field| {
                if (comptime is_slice(field.type)) {
                    const child_type = @typeInfo(field.type).pointer.child;
                    std.debug.print("  --{s:<20} []{s} (multiple values allowed)\n", .{
                        field.name, @typeName(child_type)
                    });
                } else {
                    // ... existing help logic
                }
            }
        },
        // ... other cases
    }
}
```

### Slice Help Examples

```zig
const Args = struct {
    files: []const []const u8 = &[_][]const u8{},
    ports: []u16 = &[_]u16{8080},
    tags: []const []const u8 = &[_][]const u8{},
};

// Auto-generated help output:
// Options:
//   --files              []const u8 (multiple values allowed)
//   --ports              []u16 (multiple values allowed)  
//   --tags               []const u8 (multiple values allowed)
```

## Testing Strategy

### Unit Test Categories

1. **Basic Slice Parsing**
   - Repeated flags
   - Space-separated values
   - Comma-separated values
   - Mixed value types

2. **Error Conditions**
   - Invalid slice elements
   - Empty slices
   - Mixed syntax detection
   - Type validation failures

3. **Memory Management**
   - Arena cleanup
   - Large slice handling
   - Memory leak prevention

4. **Integration Tests**
   - Slices with other flag types
   - Slices in subcommands
   - Positional arguments with slices

### Test Examples

```zig
test "parse repeated flags" {
    const Args = struct {
        files: []const []const u8 = &[_][]const u8{},
    };
    
    const flags = try parse(&.{ "prog", "--files=a.txt", "--files=b.txt" }, Args);
    try std.testing.expect(flags.files.len == 2);
    try std.testing.expect(std.mem.eql(u8, flags.files[0], "a.txt"));
    try std.testing.expect(std.mem.eql(u8, flags.files[1], "b.txt"));
}

test "parse space-separated values" {
    const Args = struct {
        files: []const []const u8 = &[_][]const u8{},
    };
    
    const flags = try parse(&.{ "prog", "--files", "a.txt", "b.txt", "c.txt" }, Args);
    try std.testing.expect(flags.files.len == 3);
}

test "mixed syntax error" {
    const Args = struct {
        files: []const []const u8 = &[_][]const u8{},
    };
    
    try std.testing.expectError(Error.MixedSyntax, 
        parse(&.{ "prog", "--files=a.txt", "--files", "b.txt" }, Args));
}
```

## Performance Considerations

### Optimization Strategies

1. **Pre-allocation**: Estimate slice capacity based on argument count
2. **Batch Processing**: Process all values for a slice at once when possible
3. **Type Specialization**: Generate optimized code for common slice types
4. **Memory Locality**: Allocate slice elements contiguously

### Benchmark Tests

```zig
test "benchmark slice parsing" {
    const start_time = std.time.nanoTimestamp();
    
    // Parse large number of slice values
    const flags = try parse(large_args, Args);
    
    const end_time = std.time.nanoTimestamp();
    const duration_ns = end_time - start_time;
    
    std.debug.print("Slice parsing took {d} ns\n", .{duration_ns});
}
```

## Migration Guide

### From Single Values to Slices

```zig
// Before (single value)
const Args = struct {
    file: []const u8 = "default.txt",
};

// After (slice)
const Args = struct {
    files: []const []const u8 = &[_][]const u8{"default.txt"},
};
```

### Backward Compatibility

- Existing code using single values remains unchanged
- No breaking changes to the API
- Optional upgrade path for multiple values

This implementation guide provides the foundation for adding robust slice support to flags.zig while maintaining the library's principles of type safety, zero-cost abstractions, and developer experience.