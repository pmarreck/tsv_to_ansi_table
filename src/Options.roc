Options :: [].{
	Config : { no_header : Bool, headers : List(Str), widths : List(U64), align : List(Str), overflow : List(Str), terminal : U64, color : Str, ascii : Bool, plain : Bool, decimal : Str, help : Bool, about : Bool }
	defaults : Config
	defaults = { no_header: False, headers: [], widths: [], align: [], overflow: [], terminal: 80, color: "auto", ascii: False, plain: False, decimal: ".", help: False, about: False }
	parse : List(Str), Config -> Try(Config, [Invalid(Str)])
	parse = |args, initial| {
		var $c = initial
		var $i = 0
		while $i < args.len() {
			arg = args.get($i) ?? ""
			match arg {
				"-h" | "--help" | "/h" | "/?" => { $c = { ..$c, help: True } }
				"--about" => { $c = { ..$c, about: True } }
				"--no-header" => { $c = { ..$c, no_header: True } }
				"--ascii" => { $c = { ..$c, ascii: True } }
				"--plain" => { $c = { ..$c, plain: True, color: "never" } }
				"--headers" | "--header" | "--widths" | "--align" | "--overflow" | "--terminal-width" | "--color" | "--decimal-separator" => {
					$i = $i + 1
					value = match args.get($i) {
						Ok(v) => v
						Err(_) => return Err(Invalid("Missing value for ${arg}"))
					}
					parts = value.split_on(",")
					match arg {
						"--headers" => { $c = { ..$c, headers: $c.headers.concat(parts) } }
						"--header" => { $c = { ..$c, headers: $c.headers.append(value) } }
						"--widths" => {
							var $ws = []
							for part in parts { $ws = $ws.append(if part == "auto" 0 else positive(part)?) }
							$c = { ..$c, widths: $ws }
						}
						"--terminal-width" => { $c = { ..$c, terminal: positive(value)? } }
						"--align" => {
							if !parts.all(|p| ["auto", "left", "right", "center"].contains(p)) { return Err(Invalid("Alignment must be auto, left, right, or center")) }
							$c = { ..$c, align: parts }
						}
						"--overflow" => {
							if !parts.all(|p| ["auto", "truncate", "truncate-left", "truncate-right", "prefix-ellipsis", "suffix-ellipsis"].contains(p)) { return Err(Invalid("Unknown overflow mode")) }
							$c = { ..$c, overflow: parts }
						}
						"--color" => {
							if !["auto", "always", "never"].contains(value) { return Err(Invalid("Color must be auto, always, or never")) }
							$c = { ..$c, color: value }
						}
						"--decimal-separator" => {
							if ![".", ",", "٫"].contains(value) { return Err(Invalid("Decimal separator must be '.', ',' or '٫'")) }
							$c = { ..$c, decimal: value }
						}
						_ => {}
					}
				}
				_ => return Err(Invalid("Unknown argument: ${arg}"))
			}
			$i = $i + 1
		}
		Ok($c)
	}
}

positive : Str -> Try(U64, [Invalid(Str)])
positive = |text| {
	match U64.from_str(text) {
		Ok(n) if n > 0 and n <= 10000 => Ok(n)
		_ => Err(Invalid("Widths must be integers from 1 to 10000 (or auto for columns)"))
	}
}
expect Options.parse(["--no-header", "--widths", "10,auto,3", "--align", "right,left,center"], Options.defaults).map_ok(|c| (c.no_header, c.widths, c.align)) == Ok((True, [10, 0, 3], ["right", "left", "center"]))
expect Options.parse(["--headers", "Name,Value", "--header", "Extra"], Options.defaults).map_ok(|c| c.headers) == Ok(["Name", "Value", "Extra"])
expect Options.parse(["--widths", "0"], Options.defaults).is_err()
expect Options.parse(["--align", "sideways"], Options.defaults).is_err()
expect Options.parse(["--terminal-width"], Options.defaults).is_err()
expect Options.parse(["--wat"], Options.defaults).is_err()
expect Options.parse(["--plain"], Options.defaults).map_ok(|c| (c.plain, c.color)) == Ok((True, "never"))
expect Options.parse(["--decimal-separator", ","], Options.defaults).map_ok(|c| c.decimal) == Ok(",")
expect Options.parse(["--overflow", "truncate-left,truncate-right,truncate,prefix-ellipsis,suffix-ellipsis,auto"], Options.defaults).map_ok(|c| c.overflow.len()) == Ok(6)
