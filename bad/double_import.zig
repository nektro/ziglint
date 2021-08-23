// ./bad/double_import.zig:5:11: found duplicate import of "std"

const std = @import("std");

const x = @import("std");

pub fn main() !void {
    std.log.info("{s}", .{"Hello"});
    x.log.info("{s}", .{"world!"});
}
