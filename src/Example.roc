import random.Codec
import random.Drbg
import random.Sampler
import random.Fixed
import "example-words.txt" as vocabulary : Str

Example :: [].{
	words = vocabulary.trim().split_on("\n")
	seed : Str -> Try(Str, [Invalid(Str)])
	seed = |raw| match Codec.seed(raw) {
		Ok(bytes) => Ok("0x${Codec.hex(bytes)}")
		Err(_) => Err(Invalid("Seed must be an unsigned decimal or 0x hexadecimal integer smaller than 2^256"))
	}

	generate : Str, Str -> Try(List(List(Str)), [Invalid(Str)])
	generate = |raw, decimal| {
		canonical = seed(raw)?
		match generate_rows(canonical, decimal) {
			Ok(rows) => Ok(rows)
			Err(_) => Err(Invalid("Example generation failed"))
		}
	}
}

# Draw order is shared with zig/example.zig. Rendering never consumes randomness.
generate_rows = |seed, decimal| {
	initial = Drbg.new(Codec.seed(seed)?)?
	(columns, after_count) = initial.range(4, 6)?
	var $rng = after_count
	var $header = []
	var $numeric = []
	var $precision = []
	var $limits = []
	for column in 0..<columns {
		(word, r1) = $rng.range(0, 99)?
		(kind, r2) = r1.range(0, 1)?
		(places, r3) = r2.range(0, 6)?
		(digits, r4) = r3.range(1, 5)?
		$rng = r4
		$header = $header.append(Example.words.get(word.to_u64_wrap()) ?? "synergy")
		$numeric = $numeric.append(if column == 0 False else if column == 1 True else kind == 1)
		$precision = $precision.append(places)
		var $limit = 1.I64
		for _ in 0..<digits { $limit = $limit * 10 }
		$limits = $limits.append($limit - 1)
	}
	var $rows = [$header]
	for _ in 0..<12 {
		var $row = []
		for column in 0..<columns {
			index = column.to_u64_wrap()
			if $numeric.get(index) ?? False {
				(whole, r1) = $rng.range(0, $limits.get(index) ?? 9)?
				(sign, r2) = r1.range(0, 3)?
				$rng = r2
				var $cell = if sign == 0 "-${whole.to_str()}" else whole.to_str()
				places = $precision.get(index) ?? 0
				if places > 0 { $cell = $cell.concat(decimal) }
				for _ in 0..<places {
					(digit, next) = $rng.range(0, 9)?
					$rng = next
					$cell = $cell.concat(digit.to_str())
				}
				$row = $row.append($cell)
			} else {
				(length, next) = Sampler.exponential(Fixed.power_of_two(-1)).run_with($rng, |state, count| state.bytes(count))?
				$rng = next
				count = I64.min(8, length.to_int_trunc() + 1)
				var $phrases = []
				for _ in 0..<count {
					(word, after_word) = $rng.range(0, 99)?
					$rng = after_word
					$phrases = $phrases.append(Example.words.get(word.to_u64_wrap()) ?? "synergy")
				}
				$row = $row.append(Str.join_with($phrases, " "))
			}
		}
		$rows = $rows.append($row)
	}
	Ok($rows)
}

expect Example.words.len() == 100
expect Example.seed("42") == Example.seed("0x2a")
expect Example.seed("-1").is_err()
expect Example.generate("42", ".").map_ok(|rows| rows.len()) == Ok(13)
expect {
	rows = Example.generate("42", ".") ?? crash "example"
	# Independently checked with random's Lua DRBG: indices 53,90,64,52,41.
	(rows.first() ?? []) == ["context", "not just a chatbot", "latent space", "attention", "quarterly optimism"]
}
