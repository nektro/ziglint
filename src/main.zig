const std = @import("std");
const string = []const u8;
const range = @import("range").range;
const flag = @import("flag");

const linters = [_]*const fn (std.mem.Allocator, []const u8, *Source, std.fs.File.Writer) WorkError!void{
    @import("./rules/dupe_import.zig").work,
    @import("./rules/todo.zig").work,
    @import("./rules/file_as_struct.zig").work,
    @import("./rules/unused.zig").work,
};

pub const WorkError = std.mem.Allocator.Error || std.fs.File.Writer.Error || error{};
pub const CheckError = std.fs.File.Writer.Error || error{};

const Rule = enum {
    dupe_import,
    todo,
    file_as_struct,
    unused,
};

pub fn main() !void {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    const alloc = gpa.allocator();
    defer std.debug.assert(!gpa.deinit());

    //

    flag.init(alloc);
    defer flag.deinit();

    try flag.addMulti("do");
    try flag.addMulti("skip");
    try flag.addMulti("file");

    _ = try flag.parse(.single);

    const do = flag.getMulti("do") orelse @as([]const string, &.{});
    const skip = flag.getMulti("skip") orelse @as([]const string, &.{});
    const files = flag.getMulti("file");

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

    var dir = try std.fs.cwd().openIterableDir("./", .{});
    defer dir.close();

    const out = std.io.getStdOut().writer();

    if (files) |_| {
        for (files.?) |item| {
            try doFile(alloc, dir.dir, item, rulestorun.items, out);
        }
    } else {
        var walker = try dir.walk(alloc);
        defer walker.deinit();
        while (try walker.next()) |item| {
            if (item.kind != .File) continue;
            try doFile(alloc, dir.dir, item.path, rulestorun.items, out);
        }
    }
}

fn doFile(alloc: std.mem.Allocator, dir: std.fs.Dir, path: string, rules: []const Rule, out: std.fs.File.Writer) !void {
    var arena = std.heap.ArenaAllocator.init(alloc);
    const alloc2 = arena.allocator();
    defer arena.deinit();

    if (!std.mem.endsWith(u8, path, ".zig")) return;
    // TODO eventually do .gitignore parsing
    if (std.mem.startsWith(u8, path, "zig-cache")) return;
    if (std.mem.startsWith(u8, path, "zig-bin")) return;
    if (std.mem.startsWith(u8, path, ".zigmod")) return;
    if (std.mem.startsWith(u8, path, ".gyro")) return;

    const f = try dir.openFile(path, .{});
    defer f.close();

    const r = f.reader();
    const content = try r.readAllAlloc(alloc2, 1 * 1024 * 1024 * 1024 * 4);
    const nulcont = try negspan(alloc2, u8, content, 0);

    var src = Source{
        .alloc = alloc2,
        .source = nulcont,
    };

    for (rules) |jtem| {
        try linters[@enumToInt(jtem)](alloc2, path, &src, out);
    }
}

fn negspan(alloc: std.mem.Allocator, comptime T: type, input: []const T, comptime term: T) ![:term]const T {
    var list = std.ArrayList(T).init(alloc);
    defer list.deinit();
    for (input) |c| try list.append(c);
    try list.append(term);
    const res = try list.toOwnedSlice();
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
    _ast: ?std.zig.Ast = null,

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
        self._tokens = try list.toOwnedSlice();
        return self._tokens.?;
    }

    pub fn ast(self: *Source) !std.zig.Ast {
        if (self._ast) |_| {
            return self._ast.?;
        }
        self._ast = try std.zig.Ast.parse(self.alloc, self.source, .zig);
        return self._ast.?;
    }
};

fn removeItem(comptime T: type, haystack: *std.ArrayList(T), needle: T) ?T {
    for (haystack.items) |item, i| {
        if (item == needle) return haystack.orderedRemove(i);
    }
    return null;
}
