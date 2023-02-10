// zig fmt: off
const std = @import("std");
const builtin = @import("builtin");
const ModuleDependency = std.build.ModuleDependency;
const string = []const u8;

pub const GitExactStep = struct {
    step: std.build.Step,
    builder: *std.build.Builder,
    url: string,
    commit: string,

        pub fn create(b: *std.build.Builder, url: string, commit: string) *GitExactStep {
            var result = b.allocator.create(GitExactStep) catch @panic("memory");
            result.* = GitExactStep{
                .step = std.build.Step.init(.custom, b.fmt("git clone {s} @ {s}", .{ url, commit }), b.allocator, make),
                .builder = b,
                .url = url,
                .commit = commit,
            };

            var urlpath = url;
            urlpath = trimPrefix(u8, urlpath, "https://");
            urlpath = trimPrefix(u8, urlpath, "git://");
            const repopath = b.fmt("{s}/zigmod/deps/git/{s}/{s}", .{ b.cache_root, urlpath, commit });
            flip(std.fs.cwd().access(repopath, .{})) catch return result;

            var clonestep = std.build.RunStep.create(b, "clone");
            clonestep.addArgs(&.{ "git", "clone", "-q", "--progress", url, repopath });
            result.step.dependOn(&clonestep.step);

            var checkoutstep = std.build.RunStep.create(b, "checkout");
            checkoutstep.addArgs(&.{ "git", "-C", repopath, "checkout", "-q", commit });
            result.step.dependOn(&checkoutstep.step);

            return result;
        }

        fn make(step: *std.build.Step) !void {
            _ = step;
        }
};

pub fn fetch(exe: *std.build.LibExeObjStep) void {
    const b = exe.builder;
    inline for (comptime std.meta.declarations(package_data)) |decl| {
        const path = &@field(package_data, decl.name).entry;
        const root = if (@field(package_data, decl.name).store) |_| b.cache_root else ".";
        if (path.* != null) path.* = b.fmt("{s}/zigmod/deps{s}", .{ root, path.*.? });
    }
    exe.step.dependOn(&GitExactStep.create(b, "https://github.com/nektro/zig-extras", "b45c99e2e747e3bb8df5e1051078cacb1470a430").step);
    exe.step.dependOn(&GitExactStep.create(b, "https://github.com/nektro/zig-flag", "07ea6a3daa950f7bbd8bbd60c0cc2251806fde95").step);
    exe.step.dependOn(&GitExactStep.create(b, "https://github.com/nektro/zig-range", "4b2f12808aa09be4b27a163efc424dd4e0415992").step);
}

fn trimPrefix(comptime T: type, haystack: []const T, needle: []const T) []const T {
    if (std.mem.startsWith(T, haystack, needle)) {
        return haystack[needle.len .. haystack.len];
    }
    return haystack;
}

fn flip(foo: anytype) !void {
    _ = foo catch return;
    return error.ExpectedError;
}

pub fn addAllTo(exe: *std.build.LibExeObjStep) void {
    checkMinZig(builtin.zig_version, exe);
    fetch(exe);
    const b = exe.builder;
    @setEvalBranchQuota(1_000_000);
    for (packages) |pkg| {
        const moddep = pkg.zp(b);
        exe.addModule(moddep.name, moddep.module);
    }
    var llc = false;
    var vcpkg = false;
    inline for (comptime std.meta.declarations(package_data)) |decl| {
        const pkg = @as(Package, @field(package_data, decl.name));
        const root = if (pkg.store) |st| b.fmt("{s}/zigmod/deps/{s}", .{ b.cache_root, st }) else ".";
        for (pkg.system_libs) |item| {
            exe.linkSystemLibrary(item);
            llc = true;
        }
        for (pkg.frameworks) |item| {
            if (!builtin.target.isDarwin()) @panic(exe.builder.fmt("a dependency is attempting to link to the framework {s}, which is only possible under Darwin", .{item}));
            exe.linkFramework(item);
            llc = true;
        }
        for (pkg.c_include_dirs) |item| {
            exe.addIncludePath(b.fmt("{s}/{s}", .{ root, item }));
            llc = true;
        }
        for (pkg.c_source_files) |item| {
            exe.addCSourceFile(b.fmt("{s}/{s}", .{ root, item }), pkg.c_source_flags);
            llc = true;
        }
        vcpkg = vcpkg or pkg.vcpkg;
    }
    if (llc) exe.linkLibC();
    if (builtin.os.tag == .windows and vcpkg) exe.addVcpkgPaths(.static) catch |err| @panic(@errorName(err));
}

pub const Package = struct {
    name: string = "",
    entry: ?string = null,
    store: ?string = null,
    deps: []const *Package = &.{},
    c_include_dirs: []const string = &.{},
    c_source_files: []const string = &.{},
    c_source_flags: []const string = &.{},
    system_libs: []const string = &.{},
    frameworks: []const string = &.{},
    vcpkg: bool = false,

    pub fn zp(self: *const Package, b: *std.build.Builder) ModuleDependency {
        var temp: [100]ModuleDependency = undefined;
        for (self.deps) |item, i| {
            temp[i] = item.zp(b);
        }
        return .{
            .name = self.name,
            .module = b.createModule(.{
                .source_file = .{ .path = self.entry.? },
                .dependencies = b.allocator.dupe(ModuleDependency, temp[0..self.deps.len]) catch @panic("oom"),
            }),
        };
    }
};

fn checkMinZig(current: std.SemanticVersion, exe: *std.build.LibExeObjStep) void {
    const min = std.SemanticVersion.parse("0.11.0-dev.1570+693b12f8e") catch return;
    if (current.order(min).compare(.lt)) @panic(exe.builder.fmt("Your Zig version v{} does not meet the minimum build requirement of v{}", .{current, min}));
}

pub const package_data = struct {
    pub var _8dglro8ootvr = Package{
    };
    pub var _tnj3qf44tpeq = Package{
        .store = "/git/github.com/nektro/zig-range/4b2f12808aa09be4b27a163efc424dd4e0415992",
        .name = "range",
        .entry = "/git/github.com/nektro/zig-range/4b2f12808aa09be4b27a163efc424dd4e0415992/src/lib.zig",
    };
    pub var _f7dubzb7cyqe = Package{
        .store = "/git/github.com/nektro/zig-extras/b45c99e2e747e3bb8df5e1051078cacb1470a430",
        .name = "extras",
        .entry = "/git/github.com/nektro/zig-extras/b45c99e2e747e3bb8df5e1051078cacb1470a430/src/lib.zig",
        .deps = &[_]*Package{ &_tnj3qf44tpeq },
    };
    pub var _pm68dn67ppvl = Package{
        .store = "/git/github.com/nektro/zig-flag/07ea6a3daa950f7bbd8bbd60c0cc2251806fde95",
        .name = "flag",
        .entry = "/git/github.com/nektro/zig-flag/07ea6a3daa950f7bbd8bbd60c0cc2251806fde95/src/lib.zig",
        .deps = &[_]*Package{ &_f7dubzb7cyqe, &_tnj3qf44tpeq },
    };
    pub var _root = Package{
    };
};

pub const packages = [_]*const Package{
    &package_data._tnj3qf44tpeq,
    &package_data._pm68dn67ppvl,
};

pub const pkgs = struct {
    pub const range = &package_data._tnj3qf44tpeq;
    pub const flag = &package_data._pm68dn67ppvl;
};

pub const imports = struct {
};
