# flags.zig - Comprehensive API Specification

## Current Implementation Status

**Overall Progress: ~10% Complete**

### Implemented Features [x]
- `parse(args: []const []const u8)` - Flag parsing function accepting args slice
- `string(name, default, description)` - String flag getter with default value
- `boolean(name, default, description)` - Boolean flag getter with default value
- `int(name, default, description)` - Integer flag getter with default value
- Basic `-name=value` and `-flag` parsing syntax
- Global flag storage via StringHashMap
- Flag description metadata storage
- Unit tests for parsing behavior

### Not Yet Implemented [ ]
- All numeric types beyond i32 (Int64, Float64, Uint, Uint64, Duration)
- Pointer-based returns (*T pattern) - Go-style API
- Variable binding functions (IntVar, StringVar, etc.)
- Positional arguments (Arg, Args, NArg)
- Help generation and display
- FlagSet for subcommands/independent contexts
- Error handling strategies (ExitOnError, ContinueOnError, PanicOnError)
- Short flags (-n instead of -name)
- Space-separated values (-name value instead of -name=value)
- Value validation, required flags, action types
- Custom flag types via Value interface

---

## PHASE 1: MVP (Critical - Must Implement First)

### Category 1.1: Core Numeric Types

#### 1.1.1 - `Int()` Function
**Signature:**
```zig
pub fn Int(name: []const u8, value: i64, description: []const u8) i64
```

**Purpose:**
Parse a 64-bit signed integer flag with a default value. Returns the parsed integer or default if flag not provided.

**Implementation Notes:**
- Add `i64` variant to `FlagValues` union
- Update `parse()` to handle numeric parsing: detect `=`, parse value using `std.fmt.parseInt(i64, ...)`
- Handle invalid integers by returning default value (or error, see error cases)
- Store parsed value in StringHashMap entries
- Type must handle both `-name=42` and `-name=-42` (negative numbers)

**Data Structures:**
- Add to `FlagValues` union: `integer: i64` variant
- Update `Flag` struct to track parsed values

**Error Cases:**
- Invalid integer format (e.g., `-port=abc`) → return default, optionally warn
- Overflow/underflow (value outside i64 range) → return default, optionally warn
- Missing value after flag name

**Test Cases:**
```
- Parse valid positive integer: "-port=8080" → 8080
- Parse valid negative integer: "-timeout=-1" → -1
- Parse invalid integer: "-port=abc" → return default
- Parse without value: "-port" (no =) → return default or error
- Multiple same flags: "-port=8080 -port=9000" → last value wins (9000)
- Zero value: "-port=0" → 0
- Max/min i64 values: test boundaries
```

---

#### 1.1.2 - `Int64()` Function
**Signature:**
```zig
pub fn Int64(name: []const u8, value: i64, description: []const u8) i64
```

