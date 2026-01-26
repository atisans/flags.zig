# flags.zig Documentation

Complete guide to implementing a Go-like flag parsing library in Zig.

## Quick Navigation

| Document | Purpose | For Whom |
|----------|---------|----------|
| **[CLI_INTEGRATION_GUIDE.md](CLI_INTEGRATION_GUIDE.md)** | How to build CLI applications using flags.zig | Developers building command-line tools |
| **[API_SPECIFICATION.md](API_SPECIFICATION.md)** | What to build: all features with implementation notes | Contributors planning work, understanding requirements |
| **[ARCHITECTURE.md](ARCHITECTURE.md)** | How to build it: design, data structures, parsing flow (with diagrams) | Contributors implementing the library |
| **[CODE_PATTERNS.md](CODE_PATTERNS.md)** | Working code examples: 12 patterns from basic to advanced | Contributors learning patterns, users learning API |
| **[REFERENCE.md](REFERENCE.md)** | Why these choices: comparison with Go, Python, Rust + design rationale | Understanding design decisions, context for architecture |

## Getting Started

1. **Want to build a CLI app?** Start with [CLI_INTEGRATION_GUIDE.md](CLI_INTEGRATION_GUIDE.md) for practical examples
2. **New to the project (contributor)?** Start with [ARCHITECTURE.md](ARCHITECTURE.md) for the big picture
3. **Planning what to implement?** Check [API_SPECIFICATION.md](API_SPECIFICATION.md) for feature list and phases
4. **Writing code?** See [CODE_PATTERNS.md](CODE_PATTERNS.md) for examples of what you're building
5. **Wondering why a decision?** Read [REFERENCE.md](REFERENCE.md) for design context

## Project Status

- **Current**: 5% complete (basic string/bool parsing only)
- **Phase 1 (MVP)**: 43 features - parsing, types, help, FlagSet
- **Phase 2 (Common)**: 11 features - validation, subcommands, custom types
- **Phase 3 (Polish)**: 8 features - advanced options (marked clearly as "ADVANCED")

## Implementation Timeline

```
Phase 1 (MVP): 50-60 hours
  └─ Parse(), String/Bool/Int/Float/Uint types, help generation, FlagSet basics

Phase 2 (Common): 50-70 hours
  └─ Positional args, Value interface, error handling, subcommands

Phase 3 (Polish): 30-40 hours
  └─ Flag abbreviation, visiting, advanced features marked "ADVANCED"
```

## Key Design Principles

1. **Go-like API**: Procedural with pointer returns (not Python/Rust style)
2. **FlagSet-based**: Supports subcommands from the start
3. **Value interface**: Extensible to custom types without modification
4. **Clear phases**: Phase 1 is essential, Phase 3 is nice-to-have

## How to Implement a Feature

1. Find it in [API_SPECIFICATION.md](API_SPECIFICATION.md) - read implementation notes
2. Check [ARCHITECTURE.md](ARCHITECTURE.md) for how it fits in the design
3. See examples in [CODE_PATTERNS.md](CODE_PATTERNS.md)
4. Implement with reference to test cases in API_SPECIFICATION.md

## Old Documentation

Previous docs moved to `_archive/` - these are historical references:
- `_archive/MISSING_FEATURES.md` - Merged into API_SPECIFICATION.md
- `_archive/architecture_guide.md` - Rewritten as ARCHITECTURE.md
- `_archive/examples.md` - Moved to CODE_PATTERNS.md
- `_archive/comparison_with_standards.md` - Merged into REFERENCE.md
- (and others)

## Testing Strategy

Each feature should have:
- **Unit tests**: Individual function behavior
- **Integration tests**: Multiple features working together
- **Error tests**: Invalid inputs, edge cases

See ARCHITECTURE.md for test examples.

## Questions?

Check REFERENCE.md for design rationale on:
- Why pointer returns instead of values?
- Why FlagSet from Phase 1?
- Why NOT implementing Duration, callbacks, mutually exclusive groups?
- Why Go's approach over Python/Rust?
