// ./bad/todo.zig:5:1: TODO: add top-level documentation
// ./bad/todo.zig:9:1: TODO: maybe the return type should be !void
// ./bad/todo.zig:11:5: TODO: switch to something that also prints in release mode

//! TODO: add top-level documentation

const std = @import("std");

/// TODO maybe the return type should be !void
pub fn main() void {
    // TODO switch to something that also prints in release mode
    std.log.info("{s}", .{"hello world"});

    // maybe we shouldn't set the max to infinity
    // this is a non todo multiline comment
    const max = std.math.maxInt(usize);
    _ = max;
}
