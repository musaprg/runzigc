const std = @import("std");
const debug = std.debug;
const fmt = std.fmt;

const allocator = std.heap.page_allocator;

fn switchstr(num: i64) []const u8 {
    return switch(num) {
            1 => "one",
            2 => "two",
            3 => "three",
            else => |err| return fmt.allocPrint(allocator, "hogehoge {}", .{err}) catch "",
    };
}

pub fn main() !void {
    debug.print("hello, world\n", .{});
    debug.print("{s}\n", .{switchstr(1)});
    debug.print("{s}\n", .{switchstr(2)});
    debug.print("{s}\n", .{switchstr(3)});
    debug.print("{s}\n", .{switchstr(4)});
}
