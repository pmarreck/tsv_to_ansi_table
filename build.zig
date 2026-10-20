const std = @import("std");
pub fn build(b: *std.Build) void {
	const target = b.standardTargetOptions(.{});
	const optimize = b.option(std.builtin.OptimizeMode, "optimize", "Optimization profile") orelse .ReleaseFast;
	const utf8proc = b.option([]const u8, "utf8proc", "Pinned utf8proc source directory") orelse @panic("pass -Dutf8proc=PATH (provided by ./build)");
	const module = b.createModule(.{ .root_source_file = b.path("main.zig"), .target = target, .optimize = optimize, .link_libc = true });
	module.addImport("randomz", b.dependency("random", .{ .target = target, .optimize = optimize }).module("randomz"));
	addUnicode(b, module, utf8proc);
	module.addCSourceFile(.{ .file = b.path("platform/console.c"), .flags = &.{"-std=c11"} });
	const exe = b.addExecutable(.{ .name = "tsv-to-ansi-table-zig", .root_module = module });
	b.installArtifact(exe);
	const unit_module = b.createModule(.{ .root_source_file = b.path("main.zig"), .target = target, .optimize = .Debug, .link_libc = true });
	unit_module.addImport("randomz", b.dependency("random", .{ .target = target, .optimize = @as(std.builtin.OptimizeMode, .Debug) }).module("randomz"));
	addUnicode(b, unit_module, utf8proc);
	const unit = b.addTest(.{ .root_module = unit_module });
	b.step("test", "Run safety-enabled pure-core tests").dependOn(&b.addRunArtifact(unit).step);
}
fn addUnicode(b: *std.Build, module: *std.Build.Module, source: []const u8) void {
	module.addIncludePath(.{ .cwd_relative = source });
	module.addCSourceFile(.{ .file = .{ .cwd_relative = b.pathJoin(&.{ source, "utf8proc.c" }) }, .flags = &.{ "-std=c99", "-DUTF8PROC_STATIC" } });
}
