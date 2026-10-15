const std = @import("std");
const A = std.mem.Allocator;
const c = @cImport({ @cDefine("UTF8PROC_STATIC", "1"); @cInclude("utf8proc.h"); });
pub const Cluster = struct { bytes: []const u8, width: usize };
pub fn clusters(a: A, input: []const u8) ![]Cluster {
	var result: std.ArrayList(Cluster) = .empty;
	errdefer result.deinit(a);
	var offset: usize = 0;
	var start: usize = 0;
	var previous: i32 = 0;
	var state: i32 = 0;
	var cells: usize = 0;
	while (offset < input.len) {
		var cp: i32 = 0;
		const len = c.utf8proc_iterate(input.ptr + offset, @intCast(input.len - offset), &cp);
		if (len <= 0) return error.InvalidUtf8;
		if (offset > 0 and c.utf8proc_grapheme_break_stateful(previous, cp, &state)) {
			try result.append(a, .{ .bytes = input[start..offset], .width = cells });
			start = offset;
			cells = 0;
		}
		const category = c.utf8proc_category(cp);
		var w: usize = if (category == c.UTF8PROC_CATEGORY_MN or category == c.UTF8PROC_CATEGORY_ME or category == c.UTF8PROC_CATEGORY_CF) 0 else @intCast(@max(0, c.utf8proc_charwidth(cp)));
		if (cp == 0xFE0F or cp == 0x20E3 or (cp >= 0x1F1E6 and cp <= 0x1F1FF)) w = 2;
		cells = @max(cells, w);
		previous = cp;
		offset += @intCast(len);
	}
	if (offset > 0) try result.append(a, .{ .bytes = input[start..], .width = cells });
	return result.toOwnedSlice(a);
}
pub fn width(a: A, input: []const u8) !usize {
	const parts = try clusters(a, input);
	defer a.free(parts);
	var n: usize = 0;
	for (parts) |p| n += p.width;
	return n;
}
pub fn safe(a: A, input: []const u8) ![]const u8 {
	var clean: std.ArrayList(u8) = .empty;
	defer clean.deinit(a);
	var offset: usize = 0;
	while (offset < input.len) {
		var cp: i32 = 0;
		const len = c.utf8proc_iterate(input.ptr + offset, @intCast(input.len - offset), &cp);
		if (len <= 0) return error.InvalidUtf8;
		const n: usize = @intCast(len);
		const category = c.utf8proc_category(cp);
		const bad = category == c.UTF8PROC_CATEGORY_CC or category == c.UTF8PROC_CATEGORY_ZL or category == c.UTF8PROC_CATEGORY_ZP or (category == c.UTF8PROC_CATEGORY_CF and cp != 0x200C and cp != 0x200D and !(cp >= 0xE0020 and cp <= 0xE007F));
		try clean.appendSlice(a, if (bad) "�" else input[offset .. offset + n]);
		offset += n;
	}
	const parts = try clusters(a, clean.items);
	defer a.free(parts);
	var out: std.ArrayList(u8) = .empty;
	errdefer out.deinit(a);
	for (parts) |p| {
		if (p.width == 0) try out.appendSlice(a, "◌");
		try out.appendSlice(a, p.bytes);
	}
	return out.toOwnedSlice(a);
}
test "Unicode display cells and indivisible graphemes" {
	const a = std.testing.allocator;
	try std.testing.expectEqual(@as(usize, 5), try width(a, "hello"));
	try std.testing.expectEqual(@as(usize, 2), try width(a, "界"));
	try std.testing.expectEqual(@as(usize, 1), try width(a, "é"));
	try std.testing.expectEqual(@as(usize, 2), try width(a, "👩‍💻"));
	try std.testing.expectEqual(@as(usize, 2), try width(a, "🇺🇸"));
	try std.testing.expectEqual(@as(usize, 2), try width(a, "1️⃣"));
	const parts = try clusters(a, "aé界");
	defer a.free(parts);
	try std.testing.expectEqual(@as(usize, 3), parts.len);
	try std.testing.expectEqualStrings("é", parts[1].bytes);
}
test "controls are inert and orphan marks have a visible base" {
	const a = std.testing.allocator;
	const s = try safe(a, "x\x1b[31m\x07\u{202e}y");
	defer a.free(s);
	try std.testing.expectEqualStrings("x�[31m��y", s);
	const orphan = try safe(a, "\u{301}");
	defer a.free(orphan);
	try std.testing.expectEqualStrings("◌\u{301}", orphan);
}

