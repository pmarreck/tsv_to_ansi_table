const std = @import("std");
const builtin = @import("builtin");
const lib = @import("tsv_to_ansi_table");
const a = std.heap.c_allocator;
const Slice = extern struct { data: ?[*]const u8, len: usize };
const Row = extern struct { cells: ?[*]const Slice, len: usize };
const Buffer = extern struct { data: ?[*]u8 = null, len: usize = 0 };
const Options = extern struct { terminal_width: usize, decimal: Slice, glyphs_json: Slice, color: c_int, args: ?[*]const Slice, argc: usize };
fn slice(s: Slice) ![]const u8 {
	if (s.len > std.math.maxInt(isize)) return error.InvalidArgument;
	if (s.len == 0) return "";
	return (s.data orelse return error.InvalidArgument)[0..s.len];
}
fn row(allocator: std.mem.Allocator, r: Row) !lib.Row {
	if (r.len == 0 or r.len > std.math.maxInt(isize) / @sizeOf(Slice)) return error.InvalidArgument;
	const cells = (r.cells orelse return error.InvalidArgument)[0..r.len];
	const result = try allocator.alloc([]const u8, r.len);
	for (cells, result) |s, *dest| dest.* = try slice(s);
	return result;
}
fn code(err: anyerror) c_int {
	return switch (err) {
		error.InvalidArgument => 1,
		error.InvalidOptions => 2,
		error.InvalidUtf8 => 3,
		error.RaggedRow => 4,
		error.HeaderCount => 5,
		error.TooManyColumnOptions => 6,
		error.TooNarrow => 7,
		error.InvalidGlyphs => 8,
		error.InvalidSeed => 9,
		error.OutOfMemory => 10,
		error.InvalidState => 11,
		else => 12,
	};
}
fn store(out: *Buffer, bytes: []const u8) void {
	out.* = .{ .data = if (bytes.len == 0) null else @constCast(bytes.ptr), .len = bytes.len };
}
export fn tsvat_default_options() Options {
	return .{ .terminal_width = 80, .decimal = .{ .data = ".", .len = 1 }, .glyphs_json = .{ .data = null, .len = 0 }, .color = 0, .args = null, .argc = 0 };
}
export fn tsvat_create(raw: ?*const Options, output: ?*?*lib.Engine) c_int {
	const dest = output orelse return 1;
	dest.* = null;
	dest.* = create(raw orelse return 1) catch |err| return code(err);
	return 0;
}
fn create(raw: *const Options) !*lib.Engine {
	if (raw.argc > std.math.maxInt(isize) / @sizeOf(Slice) or (raw.argc > 0 and raw.args == null) or (raw.color != 0 and raw.color != 1)) return error.InvalidArgument;
	var temp = std.heap.ArenaAllocator.init(a);
	defer temp.deinit();
	const scratch = temp.allocator();
	const args = try scratch.alloc([]const u8, raw.argc);
	for (args, 0..) |*dest, i| dest.* = try slice(raw.args.?[i]);
	var config = try lib.parseOptions(scratch, args, .{ .terminal = raw.terminal_width, .decimal = try slice(raw.decimal) });
	if (!config.help and !config.about) config.glyphs = try lib.parseGlyphs(scratch, try slice(raw.glyphs_json));
	if (config.color == .auto) config.color = if (raw.color == 1) .always else .never;
	const ctx = try a.create(lib.Engine);
	errdefer a.destroy(ctx);
	ctx.* = try lib.Engine.init(a, config);
	return ctx;
}
export fn tsvat_destroy(ctx: ?*lib.Engine) void {
	if (ctx) |engine| {
		engine.deinit();
		a.destroy(engine);
	}
}
export fn tsvat_flags(ctx: ?*const lib.Engine) c_uint {
	const config = (ctx orelse return 0).config;
	return (if (config.help) @as(c_uint, 1) else 0) | (if (config.about) @as(c_uint, 2) else 0) | (if (config.example) @as(c_uint, 4) else 0) | (if (config.seed == null) @as(c_uint, 8) else 0);
}
export fn tsvat_push_row(ctx: ?*lib.Engine, input: Row, output: ?*Buffer) c_int {
	const out = output orelse return 1;
	out.* = .{};
	const engine = ctx orelse return 1;
	var temp = std.heap.ArenaAllocator.init(a);
	defer temp.deinit();
	const cells = row(temp.allocator(), input) catch |err| {
		engine.failed = true;
		return code(err);
	};
	const bytes = engine.push(a, cells) catch |err| return code(err);
	store(out, bytes);
	return 0;
}
export fn tsvat_push_tsv(ctx: ?*lib.Engine, input: Slice, output: ?*Buffer) c_int {
	const out = output orelse return 1;
	out.* = .{};
	const engine = ctx orelse return 1;
	const line = slice(input) catch |err| {
		engine.failed = true;
		return code(err);
	};
	if (std.mem.indexOfScalar(u8, line, '\n') != null) {
		engine.failed = true;
		return 1;
	}
	var temp = std.heap.ArenaAllocator.init(a);
	defer temp.deinit();
	const cells = lib.parseTsvRow(temp.allocator(), line) catch |err| {
		engine.failed = true;
		return code(err);
	};
	store(out, engine.push(a, cells) catch |err| return code(err));
	return 0;
}
export fn tsvat_finish(ctx: ?*lib.Engine, output: ?*Buffer) c_int {
	const out = output orelse return 1;
	out.* = .{};
	store(out, (ctx orelse return 1).finish(a) catch |err| return code(err));
	return 0;
}
export fn tsvat_render(raw: ?*const Options, rows: ?[*]const Row, count: usize, output: ?*Buffer) c_int {
	const out = output orelse return 1;
	out.* = .{};
	if (count > std.math.maxInt(isize) / @sizeOf(Row) or (count > 0 and rows == null)) return 1;
	const engine = create(raw orelse return 1) catch |err| return code(err);
	defer tsvat_destroy(engine);
	var result: std.ArrayList(u8) = .empty;
	defer result.deinit(a);
	for (0..count) |i| {
		var part: Buffer = .{};
		const status = tsvat_push_row(engine, rows.?[i], &part);
		if (status != 0) return status;
		defer tsvat_buffer_free(&part);
		if (part.len > 0) result.appendSlice(a, part.data.?[0..part.len]) catch return 10;
	}
	var final: Buffer = .{};
	const status = tsvat_finish(engine, &final);
	if (status != 0) return status;
	defer tsvat_buffer_free(&final);
	if (final.len > 0) result.appendSlice(a, final.data.?[0..final.len]) catch return 10;
	store(out, result.toOwnedSlice(a) catch return 10);
	return 0;
}
export fn tsvat_example(ctx: ?*lib.Engine, supplied: ?[*]const u8, used: ?[*]u8, output: ?*Buffer) c_int {
	const out = output orelse return 1;
	out.* = .{};
	const engine = ctx orelse return 1;
	if (supplied == null or used == null) return 1;
	if (engine.seen != 0 or engine.finished or engine.failed) return 11;
	const selected = engine.config.seed orelse supplied.?[0..32].*;
	@memcpy(used.?[0..32], &selected);
	generate(engine, selected, out) catch |err| {
		engine.failed = true;
		return code(err);
	};
	return 0;
}
fn generate(engine: *lib.Engine, selected: [32]u8, out: *Buffer) !void {
	var temp = std.heap.ArenaAllocator.init(a);
	defer temp.deinit();
	const rows = try lib.example.generate(temp.allocator(), selected, engine.config.decimal);
	var result: std.ArrayList(u8) = .empty;
	errdefer result.deinit(a);
	for (rows[if (engine.config.no_header) @as(usize, 1) else 0..]) |cells| {
		const bytes = try engine.push(a, cells);
		defer a.free(bytes);
		try result.appendSlice(a, bytes);
	}
	const final = try engine.finish(a);
	defer a.free(final);
	try result.appendSlice(a, final);
	store(out, try result.toOwnedSlice(a));
}
export fn tsvat_buffer_free(output: ?*Buffer) void {
	if (output) |out| {
		if (out.data) |data| a.free(data[0..out.len]);
		out.* = .{};
	}
}
export fn tsvat_help() Slice {
	return .{ .data = lib.help.ptr, .len = lib.help.len };
}
export fn tsvat_about() Slice {
	const about = "tsv-to-ansi-table 0.1.0 (Zig; " ++ @tagName(builtin.os.tag) ++ "/" ++ @tagName(builtin.cpu.arch) ++ "): render TSV as terminal tables\n";
	return .{ .data = about.ptr, .len = about.len };
}
export fn tsvat_error_message(status: c_int) [*:0]const u8 {
	return switch (status) {
		0 => "Success",
		1 => "Invalid library argument",
		2 => "Invalid option or value; use --help",
		3 => "Input and arguments must be UTF-8",
		4 => "Ragged row: every row must have the same number of fields",
		5 => "Manual header count does not match input",
		6 => "More column options than columns",
		7 => "Terminal too narrow for columns, padding, and borders; increase --terminal-width or reduce --widths",
		8 => "TSV_TO_ANSI_TABLE_GLYPHS must be a JSON object of known glyph names with safe one-cell graphemes",
		9 => "Seed must be an unsigned decimal or 0x hexadecimal integer smaller than 2^256",
		10 => "OutOfMemory",
		11 => "Invalid library context state",
		else => "Internal library error",
	};
}
