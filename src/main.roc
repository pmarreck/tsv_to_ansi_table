app [main!] {
	pf: platform "https://github.com/roc-lang/basic-cli/releases/download/0.25.0/CZsY7tYZwR3rj9kYbpaCfxki2yVAaRL8bBwMLvB2xkbA.tar.zst",
	unicode: "https://github.com/roc-lang/unicode/releases/download/4.2.0/4W8SHzvwet9hH9qZewJ1J1CVQoH7YKA6zyijWFTB3y1w.tar.zst",
}
import Table
import Text
import Options
import Render
import Engine
import BuildInfo
import Glyphs
import pf.Console
import pf.Env
import pf.Cmd
import pf.OsStr
import pf.Stdin
import pf.Stdout
import pf.Stderr

main! = |native_args| {
	Stderr.write!(BuildInfo.banner) ?? {}
	var $args = []
	for arg in native_args {
		match OsStr.to_str_try(arg) {
			Ok(text) => { $args = $args.append(text) }
			Err(_) => {
				Stderr.line!("tsv-to-ansi-table: arguments must be UTF-8") ?? {}
				return Err(Exit(2))
			}
		}
	}
	match run!($args) {
		Ok({}) => Ok({})
		Err(Invalid(message)) => {
			Stderr.line!("tsv-to-ansi-table: ${Text.safe(message)}") ?? {}
			Err(Exit(2))
		}
		Err(other) => {
			Stderr.line!("tsv-to-ansi-table: ${Text.safe(Str.inspect(other))}") ?? {}
			Err(Exit(1))
		}
	}
}

run! = |args| {
	parsed = Options.parse(args, Options.defaults)?
	if parsed.help { return Stdout.write!(help) }
	if parsed.about {
		target = Env.platform!()
		return Stdout.line!("tsv-to-ansi-table 0.1.0 (Roc; ${Str.inspect(target.os)}/${Str.inspect(target.arch)}): render TSV as terminal tables")
	}
	columns = Console.width!()
	env_width = U64.from_str(Env.var_str!("COLUMNS") ?? "") ?? 0
	width = if env_width > 0 and env_width <= 10000 env_width else if columns > 0 columns else 80
	native_decimal = Console.windows_decimal!()
	decimal = if native_decimal == 44 "," else if native_decimal == 0x66B "٫" else if native_decimal != 0 "." else {
		match Cmd.new("locale").args(["decimal_point"]).exec_output!() {
			Ok(result) => {
				value = result.stdout_utf8.trim()
				if [".", ",", "٫"].contains(value) value else "."
			}
			Err(_) => "."
		}
	}
	raw_glyphs = match Env.var_str!("TSV_TO_ANSI_TABLE_GLYPHS") {
		Ok(value) => value
		Err(VarNotFound(_)) => ""
		Err(_) => return Err(Invalid("Cannot read TSV_TO_ANSI_TABLE_GLYPHS as UTF-8"))
	}
	glyphs = Glyphs.parse(raw_glyphs)?
	config = Options.parse(args, { ..Options.defaults, terminal: width, decimal, glyphs })?
	color = if config.color == "auto" {
		if columns > 0 and Env.var_str!("NO_COLOR").is_err() and (Env.var_str!("TERM") ?? "") != "dumb" "always" else "never"
	} else config.color
	var $state = Engine.start({ ..config, color })
	var $eof = False
	while !$eof {
		match Stdin.line!() {
			Ok(line) => {
				step = Engine.push($state, Table.parse_row(line))?
				if step.output != "" { Stdout.write!(step.output)? }
				$state = step.state
			}
			Err(EndOfFile) => { $eof = True }
			Err(other) => return Err(other)
		}
	}
	last = Engine.finish($state)?
	Stdout.write!(last.output)
}


help = "tsv-to-ansi-table: render UTF-8 TSV from stdin\n\nUsage: tsv-to-ansi-table [OPTIONS] < input.tsv\n\n  --no-header                 Treat the first input row as data\n  --headers NAME,NAME         Replace the input header (prepend with --no-header)\n  --header NAME               Append one explicit header name; repeatable\n  --widths auto,12,8          Content widths; any auto buffers until EOF\n  --align auto,left,right,center  Positional column alignment\n  --overflow MODE,MODE        auto, truncate-left, truncate-right (truncate),\n                             prefix-ellipsis, or suffix-ellipsis\n  --terminal-width N          Total output width (otherwise TTY, COLUMNS, or 80)\n  --decimal-separator CHAR    Override locale decimal point: . , or ٫\n  --color auto|always|never   Auto uses color on a TTY unless NO_COLOR is set\n  --ascii                    ASCII borders and ellipsis\n  --plain                    Borderless, colorless aligned output\n  -h, --help                 Show help\n  --about                    Show version and compiled platform\n\nTSV_TO_ANSI_TABLE_GLYPHS accepts JSON overrides for border/ellipsis glyphs.\nExample: {\"top_left\":\"╭\",\"top_right\":\"╮\",\"ellipsis\":\"~\"}\nEach override must be one safe one-cell grapheme; omitted names keep defaults.\n--ascii overrides the custom profile; --plain still uses its ellipsis.\n\nNumbers are inferred from the first data row and right-aligned by default.\nText and numeric digits are preserved; long cells are clipped without splitting\ngraphemes. Paths keep their tail by default. Ragged rows and invalid UTF-8 fail.\nAll fixed widths stream after header/first-data-row inference; late errors can\nfollow already-written rows. Redirected output keeps Unicode, without color.\n"
