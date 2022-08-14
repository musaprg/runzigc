const std = @import("std");
const builtin = @import("builtin");
const os = std.os;
const fs = std.fs;
const fmt = std.fmt;
const mem = std.mem;
const heap = std.heap;
const linux = os.linux;
const log = std.log;
const debug = std.debug;
const native_arch = builtin.cpu.arch;
const testing = std.testing;

const syscall = @import("syscall.zig");

// TODO(musaprg): refactor this dirty line
pub const MkdirAllError = os.MakeDirError || syscall.LinuxKernelError;

pub fn mkdirAll(path: []const u8, mode: u32) MkdirAllError!void {
    // Fast path learned from Go source
    //  https://cs.opensource.google/go/go/+/refs/tags/go1.19:src/os/path.go;l=18
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
