use crate::{Error, text};

#[derive(Clone, Copy, Debug, PartialEq, Eq)]
pub enum Align { Auto, Left, Right, Center }
#[derive(Clone, Copy, Debug, PartialEq, Eq)]
pub enum Overflow { Auto, TruncateLeft, TruncateRight, PrefixEllipsis, SuffixEllipsis }
#[derive(Clone, Copy, Debug, PartialEq, Eq)]
pub enum Color { Auto, Always, Never }

pub const GLYPH_NAMES: [&str; 12] = ["top_left", "top_join", "top_right", "middle_left", "middle_join", "middle_right", "bottom_left", "bottom_join", "bottom_right", "horizontal", "vertical", "ellipsis"];
const DEFAULT_GLYPHS: [&str; 12] = ["┌", "┬", "┐", "├", "┼", "┤", "└", "┴", "┘", "─", "│", "…"];
pub const ASCII_GLYPHS: [&str; 12] = ["+", "+", "+", "+", "+", "+", "+", "+", "+", "-", "|", "..."];

/// Owned rendering options; no field is inferred from process-global state.
#[derive(Clone, Debug)]
pub struct Config {
	pub terminal: usize,
	pub no_header: bool,
	pub headers: Vec<String>,
	pub widths: Vec<usize>,
	pub alignments: Vec<Align>,
	pub overflow: Vec<Overflow>,
	pub color: Color,
	pub ascii: bool,
	pub plain: bool,
	pub decimal: String,
	pub glyphs: [String; 12],
	pub help: bool,
	pub about: bool,
	pub example: bool,
	pub seed: Option<[u8; 32]>,
}
impl Default for Config {
	fn default() -> Self {
		Self { terminal: 80, no_header: false, headers: vec![], widths: vec![], alignments: vec![], overflow: vec![], color: Color::Never, ascii: false, plain: false, decimal: ".".into(), glyphs: DEFAULT_GLYPHS.map(String::from), help: false, about: false, example: false, seed: None }
	}
}
fn positive(value: &str) -> Result<usize, Error> {
	let value = value.parse::<usize>().map_err(|_| Error::InvalidOptions)?;
	if value == 0 || value > 10000 { return Err(Error::InvalidOptions); }
	Ok(value)
}
impl Config {
	/// Parse the CLI's rendering options with explicit, caller-provided defaults.
	pub fn parse(args: &[&str], mut config: Self) -> Result<Self, Error> {
		let mut i = 0;
		while i < args.len() {
			let arg = args[i];
			if i == 0 && arg == "example" { config.example = true; i += 1; continue; }
			match arg {
				"--help" | "-h" | "/h" | "/?" => config.help = true,
				"--about" => config.about = true,
				"--no-header" => config.no_header = true,
				"--ascii" => config.ascii = true,
				"--plain" => { config.plain = true; config.color = Color::Never; }
				_ => {
					let (arg, value) = if let Some(pair) = arg.split_once('=') { pair } else {
						i += 1;
						(arg, *args.get(i).ok_or(Error::InvalidOptions)?)
					};
					match arg {
						"--seed" => {
							if !config.example || config.seed.is_some() { return Err(Error::InvalidOptions); }
							config.seed = Some(crate::example::parse_seed(value)?);
						}
						"--header" => config.headers.push(value.into()),
						"--headers" => config.headers.extend(value.split(',').map(String::from)),
						"--widths" => config.widths = value.split(',').map(|s| if s == "auto" { Ok(0) } else { positive(s) }).collect::<Result<_, _>>()?,
						"--terminal-width" => config.terminal = positive(value)?,
						"--align" => config.alignments = value.split(',').map(|s| match s { "auto" => Ok(Align::Auto), "left" => Ok(Align::Left), "right" => Ok(Align::Right), "center" => Ok(Align::Center), _ => Err(Error::InvalidOptions) }).collect::<Result<_, _>>()?,
						"--overflow" => config.overflow = value.split(',').map(|s| match s { "auto" => Ok(Overflow::Auto), "truncate" | "truncate-right" => Ok(Overflow::TruncateRight), "truncate-left" => Ok(Overflow::TruncateLeft), "prefix-ellipsis" => Ok(Overflow::PrefixEllipsis), "suffix-ellipsis" => Ok(Overflow::SuffixEllipsis), _ => Err(Error::InvalidOptions) }).collect::<Result<_, _>>()?,
						"--color" => config.color = match value { "auto" => Color::Auto, "always" => Color::Always, "never" => Color::Never, _ => return Err(Error::InvalidOptions) },
						"--decimal-separator" if matches!(value, "." | "," | "٫") => config.decimal = value.into(),
						_ => return Err(Error::InvalidOptions),
					}
				}
			}
			i += 1;
		}
		Ok(config)
	}
	pub fn set_glyphs_json(&mut self, raw: &str) -> Result<(), Error> {
		if raw.is_empty() { return Ok(()); }
		let parsed: serde_json::Value = serde_json::from_str(raw).map_err(|_| Error::InvalidGlyphs)?;
		let object = parsed.as_object().ok_or(Error::InvalidGlyphs)?;
		let mut glyphs = self.glyphs.clone();
		for (key, value) in object {
			let i = GLYPH_NAMES.iter().position(|name| name == key).ok_or(Error::InvalidGlyphs)?;
			let value = value.as_str().ok_or(Error::InvalidGlyphs)?;
			if !text::valid_glyph(value) { return Err(Error::InvalidGlyphs); }
			glyphs[i] = value.into();
		}
		self.glyphs = glyphs;
		Ok(())
	}
	pub(crate) fn validate(&self) -> Result<(), Error> {
		if self.terminal == 0 || self.terminal > 10000 || self.widths.iter().any(|w| *w > 10000) || !matches!(self.decimal.as_str(), "." | "," | "٫") { return Err(Error::InvalidOptions); }
		if !self.glyphs.iter().all(|g| text::valid_glyph(g)) { return Err(Error::InvalidGlyphs); }
		Ok(())
	}
	pub(crate) fn glyph(&self, index: usize) -> &str { if self.ascii { ASCII_GLYPHS[index] } else { &self.glyphs[index] } }
}
