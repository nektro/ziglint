const std = @import("std");

const x = @import("std");

pub fn main() !void {
    std.log.info("{s}", .{"Hello"});
    x.log.info("{s}", .{"world!"});
}
