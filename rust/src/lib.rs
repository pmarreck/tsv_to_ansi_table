//! Pure table rendering with an optional C ABI boundary.
mod config;
mod engine;
mod ffi;
pub mod example;
mod text;
pub use config::{Align, Color, Config, Overflow};
pub use engine::{Engine, render_table};

#[repr(i32)]
#[derive(Clone, Copy, Debug, PartialEq, Eq)]
pub enum Error {
	InvalidArgument = 1, InvalidOptions = 2, InvalidUtf8 = 3, RaggedRow = 4,
	HeaderCount = 5, TooManyOptions = 6, TooNarrow = 7, InvalidGlyphs = 8,
	InvalidSeed = 9, OutOfMemory = 10, InvalidState = 11, Internal = 12,
}
impl std::fmt::Display for Error {
	fn fmt(&self, f: &mut std::fmt::Formatter<'_>) -> std::fmt::Result { write!(f, "{self:?}") }
}
impl std::error::Error for Error {}
