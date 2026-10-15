import Text
import Options
import Table

Render :: [].{
	Layout : { widths : List(U64), align : List(Str), overflow : List(Str), config : Options.Config }
	prepare : Options.Config, List(Str), List(List(Str)) -> Try(Layout, [Invalid(Str)])
	prepare = |config, header, rows| {
		n = if header != [] header.len() else (rows.first() ?? []).len()
		if config.widths.len() > n or config.align.len() > n or config.overflow.len() > n { return Err(Invalid("More column options than columns")) }
		if !rows.all(|row| row.len() == n) { return Err(Invalid("Ragged row: every row must have the same number of fields")) }
		first = rows.first() ?? []
		var $desired = []
		var $fixed = []
		var $align = []
		for i in 0..<n {
			var $max = Text.width(Text.safe(header.get(i) ?? ""))
			for row in rows {
				w = Text.width(Text.safe(row.get(i) ?? ""))
				$max = if w > $max w else $max
			}
			$desired = $desired.append($max)
			$fixed = $fixed.append(config.widths.get(i) ?? 0)
			inferred = match Table.classify(first.get(i) ?? "", config.decimal) {
				Number(_) => "right"
				Text => "left"
			}
			explicit = config.align.get(i) ?? "auto"
			$align = $align.append(if explicit == "auto" inferred else explicit)
		}
		match Table.allocate($desired, $fixed, config.terminal, config.plain) {
			Ok(widths) => Ok({ widths, align: $align, overflow: config.overflow, config })
			Err(TooNarrow) => Err(Invalid("Terminal too narrow for columns, padding, and borders; increase --terminal-width or reduce --widths"))
		}
	}
	streaming = |config, count| config.widths.len() == count and config.widths.all(|w| w > 0)
	row = |layout, cells, header| {
		var $out = []
		for i in 0..<layout.widths.len() {
			w = layout.widths.get(i) ?? 1
			value = Text.safe(cells.get(i) ?? "")
			clipped = Text.clip(value, w, layout.overflow.get(i) ?? "auto", layout.config.ascii)
			padded = Text.pad(clipped, w, layout.align.get(i) ?? "left")
			$out = $out.append(if layout.config.plain padded else " ${padded} ")
		}
		separator = if layout.config.plain "  " else if layout.config.ascii "|" else "│"
		body = $out |> Str.join_with(separator)
		line = if layout.config.plain body else "${separator}${body}${separator}"
		if header and layout.config.color == "always" and !layout.config.plain "\u(1b)[1;36m${line}\u(1b)[0m\n" else "${line}\n"
	}
	border = |layout, kind| {
		if layout.config.plain or layout.widths == [] { return "" }
		(left, middle, right) = if layout.config.ascii ("+", "+", "+") else match kind {
			"top" => ("┌", "┬", "┐")
			"bottom" => ("└", "┴", "┘")
			_ => ("├", "┼", "┤")
		}
		horizontal = if layout.config.ascii "-" else "─"
		body = layout.widths.map(|w| Text.repeat(horizontal, w + 2)) |> Str.join_with(middle)
		"${left}${body}${right}\n"
	}
	opening = |layout, header| {
		top = border(layout, "top")
		if header == [] top else "${top}${row(layout, header, True)}${border(layout, "middle")}"
	}
}

expect Render.prepare(Options.defaults, ["n", "s"], [["-12.30", "x"], ["text", "234"]]).map_ok(|l| l.align) == Ok(["right", "left"])
expect Render.prepare({ ..Options.defaults, align: ["left", "right"] }, [], [["12", "x"]]).map_ok(|l| l.align) == Ok(["left", "right"])
expect Render.prepare(Options.defaults, ["a", "b"], [["1"]]).is_err()
expect Render.prepare({ ..Options.defaults, widths: [5, 5] }, ["a"], []).is_err()
expect Render.streaming({ ..Options.defaults, widths: [5, 5] }, 2)
expect !Render.streaming({ ..Options.defaults, widths: [5, 0] }, 2)
expect !Render.streaming({ ..Options.defaults, widths: [5] }, 2)
