const std = @import("std");
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

const zig_arg = @import("zig-arg");

const sync_t = enum(c_int) {
    SYNC_USERMAP_PLS = 0x40,
    SYNC_USERMAP_ACK = 0x41,
};

fn parent(allocator: mem.Allocator, cpid: os.pid_t, syncpipe: [2]os.fd_t) !void {
    var syncfd = syncpipe[0];
    os.close(syncpipe[1]);

    log.debug("parent pid: {}\n", .{linux.getpid()});
    log.debug("child pid: {}\n", .{cpid});

    var buf: [1]u8 = undefined;
    if (os.read(syncfd, &buf)) |size| {
        log.debug("read {} bytes from child\n", .{size});
        if (size != 1) {
            return error.Unexpected;
        }
    } else |err| {
        return err;
    }
    switch (@intToEnum(sync_t, @intCast(c_int, buf[0]))) {
        .SYNC_USERMAP_PLS => {},
        else => unreachable,
    }

    // https://man7.org/linux/man-pages/man7/user_namespaces.7.html#:~:text=User%20and%20group%20ID%20mappings%3A%20uid_map%20and%20gid_map
    // uid_map and gid_map are only writable from parent process.
    var uid = linux.getpid();
    //const uid = 1000;
    var gid = linux.getpid();
    //const gid = 1000;

    var string_pid = try fmt.allocPrint(allocator, "{}", .{cpid});
    defer allocator.free(string_pid);
    var uid_map_path = try fs.path.join(allocator, &[_][]const u8{ "/proc", string_pid, "uid_map" });
    defer allocator.free(uid_map_path);
    var gid_map_path = try fs.path.join(allocator, &[_][]const u8{ "/proc", string_pid, "gid_map" });
    defer allocator.free(gid_map_path);

    log.debug("uid_map_path: {s}\n", .{uid_map_path});
    log.debug("gid_map_path: {s}\n", .{gid_map_path});

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
    if (os.write(syncfd, synctag)) |size| {
        log.debug("wrote {} bytes to child\n", .{size});
        if (size != 1) {
            return error.Unexpected;
        }
    } else |err| {
        return err;
    }

    var result = os.waitpid(cpid, 0); // i'm not sure how to handle WaitPidResult.status with zig, there's no macro like WIFEXITED
    _ = result.status;
}

fn child(allocator: mem.Allocator, syncpipe: [2]os.fd_t) !void {
    var syncfd = syncpipe[1];
    os.close(syncpipe[0]);

    _ = allocator;

    const flags = linux.CLONE.NEWIPC | linux.CLONE.NEWNET | linux.CLONE.NEWUSER | linux.CLONE.NEWUTS;
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

    const child_args = [_:null]?[*:0]const u8{ "/bin/sh", null };
    const envp = [_:null]?[*:0]const u8{null};
    return os.execveZ("/bin/sh", &child_args, &envp);
}

fn init(allocator: mem.Allocator) !void {
    _ = allocator;
    // TODO(musaprg): implement me
}

fn run(allocator: mem.Allocator) !void {
    _ = allocator;
    // TODO(musaprg): implement me
}

fn entrypoint(allocator: mem.Allocator) !void {
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
        try child(allocator, syncsocket);
    } else { // parent
        try parent(allocator, cpid, syncsocket);
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

    log.debug("args: {s}\n", .{args});
    log.debug("matchedSubcommand: {s}\n", .{args.subcommand});

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
        //try init(allocator);
        try entrypoint(allocator);
    } else if (args.isPresent("run")) {
        log.debug("run\n", .{});
        //try run(allocator);
        try entrypoint(allocator);
    }

    debug.print("{s}\n", .{help_message});
    os.exit(1);
}
