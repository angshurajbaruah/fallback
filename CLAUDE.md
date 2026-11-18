# Fallback
Mac menu-bar app that records every file the user sends and warns
before the wrong one goes out. Full spec: PRD.md. Requirement IDs
(FR-x, NFR-x, W1-W5) come from it.

## Stack
Swift 6 (strict concurrency), SwiftUI + AppKit, macOS 14+.
XcodeGen (project.yml): never edit .xcodeproj by hand, run `make gen`.
Core logic in Packages/FallbackCore (no AppKit imports there).
GRDB for SQLite. Sparkle for updates. No other dependencies
without asking.

## Design
UI follows Design/ in the repo root: BRAND.md and tokens.json
for styling, COPY.md and screens/*.png for wording and layout.
The PRD wins on behaviour. Every colour, font size and radius
lives in one Theme.swift built from tokens.json: no hex values
in views. Burnt Tangerine is for warnings only. Dark first;
light mode swaps tokens, same layout. Never invent a screen,
state or look that isn't designed: ask first.

## Commands
make gen | make build | make test | make run

## Rules
- Privacy is the product: no network calls except Sparkle.
  No analytics, no telemetry, no crash reporters.
- Never store file contents. Fingerprints and metadata only.
- Every engine change (Destination, Family, Warning) needs unit tests.
- DB changes = new numbered GRDB migration. Never edit old ones.
- Log with os.Logger; mark file names and URLs as private.
- The owner is not a developer: explain what you changed in plain
  English, and give exact steps when Xcode or macOS needs a click.
- Before deleting or moving files outside this repo, stop and ask.
- Reference PRD IDs in commit messages, e.g. "FR-12: reveal in Finder".
