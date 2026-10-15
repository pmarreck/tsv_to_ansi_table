import Options
import Render
import Table

Engine :: [].{
	State : { config : Options.Config, header : List(Str), rows : List(List(Str)), seen : U64, layout : List(Render.Layout), ended : Bool }
	Step : { state : State, output : Str }
	start = |config| { config, header: config.headers, rows: [], seen: 0, layout: [], ended: False }
	push : State, List(Str) -> Try(Step, [Invalid(Str)])
	push = |state, row| {
		if state.ended { return Err(Invalid("Input after end of stream")) }
		if state.seen == 0 and !state.config.no_header {
			header = if state.config.headers == [] row else state.config.headers
			if header.len() != row.len() { return Err(Invalid("Manual header count does not match input")) }
			return Ok({ state: { ..state, header, seen: 1 }, output: "" })
		}
		n = if state.header != [] state.header.len() else if state.rows != [] (state.rows.first() ?? []).len() else if state.layout != [] ((state.layout.first() ?? crash "layout").widths.len()) else row.len()
		if row.len() != n { return Err(Invalid("Ragged row: every row must have the same number of fields")) }
		match state.layout {
			[layout] => Ok({ state: { ..state, seen: state.seen + 1 }, output: Render.row(layout, row, False) })
			_ => {
				if Render.streaming(state.config, n) {
					layout = Render.prepare(state.config, state.header, [row])?
					Ok({ state: { ..state, seen: state.seen + 1, layout: [layout] }, output: "${Render.opening(layout, state.header)}${Render.row(layout, row, False)}" })
				} else {
					Ok({ state: { ..state, seen: state.seen + 1, rows: state.rows.append(row) }, output: "" })
				}
			}
		}
	}
	finish : State -> Try(Step, [Invalid(Str)])
	finish = |state| {
		if state.ended { return Err(Invalid("Stream already ended")) }
		ended = { ..state, ended: True, rows: [] }
		match state.layout {
			[layout] => Ok({ state: ended, output: Render.border(layout, "bottom") })
			_ => {
				if state.header == [] and state.rows == [] { return Ok({ state: ended, output: "" }) }
				layout = Render.prepare(state.config, state.header, state.rows)?
				body = state.rows.map(|row| Render.row(layout, row, False)) |> Str.join_with("")
				Ok({ state: ended, output: "${Render.opening(layout, state.header)}${body}${Render.border(layout, "bottom")}" })
			}
		}
	}
}

expect {
	config = { ..Options.defaults, widths: [5, 5] }
	s0 = Engine.start(config)
	s1 = Engine.push(s0, ["Name", "N"]) ?? crash "header rejected"
	s2 = Engine.push(s1.state, ["a", "12"]) ?? crash "data rejected"
	s1.output == "" and s2.output != "" and s2.state.rows == [] and s2.state.layout.len() == 1
}
expect {
	s1 = Engine.push(Engine.start(Options.defaults), ["N"]) ?? crash "header rejected"
	s2 = Engine.push(s1.state, ["12"]) ?? crash "data rejected"
	s3 = Engine.finish(s2.state) ?? crash "finish rejected"
	s1.output == "" and s2.output == "" and s3.output != "" and s3.state.ended
}
expect Engine.push(Engine.start({ ..Options.defaults, no_header: True, headers: ["a", "b"] }), ["1"]).is_err()
expect Engine.finish(Engine.start(Options.defaults)).map_ok(|step| step.output) == Ok("")

expect {
	c = { ..Options.defaults, widths: [5], no_header: True }
	s1 = Engine.push(Engine.start(c), ["12"]) ?? crash "first row"
	s2 = Engine.push(s1.state, ["x"]) ?? crash "second row"
	(s2.state.layout.first() ?? crash "layout").align == ["right"] and s2.state.rows == []
}
expect {
	s1 = Engine.push(Engine.start(Options.defaults), ["a", "b"]) ?? crash "header"
	Engine.push(s1.state, ["1"]).is_err()
}
expect {
	s1 = Engine.finish(Engine.start(Options.defaults)) ?? crash "finish"
	Engine.push(s1.state, ["1"]).is_err() and Engine.finish(s1.state).is_err()
}
expect {
	c = { ..Options.defaults, headers: ["one"], no_header: True, widths: [5] }
	s1 = Engine.push(Engine.start(c), ["123"]) ?? crash "data"
	s1.state.header == ["one"] and (s1.state.layout.first() ?? crash "layout").align == ["right"]
}
