const std = @import("std");
const string = []const u8;
const range = @import("range").range;
const flag = @import("flag");

const linters = [_]fn (std.mem.Allocator, []const u8, *Source, std.fs.File.Writer) WorkError!void{
    @import("./tools/dupe_import.zig").work,
    @import("./tools/todo.zig").work,
};

pub const WorkError = std.mem.Allocator.Error || std.fs.File.Writer.Error || error{};

const Rule = enum {
    dupe_import,
    todo,
};

pub fn main() !void {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    const alloc = gpa.allocator();
    defer _ = gpa.deinit();

    //

    flag.init(alloc);
    defer flag.deinit();

    try flag.addMulti("do");
    try flag.addMulti("skip");

    _ = try flag.parse(.single);

    const do = flag.getMulti("do") orelse @as([]const string, &.{});
    const skip = flag.getMulti("skip") orelse @as([]const string, &.{});

    var rulestorun = std.ArrayList(Rule).init(alloc);
    defer rulestorun.deinit();

    if (do.len > 0 and skip.len > 0) {
        std.log.err("-do and -skip are mutually exclusive", .{});
        std.os.exit(1);
    }

    if (do.len > 0) {
        for (do) |item| {
            const r = std.meta.stringToEnum(Rule, item) orelse std.debug.panic("invalid rule name passed to -do: {s}", .{item});
            try rulestorun.append(r);
        }
    } else {
        try rulestorun.appendSlice(std.enums.values(Rule));

        if (skip.len > 0) {
            for (skip) |item| {
                const r = std.meta.stringToEnum(Rule, item) orelse std.debug.panic("invalid rule name passed to -skip: {s}", .{item});
                _ = removeItem(Rule, &rulestorun, r);
            }
        }
    }

    //

    var dir = try std.fs.cwd().openDir("./", .{ .iterate = true });
    defer dir.close();

    const out = std.io.getStdOut().writer();

    var walker = try dir.walk(alloc);
    defer walker.deinit();
    while (try walker.next()) |item| {
        var arena = std.heap.ArenaAllocator.init(alloc);
        const alloc2 = arena.allocator();
        defer arena.deinit();

        if (item.kind != .File) continue;
        if (!std.mem.endsWith(u8, item.path, ".zig")) continue;
        // TODO eventually do .gitignore parsing
        if (std.mem.startsWith(u8, item.path, "zig-cache")) continue;
        if (std.mem.startsWith(u8, item.path, ".zigmod")) continue;
        if (std.mem.startsWith(u8, item.path, ".gyro")) continue;

        const f = try dir.openFile(item.path, .{});
        defer f.close();

        const r = f.reader();
        const content = try r.readAllAlloc(alloc2, 1 * 1024 * 1024 * 1024 * 4);
        const nulcont = try negspan(alloc2, u8, content, 0);

        var src = Source{
            .alloc = alloc2,
            .source = nulcont,
        };

        for (rulestorun.items) |jtem| {
            try linters[@enumToInt(jtem)](alloc2, item.path, &src, out);
        }
    }
}

fn negspan(alloc: std.mem.Allocator, comptime T: type, input: []const T, comptime term: T) ![:term]const T {
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

pub const Source = struct {
    alloc: std.mem.Allocator,
    source: [:0]const u8,
    _tokens: ?[]const std.zig.Token = null,

    pub fn tokens(self: *Source) ![]const std.zig.Token {
        if (self._tokens) |_| {
            return self._tokens.?;
        }
        var tks = std.zig.Tokenizer.init(self.source);
        var list = std.ArrayList(std.zig.Token).init(self.alloc);

        while (true) {
            const tok = tks.next();
            if (tok.tag == .eof) break;
            try list.append(tok);
        }
        self._tokens = list.toOwnedSlice();
        return self._tokens.?;
    }
};

fn removeItem(comptime T: type, haystack: *std.ArrayList(T), needle: T) ?T {
    for (haystack.items) |item, i| {
        if (item == needle) return haystack.orderedRemove(i);
    }
    return null;
}
