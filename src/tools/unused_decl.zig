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

        else => @panic(@tagName(tags[ns_node])), // namespace
    };

    for (childs) |item| {
        try checkNamespaceItem(ast, childs, item, writer, file_name, ns_node);
    }
}

fn checkNamespaceItem(ast: std.zig.Ast, ns_childs: []const NodeIndex, node: NodeIndex, writer: std.fs.File.Writer, file_name: string, owner: NodeIndex) CheckError!void {
    const tags = ast.nodes.items(.tag);

    switch (tags[node]) {
        .simple_var_decl => {
            const x = ast.simpleVarDecl(node);
            if (x.visib_token) |_| return;
            try searchForNameInNamespace(ast, x.ast.mut_token + 1, ns_childs, node, writer, file_name);
        },

        // TODO https://github.com/nektro/ziglint/issues/6
        .fn_decl => {},

        // container level tag but not a named decl we need to check, skipping
        .container_field_init,
        .fn_proto_simple,
        .fn_proto_multi,
        .test_decl,
        => {},

        else => {
            std.log.warn("{s} has a {s} child", .{ @tagName(tags[owner]), @tagName(tags[node]) });
            @panic(@tagName(tags[node])); // decl
        },
    }
}

fn searchForNameInNamespace(ast: std.zig.Ast, name_node: NodeIndex, ns_childs: []const NodeIndex, self: NodeIndex, writer: std.fs.File.Writer, file_name: string) CheckError!void {
    const name = ast.tokenSlice(name_node);
    for (ns_childs) |item| {
        if (item == self) continue; // definition doesn't count as a use
        if (try checkValueForName(ast, name, item, writer, file_name, self)) return;
    }
    const loc = ast.tokenLocation(0, name_node);
    try writer.print("./{s}:{d}:{d}: unused local declaration '{s}'\n", .{ file_name, loc.line + 1, loc.column + 1, name });
}

