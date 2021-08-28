const std = @import("std");

pub fn work(alloc: *std.mem.Allocator, file_name: []const u8, tokens: []const std.zig.Token, source: [:0]const u8, writer: std.fs.File.Writer) !void {
    _ = alloc;
    _ = tokens;

    var i: usize = 1;
    var iter = std.mem.split(u8, source[0..source.len], "\n");
    while (iter.next()) |line| : (i += 1) {
        const lll = std.mem.trimLeft(u8, line, " ");
        const col = line.len - lll.len + 1;
        if (!std.mem.startsWith(u8, lll, "// TODO")) continue;
        try writer.print("./{s}:{d}:{d}: TODO: {s}\n", .{ file_name, i, col, std.mem.trim(u8, lll[8..], " ") });
    }
}
