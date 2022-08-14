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

pub fn valOrErr(val: anytype, errno: usize) LinuxKernelError!@TypeOf(val) {
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
    return valOrErr({}, result);
}

pub fn umount(special: [*:0]const u8, flags: ?u32) UmountError!void {
    var result: usize = undefined;
    if (flags) |unwrapped_flags| {
        result = linux.syscall2(.umount2, @ptrToInt(special), unwrapped_flags);
    } else {
        result = linux.syscall2(.umount2, @ptrToInt(special), 0);
    }
    return valOrErr({}, result);
}

pub const PivotRootError = LinuxKernelError;

pub fn pivot_root(new_root: []const u8, put_old: []const u8) PivotRootError!void {
    const result = switch (native_arch) {
        else => linux.syscall2(.pivot_root, @ptrToInt(new_root.ptr), @ptrToInt(put_old.ptr)),
    };
    return valOrErr({}, result);
}

pub const SetHostNameError = LinuxKernelError;

// TODO(musaprg): dirty hack, fix it
pub fn sethostname(hostname: []const u8) SetHostNameError!void {
    const result = switch (native_arch) {
        else => linux.syscall2(.sethostname, @ptrToInt(hostname.ptr), hostname.len),
    };
    return valOrErr({}, result);
}

pub const SetsidError = LinuxKernelError;

pub fn setsid() SetsidError!void {
    const result = switch (native_arch) {
        else => linux.syscall0(.setsid),
    };
    return valOrErr({}, result);
}

pub const StatError = LinuxKernelError;

pub const StatMode = enum(u32) {
    S_IFMT = 0o170000,
    S_IFSOCK = 0o140000,
    S_IFLNK = 0o120000,
    S_IFREG = 0o100000,
    S_IFBLK = 0o060000,
    S_IFDIR = 0o040000,
    S_IFCHR = 0o020000,
    S_IFIFO = 0o010000,
    S_ISUID = 0o004000,
    S_ISGID = 0o002000,
    S_ISVTX = 0o001000,
    S_IRWXU = 0o000700,
    S_IRUSR = 0o000400,
    S_IWUSR = 0o000200,
    S_IXUSR = 0o000100,
    S_IRWXG = 0o000070,
    S_IRGRP = 0o000040,
    S_IWGRP = 0o000020,
    S_IXGRP = 0o000010,
    S_IRWXO = 0o000007,
    S_IROTH = 0o000004,
    S_IWOTH = 0o000002,
    S_IXOTH = 0o000001,
};

pub fn stat(path: []const u8) StatError!linux.Stat {
    var stat_result: linux.Stat = undefined;

    // https://cs.opensource.google/go/go/+/refs/tags/go1.19:src/syscall/syscall_linux_amd64.go;drc=ea9c3fd42d94182ce6f87104b68a51ea92f1a571;l=58
    const err = fstatat(linux.AT.FDCWD, path, &stat_result, linux.AT.SYMLINK_NOFOLLOW);

    return valOrErr(stat_result, err);
}

fn fstatat(fd: os.fd_t, path: []const u8, stat_info: *linux.Stat, flags: u32) usize {
    // https://cs.opensource.google/go/go/+/refs/tags/go1.19:src/syscall/zsyscall_linux_arm64.go
    return switch (native_arch) {
        .x86_64 => linux.syscall6(.fstatat, @ptrToInt(&fd), @ptrToInt(path.ptr), @ptrToInt(stat_info), flags, 0, 0),
        .aarch64 => linux.syscall6(.fstatat, @ptrToInt(&fd), @ptrToInt(path.ptr), @ptrToInt(stat_info), flags, 0, 0),
        .i386, .arm => linux.syscall6(.fstatat64, @ptrToInt(&fd), @ptrToInt(path.ptr), @ptrToInt(stat_info), flags, 0, 0),
        else => @compileError("Unsupported architecture"),
    };
}

pub fn isDir(stat_info: linux.Stat) bool {
    return stat_info.mode & @enumToInt(StatMode.S_IFMT) == @enumToInt(StatMode.S_IFDIR);
}
