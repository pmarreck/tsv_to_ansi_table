use crate::{Align, Color, Config, Error, Overflow, text};
type Row = Vec<String>;
fn owned(cells: &[&str]) -> Row { cells.iter().map(|s| (*s).into()).collect() }
fn borrowed(cells: &Row) -> Vec<&str> { cells.iter().map(String::as_str).collect() }
fn numeric(input: &str, decimal: &str) -> bool {
	let raw = input.strip_prefix(['+', '-']).unwrap_or(input);
	let digits = |s: &str| s.bytes().all(|b| b.is_ascii_digit());
	if let Some((whole, fraction)) = raw.split_once(decimal) {
		(!whole.is_empty() || !fraction.is_empty()) && digits(whole) && digits(fraction)
	} else { !raw.is_empty() && digits(raw) }
}
struct Layout { widths: Vec<usize>, align: Vec<Align> }
impl Layout {
	fn new(config: &Config, header: &[String], rows: &[Row]) -> Result<Self, Error> {
		let n = if !header.is_empty() { header.len() } else { rows.first().map_or(0, Vec::len) };
		if config.widths.len() > n || config.alignments.len() > n || config.overflow.len() > n { return Err(Error::TooManyOptions); }
		if rows.iter().any(|r| r.len() != n) { return Err(Error::RaggedRow); }
		let mut desired = vec![0; n];
		let mut widths = vec![1; n];
		let mut align = vec![Align::Left; n];
		let mut used = if n == 0 { 0 } else if config.plain { 2 * (n - 1) } else { 3 * n + 1 };
		for i in 0..n {
			desired[i] = header.get(i).map_or(0, |s| text::width(&text::safe(s)));
			for row in rows { desired[i] = desired[i].max(text::width(&text::safe(&row[i]))); }
			widths[i] = config.widths.get(i).copied().unwrap_or(0).max(1);
			used += widths[i];
			let explicit = config.alignments.get(i).copied().unwrap_or(Align::Auto);
			align[i] = if explicit != Align::Auto { explicit } else if rows.first().is_some_and(|row| numeric(&row[i], &config.decimal)) { Align::Right } else { Align::Left };
		}
		if used > config.terminal { return Err(Error::TooNarrow); }
		loop {
			let before = used;
			for i in 0..n {
				if used < config.terminal && config.widths.get(i).copied().unwrap_or(0) == 0 && widths[i] < desired[i] { widths[i] += 1; used += 1; }
			}
			if before == used { break; }
		}
		Ok(Self { widths, align })
	}
	fn border(&self, config: &Config, offset: usize) -> String {
		if config.plain || self.widths.is_empty() { return String::new(); }
		let mut out = config.glyph(offset).to_string();
		for (i, width) in self.widths.iter().enumerate() {
			out.push_str(&config.glyph(9).repeat(width + 2));
			out.push_str(config.glyph(offset + if i + 1 == self.widths.len() { 2 } else { 1 }));
		}
		out.push('\n'); out
	}
	fn row(&self, config: &Config, cells: &[&str], header: bool) -> String {
		let separator = if config.plain { "  " } else { config.glyph(10) };
		let color = header && config.color == Color::Always && !config.plain;
		let mut out = if config.plain { String::new() } else { separator.into() };
		for (i, cell) in cells.iter().enumerate() {
			let clean = text::safe(cell);
			let clipped = text::clip(&clean, self.widths[i], config.overflow.get(i).copied().unwrap_or(Overflow::Auto), config.glyph(11));
			let padded = text::pad(&clipped, self.widths[i], self.align[i]);
			if !config.plain { out.push(' '); }
			if color { out.push_str("\x1b[1;36m"); }
			out.push_str(&padded);
			if color { out.push_str("\x1b[0m"); }
			if !config.plain { out.push(' '); }
			if !config.plain || i + 1 < cells.len() { out.push_str(separator); }
		}
		out.push('\n'); out
	}
	fn opening(&self, config: &Config, header: &Row) -> String {
		let mut out = self.border(config, 0);
		if !header.is_empty() { out.push_str(&self.row(config, &borrowed(header), true)); out.push_str(&self.border(config, 3)); }
		out
	}
}

/// Independent stream state. Fixed widths retain only configuration and layout;
/// auto widths retain rows until finish. Returned Strings belong to the caller.
pub struct Engine {
	pub(crate) config: Config,
	header: Row,
	rows: Vec<Row>,
	layout: Option<Layout>,
	pub(crate) seen: usize,
	pub(crate) finished: bool,
	pub(crate) failed: bool,
}
impl Engine {
	pub fn new(config: Config) -> Result<Self, Error> {
		config.validate()?;
		Ok(Self { header: config.headers.clone(), config, rows: vec![], layout: None, seen: 0, finished: false, failed: false })
	}
	pub fn push(&mut self, cells: &[&str]) -> Result<String, Error> {
		if self.failed || self.finished { return Err(Error::InvalidState); }
		let result = self.push_inner(cells);
		if result.is_err() { self.failed = true; }
		result
	}
	fn push_inner(&mut self, cells: &[&str]) -> Result<String, Error> {
		if cells.is_empty() { return Err(Error::InvalidArgument); }
		if self.seen == 0 && !self.config.no_header {
			if !self.header.is_empty() && self.header.len() != cells.len() { return Err(Error::HeaderCount); }
			if self.header.is_empty() { self.header = owned(cells); }
			self.seen += 1; return Ok(String::new());
		}
		let count = if !self.header.is_empty() { self.header.len() } else if let Some(layout) = &self.layout { layout.widths.len() } else { self.rows.first().map_or(cells.len(), Vec::len) };
		if count != cells.len() { return Err(Error::RaggedRow); }
		self.seen += 1;
		if let Some(layout) = &self.layout { return Ok(layout.row(&self.config, cells, false)); }
		if self.config.widths.len() == count && self.config.widths.iter().all(|w| *w > 0) {
			let layout = Layout::new(&self.config, &self.header, &[owned(cells)])?;
			let out = layout.opening(&self.config, &self.header) + &layout.row(&self.config, cells, false);
			self.layout = Some(layout); return Ok(out);
		}
		self.rows.push(owned(cells)); Ok(String::new())
	}
	pub fn finish(&mut self) -> Result<String, Error> {
		if self.failed || self.finished { return Err(Error::InvalidState); }
		self.finished = true;
		if let Some(layout) = &self.layout { return Ok(layout.border(&self.config, 6)); }
		if self.header.is_empty() && self.rows.is_empty() { return Ok(String::new()); }
		let layout = Layout::new(&self.config, &self.header, &self.rows)?;
		let mut out = layout.opening(&self.config, &self.header);
		for row in &self.rows { out.push_str(&layout.row(&self.config, &borrowed(row), false)); }
		out.push_str(&layout.border(&self.config, 6)); Ok(out)
	}
	pub fn push_tsv(&mut self, line: &str) -> Result<String, Error> {
		if line.contains('\n') { self.failed = true; return Err(Error::InvalidArgument); }
		self.push(&line.strip_suffix('\r').unwrap_or(line).split('\t').collect::<Vec<_>>())
	}
}
/// Render a complete table from cells, preserving the CLI's header semantics.
pub fn render_table(config: &Config, rows: &[&[&str]]) -> Result<String, Error> {
	let mut engine = Engine::new(config.clone())?;
	let mut out = String::new();
	for row in rows { out.push_str(&engine.push(row)?); }
	out.push_str(&engine.finish()?); Ok(out)
}
