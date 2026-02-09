# flags.zig Documentation

Complete guide to implementing a Go-like flag parsing library in Zig.

## Quick Navigation

| Document | Purpose | For Whom |
|----------|---------|----------|
| **[API_SPECIFICATION.md](API_SPECIFICATION.md)** | Complete API reference and supported types | Contributors planning work, understanding requirements |
| **[ARCHITECTURE.md](ARCHITECTURE.md)** | Design philosophy, data structures, parsing flow | Contributors implementing the library |
| **[REFERENCE.md](REFERENCE.md)** | Design rationale + comparisons with Go, Python, Rust | Understanding design decisions |
| **[EXAMPLES.md](EXAMPLES.md)** | Working code examples and real-world use cases | Users learning the API |
| **[DESIGN.md](DESIGN.md)** | Design principles and inspirations from other libraries | Understanding design philosophy |

## Getting Started

1. **Want to build a CLI app?** Start with [EXAMPLES.md](EXAMPLES.md) for working code examples
2. **New to the project (contributor)?** Start with [ARCHITECTURE.md](ARCHITECTURE.md) for the big picture
3. **Planning what to implement?** Check [API_SPECIFICATION.md](API_SPECIFICATION.md) for feature list and supported types
4. **Writing code?** See [EXAMPLES.md](EXAMPLES.md) for examples of what you're building
5. **Wondering why a decision?** Read [REFERENCE.md](REFERENCE.md) or [DESIGN.md](DESIGN.md) for design context

## Project Status

- **Current**: Core functionality complete (~60% of MVP)
- **Phase 1 (MVP)**: [x] Basic parsing, types (bool, int, float, string), defaults, enums, optionals, subcommands
- **Phase 2 (Common)**: Partially complete - nested subcommands work
- **Phase 3+ (Polish)**: Planned - validation, short flags, advanced features

## Completed Features

```
[x] Implemented:
  ├─ parse() with struct-based flags
  ├─ Basic types: bool, string, integers, floats
  ├─ Optional types (?T)
  ├─ Enum types with validation
  ├─ Default values via struct fields
  ├─ Subcommands via union(enum)
  ├─ Nested subcommands
  ├─ Help generation via pub const help
  ├─ Error handling: DuplicateFlag, InvalidValue, MissingValue, UnknownFlag, etc.
  └─ Comprehensive test suite (23 tests)

[~] Phase 2 (In Progress):
  ├─ Short flag names (-v)
  ├─ Space-separated values
  ├─ Positional arguments (comptime limitation)
  └─ Validation framework

[ ] Phase 3+ (Planned):
  ├─ Custom type interface
  ├─ Flag aliases
  ├─ Shell completion
  └─ Environment variable binding
```

## Key Design Principles

1. **Type-Driven**: CLI schema defined as Zig structs/unions with comptime parsing
2. **Zero-cost**: No runtime overhead, parsing logic evaluated at compile time
3. **Simple API**: Single `parse(args, Args)` function for all use cases
4. **Extensible**: Custom types via `parse_flag_value` convention

## How to Implement a Feature

1. Find it in [API_SPECIFICATION.md](API_SPECIFICATION.md) - read implementation notes
2. Check [ARCHITECTURE.md](ARCHITECTURE.md) for how it fits in the design
3. See examples in [EXAMPLES.md](EXAMPLES.md)
4. Run tests: `zig build test` to verify your changes

## Old Documentation

Previous docs moved to `_archive/` - these are historical references:
- `_archive/MISSING_FEATURES.md` - Merged into API_SPECIFICATION.md
- `_archive/architecture_guide.md` - Rewritten as ARCHITECTURE.md
- `_archive/examples.md` - Moved to EXAMPLES.md
- `_archive/comparison_with_standards.md` - Merged into REFERENCE.md
- `docs/CLI_INTEGRATION_GUIDE.md` - **Deleted** (documented non-existent API)
- `docs/CODE_PATTERNS.md` - **Deleted** (outdated, use EXAMPLES.md instead)
- `docs/COMPARISON.md` - **Deleted** (merged into REFERENCE.md)
- `docs/design.md` - **Deleted** (duplicate of DESIGN.md)
- `docs/ARCHIVE_RECOVERY_REPORT.md` - **Deleted** (internal working doc)

## Testing Strategy

Each feature should have:
- **Unit tests**: Individual function behavior
- **Integration tests**: Multiple features working together
- **Error tests**: Invalid inputs, edge cases

See ARCHITECTURE.md for test examples.

## Questions?

Check REFERENCE.md for design rationale on:
- Why struct-based parsing instead of builder pattern?
- Why comptime over runtime parsing?
- Why NOT implementing short flags, Duration, callbacks?
- Why TigerBeetle's approach over Go's FlagSet?
