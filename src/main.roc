app [main!] {
	pf: platform "https://github.com/roc-lang/basic-cli/releases/download/0.25.0/CZsY7tYZwR3rj9kYbpaCfxki2yVAaRL8bBwMLvB2xkbA.tar.zst",
	unicode: "https://github.com/roc-lang/unicode/releases/download/4.2.0/4W8SHzvwet9hH9qZewJ1J1CVQoH7YKA6zyijWFTB3y1w.tar.zst",
	random: "https://github.com/pmarreck/random/archive/76ada4a2d6259569f901985b08d8d5ad10f45059.tar.gz",
}
import Table
import Text
import Options
import Render
import Engine
import BuildInfo
import Glyphs
import Example
import pf.Console
import pf.Env
import pf.Cmd
import pf.OsStr
import pf.Stdin
import pf.Stdout
import pf.Stderr
import pf.Random
import "help.txt" as help : Str

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
	if config.example {
		seed = match config.seed {
			[value] => value
			_ => Example.seed(Random.seed_u64!()?.to_str())?
		}
		rows = Example.generate(seed, config.decimal)?
		Stderr.line!("seed=${seed}")?
		input = if config.no_header rows.drop_first(1) else rows
		for row in input {
			step = Engine.push($state, row)?
			if step.output != "" { Stdout.write!(step.output)? }
			$state = step.state
		}
		return Stdout.write!(Engine.finish($state)?.output)
	}
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
