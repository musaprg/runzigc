const std = @import("std");
const os = std.os;
const linux = os.linux;
const print = std.debug.print;

fn parent(stdinpipe: *[2]os.fd_t, stdoutpipe: *[2]os.fd_t, stderrpipe: *[2]os.fd_t) !void {
    //os.dup2(stdinpipe[1], os.STDIN_FILENO) catch os.exit(1);
    //os.dup2(stdoutpipe[0], os.STDOUT_FILENO) catch os.exit(1);
    //os.dup2(stderrpipe[0], os.STDERR_FILENO) catch os.exit(1);

    // close unused pipes in parent
    os.close(stdinpipe[0]);
    os.close(stdoutpipe[1]);
    os.close(stderrpipe[1]);
}

fn child(stdinpipe: *[2]os.fd_t, stdoutpipe: *[2]os.fd_t, stderrpipe: *[2]os.fd_t) !void {
    //os.dup2(stdinpipe[0], os.STDIN_FILENO) catch os.exit(1);
    //os.dup2(stdoutpipe[1], os.STDOUT_FILENO) catch os.exit(1);
    //os.dup2(stderrpipe[1], os.STDERR_FILENO) catch os.exit(1);

    // close unused pipes in child
    os.close(stdinpipe[1]);
    os.close(stdoutpipe[0]);
    os.close(stderrpipe[0]);

    const flags = linux.CLONE.NEWIPC | linux.CLONE.NEWNET | linux.CLONE.NEWUSER;
    if (linux.unshare(flags) == -1) {
        print("unshare failed\n", .{});
        os.exit(1);
    }

    const child_args = [_:null]?[*:0]const u8{ "/bin/sh", null };
    const envp = [_:null]?[*:0]const u8{null};
    os.execveZ("/bin/sh", &child_args, &envp) catch os.exit(1);
}

// Use fork and unshare to create a new process with a new PID
// youki: https://github.com/containers/youki/blob/619ae7d1eccbd82fd116465ed25ef410ace2a2a1/crates/libcontainer/src/process/container_main_process.rs#L206-L240
pub fn main() !void {
    // 0: read, 1: write
    var stdinpipe = os.pipe() catch os.exit(1);
    var stdoutpipe = os.pipe() catch os.exit(1);
    var stderrpipe = os.pipe() catch os.exit(1);

    var pid = os.fork() catch {
        print("fork failed\n", .{});
        os.exit(1);
    };

    if (pid == 0) { // child
        try child(&stdinpipe, &stdoutpipe, &stderrpipe);
    } else { // parent
        try parent(&stdinpipe, &stdoutpipe, &stderrpipe);
    }
}