fn checkValueForName(ast: std.zig.Ast, search_name: string, node: NodeIndex, writer: std.fs.File.Writer, file_name: string, owner: NodeIndex) CheckError!bool {
    if (node == 0) return false;
    const tags = ast.nodes.items(.tag);
    const datas = ast.nodes.items(.data);
    const main_tokens = ast.nodes.items(.main_token);

    if (node >= datas.len) std.debug.panic("owner node '{s}' indexed {d} out of bounds on slice of length {d}", .{ @tagName(tags[owner]), node, datas.len });
    const data = datas[node];

    return switch (tags[node]) {
        .root => unreachable, // handled above by skipping node 0

        .string_literal,
        .integer_literal,
        .char_literal,
        .enum_literal,
        .error_set_decl,
        .@"continue",
        .error_value,
        .unreachable_literal,
        .float_literal,
        .multiline_string_literal,
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
        .struct_init_dot_two_comma,
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
        .error_union,
        .mul,
        .less_than,
        .add,
        .greater_or_equal,
        .slice_open,
        .shl,
        .less_or_equal,
        .assign_sub,
        .div,
        .assign_div,
        .assign_mul,
        .mod,
        .switch_case_one,
        .assign_bit_or,
        .array_init_one,
        .array_init_one_comma,
        => {
            if (try checkValueForName(ast, search_name, data.lhs, writer, file_name, node)) return true;
            if (try checkValueForName(ast, search_name, data.rhs, writer, file_name, node)) return true;
            return false;
        },

        .field_access,
        .deref,
        .unwrap_optional,
        .optional_type,
        .address_of,
        .@"try",
        .bool_not,
        .@"return",
        .grouped_expression,
        .@"usingnamespace",
        .@"comptime",
        .negation,
        => {
            return try checkValueForName(ast, search_name, data.lhs, writer, file_name, node);
        },

        .@"defer",
        .test_decl,
        .@"errdefer",
        .@"break",
        => {
            return try checkValueForName(ast, search_name, data.rhs, writer, file_name, node);
        },

        .@"if" => try checkAstValuesForName(ast, search_name, writer, file_name, node, ast.ifFull(node), &.{
            .cond_expr,
            .then_expr,
            .else_expr,
        }),
        .while_simple => try checkAstValuesForName(ast, search_name, writer, file_name, node, ast.whileSimple(node), &.{
            .cond_expr,
            .then_expr,
        }),
        .slice => try checkAstValuesForName(ast, search_name, writer, file_name, node, ast.slice(node), &.{
            .sliced,
            .start,
            .end,
        }),
        .slice_sentinel => try checkAstValuesForName(ast, search_name, writer, file_name, node, ast.sliceSentinel(node), &.{
            .sliced,
            .start,
            .end,
            .sentinel,
        }),
        .ptr_type_sentinel => try checkAstValuesForName(ast, search_name, writer, file_name, node, ast.ptrTypeSentinel(node), &.{
            .sentinel,
            .child_type,
        }),
        .while_cont => try checkAstValuesForName(ast, search_name, writer, file_name, node, ast.whileCont(node), &.{
            .cond_expr,
            .cont_expr,
            .then_expr,
        }),
        .array_type_sentinel => try checkAstValuesForName(ast, search_name, writer, file_name, node, ast.arrayTypeSentinel(node), &.{
            .elem_count,
            .sentinel,
            .elem_type,
        }),

        // zig fmt: off
        .struct_init, .struct_init_comma =>         try checkAstParentOpForName(ast, search_name, writer, file_name, node, ast.structInit(node), .type_expr, .fields),
        .array_init, .array_init_comma =>           try checkAstParentOpForName(ast, search_name, writer, file_name, node, ast.arrayInit(node), .type_expr, .elements),
        .call, .call_comma =>                       try checkAstParentOpForName(ast, search_name, writer, file_name, node, ast.callFull(node), .fn_expr, .params),
        .array_init_dot, .array_init_dot_comma =>   try checkAstParentOpForName(ast, search_name, writer, file_name, node, ast.arrayInitDot(node), .type_expr, .elements),
        .struct_init_dot, .struct_init_dot_comma => try checkAstParentOpForName(ast, search_name, writer, file_name, node, ast.structInitDot(node), .type_expr, .fields),
        .switch_case =>                             try checkAstParentOpForName(ast, search_name, writer, file_name, node, ast.switchCase(node), .target_expr, .values),
        .tagged_union =>                            try checkAstParentOpForName(ast, search_name, writer, file_name, node, ast.taggedUnion(node), .arg, .members),
        // zig fmt: on

        .simple_var_decl => {
            const x = ast.simpleVarDecl(node);
            const name = ast.tokenSlice(x.ast.mut_token + 1);
            if (std.mem.eql(u8, search_name, name)) return true;
            if (try checkValueForName(ast, search_name, x.ast.type_node, writer, file_name, node)) return true;
            if (try checkValueForName(ast, search_name, x.ast.init_node, writer, file_name, node)) return true;
            return false;
        },
        .identifier => {
            const name = ast.tokenSlice(main_tokens[node]);
            return std.mem.eql(u8, search_name, name);
        },
        .fn_proto_simple => {
            var params: [1]NodeIndex = undefined;
            const x = ast.fnProtoSimple(&params, node);
            if (try checkValuesForName(ast, search_name, x.ast.params, writer, file_name, node)) return true;
            return try checkAstValuesForName(ast, search_name, writer, file_name, node, x, &.{
                .return_type,
            });
        },
        .fn_proto_multi => {
            const x = ast.fnProtoMulti(node);
            if (try checkValuesForName(ast, search_name, x.ast.params, writer, file_name, node)) return true;
            return try checkAstValuesForName(ast, search_name, writer, file_name, node, x, &.{
                .return_type,
            });
        },
        .fn_proto_one => {
            var params: [1]NodeIndex = undefined;
            const x = ast.fnProtoOne(&params, node);
            if (try checkValuesForName(ast, search_name, x.ast.params, writer, file_name, node)) return true;
            return try checkAstValuesForName(ast, search_name, writer, file_name, node, x, &.{
                .return_type,
                .align_expr,
                .addrspace_expr,
                .section_expr,
                .callconv_expr,
            });
        },
        .container_decl_two, .container_decl_two_trailing => {
            var buffer: [2]NodeIndex = undefined;
            const x = ast.containerDeclTwo(&buffer, node);
            if (try checkValuesForName(ast, search_name, x.ast.members, writer, file_name, node)) return true;
            try checkNamespace(ast, node, writer, file_name);
            return false;
        },
        .block, .block_semicolon => {
            const statements = ast.extra_data[data.lhs..data.rhs];
            if (try checkValuesForName(ast, search_name, statements, writer, file_name, node)) return true;
            return false;
        },
        .if_simple => {
            if (try checkValueForName(ast, search_name, data.lhs, writer, file_name, node)) return true;
            if (try checkValueForName(ast, search_name, data.rhs, writer, file_name, node)) return true;
            if (std.mem.eql(u8, search_name, ast.tokenSlice(main_tokens[node]))) return true;
            return false;
        },
        .container_decl, .container_decl_trailing => {
            const x = ast.containerDecl(node);
            if (try checkValuesForName(ast, search_name, x.ast.members, writer, file_name, node)) return true;
            try checkNamespace(ast, node, writer, file_name);
            return false;
        },
        .@"switch", .switch_comma => {
            const extra = ast.extraData(data.rhs, std.zig.Ast.Node.SubRange);
            const cases = ast.extra_data[extra.start..extra.end];
            if (try checkValueForName(ast, search_name, data.lhs, writer, file_name, node)) return true;
            if (try checkValuesForName(ast, search_name, cases, writer, file_name, node)) return true;
            return false;
        },
        .tagged_union_two, .tagged_union_two_trailing => {
            var params: [2]NodeIndex = undefined;
            const x = ast.taggedUnionTwo(&params, node);
            return try checkAstParentOpForName(ast, search_name, writer, file_name, node, x, .arg, .members);
        },

        else => @panic(@tagName(tags[node])), // primary
    };
}

fn checkValuesForName(ast: std.zig.Ast, search_name: string, nodes: []const NodeIndex, writer: std.fs.File.Writer, file_name: string, owner: NodeIndex) CheckError!bool {
    for (nodes) |item| {
        if (try checkValueForName(ast, search_name, item, writer, file_name, owner)) return true;
    }
    return false;
}

fn checkAstValuesForName(ast: std.zig.Ast, search_name: string, writer: std.fs.File.Writer, file_name: string, owner: NodeIndex, inner: anytype, comptime fields: []const std.meta.FieldEnum(@TypeOf(inner.ast))) CheckError!bool {
    inline for (fields) |item| {
        if (try checkValueForName(ast, search_name, @field(inner.ast, @tagName(item)), writer, file_name, owner)) return true;
    }
    return false;
}

fn checkAstParentOpForName(ast: std.zig.Ast, search_name: string, writer: std.fs.File.Writer, file_name: string, owner: NodeIndex, inner: anytype, comptime parent: std.meta.FieldEnum(@TypeOf(inner.ast)), comptime childs: @TypeOf(parent)) CheckError!bool {
    if (try checkValueForName(ast, search_name, @field(inner.ast, @tagName(parent)), writer, file_name, owner)) return true;
    if (try checkValuesForName(ast, search_name, @field(inner.ast, @tagName(childs)), writer, file_name, owner)) return true;
    return false;
}
