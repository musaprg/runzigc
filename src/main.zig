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

const Command = zig_arg.Command;
const flag = zig_arg.flag;

const native_arch = builtin.cpu.arch;

const zig_arg = @import("zig-arg");

const sync_t = enum(c_int) {
    SYNC_USERMAP_PLS = 0x40,
    SYNC_USERMAP_ACK = 0x41,
};

const MountFlags = enum(u32) {
    MS_NOSUID = 0x2,
    MS_NODEV = 0x4,
    MS_NOEXEC = 0x8,
    MS_BIND = 0x1000,
    MS_REC = 0x4000,
    MS_PRIVATE = 0x40000,
    MS_SLAVE = 0x80000,
};

const UmountFlags = enum(u32) {
    MNT_FORCE = 0x1,
    MNT_DETACH = 0x2,
    MNT_EXPIRE = 0x4,
};

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

// set hostname and exec passed command
fn init(allocator: mem.Allocator) !void {
    _ = allocator;

    const hostname = "test";
    sethostname(hostname) catch |err| {
        log.debug("sethostname failed\n", .{});
        return err;
    };

    log.debug("GRANDCHILD: current uid: {}\n", .{linux.getuid()});
    log.debug("GRANDCHILD: current gid: {}\n", .{linux.getgid()});

    var status = linux.mount("proc", "/root/rootfs/proc", "proc", @enumToInt(MountFlags.MS_NOEXEC) | @enumToInt(MountFlags.MS_NOSUID) | @enumToInt(MountFlags.MS_NODEV), @ptrToInt(""));
    switch (os.errno(status)) {
        .SUCCESS => {},
        .ACCES => return error.AccessDenied,
        .PERM => return error.OperationNotPermitted,
        .BUSY => return error.Busy,
        .NOTDIR => return error.NotDir,
        .INVAL => return error.Invalid,
        else => |err| {
            // TODO(musaprg): define error type
            return os.unexpectedErrno(err);
        },
    }

    status = linux.chdir("/root");
    switch (os.errno(status)) {
        .SUCCESS => {},
        .ACCES => return error.AccessDenied,
        .PERM => return error.OperationNotPermitted,
        .BUSY => return error.Busy,
        .NOTDIR => return error.NotDir,
        .INVAL => return error.Invalid,
        else => |err| {
            // TODO(musaprg): define error type
            return os.unexpectedErrno(err);
        },
    }

    status = linux.mount("rootfs", "/root/rootfs", "", @enumToInt(MountFlags.MS_BIND) | @enumToInt(MountFlags.MS_REC), @ptrToInt(""));
    switch (os.errno(status)) {
        .SUCCESS => {},
        .ACCES => return error.AccessDenied,
        .PERM => return error.OperationNotPermitted,
        .BUSY => return error.Busy,
        .NOTDIR => return error.NotDir,
        .INVAL => return error.Invalid,
        else => |err| {
            // TODO(musaprg): define error type
            return os.unexpectedErrno(err);
        },
    }

    fs.makeDirAbsolute("/root/rootfs/oldrootfs") catch |err| {
        log.debug("makeDirAbsolute failed\n", .{});
        return err;
    };

    // TODO(musaprg): fix here, currently we need to create /root/pivotroot/proc before executing this
    pivot_root("rootfs", "/root/rootfs/oldrootfs") catch |err| {
        log.debug("pivot_root failed\n", .{});
        return err;
    };

    status = linux.umount2("/oldrootfs", @enumToInt(UmountFlags.MNT_DETACH));
    switch (os.errno(status)) {
        .SUCCESS => {},
        .ACCES => return error.AccessDenied,
        .PERM => return error.OperationNotPermitted,
        .BUSY => return error.Busy,
        .NOTDIR => return error.NotDir,
        .INVAL => return error.Invalid,
        else => |err| {
            // TODO(musaprg): define error type
            return os.unexpectedErrno(err);
        },
    }

    fs.deleteDirAbsolute("/oldrootfs") catch |err| {
        log.debug("deleteDirAbsolute failed\n", .{});
        return err;
    };

    status = linux.chdir("/");
    switch (os.errno(status)) {
        .SUCCESS => {},
        .ACCES => return error.AccessDenied,
        .PERM => return error.OperationNotPermitted,
        .BUSY => return error.Busy,
        .NOTDIR => return error.NotDir,
        .INVAL => return error.Invalid,
        else => |err| {
            // TODO(musaprg): define error type
            return os.unexpectedErrno(err);
        },
    }

    const child_args = [_:null]?[*:0]const u8{ "/bin/sh", null };
    const envp = [_:null]?[*:0]const u8{null};
    return os.execveZ("/bin/sh", &child_args, &envp);
}

