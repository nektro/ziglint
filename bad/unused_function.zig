// https://github.com/nektro/ziglint/issues/6

const std = @import("std");

pub fn main() void {
    std.log.info("yo", .{});
}

fn foo() void {
    //
}
