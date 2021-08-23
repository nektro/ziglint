const std = @import("std");
const range = @import("range").range;

const linters = [_]type{
    @import("./tools/dupe_import.zig"),
};

pub fn main() !void {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    const alloc = &gpa.allocator;
    defer _ = gpa.deinit();

    var dir = try std.fs.cwd().openDir("./", .{ .iterate = true });
    defer dir.close();

    var walker = try dir.walk(alloc);
    defer walker.deinit();
    while (try walker.next()) |item| {
        var arena = std.heap.ArenaAllocator.init(alloc);
        const alloc2 = &arena.allocator;
        defer arena.deinit();

        if (item.kind != .File) continue;
        if (!std.mem.endsWith(u8, item.path, ".zig")) continue;
        // std.log.debug("{s}", .{item.path});

        const f = try dir.openFile(item.path, .{});
        defer f.close();

        const r = f.reader();
        const content = try r.readAllAlloc(alloc2, 1 * 1024 * 1024 * 1024 * 4);
        const nulcont = try negspan(alloc2, u8, content, 0);

        var tks = std.zig.Tokenizer.init(nulcont);
        var list = std.ArrayList(std.zig.Token).init(alloc2);

        while (true) {
            const tok = tks.next();
            if (tok.tag == .eof) break;
            try list.append(tok);
        }
        const tokens = list.toOwnedSlice();

        inline for (linters) |ns| {
            try ns.work(alloc2, item.path, tokens, nulcont);
        }
    }
    std.debug.print("\n", .{});
}

fn negspan(alloc: *std.mem.Allocator, comptime T: type, input: []const T, comptime term: T) ![:term]const T {
    var list = std.ArrayList(T).init(alloc);
    defer list.deinit();
    for (input) |c| try list.append(c);
    try list.append(term);
    const res = list.toOwnedSlice();
    return res[0 .. res.len - 1 :term];
}

pub const Loc = struct {
    line: usize,
    pos: usize,
};

pub fn locToLoc(source: [:0]const u8, loc: std.zig.Token.Loc) Loc {
    var line: usize = 1;
    var pos: usize = 1;
    for (range(loc.start)) |_, i| {
        pos += 1;
        if (source[i] != '\n') continue;
        line += 1;
        pos = 1;
    }
    return Loc{ .line = line, .pos = pos };
}
