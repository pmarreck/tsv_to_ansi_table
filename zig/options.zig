const std = @import("std");
const text = @import("text.zig");
const A = std.mem.Allocator;
pub const Config = struct {
	glyphs: @import("glyphs.zig").Set = .{},
	no_header: bool = false,
	headers: []const []const u8 = &.{},
	widths: []const usize = &.{},
	alignments: []const text.Align = &.{},
	overflow: []const text.Overflow = &.{},
	terminal: usize = 80,
	color: enum { auto, always, never } = .auto,
	ascii: bool = false,
	plain: bool = false,
	decimal: []const u8 = ".",
	help: bool = false,
	about: bool = false,
	example: bool = false,
	seed: ?[32]u8 = null,
};
pub fn parse(a: A, args: []const []const u8, initial: Config) !Config {
	var config = initial;
	var i: usize = 0;
	while (i < args.len) : (i += 1) {
		const raw = args[i];
		if (!std.unicode.utf8ValidateSlice(raw)) return error.InvalidOptions;
		if (i == 0 and eq(raw, "example")) { config.example = true; continue; }
		if (eq(raw, "--help") or eq(raw, "-h") or eq(raw, "/h") or eq(raw, "/?")) { config.help = true; continue; }
		if (eq(raw, "--about")) { config.about = true; continue; }
		if (eq(raw, "--no-header")) { config.no_header = true; continue; }
		if (eq(raw, "--ascii")) { config.ascii = true; continue; }
		if (eq(raw, "--plain")) { config.plain = true; config.color = .never; continue; }
		const separator = std.mem.indexOfScalar(u8, raw, '=');
		const arg = if (separator) |index| raw[0..index] else raw;
		const value = if (separator) |index| raw[index + 1 ..] else value: {
			i += 1;
			if (i == args.len) return error.InvalidOptions;
			break :value args[i];
		};
		if (!std.unicode.utf8ValidateSlice(value)) return error.InvalidOptions;
		var parts = std.mem.splitScalar(u8, value, ',');
		if (eq(arg, "--seed")) {
			if (!config.example or config.seed != null) return error.InvalidOptions;
			config.seed = try @import("example.zig").seed(value);
		} else if (eq(arg, "--headers") or eq(arg, "--header")) {
			var names: std.ArrayList([]const u8) = .empty;
			try names.appendSlice(a, config.headers);
			if (eq(arg, "--header")) try names.append(a, value) else while (parts.next()) |p| try names.append(a, p);
			config.headers = try names.toOwnedSlice(a);
		} else if (eq(arg, "--widths")) {
			var widths: std.ArrayList(usize) = .empty;
			while (parts.next()) |p| try widths.append(a, if (eq(p, "auto")) 0 else try positive(p));
			config.widths = try widths.toOwnedSlice(a);
		} else if (eq(arg, "--terminal-width")) {
			config.terminal = try positive(value);
		} else if (eq(arg, "--align")) {
			var alignments: std.ArrayList(text.Align) = .empty;
			while (parts.next()) |p| try alignments.append(a, std.meta.stringToEnum(text.Align, p) orelse return error.InvalidOptions);
			config.alignments = try alignments.toOwnedSlice(a);
		} else if (eq(arg, "--overflow")) {
			var modes: std.ArrayList(text.Overflow) = .empty;
			while (parts.next()) |p| {
				const mode: text.Overflow = if (eq(p, "auto")) .auto else if (eq(p, "truncate") or eq(p, "truncate-right")) .truncate_right else if (eq(p, "truncate-left")) .truncate_left else if (eq(p, "prefix-ellipsis")) .prefix_ellipsis else if (eq(p, "suffix-ellipsis")) .suffix_ellipsis else return error.InvalidOptions;
				try modes.append(a, mode);
			}
			config.overflow = try modes.toOwnedSlice(a);
		} else if (eq(arg, "--color")) {
			config.color = std.meta.stringToEnum(@TypeOf(config.color), value) orelse return error.InvalidOptions;
		} else if (eq(arg, "--decimal-separator")) {
			if (!eq(value, ".") and !eq(value, ",") and !eq(value, "٫")) return error.InvalidOptions;
			config.decimal = value;
		} else return error.InvalidOptions;
	}
	return config;
}
fn eq(a: []const u8, b: []const u8) bool { return std.mem.eql(u8, a, b); }
fn positive(value: []const u8) !usize {
	const n = std.fmt.parseInt(usize, value, 10) catch return error.InvalidOptions;
	if (n == 0 or n > 10000) return error.InvalidOptions;
	return n;
}
test "parse options and reject invalid option sets" {
	var arena = std.heap.ArenaAllocator.init(std.testing.allocator);
	defer arena.deinit();
	const a = arena.allocator();
	const config = try parse(a, &.{"--no-header", "--widths", "10,auto,3", "--align", "right,left,center", "--headers", "Name,N"}, .{});
	try std.testing.expect(config.no_header);
	try std.testing.expectEqualSlices(usize, &.{10,0,3}, config.widths);
	try std.testing.expectEqualSlices(text.Align, &.{.right,.left,.center}, config.alignments);
	try std.testing.expectEqualStrings("Name", config.headers[0]);
	for ([_][]const []const u8{ &.{"--wat"}, &.{"--widths"}, &.{"--widths", "0"}, &.{"--align","sideways"}, &.{"--color","sometime"} }) |args| {
		try std.testing.expectError(error.InvalidOptions, parse(a, args, .{}));
	}
	for ([_][]const []const u8{ &.{"--header", "\xff"}, &.{"--headers", "A,\xff", "--help"} }) |args| {
		try std.testing.expectError(error.InvalidOptions, parse(a, args, .{}));
	}
}
