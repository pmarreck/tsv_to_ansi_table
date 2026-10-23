const std = @import("std");
pub fn build(b: *std.Build) void {
	const target = b.standardTargetOptions(.{});
	const dependency = b.dependency("tsv_to_ansi_table", .{ .target = target, .optimize = @as(std.builtin.OptimizeMode, .Debug) });
	const root = b.createModule(.{ .root_source_file = b.path("main.zig"), .target = target, .optimize = .Debug });
	root.addImport("table", dependency.module("tsv_to_ansi_table"));
	const tests = b.addTest(.{ .root_module = root });
	b.step("test", "Consume the public module without dependency path overrides").dependOn(&b.addRunArtifact(tests).step);
}
