# PLAN

## Finish and publish

- [ ] Add an environment-variable glyph configuration to both implementations with shared CLI tests, then publish after tests/build pass.
- [ ] Incorporate feedback on the decorated output preview before freezing decorative fixtures.

## Completed

- [x] Publish native/cross packages and verify exact-commit Mechatron Prime CI (done 2026-10-15 17:26 EDT; commit b665fbe).
- [x] Run ./bm and record the measured comparison with UNBASELINED history status in docs/benchmark-results.md (done 2026-10-15 17:20 EDT; measured commit b665fbe).
- [x] Establish shared Bash stdin/stdout tests, 216 rendering parity cases, optimized target-separated builds and complete ./test entry point (done 2026-10-15 17:13 EDT; commit b665fbe).
- [x] Add ./bm with identical auto/fixed workloads, independent output oracle, wall/CPU samples and external history (done 2026-10-15 17:13 EDT; commit b665fbe).
- [x] Document flags, defaults, Unicode limits, benchmarking method and platform verification limits in README.md (done 2026-10-15 17:13 EDT; commit b665fbe).
