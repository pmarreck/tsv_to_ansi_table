const std = @import("std");
const core = @import("core.zig");
const text = @import("text.zig");
const options = @import("options.zig");
const A = std.mem.Allocator;
pub const Row = []const []const u8;
pub const Layout = struct { config: options.Config, widths: []usize, alignments: []text.Align };
pub fn prepare(a: A, config: options.Config, header: Row, rows: []const Row) !Layout {
	const n = if (header.len > 0) header.len else if (rows.len > 0) rows[0].len else 0;
	if (config.widths.len > n or config.alignments.len > n or config.overflow.len > n) return error.TooManyColumnOptions;
	for (rows) |cells| if (cells.len != n) return error.RaggedRow;
	const desired = try a.alloc(usize, n);
	defer a.free(desired);
	const fixed = try a.alloc(usize, n);
	defer a.free(fixed);
	const alignments = try a.alloc(text.Align, n);
	errdefer a.free(alignments);
	for (0..n) |i| {
		desired[i] = if (header.len > 0) try safeWidth(a, header[i]) else 0;
		for (rows) |cells| desired[i] = @max(desired[i], try safeWidth(a, cells[i]));
		fixed[i] = if (i < config.widths.len) config.widths[i] else 0;
		const explicit = if (i < config.alignments.len) config.alignments[i] else .auto;
		alignments[i] = if (explicit != .auto) explicit else if (rows.len > 0 and core.classify(rows[0][i], config.decimal) != null) .right else .left;
	}
	return .{ .config = config, .widths = try core.allocate(a, desired, fixed, config.terminal, config.plain), .alignments = alignments };
}
fn safeWidth(a: A, cell: []const u8) !usize {
	const clean = try text.safe(a, cell);
	defer a.free(clean);
	return text.width(a, clean);
}
pub fn streaming(config: options.Config, n: usize) bool {
	if (config.widths.len != n) return false;
	for (config.widths) |w| if (w == 0) return false;
	return true;
}
pub fn row(a: A, layout: Layout, cells: Row, header: bool) ![]const u8 {
	if (cells.len != layout.widths.len) return error.RaggedRow;
	var out: std.ArrayList(u8) = .empty;
	errdefer out.deinit(a);
	const color = header and layout.config.color == .always and !layout.config.plain;
	if (color) try out.appendSlice(a, "\x1b[1;36m");
	const separator = if (layout.config.plain) "  " else if (layout.config.ascii) "|" else "│";
	if (!layout.config.plain) try out.appendSlice(a, separator);
	for (cells, 0..) |cell, i| {
		const clean = try text.safe(a, cell);
		defer a.free(clean);
		const clipped = try text.clip(a, clean, layout.widths[i], if (i < layout.config.overflow.len) layout.config.overflow[i] else .auto, layout.config.ascii);
		defer a.free(clipped);
		const padded = try text.pad(a, clipped, layout.widths[i], layout.alignments[i]);
		defer a.free(padded);
		if (!layout.config.plain) try out.append(a, ' ');
		try out.appendSlice(a, padded);
		if (!layout.config.plain) try out.append(a, ' ');
		if (!layout.config.plain or i + 1 < cells.len) try out.appendSlice(a, separator);
	}
	if (color) try out.appendSlice(a, "\x1b[0m");
	try out.append(a, '\n');
	return out.toOwnedSlice(a);
}
pub fn border(a: A, layout: Layout, kind: enum { top, middle, bottom }) ![]const u8 {
	var out: std.ArrayList(u8) = .empty;
	errdefer out.deinit(a);
	if (layout.config.plain or layout.widths.len == 0) return out.toOwnedSlice(a);
	const marks: [3][]const u8 = if (layout.config.ascii) .{"+", "+", "+"} else switch (kind) {
		.top => .{"┌", "┬", "┐"}, .middle => .{"├", "┼", "┤"}, .bottom => .{"└", "┴", "┘"},
	};
	try out.appendSlice(a, marks[0]);
	for (layout.widths, 0..) |w, i| {
		for (0..w + 2) |_| try out.appendSlice(a, if (layout.config.ascii) "-" else "─");
		try out.appendSlice(a, if (i + 1 == layout.widths.len) marks[2] else marks[1]);
	}
	try out.append(a, '\n');
	return out.toOwnedSlice(a);
}
test "first data row controls alignment, explicit options win" {
	var arena = std.heap.ArenaAllocator.init(std.testing.allocator);
	defer arena.deinit();
	const a = arena.allocator();
	const layout = try prepare(a, .{}, &.{"n", "s"}, &.{ &.{"-12.30", "x"}, &.{"text", "234"} });
	try std.testing.expectEqualSlices(text.Align, &.{.right, .left}, layout.alignments);
	const explicit = try prepare(a, .{ .alignments = &.{.left,.right} }, &.{}, &.{ &.{"12", "x"} });
	try std.testing.expectEqualSlices(text.Align, &.{.left, .right}, explicit.alignments);
	try std.testing.expectError(error.RaggedRow, prepare(a, .{}, &.{"a","b"}, &.{&.{"1"}}));
}
