use crate::config::{Align, Overflow};
use utf8proc_sys::{utf8proc_category, utf8proc_charwidth, utf8proc_grapheme_break_stateful};

/// Segment valid UTF-8 into graphemes and compute display cells, matching the
/// documented Unicode policy rather than byte length or scalar count.
pub fn clusters(input: &str) -> Vec<(&str, usize)> {
	let mut out = vec![];
	let (mut start, mut previous, mut state, mut cells) = (0, 0, 0, 0);
	for (offset, ch) in input.char_indices() {
		let cp = ch as i32;
		// Scalars are valid Unicode and state is private to this ordered scan.
		unsafe {
			if offset > 0 && utf8proc_grapheme_break_stateful(previous, cp, &mut state) {
				out.push((&input[start..offset], cells)); start = offset; cells = 0;
			}
			let category = utf8proc_category(cp).0;
			let mut width = if matches!(category, 6 | 8 | 27) { 0 } else { utf8proc_charwidth(cp).max(0) as usize };
			if cp == 0xfe0f || cp == 0x20e3 || (0x1f1e6..=0x1f1ff).contains(&cp) { width = 2; }
			cells = cells.max(width);
		}
		previous = cp;
	}
	if !input.is_empty() { out.push((&input[start..], cells)); }
	out
}
pub fn width(input: &str) -> usize { clusters(input).iter().map(|p| p.1).sum() }
pub fn safe(input: &str) -> String {
	let clean: String = input.chars().map(|ch| {
		let cp = ch as i32;
		// utf8proc accepts every scalar yielded by str::chars.
		let category = unsafe { utf8proc_category(cp).0 };
		if matches!(category, 24..=26) || (category == 27 && cp != 0x200c && cp != 0x200d && !(0xe0020..=0xe007f).contains(&cp)) { '�' } else { ch }
	}).collect();
	let mut out = String::new();
	for (s, width) in clusters(&clean) { if width == 0 { out.push('◌'); } out.push_str(s); }
	out
}
pub fn valid_glyph(value: &str) -> bool {
	let parts = clusters(value);
	parts.len() == 1 && parts[0].1 == 1 && safe(value) == value
}
pub fn clip(input: &str, size: usize, mode: Overflow, glyph: &str) -> String {
	if width(input) <= size { return input.into(); }
	let mode = if mode == Overflow::Auto { if input.contains(['/', '\\']) { Overflow::PrefixEllipsis } else { Overflow::SuffixEllipsis } } else { mode };
	let ellipsis = matches!(mode, Overflow::PrefixEllipsis | Overflow::SuffixEllipsis);
	let marker = if !ellipsis || size == 0 { "" } else if glyph == "..." { &glyph[..size.min(3)] } else { glyph };
	let budget = size.saturating_sub(width(marker));
	let parts = clusters(input);
	let from_end = matches!(mode, Overflow::PrefixEllipsis | Overflow::TruncateLeft);
	let mut used = 0;
	let mut bytes = 0;
	for i in 0..parts.len() {
		let (s, width) = parts[if from_end { parts.len() - i - 1 } else { i }];
		if used + width > budget { break; }
		used += width; bytes += s.len();
	}
	if from_end { format!("{marker}{}", &input[input.len() - bytes..]) } else { format!("{}{marker}", &input[..bytes]) }
}
pub fn pad(input: &str, size: usize, alignment: Align) -> String {
	let gap = size.saturating_sub(width(input));
	let left = match alignment { Align::Right => gap, Align::Center => gap / 2, _ => 0 };
	format!("{}{input}{}", " ".repeat(left), " ".repeat(gap - left))
}
