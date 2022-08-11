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

pub const LinuxKernelErrorBase = error{ OperationNotPermitted, NoSuchFileOrDirectory, NoSuchProcess, InterruptedSystemCall, IOError, NoSuchDeviceOrAddress, ArgumentListTooLong, ExecFormatError, BadFileNumber, NoChildProcesses, TryAgain, OutOfMemory, PermissionDenied, BadAddress, BlockDeviceRequired, DeviceOrResourceBusy, FileExists, CrossDeviceLink, NoSuchDevice, NotADirectory, IsADirectory, InvalidArgument, FileTableOverflow, TooManyOpenFiles, NotATypewriter, TextFileBusy, FileTooLarge, NoSpaceLeftOnDevice, IllegalSeek, ReadOnlyFileSystem, TooManyLinks, BrokenPipe, MathArgumentOutOfDomainOfFunc, MathResultNotRepresentable };
pub const LinuxKernelError = LinuxKernelErrorBase || os.UnexpectedError;

pub fn valOrErr(comptime T: type, val: T, errno: usize) LinuxKernelError!T {
    return switch (os.errno(errno)) {
        .SUCCESS => val,
        .PERM => error.OperationNotPermitted,
        .NOENT => error.NoSuchFileOrDirectory,
        .SRCH => error.NoSuchProcess,
        .INTR => error.InterruptedSystemCall,
        .IO => error.IOError,
        .NXIO => error.NoSuchDeviceOrAddress,
        .@"2BIG" => error.ArgumentListTooLong,
        .NOEXEC => error.ExecFormatError,
        .BADF => error.BadFileNumber,
        .CHILD => error.NoChildProcesses,
        .AGAIN => error.TryAgain,
        .NOMEM => error.OutOfMemory,
        .ACCES => error.PermissionDenied,
        .FAULT => error.BadAddress,
        .BUSY => error.DeviceOrResourceBusy,
        .EXIST => error.FileExists,
        .XDEV => error.CrossDeviceLink,
        .NODEV => error.NoSuchDevice,
        .NOTDIR => error.NotADirectory,
        .ISDIR => error.IsADirectory,
        .INVAL => error.InvalidArgument,
        .NFILE => error.FileTableOverflow,
        .MFILE => error.TooManyOpenFiles,
        .NOTTY => error.NotATypewriter,
        .TXTBSY => error.TextFileBusy,
        .FBIG => error.FileTooLarge,
        .NOSPC => error.NoSpaceLeftOnDevice,
        .SPIPE => error.IllegalSeek,
        .ROFS => error.ReadOnlyFileSystem,
        .MLINK => error.TooManyLinks,
        .PIPE => error.BrokenPipe,
        .DOM => error.MathArgumentOutOfDomainOfFunc,
        .RANGE => error.MathResultNotRepresentable,
        else => |e| return os.unexpectedErrno(e),
    };
}

pub const MountFlags = enum(u32) {
    MS_NOSUID = 0x2,
    MS_NODEV = 0x4,
    MS_NOEXEC = 0x8,
    MS_BIND = 0x1000,
    MS_REC = 0x4000,
    MS_PRIVATE = 0x40000,
    MS_SLAVE = 0x80000,
};

pub const MountError = LinuxKernelError;

pub const UmountFlags = enum(u32) {
    MNT_FORCE = 0x1,
    MNT_DETACH = 0x2,
    MNT_EXPIRE = 0x4,
};

pub const UmountError = LinuxKernelError;

pub fn mount(special: [*:0]const u8, dir: [*:0]const u8, fstype: [*:0]const u8, flags: u32, data: usize) MountError!void {
    const result = linux.syscall5(.mount, @ptrToInt(special), @ptrToInt(dir), @ptrToInt(fstype), flags, data);
    return valOrErr(void, {}, result);
}

pub fn umount(special: [*:0]const u8, flags: ?u32) UmountError!void {
    var result: usize = undefined;
    if (flags) |unwrapped_flags| {
        result = linux.syscall2(.umount2, @ptrToInt(special), unwrapped_flags);
    } else {
        result = linux.syscall2(.umount2, @ptrToInt(special), 0);
    }
    return valOrErr(void, {}, result);
}

pub const PivotRootError = LinuxKernelError;

pub fn pivot_root(new_root: []const u8, put_old: []const u8) PivotRootError!void {
    const result = switch (native_arch) {
        else => linux.syscall2(.pivot_root, @ptrToInt(new_root.ptr), @ptrToInt(put_old.ptr)),
    };
    return valOrErr(void, {}, result);
}

pub const SetHostNameError = LinuxKernelError;

// TODO(musaprg): dirty hack, fix it
pub fn sethostname(hostname: []const u8) SetHostNameError!void {
    const result = switch (native_arch) {
        else => linux.syscall2(.sethostname, @ptrToInt(hostname.ptr), hostname.len),
    };
    return valOrErr(void, {}, result);
}
