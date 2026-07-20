# Swift code guidelines

## Swift coding standards

You are an experienced Swift developer. When writing and changing code, follow modern, widely accepted Swift practices. For API naming, argument labels, and `///` documentation, see `swift-api-design-guidelines.md`.

### Requirements

- Write idiomatic Swift, not a port of patterns from C#, Java, or other languages.
- Prefer simple, clear, maintainable code.
- Use value types (`struct`, `enum`) by default. Use `class` only when reference semantics, inheritance, or lifecycle control is required.
- Prefer protocols and composition over deep inheritance hierarchies.
- Apply SOLID principles where they genuinely simplify the architecture. Do not add abstractions for their own sake.
- Do not prematurely introduce generic types, protocols, factories, DI containers, or extra layers.
- Avoid overengineering.
- Make dependencies explicit and pass them through initializers.
- Minimize global mutable state and singletons.
- Use strong typing instead of string identifiers and unstructured dictionaries.
- Model state correctly with `enum`, including associated values.
- Do not use force unwrap, force cast, or `try!` except when backed by a provable invariant. Document such cases with a comment.
- Use `guard` for early exits and to reduce nesting.
- Do not ignore errors. Use meaningful error types and propagate them correctly to callers.
- Prefer Swift Concurrency (`async/await`, `Task`, actors) over callback-based APIs unless there is a good reason not to.
- Respect `Sendable`, actor isolation, and structured concurrency rules.
- Do not use `Task.detached`, `@unchecked Sendable`, or unsafe synchronization without explicit need and explanation.
- Do not block threads waiting on asynchronous work.
- For UI code, respect `@MainActor` requirements.
- Consider ownership and retain cycles. Use `[weak self]` only where lifetime semantics truly require it.
- Keep functions and types reasonably small, but do not split code mechanically.
- Names must clearly express intent.
- Comments should explain why and document constraints, not restate the code.
- Preserve the project's existing style and architecture unless they cause a clear problem.
- Do not perform unrelated refactoring.
- Do not change public API without need.
- Respect the project's minimum supported Swift version and target platform (macOS 14.0+, Swift 5).
- Write code that is straightforward to cover with unit tests.
- Add or update tests for non-trivial logic.
- Test behavior and edge cases, not internal implementation details.
- Do not add third-party dependencies when the standard library or system frameworks solve the task reasonably.
- Do not invent framework APIs or capabilities. If unsure, say so explicitly.

### Before changing code

1. Study surrounding code and project conventions.
2. Identify the minimal set of changes required.
3. Check for errors, race conditions, lifetime issues, and backward compatibility risks.
4. Choose the simplest solution that meets the requirements.

### After changing code

1. Verify the project compiles.
2. Run relevant tests and static analysis if available.
3. Check compiler warnings.
4. Briefly summarize what changed.
5. Call out trade-offs, risks, and unverified assumptions.

### Priority when requirements conflict

1. Correctness
2. Data and thread safety
3. Consistency with project architecture
4. Readability and maintainability
5. Simplicity
6. Performance, only when it materially matters for the task

Do not apply a pattern just because it is considered a "best practice." Justify non-trivial architectural choices with concrete task requirements.

## Formatting

- Indent: exactly 2 spaces. No tabs. Continuation lines: +2 spaces.
- UTF-8, POSIX final newline, no trailing whitespace.
- Soft line limit ~100 chars; break earlier when it improves readability.
- Opening `{` on the same line unless wrapping makes a separate line clearer.
- When touching a file that uses a different indent width, re-indent the whole file to 2 spaces.

## Naming (project-specific)

General Swift naming rules: `swift-api-design-guidelines.md`.

- Protocol boundaries use the `*Protocol` suffix.
- Concrete macOS adapters use `Mac*Adapter`.
- Test files and types end in `Tests`; methods start with `test`.

## Language use

- `guard` for early exits; keep the happy path un-nested.
- Tighten access by default (`private`/`fileprivate`/`internal`).
- Mark non-subclassed classes `final`.
- Avoid force-unwrap outside tests or documented invariants.
- Avoid `default` in `switch` when exhaustiveness should stay checked.
- Concurrency: `@MainActor` for UI, serial `DispatchQueue` for pipeline/mutation work, `@unchecked Sendable` only with justification matching existing usage.

## Comments

- Use `//` comments to explain non-obvious why and constraints in implementation code.
- API documentation (`///`): `swift-api-design-guidelines.md`.

## Architecture (overrides generic style on conflict)

- Layers and dependency direction: `App` → `Runtime` → `Domain`, with `Platform` and `Infra` as adapters. Source split: `src/SwitchyOneCore/{App,Runtime,Domain,Platform,Infra}`. Executable bootstrap is separate in `src/SwitchyOne`.
- Boundaries are protocol-driven (`*Protocol`); macOS implementations are `Mac*Adapter`. Constructor injection throughout.
- Configuration is immutable snapshots replaced via `ConfigStore.replace(with:)`. Store observation uses token-style `StoreObservation`.
- Runtime operations return domain result types (`SwitchResult`, `MutationResult`) with `.skipped` / `.failed` payloads. Reserve `throws` for unexpected failures.
- Logging: `AppLogger` (over `OSLog`). Metrics: string-keyed `MetricsProtocol`. Diagnostics surface through `DiagnosticsStore` snapshots.
- UI is SwiftUI pages embedded in an AppKit main window controller.
- Dependencies: Apple frameworks only. Do not add SwiftPM dependencies without explicit approval.
- Tests: single XCTest target, `@testable import SwitchyOneCore`, fakes in `TestSupport/TestDoubles.swift`.

## Pre-finish checklist

Build, architecture, and tests. For API naming and `///`, also run the checklist in `swift-api-design-guidelines.md`.

1. 2-space indent, no tabs.
2. Project patterns respected (`*Protocol`, `Mac*Adapter`, `final`).
3. Access control matches actual usage.
4. Layering and adapter boundaries respected.
5. Tests added or updated; `./scripts/run_tests.sh` is green.
