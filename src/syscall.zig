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

pub const MountFlags = enum(u32) {
    MS_NOSUID = 0x2,
    MS_NODEV = 0x4,
    MS_NOEXEC = 0x8,
    MS_BIND = 0x1000,
    MS_REC = 0x4000,
    MS_PRIVATE = 0x40000,
    MS_SLAVE = 0x80000,
};

pub const MountError = error{} || os.UnexpectedError;

pub const UmountFlags = enum(u32) {
    MNT_FORCE = 0x1,
    MNT_DETACH = 0x2,
    MNT_EXPIRE = 0x4,
};

pub const UmountError = error{} || os.UnexpectedError;

pub fn mount(special: [*:0]const u8, dir: [*:0]const u8, fstype: [*:0]const u8, flags: u32, data: usize) MountError!usize {
    const result = linux.syscall5(.mount, @ptrToInt(special), @ptrToInt(dir), @ptrToInt(fstype), flags, data);
    return switch (os.errno(result)) {
        .SUCCESS => {},
        else => |err| return os.unexpectedErrno(err),
    };
}

pub fn umount(special: [*:0]const u8, flags: ?u32) UmountError!usize {
    const result = if (flags) |unwrapped_flags| {
        return linux.syscall2(.umount2, @ptrToInt(special), unwrapped_flags);
    } else {
        return linux.syscall2(.umount2, @ptrToInt(special), 0);
    };
    return switch (os.errno(result)) {
        .SUCCESS => {},
        else => |err| return os.unexpectedErrno(err),
    };
}

pub const PivotRootError = error{
    Busy,
    Invalid,
    OperationNotPermitted,
    NotDir,
} || os.UnexpectedError;

pub fn pivot_root(new_root: []const u8, put_old: []const u8) PivotRootError!void {
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
pub fn sethostname(hostname: []const u8) SetHostNameError!void {
    const result = switch (native_arch) {
        else => linux.syscall2(.sethostname, @ptrToInt(hostname.ptr), hostname.len),
    };
    return switch (os.errno(result)) {
        .SUCCESS => {},
        .PERM => error.OperationNotPermitted,
        else => |err| return os.unexpectedErrno(err),
    };
}
