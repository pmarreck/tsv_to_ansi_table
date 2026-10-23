//! Seeded examples use randomr's integer-only distributions and shared vocabulary.
use crate::{Engine, Error};
use randomr::{Drbg, Fixed, exponential, range};

pub fn parse_seed(raw: &str) -> Result<[u8; 32], Error> {
	let hex = raw.starts_with("0x") || raw.starts_with("0X");
	let digits = if hex { &raw[2..] } else { raw };
	if digits.is_empty() || (hex && digits.len() > 64) { return Err(Error::InvalidSeed); }
	let mut bytes = [0u8; 32];
	for ch in digits.bytes() {
		let digit = match ch { b'0'..=b'9' => ch - b'0', b'a'..=b'f' if hex => ch - b'a' + 10, b'A'..=b'F' if hex => ch - b'A' + 10, _ => return Err(Error::InvalidSeed) };
		let mut carry = u16::from(digit);
		for b in bytes.iter_mut().rev() {
			let next = u16::from(*b) * if hex { 16 } else { 10 } + carry;
			*b = next as u8; carry = next >> 8;
		}
		if carry != 0 { return Err(Error::InvalidSeed); }
	}
	Ok(bytes)
}
pub fn canonical(seed: &[u8; 32]) -> String {
	use std::fmt::Write;
	let mut out = String::from("0x");
	for b in seed { write!(out, "{b:02x}").unwrap(); }
	out
}
fn draw(rng: &mut Drbg, first: i64, last: i64) -> Result<i64, Error> {
	range(rng, first, last).map_err(|_| Error::Internal)
}
pub fn generate(seed: [u8; 32], decimal: &str) -> Result<Vec<Vec<String>>, Error> {
	let words: Vec<_> = include_str!("../../src/example-words.txt").lines().collect();
	if words.len() != 100 { return Err(Error::Internal); }
	let mut rng = Drbg::new(&seed);
	let count = draw(&mut rng, 4, 6)? as usize;
	let mut header = vec![];
	let mut numeric = vec![];
	let mut precision = vec![];
	let mut limits = vec![];
	for i in 0..count {
		header.push(words[draw(&mut rng, 0, 99)? as usize].into());
		let kind = draw(&mut rng, 0, 1)?;
		numeric.push(if i == 0 { false } else if i == 1 { true } else { kind == 1 });
		precision.push(draw(&mut rng, 0, 6)? as usize);
		limits.push(10i64.pow(draw(&mut rng, 1, 5)? as u32) - 1);
	}
	let mut rows = vec![header];
	for _ in 0..12 {
		let mut row = vec![];
		for column in 0..count {
			let mut cell = String::new();
			if numeric[column] {
				let whole = draw(&mut rng, 0, limits[column])?;
				if draw(&mut rng, 0, 3)? == 0 { cell.push('-'); }
				cell.push_str(&whole.to_string());
				if precision[column] > 0 { cell.push_str(decimal); }
				for _ in 0..precision[column] { cell.push((b'0' + draw(&mut rng, 0, 9)? as u8) as char); }
			} else {
				let half = Fixed::from_i64(1).div(Fixed::from_i64(2)).map_err(|_| Error::Internal)?;
				let count = (exponential(&mut rng, half).map_err(|_| Error::Internal)?.to_i64_trunc() + 1).min(8);
				for i in 0..count {
					if i > 0 { cell.push(' '); }
					cell.push_str(words[draw(&mut rng, 0, 99)? as usize]);
				}
			}
			row.push(cell);
		}
		rows.push(row);
	}
	Ok(rows)
}
impl Engine {
	/// Generate only on a fresh context, using a configured seed or explicit bytes.
	pub fn example(&mut self, supplied: [u8; 32]) -> Result<([u8; 32], String), Error> {
		if self.seen != 0 || self.finished || self.failed { return Err(Error::InvalidState); }
		let seed = self.config.seed.unwrap_or(supplied);
		let result = (|| {
			let rows = generate(seed, &self.config.decimal)?;
			let mut output = String::new();
			for row in rows.iter().skip(usize::from(self.config.no_header)) {
				output.push_str(&self.push(&row.iter().map(String::as_str).collect::<Vec<_>>())?);
			}
			output.push_str(&self.finish()?);
			Ok((seed, output))
		})();
		if result.is_err() { self.failed = true; }
		result
	}
}
