import Text

Glyphs :: [].{
	Set : { top_left : Str, top_join : Str, top_right : Str, middle_left : Str, middle_join : Str, middle_right : Str, bottom_left : Str, bottom_join : Str, bottom_right : Str, horizontal : Str, vertical : Str, ellipsis : Str }
	defaults : Set
	defaults = { top_left: "┌", top_join: "┬", top_right: "┐", middle_left: "├", middle_join: "┼", middle_right: "┤", bottom_left: "└", bottom_join: "┴", bottom_right: "┘", horizontal: "─", vertical: "│", ellipsis: "…" }
	ascii : Set
	ascii = { top_left: "+", top_join: "+", top_right: "+", middle_left: "+", middle_join: "+", middle_right: "+", bottom_left: "+", bottom_join: "+", bottom_right: "+", horizontal: "-", vertical: "|", ellipsis: "..." }
	parse : Str -> Try(Set, [Invalid(Str)])
	parse = |raw| {
		if raw == "" { return Ok(defaults) }
		decoded : Try(Dict(Str, Str), [InvalidJson(Str)])
		decoded = Json.parse(raw)
		pairs = match decoded {
			Ok(values) => values.to_list()
			Err(_) => return Err(Invalid("TSV_TO_ANSI_TABLE_GLYPHS must be a JSON object of named strings"))
		}
		var $g = defaults
		for (name, value) in pairs {
			if Text.clusters(value).len() != 1 or Text.width(value) != 1 or Text.safe(value) != value {
				return Err(Invalid("Glyph ${name} must be one safe grapheme occupying one display cell"))
			}
			match name {
				"top_left" => { $g = { ..$g, top_left: value } }
				"top_join" => { $g = { ..$g, top_join: value } }
				"top_right" => { $g = { ..$g, top_right: value } }
				"middle_left" => { $g = { ..$g, middle_left: value } }
				"middle_join" => { $g = { ..$g, middle_join: value } }
				"middle_right" => { $g = { ..$g, middle_right: value } }
				"bottom_left" => { $g = { ..$g, bottom_left: value } }
				"bottom_join" => { $g = { ..$g, bottom_join: value } }
				"bottom_right" => { $g = { ..$g, bottom_right: value } }
				"horizontal" => { $g = { ..$g, horizontal: value } }
				"vertical" => { $g = { ..$g, vertical: value } }
				"ellipsis" => { $g = { ..$g, ellipsis: value } }
				_ => return Err(Invalid("Unknown glyph name: ${name}"))
			}
		}
		Ok($g)
	}
}

expect Glyphs.parse("{\"top_left\":\"╭\",\"ellipsis\":\"~\"}").map_ok(|g| (g.top_left, g.top_right, g.ellipsis)) == Ok(("╭", "┐", "~"))
expect Glyphs.parse("{}").map_ok(|g| g.vertical) == Ok("│")
expect Glyphs.parse("") == Ok(Glyphs.defaults)
expect ["null", "[]", "bad", "{\"x\":\"!\"}", "{\"vertical\":1}", "{\"vertical\":\"界\"}", "{\"vertical\":\"\u(1b)\"}", "{\"vertical\":\"\"}", "{\"vertical\":\"||\"}"].all(|raw| Glyphs.parse(raw).is_err())
