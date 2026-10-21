# PLAN

## Current

- [ ] Verify the published header, README and current-host PATH update in exact-commit CI; commit 496c51a remains claimed behind another project's test target as of 2026-10-21 16:01 EDT.

## Completed

- [x] Pass ./test, ./build, debug and all configured cross-target builds; verify the installed PATH command selects the current-host Zig binary and push commit 496c51a (done 2026-10-21 16:01 EDT).
- [x] Keep header separators in the normal border color in both renderers; observe regression failures before the fix and pass Unicode, ASCII, custom-glyph and unstyled checks (done 2026-10-21 15:18 EDT).
- [x] Add actual seed 42 and 88 tables to the README and verify both fixtures against both rebuilt implementations (done 2026-10-21 15:18 EDT).
- [x] Publish bin/tsv-to-ansi-table as a current-host Zig link; observe failures before implementation and pass PATH selection, retry, stale-link and file-preservation tests (done 2026-10-21 15:18 EDT).
- [x] Verify the published example subcommand update in exact-commit CI (done 2026-10-20 11:17 EDT; commit 13f4c1a).
- [x] Add seeded examples using the random libraries and shared vocabulary; pass the complete suite, native/debug builds, and all configured cross-target builds (done 2026-10-20 11:16 EDT; commit 13f4c1a).
- [x] Document example usage, seed replay, and dependency pinning; annotate all new files (done 2026-10-20 11:16 EDT; commit 13f4c1a).
- [x] Fill purpose notes for all tracked files and key directories, preserve depth=3, and verify no orphaned notes (done 2026-10-20 10:55 EDT).
- [x] Add validated environment glyph overrides to both implementations, pass all tests/target builds and verify published exact-commit CI (done 2026-10-15 17:35 EDT; commit 04ce607).
- [x] Repeat ./bm on the glyph update and record verified UNBASELINED observations (done 2026-10-15 17:35 EDT; measured commit 04ce607).
