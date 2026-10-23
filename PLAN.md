# PLAN

## Build architecture conformance

- [ ] Conform to the 2026-10-23 cross-platform-project-build-arch skill and its canonical-implementations and verification-and-migration references; inventory current products, callers and supported combinations, and reconcile the earlier generic bin/ executable requirement before changing publication.
- [ ] Add tracked CANONICAL_IMPL selection for Roc/Zig/Rust with Zig as the initial selection; implement validated, atomic, idempotent ./build canonize IMPL with no build or publication side effects.
- [ ] Make ./build default to the canonical implementation on the current platform; add --all-impls/--all-implementations, --all-plats/--all-platforms and --all with honest support-matrix handling, preserving debug/test modes.
- [ ] Extend Rust packaging beyond native Nix hosts to the declared cross-target matrix, and verify actual compiler/runtime support before advertising those combinations.
- [ ] Migrate project-owned output namespaces to PF (linux-amd64, linux-arm64, macos-arm64, mswin-amd64, mswin-arm64), separate applicable gnu/musl variants and profiles, and retain explicit compiler/Nix target translations and store GC roots.
- [ ] Publish only canonical public commands under bin/<PF>/, align ./run with that selection, retain other implementations in namespaced product trees, and preserve prior working products, Windows runtime resources and recoverable migration paths.
- [ ] Prove conformance through ./test with selection validation, scope-set equivalence, platform-alias classification, ABI/profile coexistence, concurrent and failed publication, PATH isolation and real host builds; update intent, docs, Nix packaging and CI while distinguishing cross-compilation from native runtime verification.

## Completed library implementation

- [x] Preserve the existing CLI contract while exposing the Zig renderer as a public module and C ABI static library, with all CLI I/O performed by a C frontend through that ABI (done 2026-10-23 15:35 EDT).
- [x] Add an independent Rust rendering library and CLI implementation, expose Rust and C library APIs, and pass the same complete Bash CLI suite against Roc, Zig and Rust, including 234 parity cases per pair (done 2026-10-23 15:35 EDT).
- [x] Test library ownership, invalid buffers, UTF-8, errors, streaming and external consumer linkage; package headers/libraries/dependencies and document both language APIs in docs/libraries.md (done 2026-10-23 15:35 EDT).
- [x] Pass the complete native test entry point, ./build, debug and all four configured cross builds; verify current-host Zig PATH selection and the installed Rust command (done 2026-10-23 15:35 EDT).

- [x] Expose a pure public tsv_to_ansi_table Zig module and length-delimited C ABI static library/header for xattr_stream; define ownership, errors and caller-supplied rendering configuration without terminal or environment queries (done 2026-10-23 15:35 EDT).
- [x] Declare utf8proc as a dependency usable by consumer Zig and Nix builds without -Dutf8proc=PATH; document and test text contracts, verify external consumers, and notify the requesting project through its inbox (done 2026-10-23 15:35 EDT).

## Completed

- [x] Verify exact-commit CI for the published header, README and current-host PATH update: fa2804c passed on 2026-10-21 at 16:50 EDT (verified 2026-10-23 14:02 EDT).
- [x] Pass ./test, ./build, debug and all configured cross-target builds; verify the installed PATH command selects the current-host Zig binary and push commit 496c51a (done 2026-10-21 16:01 EDT).
- [x] Add actual seed 42 and 88 tables to the README and verify both fixtures against both rebuilt implementations (done 2026-10-21 15:18 EDT).
- [x] Publish bin/tsv-to-ansi-table as a current-host Zig link; observe failures before implementation and pass PATH selection, retry, stale-link and file-preservation tests (done 2026-10-21 15:18 EDT).