// fork and unshare and exec init
fn run(allocator: mem.Allocator) !void {
    _ = allocator;

    var syncsocket: [2]os.fd_t = undefined;
    if (linux.socketpair(linux.AF.UNIX, linux.SOCK.STREAM, 0, syncsocket) < 0) {
        log.debug("socketpair failed\n", .{});
        os.exit(1);
    }

    var cpid = os.fork() catch {
        log.debug("fork failed\n", .{});
        os.exit(1);
    };

    if (cpid == 0) { // child
        var syncfd = syncsocket[0];

        const flags = linux.CLONE.NEWIPC | linux.CLONE.NEWNET | linux.CLONE.NEWUSER | linux.CLONE.NEWUTS | linux.CLONE.NEWPID | linux.CLONE.NEWNS;
        if (linux.unshare(flags) == -1) {
            log.debug("unshare failed\n", .{});
            os.exit(1);
        }

        var synctag: []const u8 = &[_]u8{@intCast(u8, @enumToInt(sync_t.SYNC_USERMAP_PLS))};
        if (os.write(syncfd, synctag)) |size| {
            if (size != 1) {
                return error.Unexpected;
            }
        } else |err| {
            return err;
        }
        var buf: [1]u8 = undefined;
        if (os.read(syncfd, &buf)) |size| {
            if (size != 1) {
                return error.Unexpected;
            }
        } else |err| {
            return err;
        }
        switch (@intToEnum(sync_t, @intCast(c_int, buf[0]))) {
            .SYNC_USERMAP_ACK => {},
            else => unreachable,
        }

        if (linux.setresuid(0, 0, 0) == -1) {
            log.debug("setresuid failed\n", .{});
            return error.Unexpected;
        }
        if (linux.setresgid(0, 0, 0) == -1) {
            log.debug("setresgid failed\n", .{});
            return error.Unexpected;
        }

        var gcpid = os.fork() catch {
            log.debug("CHILD: fork failed\n", .{});
            os.exit(1);
        };

        if (gcpid == 0) { // grandchild
            const child_args = [_:null]?[*:0]const u8{ "/proc/self/exe", "init", null };
            const envp = [_:null]?[*:0]const u8{null};
            return os.execveZ("/proc/self/exe", &child_args, &envp);
        } else { // child
            log.debug("CHILD: grandchild pid: {}\n", .{gcpid});
            log.debug("CHILD: waiting for grandchild\n", .{});
            var result = os.waitpid(gcpid, 0); // i'm not sure how to handle WaitPidResult.status with zig, there's no macro like WIFEXITED
            _ = result.status;
            os.exit(0);
        }
    } else { // parent
        var syncfd = syncsocket[1];

        log.debug("PARENT: parent pid: {}\n", .{linux.getpid()});
        log.debug("PARENT: child pid: {}\n", .{cpid});

        var buf: [1]u8 = undefined;
        if (os.read(syncfd, &buf)) |size| {
            log.debug("PARENT: read {} bytes\n", .{size});
            if (size != 1) {
                return error.Unexpected;
            }
        } else |err| {
            return err;
        }
        switch (@intToEnum(sync_t, @intCast(c_int, buf[0]))) {
            .SYNC_USERMAP_PLS => log.debug("PARENT: received SYNC_USERMAP_PLS from child\n", .{}),
            else => unreachable,
        }

        // https://man7.org/linux/man-pages/man7/user_namespaces.7.html#:~:text=User%20and%20group%20ID%20mappings%3A%20uid_map%20and%20gid_map
        // uid_map and gid_map are only writable from parent process.
        var uid = linux.getuid();
        //const uid = 1000;
        var gid = linux.getgid();
        //const gid = 1000;

        log.debug("PARENT: uid: {}, gid: {}\n", .{ uid, gid });

        var string_pid = try fmt.allocPrint(allocator, "{}", .{cpid});
        defer allocator.free(string_pid);
        var uid_map_path = try fs.path.join(allocator, &[_][]const u8{ "/proc", string_pid, "uid_map" });
        defer allocator.free(uid_map_path);
        var gid_map_path = try fs.path.join(allocator, &[_][]const u8{ "/proc", string_pid, "gid_map" });
        defer allocator.free(gid_map_path);

        log.debug("PARENT: uid_map_path: {s}\n", .{uid_map_path});
        log.debug("PARENT: gid_map_path: {s}\n", .{gid_map_path});

        var uid_map = try fs.openFileAbsolute(uid_map_path, .{ .read = true, .write = true });
        defer uid_map.close();
        var gid_map = try fs.openFileAbsolute(gid_map_path, .{ .read = true, .write = true });
        defer gid_map.close();

        var uid_map_contents = try fmt.allocPrint(allocator, "0 {} 1\n", .{uid});
        defer allocator.free(uid_map_contents);
        var gid_map_contents = try fmt.allocPrint(allocator, "0 {} 1\n", .{gid});
        defer allocator.free(gid_map_contents);

        try uid_map.writer().writeAll(uid_map_contents);
        try gid_map.writer().writeAll(gid_map_contents);

        var synctag: []const u8 = &[_]u8{@intCast(u8, @enumToInt(sync_t.SYNC_USERMAP_ACK))};
        log.debug("PARENT: sending SYNC_USERMAP_ACK to child\n", .{});
        if (os.write(syncfd, synctag)) |size| {
            log.debug("PARENT: wrote {} bytes\n", .{size});
            if (size != 1) {
                return error.Unexpected;
            }
        } else |err| {
            return err;
        }

        log.debug("PARENT: wait for child\n", .{});
        var result = os.waitpid(cpid, 0); // i'm not sure how to handle WaitPidResult.status with zig, there's no macro like WIFEXITED
        _ = result.status;

        log.debug("parent exited\n", .{});
    }
}

