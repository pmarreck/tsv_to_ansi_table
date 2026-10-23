const std = @import("std");
const table = @import("table");
test "public module works as a downstream dependency" {
	const output = try table.renderTable(std.testing.allocator, .{ .plain = true }, &.{ &.{ "Name", "N" }, &.{ "a", "12" } });
	defer std.testing.allocator.free(output);
	try std.testing.expectEqualStrings("Name   N\na     12\n", output);
}
