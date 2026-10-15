# tsv-to-ansi-table

Render TSV from stdin as a terminal-width-aware table. Independent Roc and Zig
0.16.0 implementations share the same CLI contract and Bash acceptance suite.

[![Mechatron Prime CI](https://img.shields.io/endpoint?url=https%3A%2F%2Fthelio-nixos.tail66c90.ts.net%2Fbadges%2Ftsv_to_ansi_table.json&style=for-the-badge)](https://thelio-nixos.tail66c90.ts.net/mechatron-prime/)

Mechatron Prime CI is the continuous-integration service that builds the targets
listed in `.mechatron-prime/targets` at each pushed commit.

## Build and run

Install Nix with flakes enabled, then:

```bash
./build
printf 'Name\tCount\na\t12\nb\t3\n' | ./run --ascii
```

`./build` creates optimized binaries in `bin/<os>/<arch>/`. The default
`tsv-to-ansi-table` selects Roc; `tsv-to-ansi-table-roc` and
`tsv-to-ansi-table-zig` select implementations explicitly. `./run` builds first
and forwards arguments to Roc. `./build --debug` publishes debug binaries that
announce themselves on stderr. `./build --test` runs the complete suite first.

A Nix package also installs all three commands:

```bash
nix build
printf 'Name\tCount\na\t12\n' | result/bin/tsv-to-ansi-table-zig
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

Both implementations use Unicode 17 data. Clipping preserves grapheme clusters;
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

`./test` includes Roc expectations, safety-enabled Zig allocator tests, shared
CLI error/header/Unicode tests, a producer handshake proving fixed-width output
before EOF, 216 cross-implementation option combinations, debug announcements,
and a benchmark oracle that rejects missing, reordered, rounded, or extra rows.
Expected stderr is captured. Native runtime verification is on Linux x86_64.

`./bm` builds optimized executables and compares identical 10,000-row workloads
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
Zig `0.16.0`, and utf8proc `2.11.3`. The Roc compiler is a prebuilt upstream
release; its matching Darwin linker stub is pinned separately. A small C adapter
provides terminal width/TTY detection and Windows locale lookup to both programs.

Native Nix builds are exposed for Linux x86_64, Linux ARM64, and macOS ARM64.
Cross packages are `linux-arm64`, `macos-arm64`, `windows-x86_64`, and
`windows-arm64`; for example `nix build .#windows-x86_64`. Both Windows packages
contain only Zig: the pinned Roc platform has no ARM64 Windows host, and its
x86_64 host lacks CRT import libraries needed to link successfully. Cross builds
verify compilation and linking, not runtime behavior on those operating systems.
Linux executables use musl and are static. macOS Intel is outside the target set.

The pure cores are in `src/` and `zig/`; stdin, stdout, environment, and terminal
adapters remain at the boundary. See [INTENT.md](INTENT.md) and
[the CLI contract](docs/cli-contract.md) for scope and edge-case decisions.

MIT licensed. Unicode libraries and toolchains retain their upstream licenses.
