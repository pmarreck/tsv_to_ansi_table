# PLAN

## Finish and publish

- [ ] Pass final native tests/debug builds and cross-compilation matrix, then publish MIT-licensed repository and verify exact-commit Mechatron Prime CI.
- [ ] Run ./bm on the published implementations and report measured comparison with baseline status.
- [ ] Incorporate feedback on the decorated output preview before freezing decorative fixtures.

## Completed

- [x] Pin Roc compiler/platform and Zig 0.16.0; document CLI syntax and target constraints (done 2026-10-15 17:13 EDT; initial commit pending).
- [x] Implement pure TSV parsing, first-data-row numeric inference, locale override, all header modes and strict ragged-row handling with red-first tests (done 2026-10-15 17:13 EDT; initial commit pending).
- [x] Implement Unicode-safe width allocation, alignment, clipping and control sanitization in Roc and Zig (done 2026-10-15 17:13 EDT; initial commit pending).
- [x] Prove fixed-width output before EOF with a controlled producer and auto-width buffering with pure state tests (done 2026-10-15 17:13 EDT; initial commit pending).
- [x] Establish shared Bash stdin/stdout tests, 216 rendering parity cases, optimized target-separated builds and complete ./test entry point (done 2026-10-15 17:13 EDT; initial commit pending).
- [x] Add ./bm with identical auto/fixed workloads, independent output oracle, wall/CPU samples and external history (done 2026-10-15 17:13 EDT; initial commit pending).
- [x] Document flags, defaults, Unicode limits, benchmarking method and platform verification limits in README.md (done 2026-10-15 17:13 EDT; initial commit pending).
