const std = @import("std");
const os = std.os;
const linux = os.linux;
const print = std.debug.print;
const assert = std.debug.assert;

fn parent(_: usize) !void {
    print("parent\n", .{});
    os.exit(0);
}

fn child(_: usize) callconv(.C) u8 {
    print("child\n", .{});
    const child_args = [_:null]?[*:0]const u8{ "/bin/echo", "hello world", null };
    const envp = [_:null]?[*:0]const u8{null};
    os.execveZ("/bin/echo", &child_args, &envp) catch return 1;
    return 0;
}

const STACK_SIZE = 1024 * 1024;

// NOT WORKING, need to fix
pub fn main() !void {
    // reference: https://github.com/ziglang/zig/blob/1a16b7214d88261f0e38b7ca4d15bcd76caaec4c/lib/std/Thread.zig#L896
    const page_size = std.mem.page_size;

    var guard_offset: usize = undefined;
    var stack_offset: usize = undefined;
    var tls_offset: usize = undefined;
    //var instance_offset: usize = undefined;

    const map_bytes = blk: {
        var bytes: usize = page_size;
        guard_offset = bytes;

        bytes += std.math.max(page_size, STACK_SIZE);
        bytes = std.mem.alignForward(bytes, page_size);
        stack_offset = bytes;

        bytes = std.mem.alignForward(bytes, linux.tls.tls_image.alloc_align);
        tls_offset = bytes;
        bytes += linux.tls.tls_image.alloc_size;

        //        bytes = std.mem.alignForward(bytes, @alignOf(fn (usize) callconv(.C) u8));
        //        instance_offset = bytes;
        //        bytes += @sizeOf(fn (usize) callconv(.C) u8);
        //
        bytes = std.mem.alignForward(bytes, page_size);
        break :blk bytes;
    };

    // map all memory needed without read/write permissions
    // to avoid committing the whole region right away
    const mapped = os.mmap(
        null,
        map_bytes,
        os.PROT.NONE,
        os.MAP.PRIVATE | os.MAP.ANONYMOUS,
        -1,
        0,
    ) catch |err| switch (err) {
        error.MemoryMappingNotSupported => unreachable,
        error.AccessDenied => unreachable,
        error.PermissionDenied => unreachable,
        else => |e| return e,
    };
    assert(mapped.len >= map_bytes);
    errdefer os.munmap(mapped);
    var tls_ptr = os.linux.tls.prepareTLS(mapped[tls_offset..]);
    const arg = "";

    // pub extern fn clone(func: CloneFn, stack: usize, flags: usize, arg: usize, ptid: *i32, tls: usize, ctid: *i32)
    // ref) https://github.com/ziglang/zig/blob/1a16b7214d88261f0e38b7ca4d15bcd76caaec4c/lib/std/os/linux/x86_64.zig#L104
    // ref) https://github.com/ziglang/zig/blob/1a16b7214d88261f0e38b7ca4d15bcd76caaec4c/lib/std/Thread.zig#L995-L1013
    const flags = linux.CLONE.NEWIPC | linux.CLONE.NEWNET | linux.CLONE.NEWUSER;
    var parent_tid: i32 = undefined;
    var child_tid: i32 = 1;
    switch (linux.getErrno(linux.clone(
        child,
        @ptrToInt(&mapped[stack_offset]), // stack pointer address
        flags,
        @ptrToInt(arg), // arg <- what's this???
        &parent_tid, // parent_tid
        tls_ptr, // thread local storage ptr address
        &child_tid, // child_tid
    ))) {
        .SUCCESS => return,
        .INVAL => unreachable,
        .NOMEM => return error.SystemResources,
        .NOSPC => unreachable,
        .PERM => unreachable,
        .USERS => unreachable,
        else => |e| return os.unexpectedErrno(e),
    }

    print("parent");
}
