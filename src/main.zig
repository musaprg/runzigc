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

const syscall = @import("syscall.zig");
const util = @import("util.zig");

const Command = zig_arg.Command;
const flag = zig_arg.flag;

const native_arch = builtin.cpu.arch;

const zig_arg = @import("zig-arg");

const sync_t = enum(c_int) {
    SYNC_USERMAP_PLS = 0x40,
    SYNC_USERMAP_ACK = 0x41,
};

// set hostname and exec passed command
fn init(allocator: mem.Allocator) !void {
    _ = allocator;

    var status: usize = undefined;

    const hostname = "test";
    syscall.sethostname(hostname) catch |err| {
        log.debug("sethostname failed\n", .{});
        return err;
    };

    log.debug("GRANDCHILD: current uid: {}\n", .{linux.getuid()});
    log.debug("GRANDCHILD: current gid: {}\n", .{linux.getgid()});

    util.mkdirAll("/sys/fs/cgroup/cpu/my-container", 0700) catch |err| {
        switch (err) {
            error.PathAlreadyExists => {},
            else => {
                log.debug("mkdir failed: {}\n", .{err});
                return err;
            },
        }
    };

    const cgroup_cpu = try fs.openFileAbsolute("/sys/fs/cgroup/cpu/my-container/tasks", .{ .write = true });
    defer cgroup_cpu.close();

    const cgroup_cpu_content = try fmt.allocPrint(allocator, "{}\n", .{linux.getpid()});
    defer allocator.free(cgroup_cpu_content);

    try cgroup_cpu.writer().writeAll(cgroup_cpu_content);

    const cgroup_cpu_quota = try fs.openFileAbsolute("/sys/fs/cgroup/cpu/my-container/cpu.cfs_quota_us", .{ .write = true });
    defer cgroup_cpu_quota.close();

    const cgroup_cpu_quota_content = try fmt.allocPrint(allocator, "{}\n", .{1000});
    defer allocator.free(cgroup_cpu_quota_content);

    try cgroup_cpu_quota.writer().writeAll(cgroup_cpu_quota_content);

    try syscall.mount("proc", "/root/rootfs/proc", "proc", @enumToInt(syscall.MountFlags.MS_NOEXEC) | @enumToInt(syscall.MountFlags.MS_NOSUID) | @enumToInt(syscall.MountFlags.MS_NODEV), @ptrToInt(""));

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

    try syscall.mount("rootfs", "/root/rootfs", "", @enumToInt(syscall.MountFlags.MS_BIND) | @enumToInt(syscall.MountFlags.MS_REC), @ptrToInt(""));

    util.mkdirAll("/root/rootfs/oldrootfs", 0700) catch |err| {
        log.debug("makeDirAbsolute failed\n", .{});
        return err;
    };

    // TODO(musaprg): fix here, currently we need to create /root/pivotroot/proc before executing this
    syscall.pivot_root("rootfs", "/root/rootfs/oldrootfs") catch |err| {
        log.debug("pivot_root failed\n", .{});
        return err;
    };

    try syscall.umount("/oldrootfs", @enumToInt(syscall.UmountFlags.MNT_DETACH));

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

        syscall.setsid() catch |err| {
            log.debug("setresuid failed\n", .{});
            return err;
        };

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
