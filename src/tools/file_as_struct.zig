const std = @import("std");
const main = @import("../main.zig");

pub fn work(alloc: std.mem.Allocator, file_name: []const u8, src: *main.Source, writer: std.fs.File.Writer) main.WorkError!void {
    //
    _ = alloc;
    _ = src;
    _ = writer;

    const ast = try src.ast();

    const tags = ast.nodes.items(.tag);
    const rootDecls = ast.rootDecls();

    const has_top_level_fields = for (rootDecls) |item| {
        if (tags[item] == .container_field_init) break true;
    } else false;

    const has_lower_name = std.ascii.isLower(std.fs.path.basename(file_name)[0]);
    const has_upper_name = std.ascii.isUpper(std.fs.path.basename(file_name)[0]);

    if (has_top_level_fields and has_lower_name) {
        try writer.print("./{s}:{d}:{d}: found top level fields, file name should be capitalized\n", .{ file_name, 1, 1 });
    }
    if (!has_top_level_fields and has_upper_name) {
        try writer.print("./{s}:{d}:{d}: found no top level fields, file name should be lowercase\n", .{ file_name, 1, 1 });
    }
}
