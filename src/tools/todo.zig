const std = @import("std");
const main = @import("../main.zig");

pub fn work(alloc: std.mem.Allocator, file_name: []const u8, src: *main.Source, writer: std.fs.File.Writer) main.WorkError!void {
    //
    _ = alloc;
    const source = src.source;

    var i: usize = 1;
    var iter = std.mem.split(u8, source[0..source.len], "\n");
    while (iter.next()) |line| : (i += 1) {
        const lll = std.mem.trimLeft(u8, line, " ");
        const col = line.len - lll.len + 1;
        if (lll.len < 7 or !std.mem.startsWith(u8, lll, "//")) continue;
        // allow for //, ///, or //! comments
        switch (lll[2]) {
            '/', '!', ' ' => {},
            else => continue,
        }
        const comment_str = std.mem.trimLeft(u8, lll[3..], " ");
        if (!std.mem.startsWith(u8, comment_str, "TODO")) continue;
        const todo_msg = msg: {
            // skip colon character if it's immediately after TODO
            const msg_start: usize = if (std.mem.startsWith(u8, comment_str[4..], ":")) 5 else 4;
            break :msg std.mem.trim(u8, comment_str[msg_start..], " ");
        };
        try writer.print("./{s}:{d}:{d}: TODO: {s}\n", .{ file_name, i, col, todo_msg });
    }
}
