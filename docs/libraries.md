# Library APIs

The Zig and Rust implementations each provide a pure rendering library and the
same C ABI. Their CLIs compile the same `cli/main.c` against the selected static
library. Roc remains an independent CLI implementation.

Rendering never reads stdin, files, environment variables, clocks, terminal
state or random devices. Supply terminal width, color, decimal separator and
glyph configuration explicitly. The C CLI supplies these from its environment.
The default library configuration uses 80 columns, `.` and no color.

## Zig 0.16.0

Add this repository as a Zig package dependency named `tsv_to_ansi_table`, pinned
to a commit and its package hash, or use a local path during development:

```zig
.dependencies = .{
	.tsv_to_ansi_table = .{ .path = "../tsv_to_ansi_table" },
},
```

In `build.zig`, import the public module into your application's module:

```zig
const dependency = b.dependency("tsv_to_ansi_table", .{
	.target = target,
	.optimize = optimize,
});
app.root_module.addImport("table", dependency.module("tsv_to_ansi_table"));
```

The package declares and links utf8proc and the random library. No
`-Dutf8proc=PATH` argument is required. An optional override exists for packaging.

```zig
const table = @import("table");
const output = try table.renderTable(allocator, .{ .plain = true }, &.{
	&.{ "Name", "N" },
	&.{ "a", "12" },
});
defer allocator.free(output);
```

`Config` exposes rendering settings; `parseOptions` accepts the CLI option
syntax. `Engine.init(allocator, config)` copies configuration and owns buffered
rows until `deinit()`. Each `push(allocator, row)` and `finish(allocator)` returns
an owned output slice that the caller frees with that call's allocator.
Use a scratch arena for `parseOptions`, `parseGlyphs` and `parseTsvRow`; their
intermediate allocations share that lifetime. Keep the parsed configuration
and borrowed argument strings alive until `Engine.init` copies them, then
release the scratch arena. Keep each parsed row alive through its `push` call.
The [downstream fixture](../tests/fixtures/zig-consumer/) compiles this public
module through an actual package dependency as part of `./test`.

## Rust

The crate lives under `rust/` and produces both an `rlib` and a C static library.
For local development, add a Cargo path dependency:

```toml
[dependencies]
tsv-to-ansi-table = { path = "../tsv_to_ansi_table/rust" }
```

```rust
use tsv_to_ansi_table::{Config, render_table};

let config = Config::parse(&["--plain"], Config::default())?;
let output = render_table(&config, &[&["Name", "N"], &["a", "12"]])?;
assert_eq!(output, "Name   N\na     12\n");
```

`Engine::new(config)`, `push(&[&str])` and `finish()` provide incremental rendering
and return owned `String` values. Native strings are valid UTF-8 by construction.
Rust implements layout, inference, parsing and rendering independently of Zig;
its random dependency uses the same pinned generator as the other implementations.
Build the repository checkout, including `src/help.txt` and
`src/example-words.txt`, rather than copying the `rust/` directory alone.

## C ABI

`nix build` installs the following native artifacts:

| Path under `result/` | Artifact |
| --- | --- |
| `include/tsv_to_ansi_table.h` | Common C/C++ header |
| `lib/libtsv_to_ansi_table.a` | Zig implementation |
| `lib/rust/libtsv_to_ansi_table.a` | Rust implementation |
| `bin/tsv-to-ansi-table-zig` | C CLI linked to Zig |
| `bin/tsv-to-ansi-table-rust` | C CLI linked to Rust |

`nix build .#rust` installs the Rust archive directly under `result/lib/`.
Link exactly one implementation: both export the same `tsvat_*` symbols.
Use a C compiler and runtime matching the archive's target. Linux Nix artifacts
use musl; they are not glibc archives. Rust's Linux archive additionally needs
`-ldl -lpthread -lm` when linked from C.

```c
#include "tsv_to_ansi_table.h"
#define S(s) { (const uint8_t *)(s), sizeof(s) - 1 }

tsvat_options options = tsvat_default_options();
const tsvat_slice args[] = { S("--plain") };
options.args = args;
options.argc = 1;
const tsvat_slice heading[] = { S("Name"), S("N") };
const tsvat_slice data[] = { S("a"), S("12") };
const tsvat_row rows[] = { { heading, 2 }, { data, 2 } };
tsvat_buffer output = {0};
int status = tsvat_render(&options, rows, 2, &output);
/* On success, consume output.data[0..output.len]; it is not NUL-terminated. */
tsvat_buffer_free(&output);
```

Inputs are borrowed only for the call. Contexts copy configuration and retained
rows, so callers may reuse input buffers afterward. All lengths count bytes or
array elements as declared in the header. A null input pointer requires zero
length; non-null pointers must reference valid, correctly aligned storage of
the stated size. Every row must contain at least one cell.

Start output buffers empty. Free them with `tsvat_buffer_free` from the same
implementation that created them. It clears the buffer and accepts null or an
already cleared buffer. `tsvat_help` and `tsvat_about` return borrowed static
slices; do not free them. Destroy each context exactly once; destroying null is
allowed. Separate contexts can run concurrently; serialize access to a shared
context. Do not retain a context after a feed or finish error.

Return codes distinguish invalid arguments, invalid options/UTF-8, ragged rows,
header mismatches, excess column options, insufficient width, invalid glyphs or
seeds, allocation failure, invalid state and internal errors. The header names
every code; `tsvat_error_message` returns a borrowed diagnostic. Rust follows its
standard allocator behavior on allocation exhaustion, which may abort rather
than return `TSVAT_OUT_OF_MEMORY`.

For streaming, create a context, call `tsvat_push_row` or `tsvat_push_tsv` for each
record, consume/free each returned buffer, then call `tsvat_finish` and destroy
the context. `push_tsv` accepts one record without LF and removes a trailing CR.
All-fixed widths produce output after header and first-data-row inference;
automatic widths buffer until finish. A late error can follow already consumed
streaming output. Batch `tsvat_render` returns no partial output on failure.

## Text and examples

Cells and headers must be valid UTF-8. Invalid input is rejected. Embedded NUL,
tab, newline and unsafe terminal controls in already separated cells become
U+FFFD. `tsvat_push_tsv` and Rust's `Engine::push_tsv` treat tab as a delimiter
and reject embedded LF. Zig's lower-level `parseTsvRow` only splits fields and
strips trailing CR; `Engine.push` validates and sanitizes the resulting cells.
The rendering rules, numeric inference, glyph safety and grapheme clipping are
the [same as the CLI](cli-contract.md). Zig uses utf8proc 2.11.3; Rust's pinned
`utf8proc-sys` 0.1.2 bundles utf8proc 2.11.0. Both use Unicode 17 data.

The C example API accepts a caller-supplied 32-byte seed; a configured `--seed`
takes precedence. On a fresh valid context it reports the selected seed even
if layout fails. Native Zig and Rust example generators also accept explicit
seeds. None obtains entropy or prints seed metadata; the CLI handles those tasks.

`./test` checks native APIs, Zig allocation-failure cleanup, both archives from
a C consumer, the downstream Zig module, and the complete shared CLI suite for
Roc, Zig and Rust. Current native runtime verification is Linux x86_64. The
existing cross packages compile Zig libraries and C CLIs for Linux ARM64,
macOS ARM64 and both Windows architectures. Rust cross packages remain part of
the build-architecture work in `PLAN.md`.