pub const Overflow = enum { auto, truncate_left, truncate_right, prefix_ellipsis, suffix_ellipsis };
pub const Align = enum { auto, left, right, center };
pub fn clip(a: A, text: []const u8, size: usize, mode: Overflow, ascii: bool) ![]const u8 {
	if (try width(a, text) <= size) return a.dupe(u8, text);
	const actual = if (mode == .auto) (if (std.mem.indexOfAny(u8, text, "/\\") != null) Overflow.prefix_ellipsis else Overflow.suffix_ellipsis) else mode;
	const ellipsis = actual == .prefix_ellipsis or actual == .suffix_ellipsis;
	const marker = if (!ellipsis or size == 0) "" else if (ascii) "..."[0..@min(size, 3)] else "…";
	const budget = size - try width(a, marker);
	const parts = try clusters(a, text);
	defer a.free(parts);
	const from_end = actual == .prefix_ellipsis or actual == .truncate_left;
	var used: usize = 0;
	var first: usize = if (from_end) text.len else 0;
	var last: usize = if (from_end) text.len else 0;
	for (0..parts.len) |i| {
		const p = parts[if (from_end) parts.len - i - 1 else i];
		if (used + p.width > budget) break;
		used += p.width;
		if (from_end) first -= p.bytes.len else last += p.bytes.len;
	}
	return if (from_end) std.mem.concat(a, u8, &.{ marker, text[first..last] }) else std.mem.concat(a, u8, &.{ text[first..last], marker });
}
pub fn pad(a: A, text: []const u8, size: usize, alignment: Align) ![]const u8 {
	const w = try width(a, text);
	const gap = size -| w;
	const left = if (alignment == .right) gap else if (alignment == .center) gap / 2 else 0;
	const out = try a.alloc(u8, text.len + gap);
	@memset(out, ' ');
	@memcpy(out[left..][0..text.len], text);
	return out;
}
test "all overflow and alignment modes honor cell budgets" {
	var arena = std.heap.ArenaAllocator.init(std.testing.allocator);
	defer arena.deinit();
	const a = arena.allocator();
	try std.testing.expectEqualStrings("abcd", try clip(a, "abcdef", 4, .truncate_right, false));
	try std.testing.expectEqualStrings("cdef", try clip(a, "abcdef", 4, .truncate_left, false));
	try std.testing.expectEqualStrings("abc…", try clip(a, "abcdef", 4, .suffix_ellipsis, false));
	try std.testing.expectEqualStrings("…def", try clip(a, "abcdef", 4, .prefix_ellipsis, false));
	try std.testing.expectEqualStrings("…e.txt", try clip(a, "/abc/file.txt", 6, .auto, false));
	try std.testing.expectEqualStrings("..", try clip(a, "abcdef", 2, .suffix_ellipsis, true));
	try std.testing.expectEqualStrings("é界", try clip(a, "é界xx", 3, .truncate_right, false));
	try std.testing.expectEqualStrings("", try clip(a, "界", 1, .truncate_right, false));
	try std.testing.expectEqualStrings("   12", try pad(a, "12", 5, .right));
	try std.testing.expectEqualStrings(" a  ", try pad(a, "a", 4, .center));
	try std.testing.expectEqualStrings("界 ", try pad(a, "界", 3, .left));
}
