const std = @import("std");
const os = std.os;
const fs = std.fs;
const fmt = std.fmt;
const mem = std.mem;
const heap = std.heap;
const ArenaAllocator = heap.ArenaAllocator;
const linux = os.linux;
const print = std.debug.print;

const sync_t = enum(c_int) {
    SYNC_USERMAP_PLS = 0x40,
    SYNC_USERMAP_ACK = 0x41,
};

fn parent(allocator: mem.Allocator, cpid: os.pid_t, syncpipe: [2]os.fd_t) !void {
    var syncfd = syncpipe[0];
    os.close(syncpipe[1]);

    print("parent pid: {}\n", .{linux.getpid()});
    print("child pid: {}\n", .{cpid});

    var buf: [1]u8 = undefined;
    if (os.read(syncfd, &buf)) |size| {
        print("read {} bytes from child\n", .{size});
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
    // uid_map and gid_map are only writable from parent process.
    var uid = linux.getpid();
    var gid = linux.getpid();

    var string_pid = try fmt.allocPrint(allocator, "{}", .{cpid});
    defer allocator.free(string_pid);
    var uid_map_path = try fs.path.join(allocator, &[_][]const u8{ "/proc", string_pid, "uid_map" });
    defer allocator.free(uid_map_path);
    var gid_map_path = try fs.path.join(allocator, &[_][]const u8{ "/proc", string_pid, "gid_map" });
    defer allocator.free(gid_map_path);

    print("uid_map_path: {s}\n", .{uid_map_path});
    print("gid_map_path: {s}\n", .{gid_map_path});

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
        print("wrote {} bytes to child\n", .{size});
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

    const flags = linux.CLONE.NEWIPC | linux.CLONE.NEWNET | linux.CLONE.NEWUSER;
    if (linux.unshare(flags) == -1) {
        print("unshare failed\n", .{});
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
        print("setresuid failed\n", .{});
        return error.Unexpected;
    }

    const child_args = [_:null]?[*:0]const u8{ "/bin/sh", null };
    const envp = [_:null]?[*:0]const u8{null};
    return os.execveZ("/bin/sh", &child_args, &envp);
}

// Use fork and unshare to create a new process with a new PID
// youki: https://github.com/containers/youki/blob/619ae7d1eccbd82fd116465ed25ef410ace2a2a1/crates/libcontainer/src/process/container_main_process.rs#L206-L240
pub fn main() !void {
    var arena = ArenaAllocator.init(std.heap.page_allocator);
    defer arena.deinit();
    const allocator = arena.allocator();

    var syncsocket: [2]os.fd_t = undefined;
    if (linux.socketpair(linux.AF.UNIX, linux.SOCK.STREAM, 0, syncsocket) < 0) {
        print("socketpair failed\n", .{});
        os.exit(1);
    }

    var cpid = os.fork() catch {
        print("fork failed\n", .{});
        os.exit(1);
    };

    if (cpid == 0) { // child
        try child(allocator, syncsocket);
    } else { // parent
        try parent(allocator, cpid, syncsocket);
    }
}
