const std = @import("std");
const Allocator = std.mem.Allocator;

pub fn parseRow(a: Allocator, line: []const u8) ![][]const u8 {
	const clean = if (std.mem.endsWith(u8, line, "\r")) line[0 .. line.len - 1] else line;
	var result: std.ArrayList([]const u8) = .empty;
	errdefer result.deinit(a);
	var parts = std.mem.splitScalar(u8, clean, '\t');
	while (parts.next()) |part| try result.append(a, part);
	return result.toOwnedSlice(a);
}
pub fn classify(text: []const u8, decimal: []const u8) ?usize {
	const unsigned = if (text.len > 0 and (text[0] == '+' or text[0] == '-')) text[1..] else text;
	if (std.mem.indexOf(u8, unsigned, decimal)) |i| {
		const fraction = unsigned[i + decimal.len ..];
		const whole = unsigned[0..i];
		if (whole.len + fraction.len == 0) return null;
		if (!digits(whole) or !digits(fraction)) return null;
		return fraction.len;
	}
	return if (unsigned.len > 0 and digits(unsigned)) 0 else null;
}
fn digits(s: []const u8) bool {
	for (s) |b| if (b < '0' or b > '9') { return false; };
	return true;
}

test "TSV preserves empty and trailing cells and CRLF" {
	const a = std.testing.allocator;
	const row = try parseRow(a, "a\t\tb\t\r");
	defer a.free(row);
	try std.testing.expectEqual(@as(usize, 4), row.len);
	try std.testing.expectEqualStrings("", row[1]);
	try std.testing.expectEqualStrings("", row[3]);
}
test "numeric classification is lexical and locale-specific" {
	try std.testing.expectEqual(@as(?usize, 0), classify("-12", "."));
	try std.testing.expectEqual(@as(?usize, 3), classify("+12.340", "."));
	try std.testing.expectEqual(@as(?usize, 2), classify("12,30", ","));
	try std.testing.expectEqual(@as(?usize, 1), classify(".5", "."));
	try std.testing.expectEqual(@as(?usize, 0), classify("5.", "."));
	for ([_][]const u8{ "", "-", ".", "1.2.3", "12e3", " 12" }) |s| try std.testing.expectEqual(@as(?usize, null), classify(s, "."));
	try std.testing.expectEqual(@as(?usize, null), classify("12.30", ","));
}

test { _ = @import("text.zig"); }

pub fn allocate(a: Allocator, desired: []const usize, fixed: []const usize, terminal: usize, plain: bool) ![]usize {
	const n = desired.len;
	const result = try a.alloc(usize, n);
	errdefer a.free(result);
	if (n == 0) return result;
	var used: usize = if (plain) 2 * (n - 1) else 3 * n + 1;
	for (result, 0..) |*w, i| {
		w.* = if (fixed[i] == 0) 1 else fixed[i];
		used += w.*;
	}
	if (used > terminal) return error.TooNarrow;
	var changed = true;
	while (used < terminal and changed) {
		changed = false;
		for (result, 0..) |*w, i| {
			if (used < terminal and fixed[i] == 0 and w.* < desired[i]) {
				w.* += 1;
				used += 1;
				changed = true;
			}
		}
	}
	return result;
}
test "fair auto widths preserve fixed widths and reject narrow output" {
	const a = std.testing.allocator;
	const fair = try allocate(a, &.{100, 3, 100}, &.{0, 0, 0}, 25, false);
	defer a.free(fair);
	try std.testing.expectEqualSlices(usize, &.{6, 3, 6}, fair);
	const mixed = try allocate(a, &.{100, 3}, &.{5, 0}, 17, false);
	defer a.free(mixed);
	try std.testing.expectEqualSlices(usize, &.{5, 3}, mixed);
	try std.testing.expectError(error.TooNarrow, allocate(a, &.{1, 1}, &.{8, 8}, 12, false));
	try std.testing.expectError(error.TooNarrow, allocate(a, &.{1, 1}, &.{0, 0}, 8, false));
}
test { _ = @import("options.zig"); }
test { _ = @import("render.zig"); }
