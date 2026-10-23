# PLAN

## Build architecture conformance

- [ ] Conform to the 2026-10-23 cross-platform-project-build-arch skill and its canonical-implementations and verification-and-migration references; inventory current products, callers and supported combinations, and reconcile the earlier generic bin/ executable requirement before changing publication.
- [ ] Add tracked CANONICAL_IMPL selection for Roc/Zig with Zig as the initial selection; implement validated, atomic, idempotent ./build canonize IMPL with no build or publication side effects.
- [ ] Make ./build default to the canonical implementation on the current platform; add --all-impls/--all-implementations, --all-plats/--all-platforms and --all with honest support-matrix handling, preserving debug/test modes.
- [ ] Migrate project-owned output namespaces to PF (linux-amd64, linux-arm64, macos-arm64, mswin-amd64, mswin-arm64), separate applicable gnu/musl variants and profiles, and retain explicit compiler/Nix target translations and store GC roots.
- [ ] Publish only canonical public commands under bin/<PF>/, align ./run with that selection, retain other implementations in namespaced product trees, and preserve prior working products, Windows runtime resources and recoverable migration paths.
- [ ] Prove conformance through ./test with selection validation, scope-set equivalence, platform-alias classification, ABI/profile coexistence, concurrent and failed publication, PATH isolation and real host builds; update intent, docs, Nix packaging and CI while distinguishing cross-compilation from native runtime verification.

## Library request

- [ ] Expose a pure public tsv_to_ansi_table Zig module and length-delimited C ABI static library/header for xattr_stream; define ownership, errors and caller-supplied rendering configuration without terminal or environment queries.
- [ ] Declare utf8proc as a dependency usable by consumer Zig and Nix builds without -Dutf8proc=PATH; document and test UTF-8/control-character and cell-delimiter contracts, verify external consumer linkage, and notify the requesting project when available; no Rust implementation is requested.

## Completed

- [x] Verify exact-commit CI for the published header, README and current-host PATH update: fa2804c passed on 2026-10-21 at 16:50 EDT (verified 2026-10-23 14:02 EDT).
- [x] Pass ./test, ./build, debug and all configured cross-target builds; verify the installed PATH command selects the current-host Zig binary and push commit 496c51a (done 2026-10-21 16:01 EDT).
- [x] Keep header separators in the normal border color in both renderers; observe regression failures before the fix and pass Unicode, ASCII, custom-glyph and unstyled checks (done 2026-10-21 15:18 EDT).
- [x] Add actual seed 42 and 88 tables to the README and verify both fixtures against both rebuilt implementations (done 2026-10-21 15:18 EDT).
- [x] Publish bin/tsv-to-ansi-table as a current-host Zig link; observe failures before implementation and pass PATH selection, retry, stale-link and file-preservation tests (done 2026-10-21 15:18 EDT).
- [x] Verify the published example subcommand update in exact-commit CI (done 2026-10-20 11:17 EDT; commit 13f4c1a).
- [x] Add seeded examples using the random libraries and shared vocabulary; pass the complete suite, native/debug builds, and all configured cross-target builds (done 2026-10-20 11:16 EDT; commit 13f4c1a).
- [x] Document example usage, seed replay, and dependency pinning; annotate all new files (done 2026-10-20 11:16 EDT; commit 13f4c1a).
- [x] Fill purpose notes for all tracked files and key directories, preserve depth=3, and verify no orphaned notes (done 2026-10-20 10:55 EDT).
- [x] Repeat ./bm on the glyph update and record verified UNBASELINED observations (done 2026-10-15 17:35 EDT; measured commit 04ce607).
