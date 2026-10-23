const std = @import("std");
pub fn build(b: *std.Build) void {
	const target = b.standardTargetOptions(.{});
	const optimize = b.option(std.builtin.OptimizeMode, "optimize", "Optimization profile") orelse .ReleaseFast;
	const utf8proc: std.Build.LazyPath = if (b.option([]const u8, "utf8proc", "Override utf8proc source directory")) |path| .{ .cwd_relative = path } else b.dependency("utf8proc", .{}).path("");
	const public = b.addModule("tsv_to_ansi_table", .{ .root_source_file = b.path("lib.zig"), .target = target, .optimize = optimize, .link_libc = true });
	public.addImport("randomz", b.dependency("random", .{ .target = target, .optimize = optimize }).module("randomz"));
	addUnicode(b, public, utf8proc);
	const ffi = b.createModule(.{ .root_source_file = b.path("ffi.zig"), .target = target, .optimize = optimize, .link_libc = true });
	ffi.addImport("tsv_to_ansi_table", public);
	const library = b.addLibrary(.{ .name = "tsv_to_ansi_table", .linkage = .static, .root_module = ffi });
	library.installHeader(b.path("include/tsv_to_ansi_table.h"), "tsv_to_ansi_table.h");
	b.installArtifact(library);
	const cli = b.createModule(.{ .target = target, .optimize = optimize, .link_libc = true });
	cli.addIncludePath(b.path("include"));
	cli.addCSourceFile(.{ .file = b.path("cli/main.c"), .flags = &.{ "-std=c11", if (optimize == .Debug) "-DTSVAT_DEBUG=1" else "-DTSVAT_DEBUG=0" } });
	cli.addCSourceFile(.{ .file = b.path("platform/console.c"), .flags = &.{"-std=c11"} });
	cli.linkLibrary(library);
	if (target.result.os.tag == .windows) {
		cli.linkSystemLibrary("bcrypt", .{});
		cli.linkSystemLibrary("shell32", .{});
	}
	b.installArtifact(b.addExecutable(.{ .name = "tsv-to-ansi-table-zig", .root_module = cli }));
	const consumer_module = b.createModule(.{ .target = target, .optimize = .Debug, .link_libc = true });
	consumer_module.addIncludePath(b.path("include"));
	consumer_module.addCSourceFile(.{ .file = b.path("tests/integration/library.c"), .flags = &.{"-std=c11"} });
	consumer_module.linkLibrary(library);
	const consumer = b.addExecutable(.{ .name = "library-consumer", .root_module = consumer_module });
	b.step("test-library", "Exercise the C ABI from an external C consumer").dependOn(&b.addRunArtifact(consumer).step);
	const unit_module = b.createModule(.{ .root_source_file = b.path("lib.zig"), .target = target, .optimize = .Debug, .link_libc = true });
	unit_module.addImport("randomz", b.dependency("random", .{ .target = target, .optimize = @as(std.builtin.OptimizeMode, .Debug) }).module("randomz"));
	addUnicode(b, unit_module, utf8proc);
	const unit = b.addTest(.{ .root_module = unit_module });
	b.step("test", "Run safety-enabled pure-core tests").dependOn(&b.addRunArtifact(unit).step);
}
fn addUnicode(b: *std.Build, module: *std.Build.Module, source: std.Build.LazyPath) void {
	module.addIncludePath(source);
	module.addCSourceFile(.{ .file = source.path(b, "utf8proc.c"), .flags = &.{ "-std=c99", "-DUTF8PROC_STATIC" } });
}