// Use fork and unshare to create a new process with a new PID
// youki: https://github.com/containers/youki/blob/619ae7d1eccbd82fd116465ed25ef410ace2a2a1/crates/libcontainer/src/process/container_main_process.rs#L206-L240
pub fn main() anyerror!void {
    var arena = heap.ArenaAllocator.init(std.heap.page_allocator);
    defer arena.deinit();
    const allocator = arena.allocator();

    // TODO(musaprg): automatic generation
    const help_message =
        \\ runzigc - a simple container runtime written in zig
        \\
        \\ Usage: runzigc SUBCOMMAND [options]
        \\
        \\ Subcommands:
        \\   init: initialize container
        \\   run: run a command inside the container
        \\
        \\ Options:
        \\   -h, --help     Print this help message
        \\   -v, --version  Print the version
    ;

    var parser = Command.new(allocator, "runzigc");
    defer parser.deinit();

    try parser.addArg(flag.boolean("help", 'h'));
    try parser.addArg(flag.boolean("version", 'v'));

    var subcmd_init = Command.new(allocator, "init");
    try parser.addSubcommand(subcmd_init);

    var subcmd_run = Command.new(allocator, "run");
    try parser.addSubcommand(subcmd_run);

    var args = try parser.parseProcess();
    defer args.deinit();

    if (args.isPresent("help")) {
        debug.print("{s}\n", .{help_message});
        os.exit(1);
    }

    // TODO(musaprg): automatic generation
    const version = "v0.0.0";
    if (args.isPresent("version")) {
        debug.print("runzigc version {s}\n", .{version});
        return;
    }

    if (args.isPresent("init")) {
        log.debug("init\n", .{});
        try init(allocator);
    } else if (args.isPresent("run")) {
        log.debug("run\n", .{});
        try run(allocator);
    } else {
        debug.print("{s}\n", .{help_message});
        os.exit(1);
    }
}
