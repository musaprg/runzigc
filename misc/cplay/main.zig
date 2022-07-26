const std = @import("std");
const os = std.os;
const linux = os.linux;
const print = std.debug.print;

fn parent(_: usize) !void {
    print("parent\n", .{});
    os.exit(0);
}

fn child() !void {
    print("child\n", .{});
    const child_args = [_:null]?[*:0]const u8{ "/bin/echo", "hello world", null };
    const envp = [_:null]?[*:0]const u8{null};
    os.execveZ("/bin/echo", &child_args, &envp) catch os.exit(1);
}

pub fn main() !void {
    var pid = linux.clone2(
        1024 * 1024,
        linux.CLONE.NEWIPC | linux.CLONE.NEWNET | linux.CLONE.NEWUSER,
    );
    //var pid = linux.fork();
    if (pid == -1) {
        print("fork failed\n", .{});
    } else if (pid == 0) {
        try child();
    } else {
        try parent(pid);
    }
}
