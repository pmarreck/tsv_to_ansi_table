# TSV to ANSI table

Turn tab-delimited input into an attractive, readable terminal table using Roc.
The command is `tsv-to-ansi-table`. It is intended for interactive shell users
and pipelines, with Nix-pinned dependencies and an MIT-licensed public repository.

## Accepted behavior

- Read TSV from standard input by default. Preserve empty cells and trailing fields.
- Treat the first input row as headers unless `--no-header` is specified. Support explicitly supplied header names as well.
- Infer numeric/decimal classification and decimal places from the first **data** row, excluding any header. Numeric values default to right alignment; other values default to left alignment. Explicit column alignment overrides inference. This replaces the earlier default decimal-point alignment proposal.
- Use the active locale's decimal separator when recognizing decimal-like values. Treat first-row decimal precision as inferred metadata; do not silently round or discard subsequent input digits. Clarify any requested formatting policy separately.
- All column widths default to `auto`. If any width is auto, consume the entire input before rendering. When all widths are fixed, stream output as rows arrive after the bounded header/first-data-row inference step; never await EOF to align numeric values.
- Support per-column widths and alignment. Fit the complete table, including borders, separators and padding, within the available terminal width. Fairly cap oversized auto columns so one long value does not starve the others; apply normal overflow behavior to capped columns.
- Support `truncate-left`, `truncate-right` (alias `truncate`), `prefix-ellipsis`, and `suffix-ellipsis`. Default to suffix ellipsis, except path-looking cells default to prefix ellipsis to preserve the tail. Explicit overflow configuration wins. Use Unicode `…` in normal output.
- Follow established CLI conventions: clear help/about, UTF-8, useful errors on stderr, ANSI/color controls, plain/ASCII alternatives and documented redirected-output behavior.
- Allow named border and ellipsis glyph overrides through an environment variable while preserving display-width and terminal-control safety guarantees.
- Provide an example subcommand using the random project's deterministic libraries, replayable reported seeds, and a small shared corporate/LLM-themed vocabulary to demonstrate mixed column types, precision, and cell lengths.
- Provide `./build` for an optimized current-platform build, `./test` for the complete suite, and `./run` to build and run. Keep binaries under `bin/<os>/<arch>/` and publish `bin/tsv-to-ansi-table` as a generated link to the faster measured implementation for the current host so adding the project's `bin/` to PATH exposes the command.

## Design and verification

Separate pure parsing, classification, allocation of column widths and rendering
from terminal/locale/input/output adapters. Inject terminal width and locale in
tests. Test streaming with a controlled producer that does not send EOF until
output is observed, rather than sleep-based timing guesses.

Verify display-cell widths rather than UTF-8 byte counts, grapheme-safe clipping,
wide and combining characters, narrow terminals, ragged rows, empty input,
header-only input, signs, integer values and locale-specific decimals. Treat
untrusted control sequences as an explicit input-safety contract. Document
the limits of supported terminal text rendering rather than claiming universality.

The target matrix follows the shared cross-platform build guidance. Report actual
Roc compiler/platform constraints and untested targets honestly. Do not silently
replace the requested Roc implementation with another language.

Before implementation, choose and document reversible CLI details: width/alignment
selector syntax, manual header syntax, malformed-row behavior and width fallback
when stdout is redirected. Proposed manual-header behavior is to replace an
existing header by default, or supply one without consuming a data row when
combined with `--no-header`.

## Boundaries

No spreadsheet evaluation, arbitrary terminal escape execution, or interactive
editor is needed. Keep this a focused TSV renderer. These requirements define
intended behavior; tests and the documented target matrix record verification.

Commit and push validated work and verify CI. Create release tags and GitHub
releases only when explicitly requested.

## Additional implementation

Provide a Zig 0.16.0 implementation after establishing the Bash stdin/output
acceptance suite for the Roc implementation. Both implementations must satisfy
the same accepted CLI contract and shared suite. Keep the Roc implementation
and its pure core as an independently usable implementation.
