const std = @import("std");
const assert = std.debug.assert;
const mem = std.mem;
const CrossTarget = std.zig.CrossTarget;
const Target = std.Target;
const builtin = @import("builtin");
const process = std.process;
const print = std.debug.print;

comptime {
    assert(builtin.link_libc);
    if (!builtin.is_test) {
        @export(main, .{ .name = "main" });
    }
}

pub fn fatal(comptime format: []const u8, args: anytype) noreturn {
    std.log.err(format, args);
    process.exit(1);
}

const usage =
    \\Usage: hello [your name]
    \\
;

pub fn main(argc: c_int, argv: [*][*:0]u8) callconv(.C) c_int {
    std.os.argv = argv[0..@intCast(usize, argc)];

    std.debug.maybeEnableSegfaultHandler();

    const gpa = std.heap.c_allocator;
    var arena_instance = std.heap.ArenaAllocator.init(gpa);
    defer arena_instance.deinit();
    const arena = arena_instance.allocator();

    const args = arena.alloc([]const u8, @intCast(usize, argc)) catch fatal("{s}", .{"OutOfMemory"});
    for (args) |*arg, i| {
        arg.* = mem.sliceTo(argv[i], 0);
    }

    if (args.len == 2) {
        print("Hello, {s}\n", .{args[1]});
    } else {
        std.log.info("{s}", .{usage});
        fatal("expected command argument", .{});
    }

    return 0;
}
