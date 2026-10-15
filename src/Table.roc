Table :: [].{
	headers = |rows, no_header, manual| {
		header = if manual != [] manual else if no_header [] else rows.first() ?? []
		{ header, rows: if no_header rows else rows.drop_first(1) }
	}
	# Fixed widths are immutable. Auto columns receive equal shares until satisfied.
	allocate : List(U64), List(U64), U64, Bool -> Try(List(U64), [TooNarrow])
	allocate = |desired, fixed, terminal, plain| {
		n = desired.len()
		if n == 0 { return Ok([]) }
		overhead = if plain 2 * (n - 1) else 3 * n + 1
		initial = fixed.map(|w| if w == 0 1 else w)
		minimum = overhead + initial.fold(0, |sum, w| sum + w)
		if minimum > terminal { return Err(TooNarrow) }
		var $widths = initial
		var $remaining = terminal - minimum
		var $changed = True
		while $remaining > 0 and $changed {
			$changed = False
			for i in 0..<n {
				if $remaining > 0 and (fixed.get(i) ?? 0) == 0 and ($widths.get(i) ?? 1) < (desired.get(i) ?? 1) {
					$widths = $widths.set(i, ($widths.get(i) ?? 1) + 1) ?? $widths
					$remaining = $remaining - 1
					$changed = True
				}
			}
		}
		Ok($widths)
	}
	parse_row = |line| {
		bytes = line.to_utf8()
		clean = if bytes.last() == Ok(13) Str.from_utf8_lossy(bytes.drop_last(1)) else line
		clean.split_on("\t")
	}
	classify = |text, decimal| {
		bytes = text.to_utf8()
		unsigned = if bytes.first() == Ok(43) or bytes.first() == Ok(45) Str.from_utf8_lossy(bytes.drop_first(1)) else text
		parts = unsigned.split_on(decimal)
		match parts {
			[whole] => if digits(whole) Number(0) else Text
			[whole, fraction] => if (whole == "" or digits(whole)) and (fraction == "" or digits(fraction)) and (whole != "" or fraction != "") Number(fraction.to_utf8().len()) else Text
			_ => Text
		}
	}
}

digits = |text| text != "" and text.to_utf8().all(|b| b >= 48 and b <= 57)

expect Table.parse_row("a\t\tb\t\r") == ["a", "", "b", ""]
expect Table.parse_row("") == [""]
expect Table.classify("-12", ".") == Number(0)
expect Table.classify("+12.340", ".") == Number(3)
expect Table.classify("12,30", ",") == Number(2)
expect Table.classify("12.30", ",") == Text
expect Table.classify("", ".") == Text
expect Table.classify("-", ".") == Text
expect Table.classify("1.2.3", ".") == Text

expect Table.headers([["Name", "Count"], ["a", "12"]], False, []) == { header: ["Name", "Count"], rows: [["a", "12"]] }
expect Table.headers([["a", "12"]], True, ["N", "C"]) == { header: ["N", "C"], rows: [["a", "12"]] }
expect Table.headers([["old"], ["data"]], False, ["new"]) == { header: ["new"], rows: [["data"]] }
expect Table.headers([], False, []) == { header: [], rows: [] }
expect Table.allocate([100, 3, 100], [0, 0, 0], 25, False) == Ok([6, 3, 6])
expect Table.allocate([100, 3], [5, 0], 17, False) == Ok([5, 3])
expect Table.allocate([1, 1], [8, 8], 12, False) == Err(TooNarrow)
expect Table.allocate([1, 1], [0, 0], 8, False) == Err(TooNarrow)
expect Table.allocate([100, 100], [0, 0], 8, True) == Ok([3, 3])

expect Table.classify(".5", ".") == Number(1)
expect Table.classify("-5.", ".") == Number(0)
expect Table.classify("+", ".") == Text
expect Table.classify(".", ".") == Text
expect Table.classify(" 12", ".") == Text
expect Table.classify("12e3", ".") == Text
