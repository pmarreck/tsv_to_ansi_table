const std = @import("std");
const render = @import("render.zig");
const Config = @import("options.zig").Config;
const A = std.mem.Allocator;
const Row = render.Row;

fn copyRow(a: A, row: Row) !Row {
	const result = try a.alloc([]const u8, row.len);
	for (row, result) |cell, *dest| dest.* = try a.dupe(u8, cell);
	return result;
}
fn append(a: A, out: *std.ArrayList(u8), bytes: []const u8) !void {
	defer a.free(bytes);
	try out.appendSlice(a, bytes);
}
fn opening(a: A, layout: render.Layout, header: Row, out: *std.ArrayList(u8)) !void {
	try append(a, out, try render.border(a, layout, .top));
	if (header.len > 0) {
		try append(a, out, try render.row(a, layout, header, true));
		try append(a, out, try render.border(a, layout, .middle));
	}
}
/// Owns configuration and auto-width rows; fixed-width feeds retain only layout
/// and headers. Output allocations belong to each call's supplied allocator.
pub const Engine = struct {
	arena: std.heap.ArenaAllocator,
	config: Config,
	header: Row,
	buffered: std.ArrayList(Row) = .empty,
	layout: ?render.Layout = null,
	seen: usize = 0,
	finished: bool = false,
	failed: bool = false,
	pub fn init(parent: A, input: Config) !Engine {
		var arena = std.heap.ArenaAllocator.init(parent);
		errdefer arena.deinit();
		const a = arena.allocator();
		if (input.terminal == 0 or input.terminal > 10000) return error.InvalidOptions;
		if (!std.mem.eql(u8, input.decimal, ".") and !std.mem.eql(u8, input.decimal, ",") and !std.mem.eql(u8, input.decimal, "٫")) return error.InvalidOptions;
		for (input.widths) |w| if (w > 10000) return error.InvalidOptions;
		for (input.headers) |s| if (!std.unicode.utf8ValidateSlice(s)) return error.InvalidUtf8;
		var config = input;
		config.headers = try copyRow(a, input.headers);
		config.widths = try a.dupe(usize, input.widths);
		config.alignments = try a.dupe(@import("text.zig").Align, input.alignments);
		config.overflow = try a.dupe(@import("text.zig").Overflow, input.overflow);
		config.decimal = try a.dupe(u8, input.decimal);
		inline for (std.meta.fields(@TypeOf(config.glyphs))) |field| {
			const value = @field(input.glyphs, field.name);
			const parts = try @import("text.zig").clusters(a, value);
			const clean = try @import("text.zig").safe(a, value);
			if (parts.len != 1 or parts[0].width != 1 or !std.mem.eql(u8, clean, value)) return error.InvalidGlyphs;
			@field(config.glyphs, field.name) = try a.dupe(u8, value);
		}
		return .{ .arena = arena, .config = config, .header = config.headers };
	}
	pub fn deinit(self: *Engine) void {
		self.arena.deinit();
	}
	pub fn push(self: *Engine, a: A, cells: Row) ![]const u8 {
		if (self.finished or self.failed) return error.InvalidState;
		return self.pushInner(a, cells) catch |err| {
			self.failed = true;
			return err;
		};
	}
	fn pushInner(self: *Engine, a: A, cells: Row) ![]const u8 {
		if (cells.len == 0) return error.InvalidArgument;
		for (cells) |s| if (!std.unicode.utf8ValidateSlice(s)) return error.InvalidUtf8;
		const own = self.arena.allocator();
		if (self.seen == 0 and !self.config.no_header) {
			if (self.header.len > 0 and self.header.len != cells.len) return error.HeaderCount;
			if (self.header.len == 0) self.header = try copyRow(own, cells);
			self.seen += 1;
			return a.alloc(u8, 0);
		}
		const count = if (self.header.len > 0) self.header.len else if (self.layout) |l| l.widths.len else if (self.buffered.items.len > 0) self.buffered.items[0].len else cells.len;
		if (cells.len != count) return error.RaggedRow;
		self.seen += 1;
		if (self.layout) |layout| return render.row(a, layout, cells, false);
		if (render.streaming(self.config, count)) {
			const layout = try render.prepare(own, self.config, self.header, &.{cells});
			self.layout = layout;
			var out: std.ArrayList(u8) = .empty;
			errdefer out.deinit(a);
			try opening(a, layout, self.header, &out);
			try append(a, &out, try render.row(a, layout, cells, false));
			return out.toOwnedSlice(a);
		}
		try self.buffered.append(own, try copyRow(own, cells));
		return a.alloc(u8, 0);
	}
	pub fn finish(self: *Engine, a: A) ![]const u8 {
		if (self.finished or self.failed) return error.InvalidState;
		self.finished = true;
		if (self.layout) |layout| return render.border(a, layout, .bottom);
		if (self.header.len == 0 and self.buffered.items.len == 0) return a.alloc(u8, 0);
		const layout = try render.prepare(self.arena.allocator(), self.config, self.header, self.buffered.items);
		var out: std.ArrayList(u8) = .empty;
		errdefer out.deinit(a);
		try opening(a, layout, self.header, &out);
		for (self.buffered.items) |cells| try append(a, &out, try render.row(a, layout, cells, false));
		try append(a, &out, try render.border(a, layout, .bottom));
		return out.toOwnedSlice(a);
	}
};
/// Render complete rows, including a header unless config.no_header is true.
/// The returned byte slice belongs to the caller's allocator.
pub fn renderTable(a: A, config: Config, rows: []const Row) ![]const u8 {
	var engine = try Engine.init(a, config);
	defer engine.deinit();
	var out: std.ArrayList(u8) = .empty;
	errdefer out.deinit(a);
	for (rows) |cells| try append(a, &out, try engine.push(a, cells));
	try append(a, &out, try engine.finish(a));
	return out.toOwnedSlice(a);
}

fn allocationCase(a: A) !void {
	const rendered = try renderTable(a, .{ .plain = true }, &.{ &.{ "Name", "N" }, &.{ "a", "12" } });
	defer a.free(rendered);
	try std.testing.expectEqualStrings("Name   N\na     12\n", rendered);
}
test "rendering releases every allocation on success and allocation failure" {
	try std.testing.checkAllAllocationFailures(std.testing.allocator, allocationCase, .{});
}
test "fixed-width state owns inputs and emits before finish" {
	const a = std.testing.allocator;
	var header = [_]u8{'N'};
	var engine = try Engine.init(a, .{ .plain = true, .widths = &.{2} });
	defer engine.deinit();
	const first = try engine.push(a, &.{&header});
	defer a.free(first);
	try std.testing.expectEqualStrings("", first);
	header[0] = 'X';
	const data = try engine.push(a, &.{"12"});
	defer a.free(data);
	try std.testing.expectEqualStrings(" N\n12\n", data);
	const end = try engine.finish(a);
	defer a.free(end);
	try std.testing.expectError(error.InvalidState, engine.finish(a));
}
