const std = @import("std");
const main = @import("../main.zig");

const string = []const u8;
const NodeIndex = std.zig.Ast.Node.Index;

pub fn work(alloc: std.mem.Allocator, file_name: string, src: *main.Source, writer: std.fs.File.Writer) main.WorkError!void {
    //
    _ = alloc;

    const ast = try src.ast();
    try checkNamespace(ast, 0, writer, file_name);
}

const CheckError = std.fs.File.Writer.Error || error{};

fn checkNamespace(ast: std.zig.Ast, ns_node: NodeIndex, writer: std.fs.File.Writer, file_name: string) CheckError!void {
    const tags = ast.nodes.items(.tag);
    const data = ast.nodes.items(.data)[ns_node];

    const childs = switch (tags[ns_node]) {
        .root => ast.rootDecls(),
        .block, .block_semicolon => ast.extra_data[data.lhs..data.rhs],
        .container_decl, .container_decl_trailing => ast.containerDecl(ns_node).ast.members,

        .container_decl_two, .container_decl_two_trailing => blk: {
            var buffer: [2]NodeIndex = undefined;
            const x = ast.containerDeclTwo(&buffer, ns_node);
            break :blk x.ast.members;
        },

        else => @panic(@tagName(tags[ns_node])),
    };

    for (childs) |item| {
        try checkNamespaceItem(ast, childs, item, writer, file_name);
    }
}

fn checkNamespaceItem(ast: std.zig.Ast, ns_childs: []const NodeIndex, node: NodeIndex, writer: std.fs.File.Writer, file_name: string) CheckError!void {
    const tags = ast.nodes.items(.tag);
    const main_tokens = ast.nodes.items(.main_token);

    switch (tags[node]) {
        .simple_var_decl => {
            try searchForNameInNamespace(ast, main_tokens[node] + 1, ns_childs, node, writer, file_name);
        },

        .fn_decl => {}, // TODO https://github.com/nektro/ziglint/issues/6

        .for_simple,
        .assign,
        .builtin_call_two,
        .if_simple,
        .container_field_init,
        .@"defer",
        .while_simple,
        .call_one,
        .@"try",
        .@"if",
        .call,
        .@"return",
        .assign_add,
        .switch_comma,
        => {}, // TODO double check ignoring these here is correct

        else => @panic(@tagName(tags[node])),
    }
}

fn searchForNameInNamespace(ast: std.zig.Ast, name_node: NodeIndex, ns_childs: []const NodeIndex, self: NodeIndex, writer: std.fs.File.Writer, file_name: string) CheckError!void {
    const name = ast.tokenSlice(name_node);
    for (ns_childs) |item| {
        if (item == self) continue; // definition doesn't count as a use
        if (try checkValueForName(ast, name, item, writer, file_name)) return;
    }
    const loc = ast.tokenLocation(0, name_node);
    try writer.print("./{s}:{d}:{d}: unused local declaration '{s}'\n", .{ file_name, loc.line + 1, loc.column + 1, name });
    _ = file_name;
    _ = writer;
    _ = loc;
}

