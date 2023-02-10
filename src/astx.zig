const std = @import("std");
const Ast = std.zig.Ast;
const NodeIndex = Ast.Node.Index;
const full = Ast.full;

pub fn varDecl(ast: Ast, node: NodeIndex) full.VarDecl {
    const tags = ast.nodes.items(.tag);
    return switch (tags[node]) {
        .simple_var_decl => ast.simpleVarDecl(node),
        .local_var_decl => ast.localVarDecl(node),
        .aligned_var_decl => ast.alignedVarDecl(node),
        .global_var_decl => ast.globalVarDecl(node),
        else => unreachable,
    };
}

pub fn slice(ast: Ast, node: NodeIndex) full.Slice {
    const tags = ast.nodes.items(.tag);
    return switch (tags[node]) {
        .slice => ast.slice(node),
        .slice_sentinel => ast.sliceSentinel(node),
        else => unreachable,
    };
}

pub fn ptrType(ast: Ast, node: NodeIndex) full.PtrType {
    const tags = ast.nodes.items(.tag);
    return switch (tags[node]) {
        .ptr_type => ast.ptrType(node),
        .ptr_type_sentinel => ast.ptrTypeSentinel(node),
        .ptr_type_bit_range => ast.ptrTypeBitRange(node),
        else => unreachable,
    };
}