**Purpose:**
Explicit 64-bit signed integer flag (same as Int, for API compatibility with Go's flag package).

**Implementation Notes:**
- Identical implementation to `Int()` - can be an alias or separate implementation
- Exists for API compatibility; Go has both but they're equivalent

**Data Structures:**
- Reuse `i64` in FlagValues union

**Error Cases:**
- Same as Int()

**Test Cases:**
- Same as Int()

---

#### 1.1.3 - `Uint()` Function
**Signature:**
```zig
pub fn Uint(name: []const u8, value: u64, description: []const u8) u64
```

**Purpose:**
Parse a 64-bit unsigned integer flag with a default value.

**Implementation Notes:**
- Add `u64` variant to `FlagValues` union
- Use `std.fmt.parseInt(u64, ...)` for parsing
- Handle negative numbers: either reject them or clamp to 0
- Similar structure to Int() but for unsigned values

**Data Structures:**
- Add to `FlagValues` union: `uinteger: u64` variant

**Error Cases:**
- Negative numbers provided (e.g., `-count=-5`) → error or return default
- Non-numeric input → return default
- Overflow beyond u64 range → return default

**Test Cases:**
```
- Parse valid positive integer: "-count=100" → 100
- Parse negative integer: "-count=-1" → error or clamp to 0
- Parse invalid: "-count=xyz" → return default
- Zero value: "-count=0" → 0
- Max u64 value test
- Multiple flags: last value wins
```

---

#### 1.1.4 - `Uint64()` Function
**Signature:**
```zig
pub fn Uint64(name: []const u8, value: u64, description: []const u8) u64
```

**Purpose:**
Explicit 64-bit unsigned integer flag (same as Uint, for API compatibility).

**Implementation Notes:**
- Alias or identical to Uint()

**Data Structures:**
- Reuse `u64` in FlagValues union

**Error Cases:**
- Same as Uint()

**Test Cases:**
- Same as Uint()

---

#### 1.1.5 - `Float64()` Function
**Signature:**
```zig
pub fn Float64(name: []const u8, value: f64, description: []const u8) f64
```

**Purpose:**
Parse a 64-bit floating-point flag with a default value.

**Implementation Notes:**
- Add `f64` variant to `FlagValues` union
- Use `std.fmt.parseFloat(f64, ...)` for parsing
- Handle scientific notation: `-ratio=1.5e-3` should work
- Handle both integer and decimal inputs: `-pi=3.14` and `-pi=3` both valid
- Handle negative floats: `-temp=-5.5` should work

**Data Structures:**
- Add to `FlagValues` union: `float: f64` variant

**Error Cases:**
- Invalid float format → return default
- Non-numeric input → return default
- Infinity/NaN → decide behavior (allow or error)

**Test Cases:**
```
- Parse positive float: "-ratio=0.5" → 0.5
- Parse negative float: "-temp=-273.15" → -273.15
- Parse integer as float: "-count=10" → 10.0
- Parse scientific notation: "-ratio=1e-3" → 0.001
- Parse invalid: "-ratio=abc" → return default
- Zero value: "-ratio=0" and "-ratio=0.0" → 0.0
- Very small/large values: test precision
- Multiple flags: last value wins
```

---

#### 1.1.6 - `Duration()` Function
**Signature:**
```zig
pub fn Duration(name: []const u8, value: u64, description: []const u8) u64
```

**Purpose:**
Parse a duration flag in nanoseconds with a default value. Supports human-readable formats like "5s", "100ms", "1h30m".

**Implementation Notes:**
- Accept duration in nanoseconds as default (matching Go's time.Duration)
- Parser must handle: "300ms", "5s", "1h", "1h30m", "100ns", "500us"
- Store value as u64 (nanoseconds internally)
- Create helper function to parse duration strings (separate concern)
  - Split on numeric/non-numeric boundaries
  - Support units: ns, us, ms, s, m, h
  - Support combinations: "1h30m45s" → total nanoseconds
- Return in nanoseconds for internal use

**Data Structures:**
- Add to `FlagValues` union: `duration: u64` variant
- Consider separate Duration parsing module/function

**Error Cases:**
- Invalid unit (e.g., "-timeout=5x") → error or return default
- Invalid numeric portion → error or return default
- Overflow when converting to nanoseconds → error or clamp

**Test Cases:**
```
- Parse seconds: "-timeout=5s" → 5_000_000_000 ns
- Parse milliseconds: "-timeout=500ms" → 500_000_000 ns
- Parse combined: "-timeout=1h30m" → 5400_000_000_000 ns
- Parse nanoseconds: "-timeout=100ns" → 100 ns
- Parse invalid unit: "-timeout=5x" → error
- Parse invalid format: "-timeout=abc" → error
- Zero duration: "-timeout=0s" → 0
- Very large duration: test overflow handling
- Multiple flags: last value wins
```

---

### Category 1.2: Pointer-Based Returns & Variable Binding

#### 1.2.1 - `String()` Function (Pointer Version)
**Signature:**
```zig
pub fn String(name: []const u8, value: []const u8, description: []const u8) *[]const u8
```

**Purpose:**
Define a string flag and return a pointer to it. Allows flag definition before parsing (Go pattern).

**Implementation Notes:**
- Currently returns value directly; must change to return pointer
- This is a BREAKING CHANGE to current API
- After `parse()`, pointer must reference actual stored value in StringHashMap
- Pointer lifetime tied to global StringHashMap lifetime
- Should work like: `const namePtr = String("name", "default", "..."); parse(); use namePtr.*`
- Requires rethinking flag storage strategy - maybe store actual values, not just metadata

**Data Structures:**
- Keep FlagValues union but ensure values persist
- Maintain StringHashMap with long lifetime
- Return pointers into that map

**Error Cases:**
- Value modified after parse() → should reflect actual parsed value
- Pointer validity after multiple parses → ensure reparse updates values

**Test Cases:**
```
- Define flag, parse, access via pointer: namePtr.*
- Multiple pointers to same flag: all reflect same value
- Parse updates pointer value: define before parse, value correct after
- Default value via pointer before parse: pointer default correct
- Pointer persists after parse: multiple accesses consistent
```

---

#### 1.2.2 - `Boolean()` Function (Pointer Version)
**Signature:**
```zig
pub fn Boolean(name: []const u8, value: bool, description: []const u8) *bool
```

**Purpose:**
Define a boolean flag and return a pointer to it (Go pattern).

**Implementation Notes:**
- Return pointer instead of direct value
- Same pattern as String pointer version
- Lifetime tied to StringHashMap

**Data Structures:**
- Reuse FlagValues union with bool variant
- Return pointers into StringHashMap values

**Error Cases:**
- Same as String pointer version

**Test Cases:**
- Same as String pointer version

---

#### 1.2.3 - `IntVar()` Function
**Signature:**
```zig
pub fn IntVar(p: *i64, name: []const u8, value: i64, description: []const u8) void
```

**Purpose:**
Bind a flag to an existing variable. When flag is parsed, the variable is updated directly (Go pattern).

**Implementation Notes:**
- User provides pointer to their own i64 variable
- Store mapping: flag name → pointer to user's variable
- During `parse()`, update the user's variable directly instead of internal map
- Initialize user's variable with default value
- Must handle pointer lifetime carefully (user owns the variable)

**Data Structures:**
- Create new storage: map from flag name to `*i64` (pointer type)
- May need separate maps for each type (IntMap, StringMap, BoolMap)
- Or use a union in value type for pointers

**Error Cases:**
- Null pointer provided → detect and error
- Variable goes out of scope → undefined behavior (user responsibility)
- Invalid flag value → don't update variable, return error

**Test Cases:**
```
- Bind to variable: var x: i64 = 5; IntVar(&x, "count", 10, "..."); parse(); x == parsed_value
- Default value applied: IntVar(&x, "count", 10, "..."); x == 10 before parse
- Multiple parses update variable: parse, check value, parse again, value updated
- Variable isolation: multiple IntVar calls to different vars don't interfere
- Error handling: invalid input doesn't update variable
```

---

#### 1.2.4 - `StringVar()` Function
**Signature:**
```zig
pub fn StringVar(p: *[]const u8, name: []const u8, value: []const u8, description: []const u8) void
```

**Purpose:**
Bind a string flag to an existing variable. Updates the variable when flag is parsed.

**Implementation Notes:**
- Similar to IntVar but for strings
- User provides pointer to their []const u8 variable
- Initialize with default value
- Update during parsing

**Data Structures:**
- Map from flag name to `*[]const u8`

**Error Cases:**
- Null pointer → detect and error
- Variable lifetime issues → user responsibility

**Test Cases:**
- Same pattern as IntVar tests

---

#### 1.2.5 - `BoolVar()` Function
**Signature:**
```zig
pub fn BoolVar(p: *bool, name: []const u8, value: bool, description: []const u8) void
```

**Purpose:**
Bind a boolean flag to an existing variable.

**Implementation Notes:**
- Similar to IntVar and StringVar but for bool
- Initialize with default value

**Data Structures:**
- Map from flag name to `*bool`

**Error Cases:**
- Same as IntVar

**Test Cases:**
- Same pattern as IntVar tests

---

#### 1.2.6 - `Float64Var()`, `UintVar()`, `DurationVar()` Functions
**Signatures:**
```zig
pub fn Float64Var(p: *f64, name: []const u8, value: f64, description: []const u8) void
pub fn UintVar(p: *u64, name: []const u8, value: u64, description: []const u8) void
pub fn DurationVar(p: *u64, name: []const u8, value: u64, description: []const u8) void
```

**Purpose:**
Bind flags to existing variables for Float64, Uint, and Duration types.

**Implementation Notes:**
- Same pattern as IntVar, StringVar, BoolVar
- Create separate maps for each type OR use union-based storage

**Data Structures:**
- Individual maps or unified storage with type information

**Error Cases:**
- Same as IntVar

**Test Cases:**
- Same pattern as IntVar tests

---

### Category 1.3: Positional Arguments

#### 1.3.1 - Update `parse()` to Extract Positional Arguments
**Signature:**
```zig
pub fn parse() !void
```

**Purpose:**
Parse command line arguments and separate flags from positional arguments.

**Implementation Notes:**
- Current implementation only handles flags
- Must distinguish between:
  - Flags: start with `-`, contain `=` or standalone
  - Positional args: everything else, come after flags
- Store positional arguments in separate global array/list
- Handle `--` separator: everything after `--` is positional, even if starts with `-`
- Allow mixed order: `-flag value positional -another-flag` (depends on flag parsing style)

**Data Structures:**
- Add `var positional_args: std.ArrayList([]const u8)` to store positional arguments
- Consider order: do positional args come only after all flags, or mixed?

**Error Cases:**
- Invalid flag format
- Unknown flags (configurable behavior)
- Mixed positional and flag args (validate expected order)

**Test Cases:**
```
- Simple positional: "program -flag=value arg1 arg2" → Args() = [arg1, arg2]
- Positional before flags (check if supported): "program arg1 -flag=value" 
- Double dash separator: "program -flag=value -- -not-a-flag" → Args() = [-not-a-flag]
- No positional args: "program -flag=value" → Args() is empty
- Only positional args: "program arg1 arg2" → Args() = [arg1, arg2]
- Mixed: various combinations depending on design
```

---

#### 1.3.2 - `Arg()` Function
**Signature:**
```zig
pub fn Arg(index: usize) ?[]const u8
```

**Purpose:**
Return the i-th positional argument (0-indexed), or null if index out of bounds.

**Implementation Notes:**
- Access positional_args array at given index
- Return option type (?[]const u8) for safety
- Lazy evaluation: don't parse until parse() is called

**Data Structures:**
- Use positional_args from parse()

**Error Cases:**
- Index out of bounds → return null
- No positional arguments parsed yet → return null

**Test Cases:**
```
- Access first arg: Arg(0) with "prog file1.txt file2.txt"
- Access middle arg: Arg(1) → "file2.txt"
- Out of bounds: Arg(999) → null
- No positional args: Arg(0) → null
- Negative index (if supported): check behavior
```

---

#### 1.3.3 - `Args()` Function
**Signature:**
```zig
pub fn Args() [][]const u8
```

**Purpose:**
Return all remaining positional arguments as a slice.

**Implementation Notes:**
- Return slice/array of all positional arguments
- Empty slice if none present
- Lifetime tied to global storage

**Data Structures:**
- Convert positional_args ArrayList to slice

**Error Cases:**
- No positional arguments → return empty slice
- Called before parse() → undefined behavior or return empty

**Test Cases:**
```
- Multiple args: Args() with multiple files → returns all
- Single arg: Args() returns array with one element
- No args: Args() returns empty slice
- Order preserved: Args() maintains order from command line
```

---

#### 1.3.4 - `NArg()` Function
**Signature:**
```zig
pub fn NArg() usize
```

**Purpose:**
Return the count of remaining positional arguments.

**Implementation Notes:**
- Return length of positional_args array
- Used to check if any positional arguments were provided

**Data Structures:**
- Count of positional_args

**Error Cases:**
- No positional arguments → return 0
- Called before parse() → return 0 or error

**Test Cases:**
```
- Count with multiple args: NArg() with 3 files → 3
- Count with single arg: NArg() → 1
- Count with no args: NArg() → 0
- Matches Args().len: NArg() == Args().len
```

---

### Category 1.4: Help Generation & Display

#### 1.4.1 - `PrintDefaults()` Function
**Signature:**
```zig
pub fn PrintDefaults() void
```

**Purpose:**
Print all flags with their names, types, defaults, and descriptions in a formatted help message.

**Implementation Notes:**
- Iterate through all flags stored in global map
- Format: similar to Go's flag package output
- Include type information: for Int flags show "(default: 42)", for String show "(default \"value\")"
- Sort flags alphabetically for consistency
- Print to stderr or stdout (check Go behavior; typically stdout)
- Example format:
  ```
  Usage of program:
    -active
          Check if user is active (default false)
    -name string
          A name of the user (default "world")
    -port int
          Server port (default 8080)
  ```

**Data Structures:**
- Iterate StringHashMap of flags
- Format each entry based on its FlagValues type

**Error Cases:**
- No flags defined → print minimal usage
- Very long descriptions → handle text wrapping

**Test Cases:**
```
- Single flag: PrintDefaults() with one flag
- Multiple flags: PrintDefaults() with various types
- Sorted output: flags appear in alphabetical order
- Type display: shows "int", "string", "float64", "duration", "bool"
- Default values: shown correctly for each type
- Description wrapping: long descriptions wrap nicely (if implemented)
- Empty descriptions: handles missing descriptions gracefully
```

---

#### 1.4.2 - Help Flag `-h` and `-help`
**Signature:**
```zig
pub fn parse() !void  // Enhanced to handle -h, -help
```

**Purpose:**
Automatically handle `-h` and `-help` flags to print help and exit.

**Implementation Notes:**
- During `parse()`, check for `-h` or `-help` flags
- If detected, call PrintDefaults() and exit with code 0
- Before implementing, decide if this happens before or after user flag definitions
- Consider: should `-h` exit immediately or collect all flag info first?
- Go's flag package has specific behavior for help timing

**Data Structures:**
- Reuse existing parse() and PrintDefaults()

**Error Cases:**
- Custom `-h` flag defined by user: who wins? (Go: library wins)
- Exit behavior: always exit(0) or configurable?

**Test Cases:**
```
- Parse with -h: should print help and exit(0)
- Parse with -help: should print help and exit(0)
- Parse with -help=true: same behavior
- User-defined -h: library behavior takes precedence
- Help output includes all flags: verify completeness
```

---

### Category 1.5: Error Handling & FlagSet Infrastructure

#### 1.5.1 - Error Handling Strategies (Enum)
**Signature:**
```zig
pub const ErrorHandling = enum {
    ExitOnError,      // Exit process on parse error
    ContinueOnError,  // Collect errors, return them
    PanicOnError,     // Panic on error (current behavior)
};
```

**Purpose:**
Define how parse errors are handled: exit, continue, or panic.

**Implementation Notes:**
- Create enum type for error handling behavior
- ExitOnError: call std.process.exit(2) on error
- ContinueOnError: return error as Result{.err = ...}
- PanicOnError: @panic() on error
- Design decision: how to return errors in ContinueOnError mode?
  - Option 1: parse() returns Result union with errors
  - Option 2: collect errors in global list, provide error accessor functions
  - Recommend Option 1 for clarity

**Data Structures:**
- Enum type
- Consider error type for returning: `ParseError` struct with message, flag name

**Error Cases:**
- N/A (this IS the error handling mechanism)

**Test Cases:**
```
- ExitOnError: invalid flag causes exit(2)
- ContinueOnError: invalid flag returns error, execution continues
- PanicOnError: invalid flag causes panic
- Multiple errors: in ContinueOnError, all collected or first stops?
- Error messages: clear and actionable
```

---

#### 1.5.2 - `FlagSet` Type (Subcommands)
**Signature:**
```zig
pub const FlagSet = struct {
    name: []const u8,
    error_handling: ErrorHandling,
    // Internal fields (flags, positional args, etc.)
};
```

**Purpose:**
Create independent flag contexts for subcommands (git add, git commit, etc.).

**Implementation Notes:**
- Each FlagSet is independent: separate flag storage, positional args, etc.
- Constructor function needed: `NewFlagSet(name, error_handling)`
- FlagSet methods: String(), Int(), Boolean(), Float64(), Duration() (and Var variants)
- FlagSet.parse() parses within its own context
- Support chained subcommands: parse() consumes relevant args, remainder available to next FlagSet
- Complexity: requires refactoring global state to per-FlagSet state

**Data Structures:**
```zig
pub const FlagSet = struct {
    name: []const u8,
    error_handling: ErrorHandling,
    flags: std.StringHashMap(Flag),
    positional_args: std.ArrayList([]const u8),
    allocator: std.mem.Allocator,
    
    pub fn NewFlagSet(name: []const u8, error_handling: ErrorHandling) !FlagSet { ... }
    pub fn (self: *FlagSet) String(name: []const u8, value: []const u8, desc: []const u8) *[]const u8 { ... }
    // ... other flag methods
    pub fn (self: *FlagSet) parse(args: [][]const u8) !void { ... }
};
```

**Error Cases:**
- Invalid FlagSet name → error
- Duplicate flag names within FlagSet → error
- Parse errors based on error_handling strategy

**Test Cases:**
```
- Create FlagSet: NewFlagSet("add", ExitOnError)
- Define flags in FlagSet: separate from global flags
- Parse FlagSet: FlagSet.parse() independent
- Multiple FlagSets: "add" and "commit" FlagSets don't interfere
- Subcommand chaining: parse "add" subcommand, then "commit"
- Help for FlagSet: PrintDefaults() within FlagSet
- Error handling: honors FlagSet's error_handling strategy
```

---

#### 1.5.3 - `NewFlagSet()` Function
**Signature:**
```zig
pub fn NewFlagSet(name: []const u8, error_handling: ErrorHandling) !FlagSet
```

**Purpose:**
Create a new independent FlagSet with the given name and error handling strategy.

**Implementation Notes:**
- Allocate new FlagSet struct
- Initialize empty flag storage and positional args
- Store error_handling preference
- Use global or passed allocator?

**Data Structures:**
- FlagSet struct created and initialized

**Error Cases:**
- Allocation failure → error
- Invalid error_handling value → error

**Test Cases:**
- Create with ExitOnError
- Create with ContinueOnError
- Create with PanicOnError
- FlagSet properly initialized and independent

---

### Category 1.6: Enhancements to `parse()`

#### 1.6.1 - Enhanced `parse()` for Type Safety
**Signature:**
```zig
pub fn parse() !void
```

**Purpose:**
Update parse() to handle all new numeric types and properly separate flags from positional arguments.

**Implementation Notes:**
- Handle numeric flag parsing: call appropriate parsers for int, float, duration
- Handle positional argument extraction
- Handle error cases based on error_handling strategy
- Update to support both `-name=value` and (in Phase 2) `-name value`
- Update to support (in Phase 2) short flags like `-n`

**Data Structures:**
- Extend FlagValues union with new variants
- Add positional_args storage

**Error Cases:**
- Invalid numeric format → based on error_handling
- Unknown flags → based on error_handling
- Missing required flags (Phase 2) → based on error_handling

**Test Cases:**
- Parse all types: -int, -float, -duration, -string, -bool
- Positional arguments extracted correctly
- Error handling respected
- Multiple parses: second parse updates values
- Interleaved flags and positional args (if supported)

---

## PHASE 2: Common Features (Should Implement)

### Category 2.1: Advanced Parsing

#### 2.1.1 - Short Flags (`-n` instead of `-name`)
**Signature:**
```zig
pub fn StringShort(short: u8, long: []const u8, value: []const u8, description: []const u8) *[]const u8
```

**Purpose:**
Define both short (`-n`) and long (`-name`) forms of a flag.

**Implementation Notes:**
- Store mapping: single character → flag name
- Accept both forms in parse: `-n value` and `-name value`
- Avoid ambiguity: '-' followed by single char is short, multiple chars is long
- Handle bundled flags: `-abc` means `-a -b -c` (if all are bool or take no args)
- Handle ambiguity: `-abc=value` - which flag gets the value? (first? error?)

**Data Structures:**
- Short-to-long flag map
- Extended Flag struct with short_name field

**Error Cases:**
- Short flag not defined → error or ignore
- Duplicate short names → error
- Bundling ambiguity (some take values, some don't) → error or clarify

**Test Cases:**
```
- Define and parse short flag: -n alice (same as -name alice)
- Both forms work: -n and -name parse to same value
- Bundled bool flags: -abc parsed as -a -b -c
- Bundled with value flag: -nf alice (if -n string, -f bool) → error or specific behavior
- Duplicates: two flags with same short name → error
- Case sensitivity: -N vs -n (if both defined)
```

---

#### 2.1.2 - Space-Separated Values
**Signature:**
```zig
pub fn parse() !void  // Enhanced
```

**Purpose:**
Support both `-name value` and `-name=value` syntax.

**Implementation Notes:**
- Current: only supports `-name=value`
- Enhancement: detect `-name` without `=`, consume next argument as value
- Must handle: `-name value positional` vs `-name=value positional`
- Complexity: must distinguish flag values from positional args
- Design: if `-flag` followed by non-flag argument, that arg is the value
  - A non-flag argument is one that doesn't start with `-` (unless it's a number for negative values)

**Data Structures:**
- Extend parse() logic to lookahead for next argument

**Error Cases:**
- `-flag` at end of args with no value following → error or use default
- `-flag - ` (dash as value) → is `-` a flag or value? (typically value)
- Negative numbers: `-count -5` → is `-5` a value or flag `-5`?

**Test Cases:**
```
- Space syntax: "-name alice" same result as "-name=alice"
- Mixed: "-name=alice -age 30" both work
- Flag at end: "-name" with nothing after → error or default
- Negative numbers: "-count -5" correctly parsed as value -5
- Multiple args: "-host localhost -port 8080" (spacing style)
- Positional after spaced args: "-name alice file.txt" → name=alice, arg=file.txt
```

---

#### 2.1.3 - Multiple Values (Append Action)
**Signature:**
```zig
pub fn StringSlice(name: []const u8, default: [][]const u8, description: []const u8) [][]const u8
```

**Purpose:**
Allow multiple values for a single flag: `-file file1.txt -file file2.txt` accumulates values.

**Implementation Notes:**
- Create ArrayList for each flag supporting multiple values
- Each time flag appears, append value to list
- Return slice of accumulated values
- Question: how to distinguish from "multiple parses"? (parse overwrites vs append mode)
- Design decision: explicit function for multi-valued flags vs implicit based on usage
- Recommend: explicit `StringSlice()` function (separate from `String()`)

**Data Structures:**
- FlagValues union: `string_slice: std.ArrayList([]const u8)` variant
- Or: separate storage for multi-valued flags

**Error Cases:**
- Invalid value for one occurrence → skip or error entire flag?
- Empty value list → return empty slice or default?

**Test Cases:**
```
- Single value: "-file file1.txt" → ["file1.txt"]
- Multiple values: "-file file1.txt -file file2.txt" → ["file1.txt", "file2.txt"]
- Order preserved: "-file a -file b -file c" → order maintained
- Mixed with other flags: "-name alice -file f1 -file f2" → correct grouping
- No values: flag not provided → return default slice
- Empty default: default is empty, results empty
```

---

#### 2.1.4 - Required Flags
**Signature:**
```zig
pub fn StringRequired(name: []const u8, description: []const u8) *[]const u8
```

**Purpose:**
Define a flag that must be provided; error if missing after parse().

**Implementation Notes:**
- Track which flags are required
- After parse(), validate that all required flags were provided
- If missing, error with clear message naming missing flags
- Return pointer like normal String() for compatibility

**Data Structures:**
- Set or list of required flag names
- Flag struct: `required: bool` field

**Error Cases:**
- Required flag not provided → error in parse() or validation step
- Multiple required flags missing → report all in one error message

**Test Cases:**
```
- Required flag provided: parses successfully
- Required flag missing: parse() or post-parse validation errors
- Multiple required flags: some missing → clear error message
- Mixed required and optional: validates correctly
- Error message: lists missing flags by name
```

---

### Category 2.2: Value Validation & Actions

#### 2.2.1 - Value Validation (Ranges)
**Signature:**
```zig
pub fn IntRange(name: []const u8, value: i64, min: i64, max: i64, description: []const u8) i64
```

**Purpose:**
Define an integer flag with range validation; error if value outside [min, max].

**Implementation Notes:**
- Store min/max in Flag metadata
- During parse(), validate parsed value is within range
- If invalid, error or use default
- Consider: should default be validated too? (recommend yes)

**Data Structures:**
- Flag struct: `min: ?i64, max: ?i64` fields (optional for flags without validation)

**Error Cases:**
- Value below minimum → error with message "value must be >= min"
- Value above maximum → error with message "value must be <= max"
- Default outside range → warning or error

**Test Cases:**
```
- Valid value in range: -count=5 with range [1, 10] → 5
- Value below minimum: -count=0 with range [1, 10] → error
- Value above maximum: -count=11 with range [1, 10] → error
- Default in range: default=5, range [1, 10] → default used
- Default out of range: default=0, range [1, 10] → error/warning
- Boundary values: min and max themselves valid
- No range specified: behaves as normal Int flag
```

---

#### 2.2.2 - Choice Validation
**Signature:**
```zig
pub fn StringChoice(name: []const u8, value: []const u8, choices: [][]const u8, description: []const u8) []const u8
```

**Purpose:**
Define a string flag that must be one of specified choices; error if not in list.

**Implementation Notes:**
- Store list of valid choices in Flag metadata
- During parse(), check if value in choices list
- If not, error with message listing valid options
- Case-sensitive or case-insensitive? (recommend case-sensitive)

**Data Structures:**
- Flag struct: `choices: ?[][]const u8` field

**Error Cases:**
- Value not in choices → error with message "must be one of: choice1, choice2, ..."
- Empty choices list → warning or error
- Default not in choices → error/warning

**Test Cases:**
```
- Valid choice: -format=json with choices [json, yaml, xml] → json
- Invalid choice: -format=toml with choices [json, yaml] → error
- Default is valid choice: default=json, choices=[json, yaml] → default used
- Default not in choices: error/warning
- Case handling: "JSON" vs "json" treated differently (case-sensitive)
- All choices present in error message
```

---

#### 2.2.3 - Count Action (for `-vvv` verbosity)
**Signature:**
```zig
pub fn Count(name: []const u8, description: []const u8) i32
```

**Purpose:**
Define a flag that increments a counter each time it appears: `-vvv` → count=3.

**Implementation Notes:**
- Special handling: don't parse value, just count occurrences
- `-v -v -v` → count=3 OR `-vvv` → count=3 (bundled)
- Start count at 0 (or specified default)
- Increment each time flag appears (with or without bundling)

**Data Structures:**
- FlagValues union: `count: i32` variant
- Special parsing logic in parse()

**Error Cases:**
- No flag provided → return 0 (or default)
- Overflow (many -v flags) → clamp to max i32?

**Test Cases:**
```
- Single flag: -v → 1
- Multiple unbundled: -v -v -v → 3
- Bundled: -vvv → 3
- Bundled mixed: -vvv -v → 4
- No flag: count not provided → 0
- Very large count: -vvvvvvvvvvvv → correct count
- Mixed with other flags: -v -name alice -v → v count is 2
```

---

### Category 2.3: Custom Types & Callbacks

#### 2.3.1 - Value Interface (Custom Types)
**Signature:**
```zig
pub const Value = interface {
    fn Set(self: *anyopaque, s: []const u8) !void,
    fn String(self: *anyopaque) []const u8,
};
```

**Purpose:**
Allow users to define custom flag types by implementing the Value interface.

**Implementation Notes:**
- Define interface (or duck-typed protocol)
- User implements Set() to parse string, String() to format value
- FlagSet.Var() method to register custom type
- During parse(), call Set(string_value) on custom types

**Data Structures:**
- FlagValues union: custom type variant (or function pointers)
- Consider: how to store arbitrary user types?
  - Option 1: FlagValues union with `custom: *anyopaque` + function pointers
  - Option 2: Separate custom value storage with type-erased interface

**Error Cases:**
- Set() returns error → parse error
- Invalid interface implementation → compile error (type safety)

**Test Cases:**
```
- Define custom type (e.g., IPv4 address)
- Register via Var()
- Parse custom flag: "-addr=192.168.1.1"
- Validate custom parsing: correct IPv4 parsed
- Error handling: invalid IPv4 errors gracefully
- Multiple custom types: different custom types coexist
- String representation: String() formats correctly
```

---

#### 2.3.2 - Callback Functions (Func, BoolFunc)
**Signature:**
```zig
pub fn Func(name: []const u8, description: []const u8, fn_ptr: *const fn ([]const u8) !void) void
pub fn BoolFunc(name: []const u8, description: []const u8, fn_ptr: *const fn (bool) !void) void
```

**Purpose:**
Execute a custom function when a flag is parsed, enabling dynamic behavior.

**Implementation Notes:**
- Store function pointer with flag metadata
- During parse(), call function with parsed value
- Return type: void (side effects only) or error
- Function called immediately as flag is parsed, or deferred to after parse()?
- Recommend: deferred to after parse (simpler error handling)

**Data Structures:**
- Flag struct: `callback: ?*const fn(...) !void` field

**Error Cases:**
- Callback returns error → parse error
- Callback modifies global state → user responsible for consistency

**Test Cases:**
```
- Define callback: Func("verbose", ..., &setVerbosity)
- Parse trigger: -verbose called setVerbosity()
- Error in callback: parse fails with callback error
- Multiple callbacks: each flag's callback called
- Callback order: callbacks in definition order or appearance order?
- No callback: normal flag behavior
```

---

## PHASE 3: Polish & Advanced Features

### Category 3.1: Help & Documentation (ESSENTIAL POLISH)

#### 3.1.1 - Flag Grouping in Help
**Signature:**
```zig
pub fn StringGroup(group: []const u8, name: []const u8, value: []const u8, description: []const u8) *[]const u8
```

**Purpose:**
Group related flags together in help output for better organization.

**Implementation Notes:**
- Store group name with each flag
- PrintDefaults() organizes output by group, with headers
- Groups like "Input", "Output", "Advanced", "Debugging"
- Within group, still sort alphabetically
- Example output:
  ```
  Input:
    -file string
          Input file path
    -format string
          File format (default "json")
  
  Output:
    -output string
          Output file path
  ```

**Data Structures:**
- Flag struct: `group: ?[]const u8` field
- PrintDefaults() groups by this field

**Error Cases:**
- Ungrouped flags → "General" or "Options" default group
- Empty group name → error or default

**Test Cases:**
```
- Define grouped flags: StringGroup("Input", "file", ...)
- PrintDefaults shows groups: "Input:", "Output:", headers visible
- Alphabetical within group: flags sorted per group
- Default group: ungrouped flags appear in default group
- Multiple groups: all groups represented
- Group order: by first flag in group or explicit?
```

---

#### 3.1.2 - Flag Aliases
**Signature:**
```zig
pub fn StringAlias(name: []const u8, alias: []const u8, value: []const u8, description: []const u8) *[]const u8
```

**Purpose:**
Define multiple names for the same flag: `-v` and `--verbose` reference the same value.

**Implementation Notes:**
- Store alias mappings: "v" → "verbose", "verbose" → "verbose" (canonical)
- Parse accepts either form
- Value shared between aliases (point to same storage)
- Help shows primary name and aliases: `-v, --verbose`

**Data Structures:**
- Alias map: short/alt name → canonical name
- Flag storage keyed by canonical name

**Error Cases:**
- Duplicate alias → error
- Alias same as existing flag → error
- Circular aliases → error

**Test Cases:**
```
- Parse via primary: -verbose=true
- Parse via alias: -v=true (same storage)
- Help display: shows both names "-v, --verbose"
- Multiple aliases: multiple names for one flag
- No aliases: normal flag behavior
- Canonical consistency: regardless of which name used, value same
```

---

#### 3.1.3 - Mutually Exclusive Groups
**Signature:**
```zig
pub fn StringExclusive(group: []const u8, name: []const u8, value: []const u8, description: []const u8) *[]const u8
```

**Purpose:**
Define flags that cannot be used together: `-json` and `-yaml` mutually exclusive.

**Implementation Notes:**
- Store exclusive group names with flags
- During parse validation, check: at most one flag from group provided
- Error if multiple flags from same group used
- Error message: "cannot use both -json and -yaml"

**Data Structures:**
- Flag struct: `exclusive_group: ?[]const u8` field
- Validation after parse() checks groups

**Error Cases:**
- Multiple flags from exclusive group → error with message
- No flags from exclusive group → valid (optional)
- Required exclusive group: exactly one required (Phase 2 feature)

**Test Cases:**
```
- Single flag from group: -json → valid
- Two flags from same group: -json -yaml → error
- Multiple groups: different exclusive groups independent
- None from group: valid (optional)
- Help display: notes mutual exclusivity (if implemented)
```

---

#### 3.1.4 - Typo Suggestions
**Signature:**
```zig
pub fn parse() !void  // Enhanced with suggestions
```

**Purpose:**
Suggest close matches when user provides unknown flag: "Did you mean --verbose?"

**Implementation Notes:**
- On unknown flag error, calculate string similarity (Levenshtein distance)
- Find closest matching known flag
- Include suggestion in error message if similarity above threshold
- Threshold: suggest if within 2 edit distances? (tunable)
- Example error: "unknown flag -verbode. Did you mean -verbose?"

**Data Structures:**
- Implement similarity function (Levenshtein or similar)
- Integration point: parse() error handling

**Error Cases:**
- No close matches → error without suggestion
- Multiple close matches → suggest all or just closest?
- Exact match unlikely: typos typically 1-2 character differences

**Test Cases:**
```
- Typo suggestion: -verbode → suggests -verbose
- No match: -xyz → error without suggestion
- Multiple candidates: -verbse → suggests -verbose
- Edit distance threshold: verify threshold used
- Existing flag: exact match takes precedence
```

---

### Category 3.2: Display & Formatting (ESSENTIAL POLISH)

#### 3.2.1 - Colorized Output
**Signature:**
```zig
pub fn PrintDefaults() void  // Enhanced with colors
```

**Purpose:**
Add ANSI color codes to help output for better readability.

**Implementation Notes:**
- Color categories:
  - Flag names: bright cyan
  - Default values: yellow
  - Descriptions: white/normal
  - Types: dim or gray
- Check terminal support: only colorize if stdout is TTY
- Allow disabling via env var: `NO_COLOR=1` (standard)
- Example:
  ```
  [cyan]-name[reset] [dim]string[reset]
          [normal]A name of the user[reset] ([yellow]default "world"[/yellow])
  ```

**Data Structures:**
- Helper functions for color codes
- Check isatty() before applying colors

**Error Cases:**
- Non-TTY output (pipe, redirect) → no colors
- Terminal doesn't support colors → graceful degradation
- NO_COLOR env var → disable colors

**Test Cases:**
```
- TTY output: colors applied
- Piped output: no colors
- NO_COLOR set: no colors even on TTY
- Color codes present: verify ANSI codes in output
- Color vs non-color: same text, different formatting
```

---

#### 3.2.2 - Help Template Customization
**Signature:**
```zig
pub fn SetHelpTemplate(template: []const u8) void
```

**Purpose:**
Allow custom help text formatting instead of default template.

**Implementation Notes:**
- Template variables: {{.Name}}, {{.Description}}, {{.Usage}}, {{.Flags}}, etc.
- Parse template with simple substitution
- Users can create branded help output
- Default template provided for standard behavior
- Example template:
  ```
  Usage: {{.Name}} [options] [args...]
  
  {{.Description}}
  
  Options:
  {{range .Flags}}
    {{.Name}}: {{.Description}} (default: {{.Default}})
  {{end}}
  ```

**Data Structures:**
- Store template string
- ParseTemplate function to render with variables

**Error Cases:**
- Invalid template syntax → error
- Missing variables in template → substitution skipped or error

**Test Cases:**
```
- Custom template: SetHelpTemplate(...) with custom format
- Default template: no call to SetHelpTemplate uses default
- Template rendering: {{.Name}} substituted correctly
- All variables present: {{.Name}}, {{.Description}}, {{.Flags}}, etc.
- Invalid template: error handling
```

---

### Category 3.3: Advanced Features (ADVANCED)

#### 3.3.1 - Metavar (Display Names)
**Signature:**
```zig
pub fn StringMetavar(name: []const u8, metavar: []const u8, value: []const u8, description: []const u8) *[]const u8
```

**Purpose:**
Show custom name in help for clarity: "FILE" instead of "string".

**Implementation Notes:**
- Store metavar with flag
- PrintDefaults() shows: `-input FILE` instead of `-input string`
- Useful for clarity: `-name STRING` vs `-name string`
- Example help output:
  ```
  -input FILE
          Path to input file
  -count INT
          Number of items (default 10)
  ```

**Data Structures:**
- Flag struct: `metavar: ?[]const u8` field

**Error Cases:**
- Empty metavar → use default type name
- No metavar specified → use type name ("string", "int", etc.)

**Test Cases:**
```
- Define metavar: StringMetavar("file", "FILE", ...)
- Help display: shows "FILE" not "string"
- Default type: no metavar shows default type name
- Capitalization: metavar case preserved (FILE, File, file)
- Multiple flags: each has own metavar if specified
```

---

#### 3.3.2 - Environment Variable Binding
**Signature:**
```zig
pub fn StringEnv(name: []const u8, env_var: []const u8, default: []const u8, description: []const u8) *[]const u8
```

**Purpose:**
Bind flag to environment variable with priority: CLI > env > default.

**Implementation Notes:**
- Check env var if flag not provided via CLI
- Priority: CLI flag value > env var > provided default
- Example: `-host localhost` uses CLI, no flag → use HOST env, no env → use default
- Env var name typically uppercase version of flag name

**Data Structures:**
- Flag struct: `env_var: ?[]const u8` field
- During parse(), check env vars

**Error Cases:**
- Env var not set → use default
- Env var set but invalid → treat as default or error?
- Both CLI and env provided → CLI wins

**Test Cases:**
```
- CLI flag provided: uses CLI value (env ignored)
- CLI flag missing, env set: uses env value
- Both missing: uses default
- Env invalid format: fallback to default or error
- Env overrides: verify priority correct
```

---

#### 3.3.3 - Hidden Flags
**Signature:**
```zig
pub fn StringHidden(name: []const u8, value: []const u8, description: []const u8) *[]const u8
```

**Purpose:**
Define flags that work but don't appear in help (for deprecated/internal flags).

**Implementation Notes:**
- Flag works normally during parsing
- PrintDefaults() skips hidden flags
- Use case: deprecated flag `-old-name` still works but not shown
- Users can still use if they know about it

**Data Structures:**
- Flag struct: `hidden: bool` field

**Error Cases:**
- No hidden flags: normal behavior
- All flags hidden: help shows "Usage: ..." only

**Test Cases:**
```
- Hidden flag works: -deprecated=value → parses correctly
- Hidden in help: PrintDefaults() doesn't show hidden flag
- Mixed hidden/visible: visible flags shown, hidden omitted
- Help otherwise complete: all non-hidden flags shown
```

---

#### 3.3.4 - Configuration File Support
**Signature:**
```zig
pub fn LoadConfigFile(path: []const u8) !void
```

**Purpose:**
Load flags from JSON/YAML config files as alternative to CLI args.

**Implementation Notes:**
- Parse config file format (recommend JSON for simplicity)
- Config file values override defaults, CLI values override config
- Priority: CLI > config > default
- Example JSON:
  ```json
  {
    "host": "localhost",
    "port": 8080,
    "workers": 4,
    "verbose": true
  }
  ```
- Alternative: YAML, TOML (more complex)
- Integration: LoadConfigFile() before parse(), or merged in parse()?

**Data Structures:**
- Config file parser (JSON)
- Merge config values into flag defaults

**Error Cases:**
- File not found → error or silent ignore?
- Invalid JSON → error with line number
- Unknown keys in config → error or ignore?
- Type mismatch in config → error or coerce

**Test Cases:**
```
- Load valid config: LoadConfigFile("config.json")
- File not found: error or graceful failure
- Invalid JSON: error with details
- Config values used: flags not in CLI take config values
- Priority: CLI > config > default verified
- Type validation: config values must match flag types
```

---

#### 3.3.5 - Shell Completion
**Signature:**
```zig
pub fn GenerateCompletion(shell: []const u8) ![]const u8
```

**Purpose:**
Generate shell completion scripts for bash/zsh/fish.

**Implementation Notes:**
- Support bash, zsh, fish shells
- Generate script that provides flag name completion
- Example: `program -[TAB]` completes to known flags
- Advanced: value completion based on choices (e.g., -format [json|yaml])
- Output shell script to stdout or file

**Data Structures:**
- Completion templates per shell
- Integration with flag metadata (choices, value types)

**Error Cases:**
- Unknown shell → error or list supported
- No completions available → minimal completion

**Test Cases:**
```
- Generate bash completion: GenerateCompletion("bash")
- Generate zsh completion: GenerateCompletion("zsh")
- Completion triggers: program -[TAB] shows flags
- Value completion: -format [TAB] shows [json, yaml]
- Install completion: script installable in ~/.bash_completion
```

---

#### 3.3.6 - Version Flag Auto-Generation
**Signature:**
```zig
pub fn SetVersion(version: []const u8) void
```

**Purpose:**
Automatically handle `-version` flag to display version.

**Implementation Notes:**
- Store version string
- Automatically create `-version` flag
- Separate from `-v` (which might be `-verbose`)
- Parse sees `-version`, prints version, exits
- Works similarly to help flag auto-generation

**Data Structures:**
- Version string storage
- Auto-registered flag in parse()

**Error Cases:**
- User defines own `-version` flag → library flag takes precedence (like help)
- No version set → flag not registered or shows "unknown"

**Test Cases:**
```
- SetVersion("1.0.0"): version stored
- Parse with -version: prints "version 1.0.0" and exits
- No SetVersion call: -version flag not available
- Help doesn't show -version in -h output (special case)
```

---

## Testing Strategy

### Unit Tests
- Test each function individually with valid, invalid, and edge case inputs
- Test type parsing (Int, Float, Duration, String, Bool)
- Test error handling for each error_handling strategy
- Test pointer returns and variable binding
- Test positional argument extraction

### Integration Tests
- Test full parsing workflows combining multiple features
- Test FlagSet independence and non-interference
- Test priority systems (CLI > env > config > default)
- Test error message clarity and suggestions

### Regression Tests
- Ensure new features don't break existing API
- Test backwards compatibility (if maintaining)
- Test Phase 1 features still work when Phase 2 added

### Performance Tests
- Large number of flags (1000+)
- Large argument lists
- FlagSet creation and parsing

---

## Implementation Priority

1. **MUST DO FIRST**: Phase 1 core types (Int, Float, Duration) - blocks all real use
2. **MUST DO EARLY**: Pointer returns and Var functions - API compatibility
3. **MUST DO EARLY**: Positional arguments (Arg, Args, NArg) - required for usable CLI
4. **MUST DO EARLY**: Help generation - users need to learn how to use
5. **SHOULD DO EARLY**: FlagSet - enables subcommands (common pattern)
6. **SHOULD DO**: Error handling strategies - essential for robust CLI
7. **THEN PHASE 2**: Common features (short flags, validation, actions)
8. **THEN PHASE 3**: Polish and advanced features
