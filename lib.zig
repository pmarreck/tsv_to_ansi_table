//! Pure table rendering and streaming; the caller supplies all configuration.
pub const Config = @import("zig/options.zig").Config;
pub const parseOptions = @import("zig/options.zig").parse;
pub const parseGlyphs = @import("zig/glyphs.zig").parse;
pub const Row = @import("zig/render.zig").Row;
pub const parseTsvRow = @import("zig/core.zig").parseRow;
pub const Engine = @import("zig/engine.zig").Engine;
pub const renderTable = @import("zig/engine.zig").renderTable;
pub const example = @import("zig/example.zig");
pub const help = @embedFile("src/help.txt");
test {
	_ = @import("zig/core.zig");
	_ = @import("zig/example.zig");
	_ = @import("zig/engine.zig");
}
