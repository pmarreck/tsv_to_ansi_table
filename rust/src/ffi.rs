//! C ABI adapters. The caller guarantees live, correctly aligned input objects;
//! all strings are length-delimited and copied before a call returns.
use crate::{Color, Config, Engine, Error};
use std::{ffi::{c_char, c_int, c_uint}, panic::{catch_unwind, AssertUnwindSafe}, ptr, slice, str};

#[repr(C)]
pub struct Slice { data: *const u8, len: usize }
#[repr(C)]
pub struct Row { cells: *const Slice, len: usize }
#[repr(C)]
pub struct Buffer { data: *mut u8, len: usize }
#[repr(C)]
pub struct Options { terminal_width: usize, decimal: Slice, glyphs_json: Slice, color: c_int, args: *const Slice, argc: usize }

// Raw pointers are never dereferenced until null/length checks have passed.
// Pointer validity, alignment, provenance and actual allocation size are the
// caller's responsibility, as for all length-delimited C interfaces.
unsafe fn array<'a, T>(data: *const T, len: usize) -> Result<&'a [T], Error> {
	if len > isize::MAX as usize / size_of::<T>() { return Err(Error::InvalidArgument); }
	if len == 0 { return Ok(&[]); }
	if data.is_null() { return Err(Error::InvalidArgument); }
	Ok(unsafe { slice::from_raw_parts(data, len) })
}
unsafe fn string<'a>(s: &Slice) -> Result<&'a str, Error> {
	str::from_utf8(unsafe { array(s.data, s.len)? }).map_err(|_| Error::InvalidUtf8)
}
unsafe fn row<'a>(r: Row) -> Result<Vec<&'a str>, Error> {
	if r.len == 0 { return Err(Error::InvalidArgument); }
	unsafe { array(r.cells, r.len)? }.iter().map(|s| unsafe { string(s) }).collect()
}
fn guard(f: impl FnOnce() -> Result<(), Error>) -> c_int {
	match catch_unwind(AssertUnwindSafe(f)) { Ok(Ok(())) => 0, Ok(Err(e)) => e as c_int, Err(_) => Error::Internal as c_int }
}
unsafe fn clear<'a>(output: *mut Buffer) -> Result<&'a mut Buffer, Error> {
	let out = unsafe { output.as_mut() }.ok_or(Error::InvalidArgument)?;
	out.data = ptr::null_mut(); out.len = 0;
	Ok(out)
}
fn store(out: &mut Buffer, text: String) {
	let bytes = text.into_bytes().into_boxed_slice();
	out.len = bytes.len();
	if !bytes.is_empty() { out.data = Box::into_raw(bytes) as *mut u8; }
}
unsafe fn create(raw: *const Options) -> Result<Engine, Error> {
	let options = unsafe { raw.as_ref() }.ok_or(Error::InvalidArgument)?;
	if options.color != 0 && options.color != 1 { return Err(Error::InvalidArgument); }
	let args: Vec<_> = unsafe { array(options.args, options.argc)? }.iter().map(|s| unsafe { string(s) }.map_err(|e| if e == Error::InvalidUtf8 { Error::InvalidOptions } else { e })).collect::<Result<_, _>>()?;
	let initial = Config { terminal: options.terminal_width, decimal: unsafe { string(&options.decimal)? }.into(), color: Color::Auto, ..Config::default() };
	let mut config = Config::parse(&args, initial)?;
	if !config.help && !config.about { config.set_glyphs_json(unsafe { string(&options.glyphs_json) }.map_err(|e| if e == Error::InvalidUtf8 { Error::InvalidGlyphs } else { e })?)?; }
	if config.color == Color::Auto { config.color = if options.color == 1 { Color::Always } else { Color::Never }; }
	Engine::new(config)
}
#[unsafe(no_mangle)]
pub extern "C" fn tsvat_default_options() -> Options {
	Options { terminal_width: 80, decimal: Slice { data: b".".as_ptr(), len: 1 }, glyphs_json: Slice { data: ptr::null(), len: 0 }, color: 0, args: ptr::null(), argc: 0 }
}
#[unsafe(no_mangle)]
pub unsafe extern "C" fn tsvat_create(raw: *const Options, output: *mut *mut Engine) -> c_int {
	guard(|| {
		let dest = unsafe { output.as_mut() }.ok_or(Error::InvalidArgument)?;
		*dest = ptr::null_mut();
		*dest = Box::into_raw(Box::new(unsafe { create(raw)? }));
		Ok(())
	})
}
#[unsafe(no_mangle)]
pub unsafe extern "C" fn tsvat_destroy(ctx: *mut Engine) { if !ctx.is_null() { drop(unsafe { Box::from_raw(ctx) }); } }
#[unsafe(no_mangle)]
pub unsafe extern "C" fn tsvat_flags(ctx: *const Engine) -> c_uint {
	let Some(ctx) = (unsafe { ctx.as_ref() }) else { return 0; };
	u32::from(ctx.config.help) | (u32::from(ctx.config.about) << 1) | (u32::from(ctx.config.example) << 2) | (u32::from(ctx.config.seed.is_none()) << 3)
}
#[unsafe(no_mangle)]
pub unsafe extern "C" fn tsvat_push_row(ctx: *mut Engine, input: Row, output: *mut Buffer) -> c_int {
	guard(|| {
		let out = unsafe { clear(output)? };
		let engine = unsafe { ctx.as_mut() }.ok_or(Error::InvalidArgument)?;
		let cells = unsafe { row(input) }.inspect_err(|_| engine.failed = true)?;
		store(out, engine.push(&cells)?); Ok(())
	})
}
#[unsafe(no_mangle)]
pub unsafe extern "C" fn tsvat_push_tsv(ctx: *mut Engine, input: Slice, output: *mut Buffer) -> c_int {
	guard(|| {
		let out = unsafe { clear(output)? };
		let engine = unsafe { ctx.as_mut() }.ok_or(Error::InvalidArgument)?;
		let line = unsafe { string(&input) }.inspect_err(|_| engine.failed = true)?;
		store(out, engine.push_tsv(line)?); Ok(())
	})
}
#[unsafe(no_mangle)]
pub unsafe extern "C" fn tsvat_finish(ctx: *mut Engine, output: *mut Buffer) -> c_int {
	guard(|| {
		let out = unsafe { clear(output)? };
		let engine = unsafe { ctx.as_mut() }.ok_or(Error::InvalidArgument)?;
		store(out, engine.finish()?); Ok(())
	})
}
#[unsafe(no_mangle)]
pub unsafe extern "C" fn tsvat_render(raw: *const Options, rows: *const Row, count: usize, output: *mut Buffer) -> c_int {
	guard(|| {
		let out = unsafe { clear(output)? };
		let rows = unsafe { array(rows, count)? };
		let mut engine = unsafe { create(raw)? };
		let mut result = String::new();
		for r in rows {
			let cells = unsafe { row(Row { cells: r.cells, len: r.len })? };
			result.push_str(&engine.push(&cells)?);
		}
		result.push_str(&engine.finish()?);
		store(out, result); Ok(())
	})
}
#[unsafe(no_mangle)]
pub unsafe extern "C" fn tsvat_example(ctx: *mut Engine, supplied: *const u8, used: *mut u8, output: *mut Buffer) -> c_int {
	guard(|| {
		let out = unsafe { clear(output)? };
		let engine = unsafe { ctx.as_mut() }.ok_or(Error::InvalidArgument)?;
		if used.is_null() { return Err(Error::InvalidArgument); }
		let seed: [u8; 32] = unsafe { array(supplied, 32)? }.try_into().map_err(|_| Error::InvalidArgument)?;
		if engine.seen != 0 || engine.finished || engine.failed { return Err(Error::InvalidState); }
		let selected = engine.config.seed.unwrap_or(seed);
		unsafe { ptr::copy_nonoverlapping(selected.as_ptr(), used, 32); }
		let (_, result) = engine.example(seed)?;
		store(out, result); Ok(())
	})
}
#[unsafe(no_mangle)]
pub unsafe extern "C" fn tsvat_buffer_free(output: *mut Buffer) {
	if let Some(out) = unsafe { output.as_mut() } {
		if !out.data.is_null() { drop(unsafe { Box::from_raw(ptr::slice_from_raw_parts_mut(out.data, out.len)) }); }
		out.data = ptr::null_mut(); out.len = 0;
	}
}
#[unsafe(no_mangle)]
pub extern "C" fn tsvat_help() -> Slice {
	const HELP: &str = include_str!("../../src/help.txt");
	Slice { data: HELP.as_ptr(), len: HELP.len() }
}
#[unsafe(no_mangle)]
pub extern "C" fn tsvat_about() -> Slice {
	static ABOUT: std::sync::OnceLock<String> = std::sync::OnceLock::new();
	let text = ABOUT.get_or_init(|| format!("tsv-to-ansi-table 0.1.0 (Rust; {}/{}): render TSV as terminal tables\n", std::env::consts::OS, std::env::consts::ARCH));
	Slice { data: text.as_ptr(), len: text.len() }
}
#[unsafe(no_mangle)]
pub extern "C" fn tsvat_error_message(status: c_int) -> *const c_char {
	match status {
		0 => c"Success", 1 => c"Invalid library argument", 2 => c"Invalid option or value; use --help",
		3 => c"Input and arguments must be UTF-8", 4 => c"Ragged row: every row must have the same number of fields",
		5 => c"Manual header count does not match input", 6 => c"More column options than columns",
		7 => c"Terminal too narrow for columns, padding, and borders; increase --terminal-width or reduce --widths",
		8 => c"TSV_TO_ANSI_TABLE_GLYPHS must be a JSON object of known glyph names with safe one-cell graphemes",
		9 => c"Seed must be an unsigned decimal or 0x hexadecimal integer smaller than 2^256",
		10 => c"OutOfMemory", 11 => c"Invalid library context state", _ => c"Internal library error",
	}.as_ptr()
}
