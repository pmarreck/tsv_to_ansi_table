# CLI choices

The command reads TSV on stdin. `--headers 'Name,Count'` replaces the first
input row by default; with `--no-header` it prepends those names and preserves
all input rows. Names containing commas can instead be supplied by repeating
`--header NAME`. Ragged rows are errors, including trailing extra empty cells.
An empty stream renders nothing; explicit headers alone render a header table.

Column lists use positional comma-separated entries: `--widths 12,auto,8`,
`--align left,right,center`, and `--overflow auto,prefix-ellipsis,truncate`.
Omitted entries use defaults; excess entries are errors once the column count
is known. Widths count content cells, excluding the one-cell padding on either
side. Fixed widths must fit, or the command fails with a useful diagnostic.
Auto widths share the remaining space by max-min allocation, each receiving at
least one cell. A terminal too narrow for this minimum produces an error.

`--terminal-width N` overrides detected terminal columns. Redirection falls
back to 80 columns, with `COLUMNS` accepted as an explicit environment override.
`--color auto|always|never` defaults to auto (TTY, unless NO_COLOR is set).
`--ascii` uses ASCII borders and `...` (or a clipped marker in very narrow cells).
`--plain` omits borders, color and row padding, with two spaces between columns.
Both alternatives keep the same width and alignment rules. Redirected output
keeps Unicode borders without color. `--decimal-separator CHAR` overrides the
active locale decimal separator; numeric recognition accepts signs and plain
integers/decimals, without exponent or thousands-grouping syntax.

Controls in cells are replaced with visible replacement characters before
measuring or rendering. Input ANSI escapes cannot execute. Invalid UTF-8 is an
error. Display-width and grapheme behavior will be documented with the pinned
Unicode data version and limitations; terminal-dependent ambiguous widths use
one cell. Original numeric text and precision are preserved.

## Implementation checks

- Parsing: distinguish EOF from a blank row and retain trailing fields.
- Inference: ignore header content and do not reclassify from later rows.
- Widths: account for borders before allocation; fixed widths never shrink.
- Clipping: never split a grapheme or exceed a content width with its marker.
- Streaming: observe output before sending EOF, including the first data row.
- Errors: a late streaming error may follow already-emitted valid rows.

## Configurable glyphs

`TSV_TO_ANSI_TABLE_GLYPHS` is a JSON object of named border/ellipsis overrides.
Missing keys keep defaults; an empty or unset variable selects the default
profile. Each override must be one grapheme occupying exactly one display cell,
and must survive the existing text sanitizer unchanged. Reject unknown keys,
non-string values, malformed JSON and invalid UTF-8. This preserves width
allocation and prevents configuration from injecting terminal controls.
`--ascii` selects the existing ASCII preset; `--plain` omits borders while
retaining the configured ellipsis. Help and about remain available even when
configuration is invalid.
