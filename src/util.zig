const std = @import("std");
const builtin = @import("builtin");
const os = std.os;
const fs = std.fs;
const fmt = std.fmt;
const mem = std.mem;
const Allocator = mem.Allocator;
const heap = std.heap;
const linux = os.linux;
const log = std.log;
const debug = std.debug;
const rand = std.rand;
const native_arch = builtin.cpu.arch;
const testing = std.testing;

const syscall = @import("syscall.zig");

// TODO(musaprg): refactor this dirty line
pub const MkdirAllError = os.MakeDirError || syscall.LinuxKernelError;

pub fn mkdirAll(path: []const u8, mode: u32) MkdirAllError!void {
    // Fast path learned from Go source
    //  https://cs.opensource.google/go/go/+/refs/tags/go1.19:src/os/path.go;l=18
    // TODO(musaprg): use os.fstatat(os.AT.FDCWD, path, 0) instead
    if (syscall.stat(path)) |s| {
        if (syscall.isDir(s)) {
            log.debug("mkdirAll: path already exists: {s}", .{path});
            return;
        }
        return error.PathAlreadyExists;
    } else |err| switch (err) {
        error.FileExists => {},
        error.NoSuchFileOrDirectory => {
            if (fs.path.dirname(path)) |parent| {
                try mkdirAll(parent, mode);
            }
            os.mkdir(path, mode) catch |e| switch (e) {
                error.PathAlreadyExists => {},
                else => return e,
            };
        },
        error.PermissionDenied => {
            return error.AccessDenied;
        },
        else => |e| return e,
    }
}

test "make multiple directories" {
    const dir_parent = "/tmp/zig-test-mkdirs";
    // TODO(musaprg): consider using path join function
    const dir_child = dir_parent ++ "/child";
    const mode = 0o755;
    try mkdirAll(dir_child, mode);
    defer {
        os.rmdir(dir_child) catch {};
        os.rmdir(dir_parent) catch {};
    }
    {
        const r = os.access(dir_parent, os.F_OK) catch |err| return err;
        try testing.expect(r == {});
    }
    {
        const r = os.access(dir_parent, os.R_OK) catch |err| return err;
        try testing.expect(r == {});
    }
    {
        const r = os.access(dir_parent, os.W_OK) catch |err| return err;
        try testing.expect(r == {});
    }
    {
        const r = os.access(dir_parent, os.X_OK) catch |err| return err;
        try testing.expect(r == {});
    }
    {
        const r = os.access(dir_child, os.F_OK) catch |err| return err;
        try testing.expect(r == {});
    }
    {
        const r = os.access(dir_child, os.R_OK) catch |err| return err;
        try testing.expect(r == {});
    }
    {
        const r = os.access(dir_child, os.W_OK) catch |err| return err;
        try testing.expect(r == {});
    }
    {
        const r = os.access(dir_child, os.X_OK) catch |err| return err;
        try testing.expect(r == {});
    }
}

pub const MkdirTempError = MkdirAllError || RandomStringError;

/// Create temporary directory with random name to the specified path
pub fn mkdirTemp(allocator: Allocator, dir: []const u8) MkdirTempError![]const u8 {
    const now = std.time.timestamp();

    var parent_path = dir;
    if (dir.len == 0) {
        // TODO(musaprg): avoid hard-coding
        parent_path = "/tmp";
    }
    var prng = rand.DefaultPrng.init(@intCast(u64, now));
    const random = prng.random();
    const max_retry = 10;
    const length = 10;
    for ([_]u0{0} ** max_retry) |_| {
        const file_name = try randomString(allocator, random, length);
        log.debug("mkdirTemp: try to create '{s}'", .{file_name});
        const path = try fs.path.join(allocator, &[_][]const u8{ parent_path, file_name });
        mkdirAll(path, 0o0700) catch |err| switch (err) {
            error.PathAlreadyExists => continue,
            else => return err,
        };
        return path;
    }
    return error.PathAlreadyExists;
}

test "mkdirTemp" {
    var arena = std.heap.ArenaAllocator.init(testing.allocator);
    defer arena.deinit();
    var allocator = arena.allocator();
    const path = try mkdirTemp(allocator, "");
    defer {
        fs.deleteDirAbsolute(path) catch {};
    }
    const s = try syscall.stat(path);
    try testing.expect(syscall.isDir(s));
}

pub const CreateTempFileError = fs.File.OpenError || RandomStringError;

/// Create temporary file with random name in the specified dir
pub fn createTempFile(allocator: Allocator, dir: []const u8) CreateTempFileError![]const u8 {
    const now = std.time.timestamp();

    var parent_path = dir;
    if (dir.len == 0) {
        // TODO(musaprg): avoid hard-coding
        parent_path = "/tmp";
    }
    var prng = rand.DefaultPrng.init(@intCast(u64, now));
    const random = prng.random();
    const max_retry = 10;
    const length = 10;
    for ([_]u0{0} ** max_retry) |_| {
        const file_name = try randomString(allocator, random, length);
        log.debug("createTempFile: try to create '{s}'", .{file_name});
        const path = try fs.path.join(allocator, &[_][]const u8{ parent_path, file_name });
        const file = fs.createFileAbsolute(path, .{}) catch |err| switch (err) {
            error.PathAlreadyExists => continue,
            else => return err,
        };
        defer file.close();
        return path;
    }
    return error.PathAlreadyExists;
}

test "createTempFile" {
    var arena = std.heap.ArenaAllocator.init(testing.allocator);
    defer arena.deinit();
    var allocator = arena.allocator();
    const path = try createTempFile(allocator, "");
    defer {
        fs.deleteFileAbsolute(path) catch {};
    }
    const s = try syscall.stat(path);
    try testing.expect(!syscall.isDir(s));
}

pub const RandomStringError = mem.Allocator.Error;

/// Generate random string
pub fn randomString(allocator: Allocator, random: rand.Random, n: usize) RandomStringError![]const u8 {
    const chars = "ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789";

    var items = try allocator.alloc(u8, n);
    for (items) |*item| {
        const random_pos = random.intRangeLessThan(usize, 0, chars.len);
        item.* = chars[random_pos];
    }

    return items;
}

test "randomString" {
    var arena = std.heap.ArenaAllocator.init(testing.allocator);
    defer arena.deinit();
    var allocator = arena.allocator();
    var prng = rand.DefaultPrng.init(0);
    const random = prng.random();
    _ = try randomString(allocator, random, 10);
}
