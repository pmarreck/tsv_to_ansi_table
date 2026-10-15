const std = @import("std");
const text = @import("text.zig");
pub const Set = struct {
	top_left: []const u8 = "┌", top_join: []const u8 = "┬", top_right: []const u8 = "┐",
	middle_left: []const u8 = "├", middle_join: []const u8 = "┼", middle_right: []const u8 = "┤",
	bottom_left: []const u8 = "└", bottom_join: []const u8 = "┴", bottom_right: []const u8 = "┘",
	horizontal: []const u8 = "─", vertical: []const u8 = "│", ellipsis: []const u8 = "…",
};
pub const ascii: Set = .{ .top_left="+", .top_join="+", .top_right="+", .middle_left="+", .middle_join="+", .middle_right="+", .bottom_left="+", .bottom_join="+", .bottom_right="+", .horizontal="-", .vertical="|", .ellipsis="..." };
// Returned strings belong to the caller's configuration arena.
pub fn parse(arena: std.mem.Allocator, raw: []const u8) !Set {
	if (raw.len == 0) return .{};
	const parsed = std.json.parseFromSlice(std.json.Value, arena, raw, .{ .duplicate_field_behavior = .use_last }) catch return error.InvalidGlyphs;
	defer parsed.deinit();
	if (parsed.value != .object) return error.InvalidGlyphs;
	var result: Set = .{};
	var entries = parsed.value.object.iterator();
	while (entries.next()) |entry| {
		if (entry.value_ptr.* != .string) return error.InvalidGlyphs;
		const value = entry.value_ptr.string;
		const parts = try text.clusters(arena, value);
		defer arena.free(parts);
		const clean = try text.safe(arena, value);
		defer arena.free(clean);
		if (parts.len != 1 or parts[0].width != 1 or !std.mem.eql(u8, clean, value)) return error.InvalidGlyphs;
		var recognized = false;
		inline for (std.meta.fields(Set)) |field| {
			if (std.mem.eql(u8, entry.key_ptr.*, field.name)) {
				@field(result, field.name) = try arena.dupe(u8, value);
				recognized = true;
			}
		}
		if (!recognized) return error.InvalidGlyphs;
	}
	return result;
}
test "partial glyph profile preserves defaults and rejects invalid sets" {
	var arena = std.heap.ArenaAllocator.init(std.testing.allocator);
	defer arena.deinit();
	const a = arena.allocator();
	const g = try parse(a, "{\"top_left\":\"╭\",\"ellipsis\":\"~\"}");
	try std.testing.expectEqualStrings("╭", g.top_left);
	try std.testing.expectEqualStrings("┐", g.top_right);
	for ([_][]const u8{ "null", "[]", "bad", "{\"x\":\"!\"}", "{\"vertical\":1}", "{\"vertical\":\"界\"}", "{\"vertical\":\"\\u001b\"}", "{\"vertical\":\"\"}", "{\"vertical\":\"||\"}" }) |raw| try std.testing.expectError(error.InvalidGlyphs, parse(a, raw));
}
