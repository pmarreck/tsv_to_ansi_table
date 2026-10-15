const std = @import("std");
const builtin = @import("builtin");
const core = @import("core.zig");
const options = @import("options.zig");
const render = @import("render.zig");
const text = @import("text.zig");
const c = @cImport({
	@cInclude("stdio.h");
	@cInclude("stdlib.h");
	if (builtin.os.tag == .windows) { @cInclude("io.h"); @cInclude("fcntl.h"); }
});
extern fn tsv_console_width() u64;
extern fn tsv_windows_decimal() u64;
extern fn tsv_stdin() *c.FILE;
extern fn tsv_stdout() *c.FILE;
extern fn tsv_stderr() *c.FILE;
const A = std.mem.Allocator;

pub fn main(init: std.process.Init) void {
	if (builtin.os.tag == .windows) {
		_ = c._setmode(c._fileno(tsv_stdin()), c._O_BINARY);
		_ = c._setmode(c._fileno(tsv_stdout()), c._O_BINARY);
	}
	if (builtin.mode == .Debug) _ = c.fputs("\x1b[33mDEBUG BUILD!\x1b[0m\n", tsv_stderr());
	run(init) catch |err| {
		const message = switch (err) {
			error.InvalidOptions => "Invalid option or value; use --help",
			error.InvalidGlyphs => "TSV_TO_ANSI_TABLE_GLYPHS must be a JSON object of known glyph names with safe one-cell graphemes",
			error.InvalidUtf8 => "Input and arguments must be UTF-8",
			error.RaggedRow => "Ragged row: every row must have the same number of fields",
			error.HeaderCount => "Manual header count does not match input",
			error.TooManyColumnOptions => "More column options than columns",
			error.TooNarrow => "Terminal too narrow for columns, padding, and borders; increase --terminal-width or reduce --widths",
			else => @errorName(err),
		};
		_ = c.fputs("tsv-to-ansi-table: ", tsv_stderr());
		_ = c.fwrite(message.ptr, 1, message.len, tsv_stderr());
		_ = c.fputc('\n', tsv_stderr());
		c.exit(2);
	};
}
fn run(init: std.process.Init) !void {
	const a = init.arena.allocator();
	const argv = try init.minimal.args.toSlice(a);
	const args = try a.alloc([]const u8, argv.len - 1);
	for (argv[1..], args) |arg, *dest| dest.* = arg;
	const parsed = try options.parse(a, args, .{});
	if (parsed.help) return write(@embedFile("../src/help.txt"));
	if (parsed.about) return write("tsv-to-ansi-table 0.1.0 (Zig; " ++ @tagName(builtin.os.tag) ++ "/" ++ @tagName(builtin.cpu.arch) ++ "): render TSV as terminal tables\n");
	const columns: usize = @intCast(tsv_console_width());
	const env_width = std.fmt.parseInt(usize, env("COLUMNS"), 10) catch 0;
	const width = if (env_width > 0 and env_width <= 10000) env_width else if (columns > 0) columns else 80;
	var config = try options.parse(a, args, .{ .terminal = width, .decimal = localeDecimal() });
	config.glyphs = try @import("glyphs.zig").parse(a, env("TSV_TO_ANSI_TABLE_GLYPHS"));
	if (config.color == .auto) config.color = if (columns > 0 and c.getenv("NO_COLOR") == null and !std.mem.eql(u8, env("TERM"), "dumb")) .always else .never;
	var scratch = std.heap.ArenaAllocator.init(init.gpa);
	defer scratch.deinit();
	var header: render.Row = config.headers;
	var buffered: std.ArrayList(render.Row) = .empty;
	var layout: ?render.Layout = null;
	var seen: usize = 0;
	while (true) {
		_ = scratch.reset(.free_all);
		const temp = scratch.allocator();
		const line = (try readLine(temp)) orelse break;
		if (!std.unicode.utf8ValidateSlice(line)) return error.InvalidUtf8;
		const cells = try core.parseRow(temp, line);
		if (seen == 0 and !config.no_header) {
			if (header.len > 0 and header.len != cells.len) return error.HeaderCount;
			if (header.len == 0) header = try copyRow(a, cells);
			seen += 1;
			continue;
		}
		seen += 1;
		const count = if (header.len > 0) header.len else if (layout) |l| l.widths.len else if (buffered.items.len > 0) buffered.items[0].len else cells.len;
		if (cells.len != count) return error.RaggedRow;
		if (layout) |l| {
			try write(try render.row(temp, l, cells, false));
		} else if (render.streaming(config, count)) {
			const l = try render.prepare(a, config, header, &.{cells});
			layout = l;
			try opening(temp, l, header);
			try write(try render.row(temp, l, cells, false));
		} else {
			try buffered.append(a, try copyRow(a, cells));
		}
	}
	const temp = scratch.allocator();
	if (layout) |l| {
		try write(try render.border(temp, l, .bottom));
	} else if (header.len > 0 or buffered.items.len > 0) {
		const l = try render.prepare(a, config, header, buffered.items);
		try opening(temp, l, header);
		for (buffered.items) |cells| {
			_ = scratch.reset(.free_all);
			try write(try render.row(scratch.allocator(), l, cells, false));
		}
		try write(try render.border(scratch.allocator(), l, .bottom));
	}
}
fn opening(a: A, layout: render.Layout, header: render.Row) !void {
	try write(try render.border(a, layout, .top));
	if (header.len > 0) {
		try write(try render.row(a, layout, header, true));
		try write(try render.border(a, layout, .middle));
	}
}
fn write(bytes: []const u8) !void {
	if (c.fwrite(bytes.ptr, 1, bytes.len, tsv_stdout()) != bytes.len or c.fflush(tsv_stdout()) != 0) return error.OutputFailure;
}
fn readLine(a: A) !?[]const u8 {
	var bytes: std.ArrayList(u8) = .empty;
	while (true) {
		const ch = c.fgetc(tsv_stdin());
		if (ch == c.EOF) {
			if (c.ferror(tsv_stdin()) != 0) return error.InputFailure;
			if (bytes.items.len == 0) return null;
			break;
		}
		if (ch == '\n') break;
		try bytes.append(a, @intCast(ch));
	}
	return try bytes.toOwnedSlice(a);
}
fn copyRow(a: A, row: render.Row) !render.Row {
	const out = try a.alloc([]const u8, row.len);
	for (row, out) |s, *dest| dest.* = try a.dupe(u8, s);
	return out;
}
fn env(key: [:0]const u8) []const u8 {
	const value = c.getenv(key) orelse return "";
	return std.mem.span(value);
}
fn localeDecimal() []const u8 {
	const native = tsv_windows_decimal();
	if (native != 0) return if (native == 44) "," else if (native == 0x66B) "٫" else ".";
	if (builtin.os.tag != .windows) {
		const pipe = c.popen("locale decimal_point 2>/dev/null", "r") orelse return ".";
		var buffer: [16]u8 = undefined;
		const count = c.fread(&buffer, 1, buffer.len, pipe);
		const rc = c.pclose(pipe);
		if (rc != 0) return ".";
		const value = std.mem.trim(u8, buffer[0..count], " \t\r\n");
		if (std.mem.eql(u8, value, ",")) return ",";
		if (std.mem.eql(u8, value, "٫")) return "٫";
	}
	return ".";
}
