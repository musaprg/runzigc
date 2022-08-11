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

pub const PivotRootError = error{
    Busy,
    Invalid,
    OperationNotPermitted,
    NotDir,
} || os.UnexpectedError;

fn pivot_root(new_root: []const u8, put_old: []const u8) PivotRootError!void {
    const result = switch (native_arch) {
        else => linux.syscall2(.pivot_root, @ptrToInt(new_root.ptr), @ptrToInt(put_old.ptr)),
    };
    return switch (os.errno(result)) {
        .SUCCESS => {},
        .PERM => error.OperationNotPermitted,
        .BUSY => error.Busy,
        .NOTDIR => error.NotDir,
        .INVAL => error.Invalid,
        else => |err| return os.unexpectedErrno(err),
    };
}

pub const SetHostNameError = error{OperationNotPermitted} || os.UnexpectedError;

// TODO(musaprg): dirty hack, fix it
fn sethostname(hostname: []const u8) SetHostNameError!void {
    const result = switch (native_arch) {
        else => linux.syscall2(.sethostname, @ptrToInt(hostname.ptr), hostname.len),
    };
    return switch (os.errno(result)) {
        .SUCCESS => {},
        .PERM => error.OperationNotPermitted,
        else => |err| return os.unexpectedErrno(err),
    };
}
