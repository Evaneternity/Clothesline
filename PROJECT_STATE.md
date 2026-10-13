# Clothesline V0.1 — prototype state

Date: 2026-10-12
Reference: Tendedero repository 71b54fd8c571c5ea8c514b56103dfa6bf08a8e74 (reviewed; source visual concepts, MIT)

Status: SOURCE_PROTOTYPE_CORE_TESTS_PASS / MACOS_GUI_BUILD_UNVERIFIED

Functional code: non-sandboxed menu-bar macOS app, user-selected Downloads watcher, filtering/stability gate, Quick Look thumbnail and fallback, rope/pegs/cards, AppKit drag source with copy-only, persisted non-destructive take-down behavior, custom icon, build script.

Validation: `scripts/test-core.sh` passed using Linux Swift compiler (name exclusions, stable samples, quiet window, changed files, deletion/recreation, real folder scan). `swiftc -frontend -parse` checked macOS sources. No macOS build/runtime tested here.

Next gate: Compile & run on macOS 14+/Apple Silicon; fix compiler/UI/TCC issues on evidence, validate real Chrome/Safari downloads and Finder drag and drop before declaring V0.1 complete.
