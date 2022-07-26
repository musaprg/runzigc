const std = @import("std");
const os = std.os;
const linux = os.linux;
const print = std.debug.print;

fn parent(_: usize) !void {
    os.exit(0);
}

fn child() !void {
    const child_args = [_:null]?[*:0]const u8{ "/bin/echo", "hello world", null };
    const envp = [_:null]?[*:0]const u8{null};
    os.execveZ("/bin/echo", &child_args, &envp) catch os.exit(1);
}

// Use fork and unshare to create a new process with a new PID
// youki: https://github.com/containers/youki/blob/619ae7d1eccbd82fd116465ed25ef410ace2a2a1/crates/libcontainer/src/process/container_main_process.rs#L206-L240
pub fn main() !void {
    var pid = linux.fork();
    if (pid == -1) {
        print("fork failed\n", .{});
    } else if (pid == 0) {
        try child();
    } else {
        try parent(pid);
    }
}
