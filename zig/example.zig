const std = @import("std");
const random = @import("randomz");
const A = std.mem.Allocator;
pub const Row = []const []const u8;
const vocabulary = @embedFile("../src/example-words.txt");

pub fn seed(raw: []const u8) ![32]u8 {
	const hex = std.mem.startsWith(u8, raw, "0x") or std.mem.startsWith(u8, raw, "0X");
	const digits = if (hex) raw[2..] else raw;
	if (digits.len == 0 or (hex and digits.len > 64)) return error.InvalidSeed;
	for (digits) |ch| {
		if (ch >= '0' and ch <= '9') continue;
		if (hex and ((ch >= 'a' and ch <= 'f') or (ch >= 'A' and ch <= 'F'))) continue;
		return error.InvalidSeed;
	}
	const value = std.fmt.parseInt(u256, digits, if (hex) 16 else 10) catch return error.InvalidSeed;
	var bytes: [32]u8 = undefined;
	std.mem.writeInt(u256, &bytes, value, .big);
	return bytes;
}
pub fn canonical(a: A, bytes: [32]u8) ![]const u8 {
	return std.fmt.allocPrint(a, "0x{x}", .{&bytes});
}
const Rng = struct {
	state: random.Drbg,
	fn init(bytes: [32]u8) !Rng {
		var self: Rng = undefined;
		try check(random.randomz_drbg_init(&self.state, &bytes));
		return self;
	}
	fn fill(ctx: ?*anyopaque, out: [*]u8, count: usize) callconv(.c) c_int {
		const state: *random.Drbg = @ptrCast(@alignCast(ctx.?));
		return random.randomz_drbg_fill(state, out, count);
	}
	fn range(self: *Rng, first: i64, last: i64) !i64 {
		var result: i64 = undefined;
		try check(random.randomz_range(fill, &self.state, first, last, &result));
		return result;
	}
	fn length(self: *Rng) !usize {
		var value: random.Fixed = undefined;
		var count: i64 = undefined;
		var half = random.randomz_fixed_from_int(1);
		half.e -= 1;
		try check(random.randomz_exponential(fill, &self.state, half, &value));
		try check(random.randomz_fixed_to_int_trunc(value, &count));
		return @intCast(@min(8, count + 1));
	}
};
fn check(status: c_int) !void {
	if (status != 0) return error.ExampleGeneration;
}

// Caller supplies a bounded arena; all output belongs to that arena.
// Draw order matches src/Example.roc; rendering never consumes randomness.
pub fn generate(a: A, bytes: [32]u8, decimal: []const u8) ![]const Row {
	var words: std.ArrayList([]const u8) = .empty;
	defer words.deinit(a);
	var lines = std.mem.tokenizeScalar(u8, vocabulary, '\n');
	while (lines.next()) |line| try words.append(a, line);
	if (words.items.len != 100) return error.InvalidVocabulary;
	var rng = try Rng.init(bytes);
	const columns: usize = @intCast(try rng.range(4, 6));
	const rows = try a.alloc(Row, 13);
	const header = try a.alloc([]const u8, columns);
	rows[0] = header;
	const numeric = try a.alloc(bool, columns);
	defer a.free(numeric);
	const precision = try a.alloc(usize, columns);
	defer a.free(precision);
	const limits = try a.alloc(i64, columns);
	defer a.free(limits);
	for (0..columns) |column| {
		header[column] = words.items[@intCast(try rng.range(0, 99))];
		const kind = try rng.range(0, 1);
		numeric[column] = if (column == 0) false else if (column == 1) true else kind == 1;
		precision[column] = @intCast(try rng.range(0, 6));
		const digits = try rng.range(1, 5);
		limits[column] = std.math.pow(i64, 10, digits) - 1;
	}
	for (rows[1..]) |*row| {
		const cells = try a.alloc([]const u8, columns);
		row.* = cells;
		for (cells, 0..) |*cell, column| {
			var result: std.ArrayList(u8) = .empty;
			if (numeric[column]) {
				const whole = try rng.range(0, limits[column]);
				const negative = (try rng.range(0, 3)) == 0;
				const integer = try std.fmt.allocPrint(a, "{s}{d}", .{ if (negative) @as([]const u8, "-") else "", whole });
				defer a.free(integer);
				try result.appendSlice(a, integer);
				if (precision[column] > 0) try result.appendSlice(a, decimal);
				for (0..precision[column]) |_| try result.append(a, '0' + @as(u8, @intCast(try rng.range(0, 9))));
			} else {
				const count = try rng.length();
				for (0..count) |i| {
					if (i > 0) try result.append(a, ' ');
					try result.appendSlice(a, words.items[@intCast(try rng.range(0, 99))]);
				}
			}
			cell.* = try result.toOwnedSlice(a);
		}
	}
	return rows;
}

test "seed spellings agree and reject invalid values" {
	try std.testing.expectEqualSlices(u8, &(try seed("42")), &(try seed("0X2a")));
	for ([_][]const u8{ "", "-1", "+1", "1_0", "0x", " 1", "1.5", "0x10000000000000000000000000000000000000000000000000000000000000000" }) |bad| {
		try std.testing.expectError(error.InvalidSeed, seed(bad));
	}
}

test "example generation has bounded mixed columns and repeatable rows" {
	var arena = std.heap.ArenaAllocator.init(std.testing.allocator);
	defer arena.deinit();
	const a = arena.allocator();
	const first = try generate(a, try seed("42"), ".");
	const replay = try generate(a, try seed("0x2a"), ".");
	try std.testing.expectEqual(@as(usize, 13), first.len);
	try std.testing.expect(first[0].len >= 4 and first[0].len <= 6);
	// Independently checked with random's Lua DRBG: indices 53,90,64,52,41.
	const expected = [_][]const u8{ "context", "not just a chatbot", "latent space", "attention", "quarterly optimism" };
	for (first[0], expected) |actual, header| try std.testing.expectEqualStrings(header, actual);
	for (first, replay) |row, same| {
		try std.testing.expectEqual(first[0].len, row.len);
		for (row, same) |cell, repeated| try std.testing.expectEqualStrings(cell, repeated);
	}
	for (first[1..]) |row| {
		try std.testing.expect(@import("core.zig").classify(row[0], ".") == null);
		try std.testing.expectEqual(@as(?usize, 6), @import("core.zig").classify(row[1], "."));
	}
}
