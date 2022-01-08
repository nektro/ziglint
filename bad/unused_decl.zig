const std = @import("std");
const builtin = @import("builtin");
const root = @import("root");
const x = builtin.os.tag;

pub fn main() void {
    std.log.info("yo", .{});
    _ = foo;
}

const foo = struct {
    const bar = struct {};
    pub const bam = enum { a };

    fn baz() void {
        _ = x;
    }
};
