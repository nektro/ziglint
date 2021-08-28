// ./bad/todo.zig:6:1: TODO: maybe the return type should be !void
// ./bad/todo.zig:8:5: TODO: switch to something that also prints in release mode

const std = @import("std");

// TODO maybe the return type should be !void
pub fn main() void {
    // TODO switch to something that also prints in release mode
    std.log.info("{s}", .{"hello world"});

    // maybe we shouldn't set the max to infinity
    // this is a non todo multiline comment
    const max = std.math.maxInt(usize);
    _ = max;
}