fn checkValueForName(ast: std.zig.Ast, search_name: string, node: NodeIndex, writer: std.fs.File.Writer, file_name: string) CheckError!bool {
    if (node == 0) return false;
    const tags = ast.nodes.items(.tag);
    const data = ast.nodes.items(.data)[node];
    const main_tokens = ast.nodes.items(.main_token);

    return switch (tags[node]) {
        .root => unreachable, // handled above by skipping node 0

        .string_literal,
        .integer_literal,
        .char_literal,
        .enum_literal,
        .error_set_decl,
        .@"continue",
        => false,

        .builtin_call_two,
        .builtin_call_two_comma,
        .fn_decl,
        .block_two,
        .block_two_semicolon,
        .assign,
        .array_access,
        .ptr_type_aligned,
        .for_simple,
        .call_one,
        .array_cat,
        .bool_or,
        .bool_and,
        .equal_equal,
        .@"catch",
        .container_field_init,
        .struct_init_dot_two,
        .struct_init_one,
        .struct_init_one_comma,
        .array_init_dot_two,
        .array_init_dot_two_comma,
        .array_type,
        .merge_error_sets,
        .@"orelse",
        .greater_than,
        .bang_equal,
        .sub,
        .assign_add,
        .@"break",
        .error_union,
        => {
            if (try checkValueForName(ast, search_name, data.lhs, writer, file_name)) return true;
            if (try checkValueForName(ast, search_name, data.rhs, writer, file_name)) return true;
            return false;
        },

        .field_access,
        .call,
        .deref,
        .unwrap_optional,
        .optional_type,
        .address_of,
        .@"try",
        .bool_not,
        .@"return",
        .@"switch",
        .switch_comma,
        => {
            return try checkValueForName(ast, search_name, data.lhs, writer, file_name);
        },

        .@"defer" => {
            return try checkValueForName(ast, search_name, data.rhs, writer, file_name);
        },

        .@"if" => try checkAstValuesForName(ast, search_name, writer, file_name, ast.ifFull(node), &.{
            .cond_expr,
            .then_expr,
            .else_expr,
        }),
        .while_simple => try checkAstValuesForName(ast, search_name, writer, file_name, ast.whileSimple(node), &.{
            .cond_expr,
            .cont_expr,
            .then_expr,
            .else_expr,
        }),
        .slice_sentinel => try checkAstValuesForName(ast, search_name, writer, file_name, ast.sliceSentinel(node), &.{
            .sentinel,
            .start,
            .end,
            .sentinel,
        }),
        .ptr_type_sentinel => try checkAstValuesForName(ast, search_name, writer, file_name, ast.ptrTypeSentinel(node), &.{
            .align_node,
            .addrspace_node,
            .sentinel,
            .bit_range_start,
            .bit_range_end,
            .child_type,
        }),

        .simple_var_decl => {
            const x = ast.simpleVarDecl(node);
            // x.visib_token; != null when pub
            const name = ast.tokenSlice(x.ast.mut_token + 1);
            if (std.mem.eql(u8, search_name, name)) return true;
            if (try checkValueForName(ast, search_name, x.ast.type_node, writer, file_name)) return true;
            if (try checkValueForName(ast, search_name, x.ast.init_node, writer, file_name)) return true;
            return false;
        },
        .identifier => {
            const name = ast.tokenSlice(main_tokens[node]);
            return std.mem.eql(u8, search_name, name);
        },
        .fn_proto_simple => {
            var params: [1]NodeIndex = undefined;
            const x = ast.fnProtoSimple(&params, node);
            if (try checkValuesForName(ast, search_name, x.ast.params, writer, file_name)) return true;
            return try checkAstValuesForName(ast, search_name, writer, file_name, x, &.{
                .return_type,
            });
        },
        .fn_proto_multi => {
            const x = ast.fnProtoMulti(node);
            if (try checkValuesForName(ast, search_name, x.ast.params, writer, file_name)) return true;
            return try checkAstValuesForName(ast, search_name, writer, file_name, x, &.{
                .return_type,
            });
        },
        .container_decl_two, .container_decl_two_trailing => {
            var buffer: [2]NodeIndex = undefined;
            const x = ast.containerDeclTwo(&buffer, node);
            if (try checkValuesForName(ast, search_name, x.ast.members, writer, file_name)) return true;
            try checkNamespace(ast, node, writer, file_name);
            return false;
        },
        .block, .block_semicolon => {
            const statements = ast.extra_data[data.lhs..data.rhs];
            if (try checkValuesForName(ast, search_name, statements, writer, file_name)) return true;
            return false;
        },
        .if_simple => {
            if (try checkValueForName(ast, search_name, data.lhs, writer, file_name)) return true;
            if (try checkValueForName(ast, search_name, data.rhs, writer, file_name)) return true;
            if (std.mem.eql(u8, search_name, ast.tokenSlice(main_tokens[node]))) return true;
            return false;
        },
        .container_decl, .container_decl_trailing => {
            const x = ast.containerDecl(node);
            if (try checkValuesForName(ast, search_name, x.ast.members, writer, file_name)) return true;
            try checkNamespace(ast, node, writer, file_name); // TODO only do this if the simple_var_decl it comes from is not `pub`
            return false;
        },
        .struct_init, .struct_init_comma => {
            const x = ast.structInit(node);
            if (try checkValueForName(ast, search_name, x.ast.type_expr, writer, file_name)) return true;
            if (try checkValuesForName(ast, search_name, x.ast.fields, writer, file_name)) return true;
            return false;
        },
        .array_init, .array_init_comma => {
            const x = ast.arrayInit(node);
            if (try checkValueForName(ast, search_name, x.ast.type_expr, writer, file_name)) return true;
            if (try checkValuesForName(ast, search_name, x.ast.elements, writer, file_name)) return true;
            return false;
        },

        else => @panic(@tagName(tags[node])),
    };
}

fn checkValuesForName(ast: std.zig.Ast, search_name: string, nodes: []const NodeIndex, writer: std.fs.File.Writer, file_name: string) CheckError!bool {
    for (nodes) |item| {
        if (try checkValueForName(ast, search_name, item, writer, file_name)) return true;
    }
    return false;
}

fn checkAstValuesForName(ast: std.zig.Ast, search_name: string, writer: std.fs.File.Writer, file_name: string, inner: anytype, comptime fields: []const std.meta.FieldEnum(@TypeOf(inner.ast))) CheckError!bool {
    inline for (fields) |item| {
        if (try checkValueForName(ast, search_name, @field(inner.ast, @tagName(item)), writer, file_name)) return true;
    }
    return false;
}
