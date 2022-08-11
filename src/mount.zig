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
    const result = if (flags) |flags| {
        return linux.syscall2(.umount2, @ptrToInt(special), flags);
    } else {
        return linux.syscall2(.umount2, @ptrToInt(special), 0);
    };
    return switch (os.errno(result)) {
        .SUCCESS => {},
        else => |err| return os.unexpectedErrno(err),
    };
}
