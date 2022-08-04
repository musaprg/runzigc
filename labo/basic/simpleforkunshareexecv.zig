const std = @import("std");
const os = std.os;
const linux = os.linux;
const print = std.debug.print;

fn parent(cpid: os.pid_t) !void {
    var result = os.waitpid(cpid, 0); // i'm not sure how to handle WaitPidResult.status with zig, there's no macro like WIFEXITED
    _ = result.status;
}

fn child() !void {
    const flags = linux.CLONE.NEWIPC | linux.CLONE.NEWNET | linux.CLONE.NEWUSER;
    if (linux.unshare(flags) == -1) {
        print("unshare failed\n", .{});
        os.exit(1);
    }

    const child_args = [_:null]?[*:0]const u8{ "/bin/sh", null };
    const envp = [_:null]?[*:0]const u8{null};
    try os.execveZ("/bin/sh", &child_args, &envp) catch return;
}

// Use fork and unshare to create a new process with a new PID
// youki: https://github.com/containers/youki/blob/619ae7d1eccbd82fd116465ed25ef410ace2a2a1/crates/libcontainer/src/process/container_main_process.rs#L206-L240
pub fn main() !void {
    var pid = os.fork() catch {
        print("fork failed\n", .{});
        os.exit(1);
    };

    if (pid == 0) { // child
        try child();
    } else { // parent
        try parent(pid);
    }
}
