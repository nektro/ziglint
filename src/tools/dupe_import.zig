const std = @import("std");
const main = @import("../main.zig");

pub fn work(alloc: *std.mem.Allocator, file_name: []const u8, tokens: []const std.zig.Token, source: [:0]const u8) !void {
    //
    var map = std.StringHashMap(main.Loc).init(alloc);
    defer map.deinit();

    for (tokens) |tok, i| {
        if (i + 4 >= tokens.len) break;

        const a = tokens[i + 0].tag == .builtin;
        const b = tokens[i + 1].tag == .l_paren;
        const c = tokens[i + 2].tag == .string_literal;
        const d = tokens[i + 3].tag == .r_paren;
        const e = tokens[i + 4].tag == .semicolon;

        if (a and b and c and d and e) {
            const builtin = tok;
            const string = tokens[i + 2];

            if (!std.mem.eql(u8, source[builtin.loc.start..builtin.loc.end], "@import")) continue;
            const loc = main.locToLoc(source, builtin.loc);
            const import = source[string.loc.start..string.loc.end];

            const res = try map.getOrPut(import);

            if (!res.found_existing) {
                res.value_ptr.* = loc;
            } else {
                std.log.warn("./{s}:{d}:{d}: found duplicate import of {s}", .{
                    file_name,
                    loc.line,
                    loc.pos,
                    import,
                });
            }
        }
    }
}