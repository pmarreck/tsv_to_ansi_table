# tsv-to-ansi-table

Render TSV from stdin as a terminal-width-aware table. Independent Roc, Zig
0.16.0 and Rust implementations share the same CLI contract and Bash acceptance
suite. Zig and Rust also provide [native libraries and a common C ABI](docs/libraries.md).

[![Mechatron Prime CI](https://img.shields.io/endpoint?url=https%3A%2F%2Fthelio-nixos.tail66c90.ts.net%2Fbadges%2Ftsv_to_ansi_table.json&style=for-the-badge)](https://thelio-nixos.tail66c90.ts.net/mechatron-prime/)

Mechatron Prime CI is the continuous-integration service that builds the targets
listed in `.mechatron-prime/targets` at each pushed commit.

## Build and run

Install Nix with flakes enabled, then:

```bash
./build
printf 'Name\tCount\na\t12\nb\t3\n' | ./run --ascii
```

`./build` creates optimized binaries in `bin/<os>/<arch>/` and a
`bin/tsv-to-ansi-table` link to the current host's Zig implementation. Add the
project's `bin/` directory to PATH to use that command. Zig was 6.40–6.76 times
faster in the [recorded benchmark workloads](docs/benchmark-results.md).
Rebuild after moving the checkout to a different platform or architecture.

The platform-specific and Nix package `tsv-to-ansi-table` aliases select Roc;
`tsv-to-ansi-table-roc`, `tsv-to-ansi-table-zig` and `tsv-to-ansi-table-rust` select implementations
explicitly. `./run` builds first and forwards arguments to Roc.
`./build --debug` publishes debug binaries that
announce themselves on stderr. `./build --test` runs the complete suite first.

A native Nix package installs all four command names, both static libraries and
the common C header:

```bash
nix build
printf 'Name\tCount\na\t12\n' | result/bin/tsv-to-ansi-table-zig
```

## Example tables

Try a generated table without preparing input:

```bash
./run example
./run example --seed 42
./run example --seed 42 --ascii --terminal-width 100
```

`example` creates 12 rows and 4–6 columns from a shared list of 100 corporate
and LLM-themed words and phrases. It always includes text and numeric columns.
Each numeric column gets a random magnitude and 0–6 decimal places. Text cells
combine 1–8 phrases with exponentially distributed lengths, so short cells are
common and long ones exercise clipping. Headings come from the same vocabulary.

The table goes to stdout; `seed=0x…` goes to stderr. With no `--seed`, the command
chooses a seed from OS randomness. Replay that seed as an unsigned decimal or
hexadecimal integer smaller than 2^256. All implementations produce identical
tables for the same seed, options, and terminal/locale settings. For byte-for-byte
fixtures, explicitly set `--terminal-width`, `--decimal-separator`, and color or
plain mode, and keep the glyph environment unchanged. Replay is tied to this
generator version and vocabulary.

The subcommand ignores stdin. `--no-header` hides the generated headings;
manual headers replace them, or prepend to the 12 data rows with `--no-header`.
All existing layout and glyph options apply. `--seed` is valid only after
`example`. No separate `random` executable or sibling checkout is needed at
runtime: Nix pins [random](https://github.com/pmarreck/random) at
`76ada4a2d6259569f901985b08d8d5ad10f45059`, and each implementation imports its
matching pure library.

The following tables are captured stdout at 120 columns. Color is disabled for
Markdown; the replay seed is printed separately on stderr. Clearing the glyph
environment selects the default borders.

### Seed 42

```bash
TSV_TO_ANSI_TABLE_GLYPHS= ./run example --seed 42 --terminal-width 120 --decimal-separator . --color never
```

```text
┌────────────────────────┬────────────────────┬────────────────────────┬───────────────────────┬───────────────────────┐
│ context                │ not just a chatbot │ latent space           │ attention             │ quarterly optimism    │
├────────────────────────┼────────────────────┼────────────────────────┼───────────────────────┼───────────────────────┤
│ horizontal             │        8855.639717 │ temperature zero take… │ stakeholder buy in    │ embeddings traction … │
│ artisanal embeddings … │        7897.686536 │ moat prompt whisperer… │ sampling              │ in the ever evolving… │
│ customer obsession st… │         -82.960028 │ vertical               │ latent space          │ agentic workflow mee… │
│ vertical mission crit… │        1518.191594 │ alignment gentle remi… │ context window unloc… │ chain of thought      │
│ north star metric del… │       -9142.380014 │ alignment              │ touch base            │ inference             │
│ per my last email tho… │        9965.531589 │ in the ever evolving … │ flywheel              │ weights attention     │
│ spreadsheet theater e… │       -4781.103940 │ tokens gradients take… │ alignment tax tracti… │ context agentic work… │
│ seamless paradigm shi… │        6237.874156 │ touch base low hangin… │ bandwidth             │ transformer           │
│ value proposition moa… │        4473.242296 │ please advise attenti… │ temperature as a lar… │ artisanal embeddings… │
│ benchmark maximalism   │        8607.474019 │ zero shot confidence … │ alignment zero shot … │ please think harder   │
│ calendar Tetris quart… │        1219.703522 │ vector database scala… │ chain of thought dee… │ spreadsheet theater … │
│ temperature zero takes │       -7062.184980 │ temperature zero take… │ sent from my deck tr… │ locally grown halluc… │
└────────────────────────┴────────────────────┴────────────────────────┴───────────────────────┴───────────────────────┘
```

### Seed 88

```bash
TSV_TO_ANSI_TABLE_GLYPHS= ./run example --seed 88 --terminal-width 120 --decimal-separator . --color never
```

```text
┌───────────────────────────────────────────────┬───────────┬────────────────────┬───────────────────┬─────────────────┐
│ benchmark maximalism                          │ inference │ let us unpack that │ few shot optimism │ move the needle │
├───────────────────────────────────────────────┼───────────┼────────────────────┼───────────────────┼─────────────────┤
│ GPU scarcity mindset                          │        69 │       -14155.30561 │                 7 │         4.28213 │
│ please advise bandwidth                       │        98 │        29853.25476 │                 7 │         9.27640 │
│ spreadsheet theater                           │        53 │        46735.00889 │                 6 │         9.77092 │
│ sampling                                      │       -92 │        30397.79698 │                -0 │         2.92749 │
│ take this offline synthetic wisdom per my la… │       -39 │        48346.28203 │                 5 │         2.00680 │
│ agentic workflow pivot core competency ethic… │       -58 │        72110.61629 │                 7 │         9.24715 │
│ stakeholders budget adjacent                  │         2 │        -2149.88572 │                 5 │        -1.17485 │
│ executive presence                            │        12 │       -20815.13705 │                 9 │         0.29166 │
│ nuanced perspective                           │        10 │        13875.61123 │                 7 │         8.62797 │
│ headcount roadmap embeddings logits spreadsh… │         1 │       -24180.38477 │                 3 │         3.01422 │
│ attention                                     │        32 │        27479.49970 │                 3 │        -7.86357 │
│ actionable insights                           │        66 │       -73367.88153 │                -6 │         7.02302 │
└───────────────────────────────────────────────┴───────────┴────────────────────┴───────────────────┴─────────────────┘
```

## Table behavior

The first row supplies headers by default. Numeric classification comes from
the first **data** row, so numeric columns, including their headers, align right;
other columns align left. Later rows preserve their original digits and spelling.

```bash
# No input header; supply names without consuming a data row.
printf 'one\t12\ntwo\t3\n' | ./run --no-header --headers Name,Count

# Replace an existing input header. Repeat --header for names containing commas.
printf 'old\tn\none\t12\n' | ./run --header Name --header 'Count, total'

# Fixed widths stream before EOF, after the first-data-row inference step.
producer | ./run --widths 20,10 --align left,right

# Mix fixed and automatic widths; explicitly choose overflow behavior.
producer | ./run --widths auto,10 --overflow prefix-ellipsis,truncate
```

Column options are comma-separated positional lists; omitted entries use the
default. Widths count content cells. With any automatic width, the command reads
to EOF, then shares available space fairly among auto columns. With every width
fixed, it emits rows incrementally and retains only the header, inferred layout,
and current row. Fixed widths never shrink. An impossibly narrow table is an
error. A malformed late streaming row may follow already-written valid output.

| Option | Behavior |
| --- | --- |
| `--no-header` | Treat every input row as data |
| `--headers A,B` / repeated `--header NAME` | Replace input headers, or prepend with `--no-header` |
| `--widths auto,12` | Content widths; default all auto |
| `--align auto,left,right,center` | Override inferred column alignment |
| `--overflow auto,truncate-left,truncate-right,prefix-ellipsis,suffix-ellipsis` | Per-column clipping; `truncate` aliases `truncate-right` |
| `--terminal-width N` | Override terminal detection and `COLUMNS` |
| `--decimal-separator CHAR` | Override locale decimal separator with `.`, `,`, or `٫` |
| `--color auto\|always\|never` | Auto uses TTY detection and honors `NO_COLOR` and `TERM=dumb` |
| `--ascii` | ASCII borders and `...` ellipses |
| `--plain` | No borders or color; two spaces between columns |
| `-h` / `--help`, `--about` | Usage, or one-line version and target information |

Auto overflow uses a suffix ellipsis, except cells containing `/` or `\` use a
prefix ellipsis to preserve path tails. Redirected output defaults to 80 columns
and Unicode borders without color. `COLUMNS` overrides detected width. Plain
output still pads cells for alignment. Input is UTF-8 TSV, with LF or CRLF rows;
empty and trailing cells are preserved. Ragged rows and invalid UTF-8 fail.

Numeric inference accepts optional signs and plain integers/decimals, including
`.5` and `5.`. It does not recognize exponent notation or thousands separators.
Unix uses `locale decimal_point`, falling back to `.` if unavailable; Windows
uses the native locale API. Decimal precision is metadata, not a rounding rule.

## Text safety and display limits

Set `TSV_TO_ANSI_TABLE_GLYPHS` to a JSON object to override individual borders
and the overflow ellipsis in every implementation:

```bash
export TSV_TO_ANSI_TABLE_GLYPHS='{"top_left":"╭","top_right":"╮","bottom_left":"╰","bottom_right":"╯","ellipsis":"~"}'
printf 'Name\tCount\na\t12\n' | ./run
```

The supported names are `top_left`, `top_join`, `top_right`, `middle_left`,
`middle_join`, `middle_right`, `bottom_left`, `bottom_join`, `bottom_right`,
`horizontal`, `vertical`, and `ellipsis`. Omitted names retain their defaults;
an unset or empty variable uses the default profile. Each value must be a safe
single grapheme occupying exactly one display cell. Unknown names, malformed
JSON, controls, empty strings, and wide glyphs fail with a diagnostic.
`--ascii` selects the ASCII preset instead of the custom profile; `--plain`
omits borders but uses the configured ellipsis. Text-safety markers remain part
of the sanitization policy.

All implementations use Unicode 17 data. Clipping preserves grapheme clusters;
wide characters and emoji occupy two cells, ambiguous-width characters one.
Combining-only clusters receive a visible dotted circle. Terminal control and
format characters become `�`, except joiners and emoji tags needed within
clusters. Input escape sequences cannot execute. Terminal/font rendering can
still vary, especially for emoji and scripts requiring shaping. This is a cell
width policy, not a claim to reproduce every terminal's glyph layout.

## Tests and benchmarks

```bash
./test
./bm
```

`./test` includes Roc expectations, safety-enabled Zig allocator tests, native
Rust API tests, real C and Zig library consumers, and shared
CLI error/header/Unicode tests, a producer handshake proving fixed-width output
before EOF, 216 input-table and 18 seeded-example cross-implementation cases,
seed replay and validation, example generation without stdin, debug announcements,
and a benchmark oracle that rejects missing, reordered, rounded, or extra rows.
Expected stderr is captured. Native runtime verification is on Linux x86_64.

`./bm` compares the Roc and Zig CLIs using optimized builds and identical 10,000-row workloads
with auto and fixed widths, under one-core and twelve-core CPU affinity. Each
case warms up twice and records five fresh-process wall-clock and child-CPU
samples. Both tools are single-threaded; twelve-core affinity measures the same
program with a different scheduling allowance. Generation and independent output
verification sit outside timing; CLI startup, locale lookup, and RAM-backed file
I/O sit inside. These measurements are whole-process throughput, not terminal
painting speed or allocation measurements.

The shared performance-profiling engine keeps history outside this repository,
under `$XDG_STATE_HOME/performance-history` (default `~/.local/state`). Set
`PERFORMANCE_HISTORY_URL` to choose another store. A new machine/toolchain cohort
is reported as **UNBASELINED** (exit 3); approving a historical baseline is a
separate explicit operation. Raw samples include CPU time even though wall time
is the comparison metric. Unsupported affinity or a missing required tool fails
visibly.

## Toolchains and target coverage

Nix pins Roc nightly `2026-10-12-2664a27`, basic-cli `0.25.0`, Roc Unicode `4.2.0`,
Zig `0.16.0`, Rust `1.97.1`, and utf8proc `2.11.3` for Zig. Rust's pinned
`utf8proc-sys` bundles utf8proc `2.11.0`; both use Unicode 17 data. The Roc compiler
is a prebuilt upstream release; its matching Darwin linker stub is pinned
separately. Zig and Rust use a shared C CLI through the public C ABI. A small C
adapter provides terminal width/TTY detection and Windows locale lookup.

Native Nix builds are exposed for Linux x86_64, Linux ARM64, and macOS ARM64.
Rust is included in native packages; Rust cross packaging is still queued in
`PLAN.md`. Cross packages are `linux-arm64`, `macos-arm64`, `windows-x86_64`, and
`windows-arm64`; for example `nix build .#windows-x86_64`. Both Windows packages
contain only Zig: the pinned Roc platform has no ARM64 Windows host, and its
x86_64 host lacks CRT import libraries needed to link successfully. Cross builds
verify compilation and linking, not runtime behavior on those operating systems.
Linux executables use musl and are static. macOS Intel is outside the target set.

The pure cores are in `src/`, `zig/` and `rust/src/`; stdin, stdout, environment, and terminal
adapters remain at the boundary. See [INTENT.md](INTENT.md) and
[the CLI contract](docs/cli-contract.md) for scope and edge-case decisions.

MIT licensed. Unicode libraries and toolchains retain their upstream licenses.
